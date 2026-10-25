# 6.2 Simulación por eventos discretos

> [Manual](../README.md) › [Arquitectura del simulador](README.md) › Simulación por eventos discretos

## El problema

Varios emisores emiten a la vez, cada uno con su PRI, y cada pulso tarda un tiempo distinto en llegar según la
distancia. El receptor tiene que recibir los pulsos **en orden de llegada**, que no es el orden de emisión:

```
  emisor A (lejos)    emite en t = 0       ──── 10 µs de vuelo ────▶  llega en 10 µs
  emisor B (cerca)    emite en t = 5 µs    ─ 1 µs ─▶                  llega en  6 µs   ← llega antes
```

B emite después pero llega antes. El simulador tiene que manejar ese entrelazado de forma exacta y sin desperdiciar
cálculo.

## Tres formas de avanzar el tiempo

| Enfoque | Cómo funciona | Problema |
| --- | --- | --- |
| **Paso fijo** | El reloj avanza Δt y en cada paso se mira quién emite o recibe | Con Δt grande se pierde precisión; con Δt = 1 ns, una misión de 120 s son 1,2·10¹¹ pasos, casi todos vacíos |
| **Flujos perezosos con fusión** | Cada emisor genera su flujo de llegadas y se van mezclando por orden | Supone que las llegadas de un emisor salen ordenadas; con plataformas móviles deja de ser cierto |
| **Eventos discretos** ✅ | Una cola de eventos ordenada por instante; el reloj **salta** al siguiente evento | Ninguno relevante aquí; es el enfoque estándar para este tipo de sistemas |

En la simulación por eventos discretos **el tiempo no avanza solo**: avanza de evento en evento. Entre dos eventos no
pasa nada que haya que calcular, así que no se calcula.

## Los dos eventos del simulador

| Evento | Significado | Qué hace al ejecutarse |
| --- | --- | --- |
| **Emit** | "El emisor E emite el pulso P en t" | Propaga P por el canal, programa su **Arrival**, pide a E su siguiente pulso y programa su **Emit** |
| **Arrival** | "El pulso P llega al receptor en t" | Entrega P al receptor, que lo detecta (o no), lo mide y lo escribe |

Cada evento, al ejecutarse, puede **programar eventos futuros**. Así, una simulación entera arranca con un solo Emit
por emisor y se alimenta sola.

### Traza de ejemplo

Emisor A a 2998 m (retardo 10 µs), emisor B a 299,79 m (retardo 1 µs), PRI de 1 ms en los dos, misión de 0,5 ms.
B empieza en 5 µs:

| Reloj | Evento ejecutado | Eventos que programa | Cola después |
| --- | --- | --- | --- |
| — | arranque | Emit A₀ @0, Emit B₀ @5 µs | A₀@0, B₀@5 |
| 0 | Emit A₀ | Arrival A₀ @10 µs (A₁ caería en 1 ms ≥ 0,5 ms: no se programa) | B₀@5, ArrA₀@10 |
| 5 µs | Emit B₀ | Arrival B₀ @6 µs (B₁ caería en 1,005 ms: no) | ArrB₀@6, ArrA₀@10 |
| 6 µs | Arrival B₀ | — (el receptor escribe `pulseId` 0) | ArrA₀@10 |
| 10 µs | Arrival A₀ | — (`pulseId` 1) | vacía → fin |

El CSV sale ordenado por llegada **sin ordenar nada al final**: el orden lo da la cola. Es exactamente el test
`RunOrdersByArrivalTime` del plan (tarea 14).

## La cola de prioridad: `EventScheduler`

El planificador es una pieza genérica: guarda acciones (`std::function<void()>`) con su instante y las ejecuta en
orden. No sabe qué es un pulso ni un radar.

```
  schedule(t, acción)   añade un evento; lanza std::logic_error si t es anterior al reloj actual
  runAll()              ejecuta eventos en orden hasta que la cola queda vacía
  empty()               ¿quedan eventos?
  get_currentTimeNs()   instante del evento que se está ejecutando
```

### Orden total: instante y número de secuencia

Dos eventos pueden caer en el **mismo** nanosegundo (dos emisores con el mismo inicio, por ejemplo). Si el desempate
dependiera de detalles internos del contenedor, dos ejecuciones podrían dar CSV distintos. Por eso cada evento lleva un
**número de secuencia** creciente, asignado al programarlo, y la cola ordena por la pareja:

```
  (instante, secuencia)    →   menor instante primero; a igual instante, el que se programó antes
```

Es un orden **total**: no hay dos eventos "iguales", y la salida es reproducible.

### Cómo se implementa

- Un `std::vector<Event>` que se mantiene como **montículo** (*heap*) con `std::push_heap` / `std::pop_heap` y un
  comparador que lo convierte en montículo de mínimos por `(at, sequence)`.
- Se descartó `std::priority_queue`: su `top()` devuelve una referencia `const`, así que no se puede **mover** el
  evento fuera (habría que copiar el `std::function` y el pulso que captura, en cada evento).
- **El orden del bucle importa.** Primero se saca el evento del montículo y se mueve a una variable local; después se
  actualiza el reloj y por último se ejecuta la acción. Si se ejecutara la acción con el evento todavía dentro del
  vector, los `schedule` que hace la propia acción podrían realocar el vector y dejar colgando la referencia al evento
  en ejecución (AddressSanitizer lo detecta).

El comparador y el bucle de `runAll` son una de las piezas marcadas para que las escribas tú (plan, "Reparto de
trabajo"), así que aquí solo se describe qué deben hacer.

### Quién vive más que quién

Las acciones capturan `this` de la `Simulation`. Por eso:

- `EventScheduler` **no se puede copiar** (copiar acciones que apuntan a otro objeto no tiene sentido) y no tiene `==`
  (un `std::function` no es comparable).
- `Simulation` no se puede copiar **ni mover**: si se moviera, las acciones seguirían apuntando a la dirección antigua.
- Las acciones capturan los datos **por valor** (el pulso entero, el índice del emisor), nunca referencias a variables
  locales que ya no existirán cuando se ejecuten.

## El final de la simulación

Un emisor deja de programar emisiones en cuanto su siguiente instante es `≥ durationS`. Pero los pulsos ya emitidos
siguen **en vuelo**: su Arrival está en la cola. `runAll` no se para en `durationS`, sino cuando la cola está **vacía**,
así que esos pulsos se entregan igualmente (con `toaNs ≥ durationS`). Un receptor real también los oiría.

## En este proyecto

- `sim::EventScheduler` y `sim::Simulation` (`src/Simulator/Engine/`), tareas 13 y 14 del plan.
- Excepciones a las reglas de clase por este diseño: E4 (`EventScheduler`) y E5 (`Simulation`) en el plan,
  decisión 2.
- Los tests usan `ctest --timeout 60`: si un error deja la cola llenándose sin fin, el test falla en lugar de colgarse.

## Ideas clave

- El reloj salta de evento en evento; entre eventos no se calcula nada.
- Dos eventos: Emit y Arrival. Cada uno programa los siguientes.
- Orden total por `(instante, secuencia)` ⇒ salida determinista.
- Se ejecuta hasta vaciar la cola: los pulsos en vuelo al final también se registran.

---

[← 6.1 Visión general](01-vision-general.md) · [↑ Arquitectura del simulador](README.md) · [Siguiente: 6.3 Modelo de dominio →](03-modelo-de-dominio.md)

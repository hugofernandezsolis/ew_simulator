# 6.3 Modelo de dominio

> [Manual](../README.md) › [Arquitectura del simulador](README.md) › Modelo de dominio

## Dos mundos: lo intrínseco y lo situacional

Un radar tiene propiedades que no dependen de dónde esté (su PRI, su frecuencia, su antena, cada cuánto gira) y otras
que sí (su posición, hacia dónde apunta, en qué modo está ahora). El diseño las separa:

| | **Catálogo** (intrínseco) | **Misión** (situacional) |
| --- | --- | --- |
| Pregunta | ¿**Cómo es** este tipo de radar? | ¿**Dónde, cuándo y hacia dónde** emite este radar concreto? |
| Contiene | Tipos de emisor, modos, PRI, RF, PW, tipo y periodo de scan, antena, potencia | Posición, calendario de modos, azimut inicial, centro del sector, apuntamiento |
| Clases | `Catalog`, `EmitterType`, `EmitterMode`, `ScanSpec` (`sigint`) | `Mission`, `Emitter`, `Segment`, `ScanPattern` orientado (`sim`) |
| Analogía | La ficha técnica de un modelo de coche | Un coche concreto: dónde está aparcado y qué ruta hace hoy |

Esta separación es la misma que hace la guerra electrónica real: el catálogo es una **librería de emisores**
([5.3](../05-analisis-de-senal/03-identificacion-de-emisores.md)), y la misión es el escenario.

## Diagrama de clases

```
  CATÁLOGO (sigint, inmutable)                   MISIÓN (sim)
  ────────────────────────────                   ────────────
  Catalog                                        Mission
   └─* EmitterType  "SearchRadar_X"               ├─ durationNs
        └─* EmitterMode  "search", "track"         ├─ ReceiverSpec (id, posición, ganancia, sensibilidad)
             ├─ peakPowerDbm                       └─* Emitter  "E1"
             ├─ intrapulseModulation                    ├─ id, posición, inicio, fin
             ├─ PriGenerator   ◁── shared_ptr<const>    ├─* Segment ───────────────────────┐
             ├─ RfGenerator    ◁── shared_ptr<const>    │    ├─ modeId ("off" = silencio)  │
             ├─ PwGenerator    ◁── shared_ptr<const>    │    ├─ duración                   │
             ├─ ScanSpec (tipo, periodo, elevación,     │    ├─ EmitterMode ◁── compartido ┘ con el catálogo
             │            anchura del sector)           │    └─ ScanPattern (ScanSpec + orientación de la misión)
             └─ AntennaPattern ◁── shared_ptr<const>    └─ estado: segmento activo, próximo instante,
                                                                    índice de pulso, pri_/rf_/pw_ (unique_ptr, clones)
```

## Composición, no herencia

Un modo de radar combina cuatro dimensiones **independientes**: cómo varía la PRI, cómo varía la RF, cómo varía la PW
y cómo barre la antena. Hay dos formas de modelarlo:

- **Con herencia**, haría falta una clase por combinación: `StaggerPriFixedRfCircularScanMode`… Con 4 tipos de PRI,
  2 de RF, 1 de PW y 3 de scan ya son 24 clases, y cada tipo nuevo multiplica.
- **Con composición** ✅, un modo *tiene* un generador de cada tipo, detrás de una interfaz:

| Interfaz | Qué responde | Implementaciones (v1) |
| --- | --- | --- |
| `PriGenerator` | ¿Cuál es la siguiente PRI? | `FixedPri`, `StaggerPri`, `SlidingPri`, `DwellSwitchPri` |
| `RfGenerator` | ¿Cuál es la siguiente frecuencia? | `FixedRf`, `ListRf` |
| `PwGenerator` | ¿Cuál es el siguiente ancho de pulso? | `FixedPw` |
| `ScanPattern` | ¿Hacia dónde apunta el haz en t? | `FixedScan`, `CircularScan`, `SectorScan` |
| `AntennaPattern` | ¿Qué ganancia hay a este desvío del haz? | `GaussianAntennaPattern` |

Añadir un tipo nuevo (por ejemplo, PRI con jitter) es **una clase nueva** que implementa una interfaz existente, más su
rama en el loader. Nada más cambia.

La teoría de cada generador está en el bloque 2: [PRI](../02-radar/03-modulacion-de-pri.md),
[RF](../02-radar/04-rf-y-modulacion-intrapulso.md), [antenas](../02-radar/05-antenas.md) y
[barrido](../02-radar/06-barrido-de-antena.md).

### Comparar y copiar a través de una interfaz

Dos problemas típicos de las jerarquías polimórficas, y cómo se resuelven:

- **Copia sin *slicing*.** Si se copia un `PriGenerator&` que en realidad es un `StaggerPri`, una copia normal solo
  copiaría la parte base. Por eso las interfaces tienen la copia `protected` y ofrecen `clone()`, que devuelve un
  `unique_ptr` al tipo dinámico correcto.
- **Igualdad entre tipos distintos.** `FixedPri{1000}` y `StaggerPri{[1000]}` no son iguales aunque den la misma
  secuencia. El `operator==` de la base compara primero el **tipo dinámico** (`typeid`) y, si coincide, delega en un
  `isEqual` de la clase concreta.

## Prototipo e instancia

Dos emisores `E1` y `E2` del mismo tipo y modo comparten la **descripción** del modo, pero cada uno tiene que llevar
**su propia** cuenta: si `E1` va por el tercer valor del stagger, eso no puede afectar a `E2`.

| | Prototipo (en el modo) | Instancia (en el emisor) |
| --- | --- | --- |
| Tipo | `std::shared_ptr<const PriGenerator>` | `std::unique_ptr<PriGenerator>` |
| ¿Se comparte? | Sí: todos los emisores del modo apuntan al mismo | No: cada emisor tiene el suyo |
| ¿Avanza? | **No puede**: el `const` está en el objeto, así que `next()` no compila | Sí: es el que lleva la cuenta |
| Se crea | Al cargar el catálogo | Al **entrar en un segmento**, con `clone()` del prototipo |

Es como un **molde** y las **piezas**: el molde no se gasta, y cada pieza sale nueva. Una consecuencia buscada: como
cada segmento clona los generadores al empezar, **cada segmento arranca con el estado a cero** (el stagger vuelve a su
primer valor, la lista de RF también).

Al copiar un `Emitter`, sus `unique_ptr` se copian **en profundidad** (con `clone()`): la copia y el original avanzan
por separado.

## `ScanSpec` + misión = `ScanPattern`

El scan está repartido entre los dos mundos:

- El **modo** sabe el tipo de scan y su forma: circular de 6 s a 2° de elevación (`ScanSpec`).
- La **misión** sabe la orientación: este emisor empieza su barrido en azimut 0°, o este sector está centrado en 120°.

El loader de la misión combina las dos partes y construye un `ScanPattern` ya orientado, que se guarda en el
`Segment`. Así el catálogo describe el radar completo sin saber nada del escenario.

| `ScanSpec.kind` | Lo que aporta el segmento de la misión |
| --- | --- |
| `fixed` | `pointingAzimuthDeg`, `pointingElevationDeg` |
| `circular` | `initialAzimuthDeg` |
| `sector` | `centerAzimuthDeg` |

## Clases con estado

`Emitter`, los generadores con memoria (`StaggerPri`, `SlidingPri`, `DwellSwitchPri`, `ListRf`), `Receiver` (cuenta
`pulseId`), `EventScheduler` y `Simulation` cambian al usarse. El diseño les da:

- Un **constructor de configuración**, que recibe solo la configuración y fija el estado inicial (índice 0, contador 0…).
  Es el que usan los loaders y los tests de comportamiento.
- **Atributos de estado protegidos**: su setter de referencia es privado, para que nadie desde fuera deje el objeto en
  un estado imposible.
- **Desconfianza defensiva**: si aun así encuentran un estado imposible (lista vacía, PRI ≤ 0, puntero nulo) lanzan
  `std::logic_error`. No se usa `assert`, que desaparece en Release y dejaría, por ejemplo, un bucle infinito con
  PRI 0.

Hay una trampa de diseño que afecta a todas ellas: dentro de un método no `const`, el getter por valor (`get_pri()`)
devuelve una **copia**, y avanzar esa copia no avanza el emisor. Para mutar se usa el setter de referencia
(`set_pri()->next()`). Está explicada en el plan, decisión 2, "Cómo cumplir R11 sin trampas".

## En este proyecto

- Catálogo: `src/SigInt/Emission/` (generadores, `ScanSpec`, scans, antena, `EmitterMode`) y `src/SigInt/Library/`
  (`EmitterType`, `Catalog`). Plan, tareas 3–8.
- Misión: `src/Simulator/Emitter/` (`Segment`, `Emitter`) y `src/Simulator/Engine/` (`Mission`, `ReceiverSpec`).
  Plan, tareas 9 y 14.
- `EmitterMode` es el modelo **generativo** de un modo. El descriptor para **reconocer** emisores, con rangos y
  tolerancias, será otra clase (spec §1).

## Ideas clave

- Catálogo = cómo es el radar; misión = dónde, cuándo y hacia dónde.
- Composición: un modo tiene un generador de cada tipo; ampliar es añadir una clase.
- Prototipo `shared_ptr<const>` compartido e inmutable; instancia `unique_ptr` clonada por segmento.
- El scan concreto nace de juntar `ScanSpec` (modo) y la orientación (misión).

---

[← 6.2 Simulación por eventos discretos](02-simulacion-por-eventos-discretos.md) · [↑ Arquitectura del simulador](README.md) · [Siguiente: 6.4 Flujo de un pulso →](04-flujo-de-un-pulso.md)

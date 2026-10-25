# 6.1 Visión general

> [Manual](../README.md) › [Arquitectura del simulador](README.md) › Visión general

## Qué hace el sistema

`ews` es un simulador **a nivel de pulso**: no genera la forma de onda (muestras IQ), sino la lista de pulsos que
llegan a un receptor ESM, con lo que este mediría de cada uno y con la verdad de quién lo emitió.

```
  scenarios/catalog/*.json  ──┐   (cómo es cada tipo de radar)
                              ├──▶  ews  ──▶  salida.csv   (una fila por pulso detectado:
  scenarios/missions/x.json ──┘   (quién, dónde, cuándo)            PDW medido + columnas truth_)
```

- **Entrada**: un **catálogo** de tipos de emisor (un JSON por tipo) y una **misión** (dónde está cada emisor y el
  receptor, qué modo usa cada emisor en cada tramo de tiempo, cuánto dura la simulación).
- **Salida**: un CSV con una fila por pulso **detectado**, en orden de llegada (ver
  [5.1 El PDW](../05-analisis-de-senal/01-pdw.md) y [5.5](../05-analisis-de-senal/05-evaluacion-con-verdad-de-terreno.md)).
- Uso: `ews <mision.json> <salida.csv>`.

## Qué simula y qué no

| Simula (v1) | Fuera de alcance, con la puerta abierta |
| --- | --- |
| Varios emisores y **un** receptor, en posiciones **fijas** | Plataformas móviles, varios receptores, geolocalización |
| PRI fija, stagger, sliding y dwell & switch; RF fija o por lista; PW fija | Jitter y agilidad aleatoria (toda aleatoriedad) |
| Scan fijo, circular y sectorial; antena gaussiana con suelo de lóbulos | Otros diagramas y scans (cónico, raster…) |
| Retardo y pérdida en espacio libre | Multitrayecto, horizonte, pérdidas atmosféricas y del sistema |
| Sensibilidad y ganancia del receptor, AoA sin error | Error de medida, saturación, solape de pulsos, banda de RF del receptor |

La lista completa está en la spec, §1. La simulación es **determinista**: la misma entrada da siempre el mismo CSV,
byte a byte.

## Dos librerías y dos namespaces

El código se reparte según una regla sencilla:

> Las clases que definen una **señal**, una parte de ella o su **tratamiento** van en `sigint`. Las que solo tienen
> sentido **dentro del simulador** van en `sim`.

| Librería | Namespace | Componentes | Contenido |
| --- | --- | --- | --- |
| `src/SigInt/` | `sigint` | `Units` | `Time` (ns enteros) y conversiones |
| | | `PulseDescriptors` | `PulseDescriptorWords`, `AngleOfArrival`, `IntrapulseModulation` |
| | | `Geometry` | `Position`, `distanceM`, `directionFromTo`, funciones de propagación |
| | | `Emission` | generadores de PRI, RF y PW; `ScanSpec` y scans; antena; `EmitterMode`; `EmittedPulse`, `IncidentPulse` |
| | | `Library` | `EmitterType`, `Catalog` |
| `src/Simulator/` | `sim` | `Emitter` | `Segment`, `Emitter` |
| | | `Channel` | `PropagationChannel` |
| | | `Receiver` | `Receiver`, `GroundTruth`, `PulseRecordWriter`, `CsvPulseRecordWriter` |
| | | `Engine` | `EventScheduler`, `ReceiverSpec`, `Mission`, `Simulation` |
| | | `Config` | `ConfigError`, loaders del catálogo y de la misión, `JsonReader` |
| | | `Runner` | `runMission` |

¿Por qué esta separación? Porque el trabajo futuro (deinterleaver, clasificador, estimación de distancia) también
necesitará PDW, ángulos, la FSPL o la librería de emisores, y **no** debe depender del simulador. Si `Catalog` o
`freeSpacePathLossDb` vivieran en `sim`, un clasificador tendría que enlazar con el simulador entero para usarlos.

Algunas piezas que no son "señal" (`Time`, `Position`) van también en `sigint` porque las usan clases de señal: si
estuvieran en `sim`, `SigInt` dependería de `Simulator` y habría un ciclo.

## Dependencias

Las dependencias van siempre en un sentido. `SigInt` no depende de nada; `Simulator` depende de `SigInt`.

```
  Simulator (sim)                               SigInt (sigint): cada capa usa las de debajo
  ───────────────                               ────────────────────────────────────────────
  main     ─▶ Config, Runner                    Library           EmitterType, Catalog
  Config   ─▶ Engine, Library, Emission            │
  Runner   ─▶ Engine, Receiver                     ▼
  Engine   ─▶ Emitter, Channel, Receiver        Emission          generadores, scans, antena, modo, pulsos
  Emitter  ─▶ Emission                             │
  Channel  ─▶ Geometry, Emission                   ▼
  Receiver ─▶ PulseDescriptors, Emission        Geometry          Position, direcciones, propagación
                                                   │
                                                   ▼
                                                PulseDescriptors  PDW, AngleOfArrival, IntrapulseModulation
                                                   │
                                                   ▼
                                                Units             Time
```

Dentro del simulador, el flujo de un pulso también es de un solo sentido: **emisor → canal → receptor**. Ninguna pieza
conoce a las que tiene detrás:

- el emisor no sabe que existe un canal,
- el canal no conoce la antena del receptor,
- el receptor no sabe de dónde viene el pulso, solo lo que trae.

Por eso cada pieza se puede probar sola, con entradas construidas a mano en el test.

Una dependencia externa: **nlohmann/json 3.12.0**, usada **solo** dentro de `Simulator/Config/src/`. Ninguna cabecera
pública la incluye (ver [6.5](05-configuracion-y-carga.md)).

## Las piezas en una frase

| Pieza | Responsabilidad |
| --- | --- |
| Loaders (`Config`) | Leer JSON, convertir a SI, validar y construir los objetos de dominio. Los únicos que conocen JSON. |
| `Catalog` / `EmitterType` / `EmitterMode` | Librería de emisores: cómo es cada tipo de radar y cada uno de sus modos. |
| `Mission` | Lo que se va a simular: duración, receptor y emisores ya construidos. |
| `Emitter` | Una instancia concreta de un tipo: posición, calendario de segmentos y estado. Produce `EmittedPulse`. |
| `PropagationChannel` | Convierte un `EmittedPulse` en un `IncidentPulse`: instante y dirección de llegada, potencia en el receptor. |
| `Receiver` | Decide si detecta el pulso, lo mide y entrega PDW + verdad al escritor. |
| `PulseRecordWriter` | Escribe cada registro; hoy en CSV. |
| `EventScheduler` | Cola de eventos ordenada en el tiempo. No sabe nada de radares. |
| `Simulation` | Une todo: programa los eventos y los ejecuta hasta vaciar la cola. |
| `runMission` / `main` | Orquestación: cargar, abrir la salida, ejecutar, gestionar errores. |

## En este proyecto

- Diseño completo: spec del simulador, §3 ([`2026-10-24-simulator-design.md`](../../superpowers/specs/2026-10-24-simulator-design.md)).
- Reparto en librerías y orden de implementación: plan, decisión 1 y tareas 1–17
  ([`2026-10-24-simulator.md`](../../superpowers/plans/2026-10-24-simulator.md)).
- Cada clase sigue las reglas de `.claude/rules/how_to_write_a_class.md`; las excepciones están en el plan,
  decisión 2.

## Ideas clave

- Entrada: catálogo + misión en JSON. Salida: CSV de PDW + verdad.
- `sigint` = señal y su tratamiento (reutilizable); `sim` = solo el simulador.
- Dependencias en un único sentido: `Simulator → SigInt` y emisor → canal → receptor.
- JSON solo en `Config`: el resto del dominio se prueba sin ficheros.

---

[← Arquitectura del simulador](README.md) · [↑ Manual](../README.md) · [Siguiente: 6.2 Simulación por eventos discretos →](02-simulacion-por-eventos-discretos.md)

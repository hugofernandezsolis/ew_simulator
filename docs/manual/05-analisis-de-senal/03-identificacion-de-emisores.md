# 5.3 Identificación de emisores

> [Manual](../README.md) › [Análisis de señal](README.md) › Identificación de emisores

## Del grupo de pulsos al tipo de radar

Tras el deinterleaving se tiene un grupo de pulsos que, con suerte, viene de un solo emisor. El siguiente paso es
**identificarlo**: decir qué tipo de radar es (y en qué modo está) comparando sus parámetros con una **librería de
emisores**.

## El descriptor de emisor

De cada grupo se extrae un **descriptor**: los parámetros intrínsecos del emisor, que no dependen de dónde esté el
receptor.

| Parámetro | De dónde sale |
| --- | --- |
| Frecuencia (valor, o lista y patrón si es ágil) | Campo de cada PDW |
| PW | Campo de cada PDW |
| MOP (tipo y parámetro) | Campo de cada PDW |
| PRI: valores y tipo de patrón (fija, stagger…) | Diferencias de TOA ([5.2](02-deinterleaving.md)) |
| Tipo y periodo de scan | Evolución de la amplitud ([5.4](04-analisis-de-scan.md)) |

Los parámetros extrínsecos (AoA, amplitud absoluta) no identifican el tipo, pero sitúan al emisor y alimentan el orden
de batalla electrónico.

## La librería de emisores

Una librería de emisores (en la literatura, a veces EPL, *Emitter Parameter List*) guarda, para cada tipo de radar
conocido, los rangos de sus parámetros en cada modo. Una entrada de reconocimiento sería algo así:

```
Tipo SearchRadar_X, modo "search":
  RF      2,9 – 3,1 GHz, fija
  PRI     stagger de 3 posiciones: 1000 / 1200 / 1100 µs (±1 %)
  PW      0,9 – 1,1 µs
  MOP     ninguna
  Scan    circular, periodo 5,5 – 6,5 s
```

Se usan **rangos y tolerancias** y no valores exactos porque las medidas tienen error, cada ejemplar del mismo radar es
un poco distinto, y los datos de inteligencia son imprecisos.

## Comparar

Para cada grupo se buscan las entradas de la librería compatibles con su descriptor y se puntúan: cuántos parámetros
encajan y con qué margen. El resultado puede ser:

- **Una identificación clara.**
- **Ambigua**: varios tipos compatibles (comparten banda, PRI parecida…). Hacen falta más pulsos o más parámetros
  (el scan suele desempatar).
- **Desconocido**: ninguna entrada encaja. Puede ser un radar nuevo, un modo no catalogado o un grupo mal formado por
  el deinterleaver. Los desconocidos son justo lo que interesa a ELINT.

## Modelo generativo frente a descriptor

El proyecto ya tiene una "librería de emisores", el catálogo (`sigint::Catalog`), pero es un **modelo generativo**: cada
modo dice exactamente cómo **producir** los pulsos (PRI de 1000 µs exactos, un generador concreto con su estado). Para
**reconocer** hace falta otra cosa:

| Modelo generativo (simulador) | Descriptor de reconocimiento (clasificador) |
| --- | --- |
| Valores exactos | Rangos y tolerancias |
| Generadores con estado (`next()`) | Datos sin estado, comparables |
| Una clase por tipo de patrón | Acceso directo a "¿es un stagger de valores X?" |

Por eso el descriptor de reconocimiento será una clase distinta, que el loader podrá construir a partir del mismo
JSON del catálogo (spec §1, fuera de alcance). Los generadores no deben intentar hacer las dos cosas.

## En este proyecto

- `sigint::EmitterType` (nombre y modos) y `sigint::Catalog` (`SigInt/Library`) forman la librería de emisores del
  simulador. Están en `sigint` precisamente porque un clasificador futuro tendrá que consultarla.
- `sigint::EmitterMode` agrupa los parámetros intrínsecos de un modo: potencia, MOP, generadores de PRI, RF y PW,
  `ScanSpec` (tipo y periodo de scan) y antena.
- La verdad de terreno (`truth_emitterId`, `truth_modeId`) permite comprobar si un clasificador acierta el emisor y el
  modo.

## Ideas clave

- Identificar = comparar el descriptor de un grupo con una librería de emisores.
- Las librerías usan rangos y tolerancias.
- El catálogo del simulador es generativo; el descriptor de reconocimiento será otra clase.

---

[← 5.2 Deinterleaving](02-deinterleaving.md) · [↑ Análisis de señal](README.md) · [Siguiente: 5.4 Análisis de scan →](04-analisis-de-scan.md)

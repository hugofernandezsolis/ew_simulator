# 5.1 El PDW

> [Manual](../README.md) › [Análisis de señal](README.md) › El PDW

## Qué es

Un **PDW** (*Pulse Descriptor Word*) es el resumen digital de **un** pulso interceptado. El receptor no guarda la
señal (sería una cantidad enorme de datos): mide unos pocos parámetros de cada pulso y entrega un PDW por pulso. Todo
el procesado posterior trabaja sobre esos PDW.

## Campos típicos

| Campo | Qué representa |
| --- | --- |
| `pulseId` | Número de secuencia: ordenar los PDW y detectar pérdidas |
| `toa` | *Time Of Arrival*: instante del flanco de subida del pulso. Base para calcular la PRI |
| `frequency` | Frecuencia portadora medida |
| `pulseWidth` | Duración del pulso (medida a mitad de amplitud) |
| `amplitude` | Potencia recibida: análisis de scan, estimación de distancia |
| `aoa` (azimut, elevación) | Ángulo de llegada |
| `intrapulseModulation` | Tipo de modulación intrapulso (MOP) |
| `modulationParameter` | Parámetro de la MOP (ancho de banda del chirp, número de chips…) |
| `polarization` | Polarización recibida |
| `snr` | Relación señal/ruido: calidad de la medida |
| `channelId` | Qué receptor, canal o antena captó el pulso |
| `flags` | Saturación, solape de pulsos, onda continua, pulso truncado… |

**La PRI no es un campo del PDW**: no se puede medir en un pulso aislado. Se deduce de las diferencias de TOA entre
pulsos del mismo emisor, después de separarlos ([5.2](02-deinterleaving.md)).

## Intrínsecos y extrínsecos

Los campos se reparten en dos familias, y esa distinción guía todo el análisis:

| Familia | Qué describe | Campos | Uso |
| --- | --- | --- | --- |
| **Intrínsecos** | Lo que el radar **transmite**; no depende de dónde esté el receptor | frecuencia, PW, MOP y su parámetro, polarización | **Identificar** el tipo de radar |
| **Extrínsecos** | La **medida**: geometría, propagación, receptor | TOA, AoA, amplitud, SNR, canal | **Separar** emisores (sobre todo el AoA) y **situarlos** |

Algunos parámetros intrínsecos no salen de un PDW, sino de un grupo de PDW: la PRI y su patrón, o el tipo y el
periodo de scan. Son los que forman el **descriptor de emisor** ([5.3](03-identificacion-de-emisores.md)).

## Representación en software

Recomendaciones habituales:

- **Tiempos como enteros** (ns o ticks de reloj): un `double` pierde precisión con tiempos absolutos grandes.
- **Tipos de ancho fijo** (`std::uint64_t`…), sobre todo si el PDW viaja por red o se guarda en disco.
- **La unidad en el nombre** (`toaNs`, `frequencyHz`, `amplitudeDbm`): es el error más común.

## En este proyecto

`sigint::PulseDescriptorWords` (`src/SigInt/PulseDescriptors/`) implementa en la v1 estos campos:

| Atributo | Tipo | Columna del CSV |
| --- | --- | --- |
| `pulseId_` | `std::uint64_t` | `pulseId` |
| `toaNs_` | `Time` (ns enteros) | `toaNs` |
| `frequencyHz_` | `double` | `frequencyMHz` |
| `pulseWidthNs_` | `Time` | `pulseWidthUs` |
| `amplitudeDbm_` | `float` | `amplitudeDbm` |
| `aoa_` | `AngleOfArrival` | `azimuthDeg`, `elevationDeg` |
| `intrapulseModulation_` | `IntrapulseModulation` | `intrapulseModulation` |

- `modulationParameter`, `polarization`, `snr`, `channelId` y `flags` quedan para más adelante.
- `AngleOfArrival` es la primera parte del PDW extraída como clase propia, porque tiene invariantes de rango y
  operaciones propias. La agrupación del resto (`Waveform`…) está en
  [`2026-10-23-pdw-attribute-grouping-design.md`](../../superpowers/specs/2026-10-23-pdw-attribute-grouping-design.md).
- El simulador escribe un PDW por pulso detectado, acompañado de un `GroundTruth` ([5.5](05-evaluacion-con-verdad-de-terreno.md)).

## Ideas clave

- Un PDW resume un pulso; el análisis trabaja con flujos de PDW.
- Intrínsecos identifican; extrínsecos separan y sitúan.
- La PRI se deduce de los TOA, no se mide en un pulso.

---

[← Análisis de señal](README.md) · [↑ Manual](../README.md) · [Siguiente: 5.2 Deinterleaving →](02-deinterleaving.md)

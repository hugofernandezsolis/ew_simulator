# 5.4 Análisis de scan

> [Manual](../README.md) › [Análisis de señal](README.md) › Análisis de scan

## La idea

Cuando la antena de un radar barre, la potencia que llega a un receptor fijo sube y baja: es alta cuando el haz le
apunta y baja (lóbulos laterales) el resto del tiempo (ver [2.6 Barrido de antena](../02-radar/06-barrido-de-antena.md)).
Si se representa la **amplitud** de los pulsos de un emisor frente al **TOA**, se ve el barrido. Analizar esa curva
permite deducir el **tipo** y el **periodo** de scan, dos de los rasgos más útiles para identificar un radar.

Este análisis necesita los pulsos ya separados por emisor ([5.2](02-deinterleaving.md)).

## Qué se mide

| Rasgo | Cómo se obtiene |
| --- | --- |
| **Periodo de scan** | Intervalo entre los máximos de ráfagas consecutivas |
| **Tipo de scan** | La forma del patrón: ver la tabla siguiente |
| **Ancho de haz** (aproximado) | De la duración de la ráfaga: con scan circular, `θ ≈ 360 · duración / periodo` (medida a −3 dB respecto al pico de la ráfaga) |
| **Nivel de lóbulos laterales** (aproximado) | Diferencia entre el pico de la ráfaga y la amplitud entre ráfagas, si el receptor llega a verlas |

### Huellas de cada tipo

| Tipo | Lo que se ve en amplitud frente a tiempo |
| --- | --- |
| **Circular** | Ráfagas iguales a intervalos regulares |
| **Sectorial bidireccional** | Dos ráfagas por periodo a intervalos **desiguales** (salvo que el receptor esté en el centro del sector); el haz pasa a la ida y a la vuelta |
| **Sectorial unidireccional** | Una ráfaga por periodo |
| **Fijo / seguimiento** | Amplitud constante, sin ráfagas (si el haz apunta al receptor) o nivel bajo constante (si no) |
| **Cónico** | Amplitud modulada de forma casi sinusoidal, a la frecuencia de giro del cono |
| **Raster** | Grupos de ráfagas, una por cada línea a distinta elevación |

## Un ejemplo con números

En la misión golden del proyecto, el emisor A gira con periodo de 0,05 s (comprimido a propósito para los tests) y un
haz de 30°. Con sensibilidad −60 dBm, el receptor solo detecta los pulsos mientras la ganancia hacia él supera
−2,47 dBi, es decir, con un desvío de hasta ±37° respecto al eje del haz:

- Ráfagas de 9 pulsos, centradas en 25 ms y 75 ms (cuando el haz pasa por la dirección del receptor).
- Separación entre ráfagas: 50 ms = **periodo de scan**.
- Duración de cada ráfaga: unos 10 ms. Esa duración la limita el umbral de detección y no el ancho a −3 dB; para
  estimar el ancho de haz habría que medir dónde cae la amplitud 3 dB respecto al pico de la ráfaga.

## Dificultades

- **Pocos pulsos por ráfaga** con haces estrechos o PRI largas: la forma se reconstruye mal.
- **Variaciones de amplitud por propagación** (multitrayecto, desvanecimientos) que no son del barrido.
- **Saturación** del receptor, que aplana el pico.
- **Cambios de modo**: el barrido cambia, o pasa a seguimiento.
- **Receptor móvil**: su propio movimiento modifica el patrón.

## En este proyecto

- La amplitud del PDW (`amplitudeDbm`) refleja la ganancia de la antena del emisor hacia el receptor. Por eso el CSV
  contiene la información necesaria para el análisis de scan.
- La verdad de terreno incluye `truth_txGainDbi`, que permite comprobar en qué parte del diagrama de antena estaba el
  receptor en cada pulso (lóbulo principal o lateral).
- El tipo y el periodo de scan reales están en el `ScanSpec` del modo del catálogo.
- El analizador de scan no está implementado; es trabajo futuro, como el resto del bloque.

## Ideas clave

- Amplitud frente a TOA de un emisor = su patrón de barrido visto desde el receptor.
- Periodo = separación entre ráfagas; tipo = forma del patrón.
- Necesita los pulsos ya separados por emisor.

---

[← 5.3 Identificación de emisores](03-identificacion-de-emisores.md) · [↑ Análisis de señal](README.md) · [Siguiente: 5.5 Evaluación con verdad de terreno →](05-evaluacion-con-verdad-de-terreno.md)

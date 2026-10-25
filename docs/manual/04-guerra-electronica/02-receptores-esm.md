# 4.2 Receptores ESM

> [Manual](../README.md) › [Guerra electrónica](README.md) › Receptores ESM

## Qué hace un receptor ESM

Un receptor ESM vigila una banda de frecuencias muy ancha (del orden de 0,5–18 GHz o más) esperando pulsos de radares
que no conoce de antemano. Por cada pulso que detecta, un **codificador** mide sus parámetros y genera un PDW.

El reto principal es la incertidumbre: no sabe ni cuándo, ni a qué frecuencia, ni desde dónde llegará el siguiente
pulso.

## Arquitecturas

Cada arquitectura ofrece un compromiso distinto entre cobertura, sensibilidad, precisión y coste:

| Arquitectura | Idea | Fuerte en | Débil en |
| --- | --- | --- | --- |
| **Cristal-vídeo** | Detector de potencia de banda ancha | Simple, ve toda la banda a la vez | Sensibilidad; no mide la frecuencia |
| **IFM** (*Instantaneous Frequency Measurement*) | Mide la frecuencia de un pulso al instante | Frecuencia precisa en banda ancha | Se confunde con dos pulsos simultáneos |
| **Superheterodino** | Sintoniza una banda estrecha cada vez | Sensibilidad y selectividad | Solo ve una parte de la banda a la vez |
| **Canalizado** | Muchos receptores estrechos en paralelo | Banda ancha y pulsos simultáneos | Complejidad, coste |
| **Digital** | Digitaliza la banda y procesa por software | Flexibilidad, varios pulsos a la vez | Velocidad de muestreo y potencia de cálculo |

## Parámetros de un receptor

### Sensibilidad

La potencia mínima que detecta (ver [3.3 Balance de enlace](../03-propagacion/03-balance-de-enlace.md)). Cuanto más
ancha es la banda instantánea, más ruido entra y peor es la sensibilidad.

### Probabilidad de interceptación (POI)

La probabilidad de que el receptor esté "mirando" en la frecuencia y la dirección correctas cuando llega el pulso.
Un superheterodino que barre la banda puede estar sintonizado en otro sitio justo cuando pasa el haz del radar, y
perderse la ráfaga entera. Un receptor de banda ancha y omnidireccional tiene POI cercana a 1.

### Rango dinámico

La diferencia entre la señal más débil y la más fuerte que el receptor mide correctamente (del orden de 50–70 dB). Por
encima **satura**: la amplitud medida se recorta y pueden aparecer señales espurias. El PDW suele llevar un *flag*
de saturación.

### Cobertura en frecuencia

Un receptor solo ve las frecuencias de su banda. Un radar fuera de ella es invisible.

### Tiempo muerto y solape de pulsos

Mientras procesa un pulso, el receptor puede no ver otro que llegue a la vez (*pulse-on-pulse*). Con muchos emisores
el solape es inevitable: con N emisores de PRI media T y PW τ, la fracción de pulsos solapados crece aproximadamente
como `N · τ / T`. Con 20 emisores de τ = 1 µs y T = 1 ms es del orden del 2 %, y en entornos densos mucho más. Los
pulsos solapados se pierden o se miden mal (por ejemplo, dos pulsos fundidos en uno más largo).

## El modelo del proyecto

El receptor del simulador es deliberadamente **ideal**:

| Aspecto | Receptor real | Simulador v1 |
| --- | --- | --- |
| Detección | Probabilística, con ruido | Umbral determinista: `P_rx ≥ sensitivityDbm` |
| Antena | Diagrama con ganancia variable según la dirección | Ganancia constante `gainDbi` |
| Banda de RF | Finita | Infinita |
| Rango dinámico | Finito, con saturación | Infinito |
| Pulsos simultáneos | Se pierden o se funden | Cada uno se detecta por separado |
| Medida | Con errores | Exacta (error 0) |
| Pérdidas internas | Varios dB | 0 |

Cada una de esas simplificaciones está en la lista de "fuera de alcance" de la spec (§1). El diseño permite añadirlas:
el `Receiver` ya recibe los pulsos en orden de llegada y decide qué escribe y cómo rellena el PDW.

## En este proyecto

- `sim::Receiver` (`Simulator/Receiver`): posición, `gainDbi`, `sensitivityDbm` y un escritor de registros. Su método
  `receive` calcula `P_rx`, decide si detecta, mide el AoA, asigna el `pulseId` (solo a los pulsos detectados) y
  escribe el PDW con su verdad de terreno.
- En el JSON de la misión: `receiver: { id, positionM, gainDbi, sensitivityDbm }`.

## Ideas clave

- Un ESM vigila una banda ancha sin saber qué llegará.
- Compromisos: cobertura frente a sensibilidad, POI, rango dinámico y pulsos simultáneos.
- El receptor del simulador es ideal; sus simplificaciones están documentadas como fuera de alcance.

---

[← 4.1 Qué es la guerra electrónica](01-que-es-la-guerra-electronica.md) · [↑ Guerra electrónica](README.md) · [Siguiente: 4.3 Medida del ángulo de llegada →](03-medida-del-aoa.md)

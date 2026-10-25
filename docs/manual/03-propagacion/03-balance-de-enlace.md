# 3.3 Balance de enlace

> [Manual](../README.md) › [Propagación](README.md) › Balance de enlace

El **balance de enlace** responde a la pregunta clave de un receptor: ¿llega este pulso con potencia suficiente para
detectarlo?

## La ecuación de Friis (en dB)

Juntando todo lo anterior, la potencia de pico que entrega la antena del receptor es:

```
P_rx = P_tx + G_tx(θ) − FSPL(d, f) + G_rx
```

| Término | Qué es | Página |
| --- | --- | --- |
| `P_tx` | potencia de pico del emisor (dBm) | [1.2](../01-fundamentos/02-decibelios-y-potencia.md) |
| `G_tx(θ)` | ganancia de la antena del emisor **en la dirección del receptor** (dBi) | [2.5](../02-radar/05-antenas.md) |
| `FSPL` | pérdida en espacio libre (dB) | [3.1](01-espacio-libre.md) |
| `G_rx` | ganancia de la antena del receptor (dBi) | [4.2](../04-guerra-electronica/02-receptores-esm.md) |

`P_tx + G_tx(θ)` es la EIRP hacia el receptor.

Es una ecuación **de ida**: la señal solo hace el camino emisor → receptor y cae con `d²`. La ecuación radar, en
cambio, es de ida y vuelta y cae con `d⁴` (ver [2.1](../02-radar/01-principio-del-radar.md)).

## Sensibilidad

El receptor detecta un pulso si su potencia supera un umbral, la **sensibilidad**:

```
detectado  ⇔  P_rx ≥ S
```

La sensibilidad depende del ruido térmico y del propio receptor:

```
S = −174 dBm/Hz + 10·log10(B) + NF + SNR_min
```

| Término | Significado |
| --- | --- |
| −174 dBm/Hz | ruido térmico a temperatura ambiente (kT) |
| `B` | ancho de banda del receptor (Hz) |
| `NF` | figura de ruido del receptor (dB): cuánto ruido añade |
| `SNR_min` | relación señal/ruido necesaria para detectar con fiabilidad |

Ejemplo: B = 10 MHz (70 dB), NF = 10 dB, SNR_min = 15 dB → `S = −174 + 70 + 10 + 15 = −79 dBm`.

Un receptor de banda ancha (que vigila muchas frecuencias a la vez) tiene un `B` grande y por tanto peor
sensibilidad; esa es una de las contrapartidas de diseño de un receptor ESM.

## Ejemplo completo

Radar a 25 km, 3 GHz, P_tx = 90 dBm, G_max = 30 dBi, suelo de lóbulos laterales −8 dBi. Receptor con 0 dBi y
sensibilidad −70 dBm. FSPL = 129,95 dB.

| Situación | P_rx | ¿Detectado? |
| --- | --- | --- |
| El haz apunta al receptor | 90 + 30 − 129,95 + 0 ≈ −10 dBm | Sí, con 60 dB de margen |
| El receptor está en un lóbulo lateral | 90 − 8 − 129,95 + 0 ≈ −48 dBm | Sí, con 22 dB de margen |

A esa distancia el receptor oye el radar **todo el tiempo**, también por los lóbulos laterales. Es lo normal en ESM a
decenas de kilómetros.

## La ventaja de alcance del ESM

¿Hasta dónde detectaría este receptor al radar? La pérdida máxima tolerable es `P_tx + G_tx + G_rx − S`:

- Por el lóbulo principal: 90 + 30 + 0 + 70 = 190 dB → d ≈ 25 000 km.
- Por los lóbulos laterales: 90 − 8 + 0 + 70 = 152 dB → d ≈ 316 km.

En la práctica, el límite lo pone el **horizonte**, no la potencia (ver [3.2](02-horizonte-radar.md)). Un radar, en
cambio, para ver a un blanco tiene que recibir su eco, que cae con `d⁴`: su alcance es de cientos de km como mucho.
**El ESM oye al radar mucho antes de que el radar le vea a él.**

## Ráfagas limpias

Para que un receptor vea el barrido de un radar como ráfagas separadas por silencio, la sensibilidad tiene que estar
**entre** el nivel del lóbulo principal y el de los laterales.

Ejemplo de la misión golden del proyecto: emisor A a 30 km, 3 GHz, P_tx = 74 dBm, G_max = 16 dBi, suelo −9 dBi;
sensibilidad −60 dBm.

- Pico: 74 + 16 − 131,5 ≈ −41,5 dBm → detectado.
- Suelo: 74 − 9 − 131,5 ≈ −66,5 dBm → no detectado.

El receptor solo oye los pulsos de cuando el haz pasa cerca de él: ráfagas de 9 pulsos separadas por silencio.

## En este proyecto

El cálculo se reparte entre dos piezas (spec §4):

- `PropagationChannel` calcula la **potencia isotrópica** en el receptor, `P_iso = P_tx + G_tx − FSPL`, sin conocer
  la antena del receptor.
- `Receiver` suma su ganancia (`P_rx = P_iso + gainDbi`) y compara con `sensitivityDbm` (`≥`). Los pulsos descartados
  no se escriben.

La amplitud del PDW (`amplitudeDbm`) es `P_rx`: potencia de pico a la salida de la antena, sin pérdidas del receptor.
Las pérdidas del sistema, la banda de RF y el rango dinámico (saturación) del receptor están fuera de alcance.

## Ideas clave

- `P_rx = P_tx + G_tx(θ) − FSPL + G_rx`; detectado si `P_rx ≥ S`.
- `S = −174 + 10·log10(B) + NF + SNR_min` (dBm).
- La señal directa cae con `d²` y el eco con `d⁴`: de ahí la ventaja del ESM.
- Ráfagas limpias ⇔ la sensibilidad está entre el pico y el suelo.

---

[← 3.2 Horizonte radar](02-horizonte-radar.md) · [↑ Propagación](README.md) · [Siguiente bloque: 4. Guerra electrónica →](../04-guerra-electronica/README.md)

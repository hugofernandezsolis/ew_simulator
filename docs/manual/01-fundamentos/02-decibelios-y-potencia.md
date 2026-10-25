# 1.2 Decibelios y potencia

> [Manual](../README.md) › [Fundamentos](README.md) › Decibelios y potencia

## Por qué decibelios

En radar las potencias abarcan muchísimos órdenes de magnitud: un radar emite un megavatio y un receptor detecta
señales de una billonésima de milivatio. Escribirlo en vatios es incómodo (1 000 000 W frente a 0,000 000 000 000 001 W)
y obliga a multiplicar y dividir números enormes.

El **decibelio** usa una escala logarítmica, que convierte esas multiplicaciones en sumas y deja los números en un
rango manejable.

## Definición

Un decibelio expresa una **relación** entre dos potencias:

```
X (dB) = 10 · log10(P1 / P2)
```

| Relación lineal | En dB |
| --- | --- |
| ×1 | 0 dB |
| ×2 | ≈ +3 dB |
| ×10 | +10 dB |
| ×100 | +20 dB |
| ×1 000 000 | +60 dB |
| ÷2 | ≈ −3 dB |
| ÷10 | −10 dB |

Dos reglas que se usan constantemente:

- **+3 dB ≈ el doble**, −3 dB ≈ la mitad.
- **+10 dB = ×10**.

## Unidades derivadas

Cuando la potencia de referencia es fija, el decibelio pasa a ser una unidad absoluta:

| Unidad | Referencia | Ejemplo |
| --- | --- | --- |
| **dBm** | 1 mW | 0 dBm = 1 mW; 30 dBm = 1 W; 60 dBm = 1 kW; 90 dBm = 1 MW; −60 dBm = 1 nW |
| **dBW** | 1 W | 0 dBW = 30 dBm |
| **dBi** | antena isotrópica (radia igual en todas las direcciones) | Una antena de 30 dBi concentra en su dirección principal 1000 veces más potencia que una isotrópica |

Conversión entre vatios y dBm:

```
P(dBm) = 10 · log10(P(W) / 0,001)
P(W)   = 0,001 · 10^(P(dBm) / 10)
```

## Por qué todo se suma

La gran ventaja del logaritmo es que `log(a · b) = log(a) + log(b)`. Una cadena de ganancias y pérdidas, que en
lineal sería un producto, en dB es una suma:

```
Lineal:  P_rx = P_tx · G_tx · (1 / L) · G_rx
En dB:   P_rx = P_tx + G_tx − L + G_rx
```

Ejemplo: 90 dBm emitidos, 30 dBi de antena, 130 dB de pérdida y 0 dBi en recepción dan
`90 + 30 − 130 + 0 = −10 dBm` recibidos. Esta suma es exactamente el **balance de enlace** que calcula el simulador
(ver [3.3 Balance de enlace](../03-propagacion/03-balance-de-enlace.md)).

## Cuidado: los dB no se suman con todo

- Se pueden **sumar dB con dB** (ganancias y pérdidas) y **dBm + dB = dBm** (una potencia multiplicada por una
  ganancia).
- **No** se pueden sumar dos potencias en dBm para obtener la potencia total: 0 dBm + 0 dBm no es 0 dBm ni 0 + 0;
  son 1 mW + 1 mW = 2 mW ≈ 3 dBm. Para sumar potencias hay que pasar a lineal.

## Potencia de pico y potencia media

Un radar pulsado no emite de forma continua: emite pulsos muy cortos y espera entre ellos. Por eso se distinguen dos
potencias:

- **Potencia de pico**: la que hay *durante* el pulso.
- **Potencia media**: la promediada en el tiempo, contando los silencios.

```
P_media = P_pico · (PW / PRI)        (PW / PRI es el ciclo de trabajo, ver 2.2)
```

Ejemplo: 1 MW de pico (90 dBm), pulsos de 1 µs cada 1 ms → ciclo de trabajo 0,001 → potencia media 1 kW (60 dBm).

Para **detectar** un pulso lo que importa es la potencia de pico: el receptor ve el pulso mientras dura, no su
promedio.

## En este proyecto

- Todas las potencias y ganancias se manejan en dB: `peakPowerDbm`, `peakGainDbi`, `sidelobeLevelDb`, `gainDbi`,
  `sensitivityDbm` (JSON) y `amplitudeDbm`, `truth_txGainDbi`, `truth_eirpDbm` (CSV).
- `peakPowerDbm` es potencia de **pico** (spec §5).
- La validación limita potencias y ganancias a [−300, 300] dB para rechazar valores absurdos antes de simular.

## Ideas clave

- dB = relación; dBm = potencia absoluta respecto a 1 mW; dBi = ganancia respecto a una antena isotrópica.
- +3 dB ≈ ×2; +10 dB = ×10.
- En dB las cadenas de ganancias y pérdidas se suman.
- Para detectar pulsos importa la potencia de pico.

---

[← 1.1 Ondas electromagnéticas](01-ondas-electromagneticas.md) · [↑ Fundamentos](README.md) · [Siguiente: 1.3 Coordenadas y ángulos →](03-coordenadas-y-angulos.md)

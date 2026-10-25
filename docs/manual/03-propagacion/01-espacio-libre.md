# 3.1 Propagación en espacio libre

> [Manual](../README.md) › [Propagación](README.md) › Propagación en espacio libre

"Espacio libre" significa sin obstáculos, sin suelo que refleje y sin atmósfera que absorba. Es el modelo más simple
y el que usa el simulador.

## Retardo de propagación

La señal tarda en llegar:

```
retardo = d / c
```

| Distancia | Retardo |
| --- | --- |
| 299,792458 m | 1000 ns = 1 µs |
| 3 km | ≈ 10 µs |
| 25 km | ≈ 83,4 µs |
| 150 km | ≈ 500 µs |

El instante de llegada de un pulso (TOA) es el de emisión más el retardo: `t_a = t_e + d / c`.

## Pérdida en espacio libre (FSPL)

### De dónde sale

Imagina el emisor en el centro de una esfera. La potencia emitida se reparte sobre la superficie de la esfera, que
crece con el cuadrado del radio. A una distancia `d`, la **densidad de potencia** es:

```
S = EIRP / (4π · d²)          (W/m²)
```

Una antena receptora captura la potencia que cae sobre su **área efectiva**. Para una antena isotrópica esa área es
`λ² / (4π)`. Multiplicando:

```
P_rx = EIRP · λ² / (4π · d)²  ⇒  pérdida = (4π · d / λ)²
```

Esta es la **pérdida en espacio libre** (FSPL, *Free-Space Path Loss*). Combina dos efectos: la dispersión esférica
(`d²`) y el tamaño de la antena receptora isotrópica, que es más pequeña a frecuencias altas (`λ²`).

### En decibelios

Con `λ = c / f`:

```
FSPL(dB) = 20·log10(d) + 20·log10(f) + 20·log10(4π / c)
         = 20·log10(d) + 20·log10(f) − 147,55          (d en m, f en Hz)
```

La constante exacta es −147,5522. El proyecto usa −147,55 a propósito, porque los valores esperados de los tests se
calcularon con ella.

Ejemplos:

| d | f | FSPL |
| --- | --- | --- |
| 1 km | 1 GHz | 92,45 dB |
| 20 km | 9 GHz | 137,6 dB |
| 25 km | 3 GHz | 129,95 dB |
| 30 km | 3 GHz | 131,5 dB |

Dos consecuencias prácticas:

- **Duplicar la distancia cuesta 6 dB** (20·log10(2) ≈ 6).
- A la misma distancia, **más frecuencia ⇒ más pérdida** (por el área efectiva más pequeña).

## Campo lejano

La fórmula solo vale en el **campo lejano**, lejos de la antena. Si `d < λ / (4π)`, la FSPL sale negativa y el
receptor "recibiría más de lo emitido", lo que es imposible. Por ejemplo, a 3 GHz eso ocurre por debajo de 8 mm, y a
30 MHz por debajo de unos 0,8 m.

El proyecto lo evita con dos reglas de validación: cada emisor a **d ≥ 1 m** del receptor y frecuencias **≥ 30 MHz**.
Con las dos, la FSPL es siempre positiva.

## Otras pérdidas (fuera de alcance)

En la realidad hay más pérdidas que la FSPL:

- **Atmosféricas**: absorción del oxígeno y el vapor de agua, importante a frecuencias altas.
- **Lluvia**: muy importante por encima de unos 10 GHz.
- **Polarización**: si la antena receptora no está alineada con la onda (ver [1.1](../01-fundamentos/01-ondas-electromagneticas.md)).
- **Del sistema**: cables, conectores y radomos en el emisor y en el receptor.

## En este proyecto

- Funciones libres en `SigInt/Geometry` (`Propagation.h`): `propagationDelay(d)` (redondea al ns más cercano),
  `freeSpacePathLossDb(d, f)` y `wrapOffsetDeg`.
- Están en `sigint` y no en el simulador porque también sirven al procesado: por ejemplo, para estimar la distancia
  a un emisor conocido a partir de la amplitud recibida.
- `PropagationChannel` (`Simulator/Channel`) las aplica a cada pulso.
- Las pérdidas adicionales están fuera de alcance (spec §1).

## Ideas clave

- Retardo = d / c; 1 µs ≈ 300 m.
- `FSPL = 20·log10(d) + 20·log10(f) − 147,55`.
- Doble distancia = 6 dB más de pérdida.
- La fórmula solo vale en campo lejano.

---

[← Propagación](README.md) · [↑ Manual](../README.md) · [Siguiente: 3.2 Horizonte radar →](02-horizonte-radar.md)

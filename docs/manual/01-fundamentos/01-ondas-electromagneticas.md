# 1.1 Ondas electromagnéticas

> [Manual](../README.md) › [Fundamentos](README.md) › Ondas electromagnéticas

## Qué es una onda electromagnética

Una onda electromagnética es una perturbación de los campos eléctrico y magnético que se propaga por el espacio. No
necesita un medio: viaja también en el vacío. Un radar, una radio o un móvil emiten este tipo de ondas a través de su
antena, y otra antena las capta a distancia.

Para este proyecto basta con tres propiedades:

| Magnitud | Símbolo | Unidad | Qué indica |
| --- | --- | --- | --- |
| Frecuencia | `f` | hercio (Hz) = oscilaciones por segundo | Cuántas veces por segundo oscila el campo |
| Longitud de onda | `λ` | metro (m) | Distancia que recorre la onda durante una oscilación |
| Velocidad de propagación | `c` | m/s | En el vacío (y, a efectos prácticos, en el aire) es la velocidad de la luz |

## La velocidad de la luz

```
c = 299 792 458 m/s   (valor exacto, por definición del metro)
```

Dos equivalencias que conviene tener en la cabeza:

- En **1 µs** la onda recorre ≈ **300 m**.
- En **1 ns** recorre ≈ **0,3 m** (30 cm).

Por eso el proyecto guarda los tiempos como un entero en nanosegundos: 1 ns de resolución equivale a unos 30 cm de
distancia, más que suficiente para un simulador de pulsos.

## Relación entre frecuencia y longitud de onda

```
λ = c / f
```

Ejemplos:

| Frecuencia | Longitud de onda | Uso típico |
| --- | --- | --- |
| 100 MHz | 3 m | Radio FM, radares de vigilancia de muy largo alcance (VHF) |
| 1 GHz | 30 cm | Radares de vigilancia en banda L |
| 3 GHz | 10 cm | Radares de vigilancia en banda S |
| 10 GHz | 3 cm | Radares de control de tiro y navegación en banda X |

La longitud de onda importa porque el tamaño de una antena se mide "en longitudes de onda": para conseguir un haz
estrecho hace falta una antena muchas veces mayor que `λ`. Por eso los radares de alta frecuencia (banda X) pueden
tener antenas pequeñas con haces finos, y los de baja frecuencia necesitan antenas enormes.

## Bandas de frecuencia

En radar se usan las letras de la norma IEEE 521:

| Banda | Frecuencias | Ejemplos de uso |
| --- | --- | --- |
| HF | 3–30 MHz | Radares sobre el horizonte |
| VHF | 30–300 MHz | Vigilancia de muy largo alcance |
| UHF | 300 MHz–1 GHz | Vigilancia de largo alcance |
| L | 1–2 GHz | Vigilancia aérea en ruta, IFF |
| S | 2–4 GHz | Vigilancia aérea y naval, meteorológicos |
| C | 4–8 GHz | Seguimiento, meteorológicos |
| X | 8–12 GHz | Control de tiro, navegación marina, radares de aviones |
| Ku | 12–18 GHz | Alta resolución, buscadores de misiles |
| K / Ka | 18–27 / 27–40 GHz | Muy corto alcance, alta resolución |

Regla general: **a menor frecuencia, más alcance y peor resolución**; a mayor frecuencia, haces más finos y mejor
precisión, pero más atenuación.

## Polarización

El campo eléctrico de la onda oscila en una dirección concreta, que se llama polarización: horizontal, vertical o
circular. Si la antena receptora no tiene la misma polarización que la onda, recibe menos potencia (pérdida por
desadaptación de polarización). Con polarizaciones lineal y circular la pérdida es de 3 dB; entre dos polarizaciones
ortogonales, en teoría la pérdida es total.

La polarización es también un rasgo que ayuda a identificar un emisor, porque cada radar usa la suya.

## En este proyecto

- `c` es la constante `kSpeedOfLightMps` (`Units.h`, Tarea 1 del plan) y se usa para calcular el retardo de
  propagación (ver [3.1 Propagación en espacio libre](../03-propagacion/01-espacio-libre.md)).
- La frecuencia de cada pulso la dan los generadores de RF (`FixedRf`, `ListRf`) y se guarda en el PDW en hercios
  (`frequencyHz_`). En el JSON y en el CSV se escribe en megahercios (`frequencyMHz`).
- La validación admite frecuencias entre 30 MHz y 300 GHz: el rango de radar y ESM, que además garantiza que la
  fórmula de pérdida en espacio libre sea válida (spec §5).
- La polarización está **fuera de alcance** en la primera versión (spec §1).

## Ideas clave

- `λ = c / f`. A 3 GHz, λ = 10 cm.
- En 1 ns la luz recorre 30 cm: por eso el tiempo se guarda en nanosegundos enteros.
- Las bandas (L, S, C, X…) agrupan radares con usos parecidos.

---

[← Fundamentos](README.md) · [↑ Manual](../README.md) · [Siguiente: 1.2 Decibelios y potencia →](02-decibelios-y-potencia.md)

# 2.1 Principio del radar

> [Manual](../README.md) › [Radar](README.md) › Principio del radar

## La idea: emitir y escuchar el eco

**Radar** viene de *RAdio Detection And Ranging*: detección y medida de distancia por radio. Funciona así:

1. El radar emite un pulso de energía electromagnética en una dirección.
2. El pulso viaja a la velocidad de la luz, choca con un objeto (el **blanco**) y parte de la energía vuelve.
3. El radar recibe el eco y mide cuánto ha tardado.

La distancia sale del tiempo de ida y vuelta:

```
R = c · Δt / 2
```

El `/ 2` es porque el pulso hace el camino dos veces. Ejemplo: un eco que tarda 100 µs viene de
`299 792 458 · 100·10⁻⁶ / 2 ≈ 15 km`.

La dirección del blanco es la dirección a la que apuntaba la antena cuando llegó el eco. Por eso los radares usan
antenas muy directivas (ver [2.5 Antenas](05-antenas.md)).

## La ecuación radar

¿Cuánta potencia vuelve? La **ecuación radar** (para un radar monoestático, que emite y recibe con la misma antena):

```
          P_t · G² · λ² · σ
P_r  =  ─────────────────────
             (4π)³ · R⁴
```

| Símbolo | Significado |
| --- | --- |
| `P_t` | potencia de pico emitida |
| `G` | ganancia de la antena (dos veces: al emitir y al recibir) |
| `λ` | longitud de onda |
| `σ` | sección radar del blanco (RCS), en m²: cuánto "refleja" |
| `R` | distancia al blanco |

Lo esencial es el **`R⁴`**: la señal se debilita con la distancia al cuadrado en la ida y otra vez en la vuelta. Si
la distancia se duplica, el eco es 16 veces más débil (−12 dB).

## Por qué esto importa en guerra electrónica

Un receptor de guerra electrónica (ESM) no escucha ecos: escucha **directamente** el pulso que emite el radar. Esa
señal solo hace el camino de ida, así que se debilita con `R²`, no con `R⁴` (ver
[3.3 Balance de enlace](../03-propagacion/03-balance-de-enlace.md)).

Consecuencia: un receptor ESM detecta a un radar desde mucho más lejos de lo que ese radar puede detectar al
receptor. Esta **ventaja de alcance** es la razón de ser de la vigilancia electrónica.

## Tipos de radar según su función

| Tipo | Qué hace | Rasgos típicos |
| --- | --- | --- |
| **Vigilancia** (*search*) | Explora un volumen grande buscando blancos | Antena que gira (scan circular), haz en abanico, PRI larga para alcance largo |
| **Seguimiento / control de tiro** (*track*, *fire control*) | Sigue un blanco concreto con precisión | Haz estrecho (pincel) apuntado al blanco, PRI corta, frecuencia alta (banda X) |
| **Navegación** | Detecta costa y barcos | Banda X o S, antena giratoria |
| **Meteorológico** | Mide precipitación | Bandas S, C o X |

Un mismo radar puede tener varios **modos** (por ejemplo, búsqueda y seguimiento) con parámetros distintos, y cambiar
de uno a otro según la situación. Por eso en el proyecto un tipo de emisor tiene una lista de modos y la misión dice
qué modo usa en cada momento.

## Pulsado frente a onda continua

- **Radar pulsado**: emite pulsos cortos y escucha en los silencios. Mide la distancia por el tiempo de vuelo. Es el
  tipo que simula el proyecto.
- **Radar de onda continua** (CW, FMCW): emite sin parar y mide la distancia o la velocidad por cambios de
  frecuencia. No produce pulsos, así que no encaja en un simulador a nivel de pulso.

## En este proyecto

- Un **tipo de emisor** del catálogo (`SearchRadar_X`) tiene varios **modos** (`search`, `track`), cada uno con su
  potencia, PRI, RF, PW, scan y antena (spec §5).
- La **misión** dice dónde está cada emisor y qué modo usa en cada tramo de tiempo (su calendario de segmentos).
- El simulador no modela blancos ni ecos: simula lo que oye un receptor ESM, es decir, el pulso directo del radar.

## Ideas clave

- `R = c · Δt / 2` para el eco.
- El eco cae con `R⁴`; la señal directa que oye un ESM cae con `R²`, de ahí su ventaja de alcance.
- Un radar puede tener varios modos con parámetros distintos.

---

[← Radar](README.md) · [↑ Manual](../README.md) · [Siguiente: 2.2 Forma de onda pulsada →](02-forma-de-onda-pulsada.md)

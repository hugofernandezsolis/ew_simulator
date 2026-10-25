# 2.2 Forma de onda pulsada

> [Manual](../README.md) › [Radar](README.md) › Forma de onda pulsada

## Anatomía de un tren de pulsos

```
potencia
   │  ┌─┐          ┌─┐          ┌─┐
   │  │ │          │ │          │ │
   │  │ │          │ │          │ │
   └──┴─┴──────────┴─┴──────────┴─┴────── tiempo
      ├─┤
       PW
      ├────────────┤
           PRI
```

| Parámetro | Nombre | Qué es | Valores típicos |
| --- | --- | --- | --- |
| **PW** | *Pulse Width*, ancho de pulso | Cuánto dura cada pulso | 0,1–100 µs |
| **PRI** | *Pulse Repetition Interval* | Tiempo entre el inicio de un pulso y el del siguiente | 10 µs – 10 ms |
| **PRF** | *Pulse Repetition Frequency* | Pulsos por segundo: `PRF = 1 / PRI` | 100 Hz – 100 kHz |
| **Ciclo de trabajo** | *duty cycle* | Fracción del tiempo en que el radar emite: `PW / PRI` | 0,1 %–10 % |

Ejemplo: PRI = 1 ms → PRF = 1 kHz. Con PW = 1 µs, el ciclo de trabajo es 0,1 %.

Siempre ha de cumplirse **PW < PRI**: un pulso tiene que terminar antes de que empiece el siguiente. El proyecto lo
valida al cargar el catálogo (la PW máxima de un modo debe ser menor que su PRI mínima).

## Alcance no ambiguo

El radar tiene que recibir el eco de un pulso **antes** de emitir el siguiente. Si el eco llega después, el radar lo
confunde con el eco del pulso nuevo y calcula una distancia equivocada (un **eco de segunda vuelta**).

El alcance máximo sin ambigüedad es:

```
R_max = c · PRI / 2
```

| PRI | R_max |
| --- | --- |
| 1 ms | 150 km |
| 250 µs | 37,5 km |
| 100 µs | 15 km |

De aquí sale una regla de diseño: **los radares de largo alcance usan PRI largas** (PRF bajas), y los de corto
alcance o los que necesitan medir velocidad pueden usar PRI cortas (PRF altas).

## Resolución en distancia y alcance mínimo

Dos blancos se distinguen si sus ecos no se solapan. Con un pulso simple:

```
ΔR = c · PW / 2
```

Con PW = 1 µs, ΔR ≈ 150 m. Pulsos más cortos dan mejor resolución, pero llevan menos energía. La compresión de pulsos
resuelve este conflicto (ver [2.4](04-rf-y-modulacion-intrapulso.md)).

Además, mientras emite, el radar no puede escuchar. Los blancos más cerca de `c · PW / 2` quedan "ciegos" (**alcance
mínimo**).

## Clases de PRF

| Clase | Qué prioriza | Comentario |
| --- | --- | --- |
| **PRF baja** | Alcance sin ambigüedad | Vigilancia de largo alcance |
| **PRF media** | Compromiso | Ambigua en distancia y en velocidad; se resuelve cambiando de PRF (ver *dwell & switch* en [2.3](03-modulacion-de-pri.md)) |
| **PRF alta** | Medida de velocidad sin ambigüedad (Doppler) | Radares *pulse Doppler* de aviones |

## Lo que ve un receptor ESM

Un receptor de guerra electrónica no ve ecos: ve llegar directamente los pulsos del radar. De cada uno mide el
instante de llegada (TOA), la frecuencia, el ancho, la amplitud y la dirección (ver
[5.1 El PDW](../05-analisis-de-senal/01-pdw.md)).

La **PRI no se mide en un solo pulso**: se deduce restando los instantes de llegada de pulsos consecutivos del mismo
emisor. Por eso el PDW no tiene un campo PRI, y por eso separar los pulsos de cada emisor (deinterleaving) es el
primer paso del análisis.

## En este proyecto

- La PRI la producen los generadores `FixedPri`, `StaggerPri`, `SlidingPri` y `DwellSwitchPri`; la PW, `FixedPw`.
- En el JSON se escriben en microsegundos (`valueUs`, `widthUs`) y el loader los convierte a nanosegundos enteros
  (`Time`), redondeando al ns más cercano.
- Un valor positivo que redondea a 0 ns es un error de configuración: una PRI de 0 ns haría que el emisor generase
  infinitos pulsos en el mismo instante.
- Regla de coherencia validada: PW máxima < PRI mínima (spec §5, regla 3).

## Ideas clave

- `PRF = 1/PRI`, ciclo de trabajo = `PW/PRI`.
- `R_max = c · PRI / 2`: más alcance exige PRI más larga.
- `ΔR = c · PW / 2`: mejor resolución exige pulsos más cortos (o compresión).
- La PRI no se mide en un pulso: se deduce de los TOA consecutivos.

---

[← 2.1 Principio del radar](01-principio-del-radar.md) · [↑ Radar](README.md) · [Siguiente: 2.3 Modulación de la PRI →](03-modulacion-de-pri.md)

# 3.2 Horizonte radar

> [Manual](../README.md) › [Propagación](README.md) › Horizonte radar

## La Tierra no es plana

Las microondas viajan casi en línea recta. Si el emisor y el receptor están lo bastante lejos, la curvatura de la
Tierra se interpone y no hay **línea de vista**: el receptor no recibe nada, por potente que sea el emisor.

## El horizonte radar

La atmósfera curva ligeramente las ondas hacia abajo (refracción), y eso extiende un poco el horizonte. Se modela con
una Tierra ficticia de radio 4/3 del real. Con las alturas de las antenas en metros:

```
d_horizonte ≈ 4,12 · (√h₁ + √h₂)      km
```

| Antena 1 | Antena 2 | Horizonte |
| --- | --- | --- |
| 10 m | 0 m | 13 km |
| 10 m | 30 m | 35,6 km |
| 10 m | 50 m | 42,2 km |
| 10 m | 10 000 m (avión) | ≈ 425 km |

Por eso los aviones de vigilancia y los receptores elevados ven mucho más lejos que los de superficie. Un radar en el
suelo a 50 km de un receptor en el suelo no se ve, aunque la potencia diera para ello.

## Multitrayecto

Además del camino directo, la señal puede llegar reflejada en el suelo o en el mar. Las dos copias se suman con fases
distintas y producen refuerzos y cancelaciones según la geometría. En el receptor, una misma emisión puede llegar
varias veces, cada vez desde una dirección y con un retardo distintos.

## En este proyecto

- El simulador trata el escenario como un plano (ENU) **sin** curvatura ni obstáculos: todos los emisores tienen
  línea de vista. Curvatura, línea de vista y multitrayecto están fuera de alcance (spec §1).
- Para que los ejemplos sean realistas, se eligen alturas que sí tendrían línea de vista. En la misión golden, el
  emisor A está a 30 m de altura y 30 km del receptor (horizonte de 35,6 km), y el B a 50 m y 20 km (horizonte de
  42,2 km).
- El diseño deja la puerta abierta al multitrayecto: el canal devolvería una lista de llegadas, cada una con su
  dirección (spec §3, decisión 1).

## Ideas clave

- Sin línea de vista no hay recepción.
- `d_horizonte ≈ 4,12 · (√h₁ + √h₂)` km, con alturas en metros.
- El multitrayecto produce varias llegadas de un mismo pulso.

---

[← 3.1 Propagación en espacio libre](01-espacio-libre.md) · [↑ Propagación](README.md) · [Siguiente: 3.3 Balance de enlace →](03-balance-de-enlace.md)

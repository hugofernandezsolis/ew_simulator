# 1.3 Coordenadas y ángulos

> [Manual](../README.md) › [Fundamentos](README.md) › Coordenadas y ángulos

## El sistema ENU

Para situar emisores y receptores hace falta un sistema de coordenadas. El proyecto usa el **plano tangente local
ENU** (*East, North, Up*):

- **X = Este**, **Y = Norte**, **Z = Arriba**, en metros.
- El origen es un punto de referencia del escenario.
- La Tierra se trata como un plano tangente en ese punto.

```
           Z (Arriba)
           │   Y (Norte)
           │  ╱
           │ ╱
           │╱
           └──────── X (Este)
```

Es la aproximación habitual para escenarios de decenas de kilómetros. Para distancias mayores habría que pasar a
coordenadas geodésicas (WGS84) o geocéntricas (ECEF) y tener en cuenta la curvatura de la Tierra; en este proyecto
eso está fuera de alcance (ver también [3.2 Horizonte radar](../03-propagacion/02-horizonte-radar.md)).

## Azimut y elevación

Una dirección en el espacio se describe con dos ángulos:

- **Azimut**: el ángulo en el plano horizontal, medido **desde el Norte** y **en sentido horario**, en [0°, 360°).
  Norte = 0°, Este = 90°, Sur = 180°, Oeste = 270°. Es la convención de navegación (la de una brújula).
- **Elevación**: el ángulo sobre el plano horizontal, positivo hacia arriba, en [−90°, 90°]. Horizonte = 0°,
  vertical hacia arriba = 90°.

> Ojo: en matemáticas los ángulos suelen medirse desde el eje X en sentido **antihorario**. La convención de
> navegación es distinta, y confundirlas es el error más típico (ver la sección de `atan2`).

## Dirección de un punto a otro

Con Δ = B − A (diferencias en Este, Norte y Arriba):

```
az = atan2(ΔE, ΔN)                 normalizado a [0, 360)
el = atan2(ΔU, √(ΔE² + ΔN²))
```

### Por qué `atan2` y por qué en ese orden

`atan(y/x)` pierde el cuadrante: `atan(1/1)` y `atan(−1/−1)` dan lo mismo aunque una dirección es Noreste y la otra
Suroeste. `atan2(y, x)` recibe los dos componentes por separado y devuelve el ángulo correcto en todo el círculo
(entre −180° y 180°).

El truco del orden: en matemáticas se escribe `atan2(y, x)` con el ángulo medido desde X. Como aquí el ángulo se mide
desde el **Norte** (eje Y) hacia el **Este** (eje X), los papeles se intercambian y el **Este va primero**:
`atan2(ΔE, ΔN)`.

Ejemplo: de (0, 0, 0) a (3, 4, 0), ΔE = 3, ΔN = 4 → `atan2(3, 4)` = 36,87°. El punto está al Norte-Noreste, a 36,87°
del Norte girando hacia el Este. Si se escribiera al revés, `atan2(4, 3)`, saldría 53,13°, que es incorrecto.

### Caso especial: la vertical

Si B está justo encima de A (ΔE = ΔN = 0), el azimut no está definido. `atan2(0, 0)` devuelve 0 por convenio (sin
error ni NaN), así que el azimut vale 0° y la elevación 90°.

## Normalización de ángulos

Los ángulos son circulares: 370° es lo mismo que 10°, y −10° lo mismo que 350°. **Normalizar** es llevar cualquier
valor a su rango canónico:

- Azimut a [0, 360).
- Elevación a [−90, 90]. Un valor como 95° no existe en ese rango: equivale a "pasar por encima del polo" y mirar
  hacia atrás, es decir, a elevación 85° con el azimut girado 180°.

## Diferencia entre dos ángulos

Restar azimuts directamente da resultados engañosos cerca de 0°/360°. Un haz que apunta a 359° y un receptor a 1° no
están separados 358°, sino 2°.

La solución es "envolver" la diferencia al intervalo (−180°, 180°]:

```
wrap(Δ) = Δ llevado a (−180, 180]
wrap(1 − 359) = wrap(−358) = 2
```

Esta operación es imprescindible siempre que se comparan direcciones: para saber si un receptor está dentro del haz de
una antena, o para agrupar pulsos por ángulo de llegada en el análisis de señal.

## El ángulo de llegada (AoA)

El **ángulo de llegada** (*Angle of Arrival*, AoA) es la dirección desde la que un receptor ve llegar una señal, es
decir, la dirección **del receptor hacia el emisor**. Es uno de los parámetros más valiosos en guerra electrónica,
porque un emisor fijo siempre llega desde la misma dirección (ver [4.3 Medida del ángulo de llegada](../04-guerra-electronica/03-medida-del-aoa.md)).

## En este proyecto

- `Position` (`SigInt/Geometry`) guarda las tres coordenadas ENU: `eastM_`, `northM_`, `upM_`.
- `directionFromTo(desde, hasta)` implementa las fórmulas de arriba y devuelve un `AngleOfArrival`.
- `AngleOfArrival` (`src/SigInt/PulseDescriptors/`) guarda azimut y elevación en grados (`float`) y los normaliza al
  construirse o al cambiarlos, incluido el plegado de la elevación sobre el polo.
- `wrapOffsetDeg` calcula la diferencia envuelta a (−180, 180].
- El mismo tipo `AngleOfArrival` se usa también para la dirección del haz de un emisor. No es un "ángulo de llegada",
  pero comparte rango y normalización (spec §2).

## Ideas clave

- ENU: X Este, Y Norte, Z Arriba.
- Azimut desde el Norte en sentido horario: `atan2(ΔE, ΔN)`, con el Este primero.
- Las diferencias de ángulos se envuelven a (−180, 180].
- AoA = dirección del receptor hacia el emisor.

---

[← 1.2 Decibelios y potencia](02-decibelios-y-potencia.md) · [↑ Fundamentos](README.md) · [Siguiente bloque: 2. Radar →](../02-radar/README.md)

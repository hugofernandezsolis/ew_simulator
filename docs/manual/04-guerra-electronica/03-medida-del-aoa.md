# 4.3 Medida del ángulo de llegada

> [Manual](../README.md) › [Guerra electrónica](README.md) › Medida del ángulo de llegada

## Por qué el AoA es tan valioso

Un radar puede cambiar su frecuencia, su PRI o su ancho de pulso de un pulso a otro, pero **no puede cambiar de
dónde viene** (al menos no en milisegundos). Por eso el **ángulo de llegada** (AoA, también llamado DOA o *bearing*)
es el parámetro más fiable para separar los pulsos de distintos emisores: dos radares en direcciones distintas se
distinguen aunque usen la misma frecuencia.

Además, el AoA es el primer paso para **localizar** un emisor: con medidas desde varios puntos se triangula su
posición.

Recordatorio: el AoA es la dirección **del receptor hacia el emisor** (ver
[1.3 Coordenadas y ángulos](../01-fundamentos/03-coordenadas-y-angulos.md)).

## Métodos de medida

### Comparación de amplitud

Varias antenas directivas apuntan a direcciones distintas (por ejemplo, cuatro a 90° entre sí). Un pulso llega con
más fuerza a la antena que mejor mira hacia él; comparando las amplitudes de las dos antenas más fuertes se interpola
el ángulo.

- Sencillo y barato.
- Precisión de varios grados.

### Interferometría de fase

Dos antenas separadas una distancia `D` reciben el mismo frente de onda con una pequeña diferencia de camino. Esa
diferencia aparece como una diferencia de fase:

```
Δφ = 2π · D · sin(θ) / λ
```

Midiendo `Δφ` se despeja `θ`.

- Precisión del orden de 1° o mejor.
- **Ambigüedad**: si `D > λ/2`, varias direcciones dan la misma fase (la fase se repite cada 2π). Se resuelve con
  varias parejas de antenas de separaciones distintas.

### Diferencia de tiempos de llegada (TDOA)

Varios receptores separados (incluso decenas de km) miden el instante de llegada del mismo pulso. La diferencia de
tiempos sitúa al emisor sobre una hipérbola, y con tres o más receptores se obtiene su posición. Exige relojes muy
precisos y sincronizados: 1 ns de error son unos 30 cm de diferencia de camino.

## Errores típicos

- **Ruido**: la medida fluctúa de pulso a pulso, más cuanto más débil es la señal.
- **Errores sistemáticos**: desalineación y calibración de las antenas, reflexiones en la propia plataforma.
- **Multitrayecto**: una reflexión llega desde otra dirección y falsea la medida.
- **Ambigüedades** de la interferometría.

Para el análisis de señal, el error del AoA fija el tamaño de las "ventanas" con que se agrupan los pulsos: si el AoA
tiene ±3° de error, dos emisores separados menos de unos 6° son difíciles de distinguir solo por dirección.

## Cerca de 0°/360°

Al agrupar pulsos por AoA hay que comparar ángulos con la diferencia envuelta: un pulso a 359° y otro a 1° están a 2°,
no a 358°. Es la función `wrapOffsetDeg` del proyecto.

## En este proyecto

- El canal calcula la **dirección de llegada** del pulso (receptor → emisor) y la guarda en el `IncidentPulse`. El
  receptor no reconstruye la geometría: aplica su **modelo de medida** a esa dirección (spec §3, decisión 4).
- Hoy el modelo de medida es la identidad (`measureAoa`, **error 0**). El diseño permite añadir un modelo con ruido
  sin tocar el canal (spec §1).
- El AoA medido va a las columnas `azimuthDeg`/`elevationDeg` del CSV, y la dirección verdadera a
  `truth_azimuthDeg`/`truth_elevationDeg`. Hoy coinciden; con un modelo de error dejarían de hacerlo.
- Varios receptores y TDOA están fuera de alcance. La resolución de 1 ns del simulador bastaría para ello.

## Ideas clave

- El AoA es el parámetro más fiable para separar emisores: no cambia pulso a pulso.
- Métodos: comparación de amplitud (grados), interferometría (≤ 1°, con ambigüedades), TDOA (varios receptores).
- Las diferencias de AoA se envuelven a (−180, 180].

---

[← 4.2 Receptores ESM](02-receptores-esm.md) · [↑ Guerra electrónica](README.md) · [Siguiente bloque: 5. Análisis de señal →](../05-analisis-de-senal/README.md)

# 2.6 Barrido de antena

> [Manual](../README.md) › [Radar](README.md) › Barrido de antena

Un haz estrecho solo ilumina una pequeña parte del espacio. Para cubrir más, el radar mueve el haz siguiendo un
patrón: el **barrido** o *scan*. El barrido se ve desde fuera como una modulación de la amplitud recibida, y es otro
rasgo característico de cada radar.

## Tipos de barrido

### Circular

La antena gira 360° a velocidad constante. Es el patrón de los radares de vigilancia.

```
az(t) = az_inicial + 360 · t / T          (normalizado a [0, 360))
```

- `T` es el **periodo de rotación** (*antenna scan period*, ASP). Típicamente entre 1 y 12 s (entre 5 y 60 rpm).
- Puede girar en sentido horario o antihorario.

### Sectorial

El haz va y viene entre dos límites, como un limpiaparabrisas.

- **Bidireccional**: barre de izquierda a derecha y vuelve (onda triangular). Es el típico mecánico.
- **Unidireccional**: barre en un sentido y vuelve de golpe al principio (*flyback*). Típico de barridos
  electrónicos.

Un detalle útil: con el bidireccional, un receptor que no está en el centro del sector ve **dos** iluminaciones por
periodo, separadas por intervalos desiguales.

### Fijo (seguimiento)

El haz apunta a una dirección fija: hacia el blanco que sigue. Un receptor en esa dirección recibe una amplitud
constante, sin ráfagas.

### Cónico y raster

- **Cónico**: el haz gira rápidamente alrededor de un eje, dibujando un cono. Se usa en seguimiento: la amplitud del
  eco varía con el ángulo del blanco respecto al eje.
- **Raster**: varias pasadas sectoriales a distintas elevaciones, como las líneas de una televisión antigua.

## Tiempo en el haz y pulsos por pasada

Con un barrido circular, ¿cuánto tiempo pasa un punto dentro del haz?

```
Tiempo en el haz = θ_az / 360 · T
Pulsos por pasada = Tiempo en el haz / PRI
```

Ejemplo: haz de 1,5°, rotación de 6 s, PRI media de 1,1 ms → 25 ms en el haz → unos 22 pulsos por pasada.

## Lo que ve un receptor

Visto desde un receptor fijo, un radar con barrido circular produce **ráfagas** periódicas:

```
amplitud
   │      ▲                       ▲
   │     ╱ ╲                     ╱ ╲        ← lóbulo principal
   │    ╱   ╲                   ╱   ╲
   │ ▔▔▔     ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔     ▔▔▔   ← lóbulos laterales
   └────────────────────────────────────── tiempo
          ├─────────── T ───────────┤
```

- El intervalo entre ráfagas es el **periodo de scan**.
- La forma de la ráfaga reproduce el diagrama de la antena.
- Si el receptor es lo bastante sensible, también recibe los pulsos de los lóbulos laterales entre ráfagas. Si no,
  solo ve las ráfagas.

Medir el tipo y el periodo de scan a partir de la amplitud es el **análisis de scan** (ver
[5.4 Análisis de scan](../05-analisis-de-senal/04-analisis-de-scan.md)).

## En este proyecto

| Tipo | Clase | JSON (`scan.kind`) | Catálogo | Misión (segmento) |
| --- | --- | --- | --- | --- |
| Fijo | `FixedScan` | `fixed` | — | `pointingAzimuthDeg`, `pointingElevationDeg` |
| Circular (solo horario) | `CircularScan` | `circular` | `periodS`, `elevationDeg` | `initialAzimuthDeg` |
| Sectorial (bidireccional) | `SectorScan` | `sector` | `widthDeg`, `periodS`, `elevationDeg` | `centerAzimuthDeg` |

- **Reparto catálogo/misión**: el catálogo da la parte intrínseca del barrido (tipo, periodo, elevación, anchura) en
  un `ScanSpec`; la misión da su orientación. El loader combina ambas partes en un `ScanPattern` por segmento.
- El scan no tiene estado: `pointingAt(t)` calcula la dirección a partir del tiempo transcurrido desde el inicio del
  segmento. Al cambiar de segmento el barrido vuelve a empezar: una antena que sale de un silencio reaparece en su
  azimut inicial.
- Barridos cónico y raster, sector unidireccional y giro antihorario están fuera de alcance.

## Ideas clave

- Circular, sectorial, fijo, cónico y raster son los barridos básicos.
- Tiempo en el haz = θ/360 · T.
- Un receptor ve el barrido como ráfagas de amplitud; su periodo es el periodo de scan.

---

[← 2.5 Antenas](05-antenas.md) · [↑ Radar](README.md) · [Siguiente bloque: 3. Propagación →](../03-propagacion/README.md)

# 2.5 Antenas

> [Manual](../README.md) › [Radar](README.md) › Antenas

## Ganancia y directividad

Una antena **isotrópica** (teórica) radiaría la misma potencia en todas las direcciones. Una antena real concentra la
potencia en una dirección preferente. La **ganancia** mide esa concentración respecto a la isotrópica, en **dBi**:

- 0 dBi: igual que la isotrópica.
- 30 dBi: en su dirección principal, 1000 veces más potencia que la isotrópica.

La ganancia no crea energía: lo que gana en una dirección lo pierde en las demás.

## El diagrama de radiación

La ganancia depende de la dirección. Su representación es el **diagrama de radiación**:

```
ganancia (dB)
   │           ▲ lóbulo principal
   │          ╱ ╲
   │         ╱   ╲          G_max
   │        ╱     ╲
   │  ╱╲   ╱       ╲   ╱╲   lóbulos laterales
   │ ╱  ╲_╱         ╲_╱  ╲
   └──────────────────────────── ángulo respecto al eje
              ├─────┤
                θ₃
```

- **Lóbulo principal**: donde se concentra la energía.
- **Ancho de haz a −3 dB** (`θ₃`): anchura angular del lóbulo principal entre los puntos en que la ganancia ha caído
  a la mitad. Puede ser distinto en azimut y en elevación.
- **Lóbulos laterales** (y traseros): energía que se escapa en otras direcciones. Su nivel se suele dar en dB por
  debajo del pico (SLL, *sidelobe level*).

Tipos de haz según su forma:

- **Pincel**: estrecho en las dos dimensiones (p. ej. 1° × 1°). Para seguimiento.
- **Abanico**: estrecho en azimut y ancho en elevación (p. ej. 1,5° × 20°). Para vigilancia: cubre muchas altitudes
  a la vez mientras gira.

## Ganancia frente a ancho de haz

Cuanto más estrecho el haz, mayor la ganancia. Una aproximación útil:

```
G ≈ 10 · log10( K / (θ_az · θ_el) )      θ en grados
```

- `K ≈ 41 253` en el caso ideal (son los grados cuadrados de una esfera, 4π rad²).
- `K ≈ 25 000–30 000` en antenas reales, por su eficiencia y sus lóbulos laterales.

| Haz | G ideal | G práctica |
| --- | --- | --- |
| 1° × 1° (pincel) | 46 dBi | 44–45 dBi |
| 1,5° × 20° (abanico) | 31 dBi | ≈ 30 dBi |
| 6° × 6° | 31 dBi | ≈ 30 dBi |
| 30° × 30° | 17 dBi | ≈ 15–16 dBi |

Sirve para comprobar si unos datos de antena tienen sentido: una antena de 30° × 30° no puede tener 30 dBi.

## El modelo gaussiano

Para simular hace falta una fórmula. El proyecto aproxima el lóbulo principal con un **haz gaussiano**, que en dB es
una parábola, y le añade un **suelo** que representa los lóbulos laterales:

```
G(Δaz, Δel) = max( G_max − 12 · [ (Δaz / θ_az)² + (Δel / θ_el)² ] ,  G_max − SLL )
```

- `Δaz`, `Δel`: desvío de la dirección considerada respecto al eje del haz.
- El **factor 12** sale de exigir −3 dB a medio ancho de haz: con `Δ = θ/2`, `12 · (1/2)² = 3`. (El valor exacto
  sería 12,04, porque −3 dB es en realidad −3,01 dB.)
- Los dos ejes se suman: en (θ_az/2, θ_el/2) la caída es de 6 dB.

Ejemplo con `G_max = 35`, `θ_az = 2°`, `θ_el = 20°`, `SLL = 30`:

| Desvío (az, el) | Ganancia |
| --- | --- |
| (0, 0) | 35 dBi (pico) |
| (1, 0) | 32 dBi (−3 dB) |
| (0, 10) | 32 dBi (−3 dB) |
| (1, 10) | 29 dBi |
| (90, 0) | 5 dBi (suelo) |

### Limitaciones del modelo

- **Suelo uniforme.** El suelo representa el **nivel medio** de los lóbulos laterales y traseros, igual en todas las
  direcciones. Por conservación de la energía, la ganancia media de una antena sobre la esfera no puede pasar de
  0 dBi, así que en antenas directivas el suelo debe quedar por debajo de 0 dBi (típicamente entre −5 y −15 dBi):
  `SLL ≈ G_max + 5…15`. El "SLL = −30 dB" que dan muchos catálogos se refiere al **primer** lóbulo lateral, que es
  mucho más alto que la media.
- **Desvíos en azimut y elevación.** Restar azimuts solo es exacto cerca del horizonte: a elevación `el`, un grado de
  azimut son `cos(el)` grados reales. En escenarios de superficie (elevaciones de centésimas de grado) el error es
  despreciable.

## EIRP

La potencia que "parece" emitir un radar en una dirección es su **EIRP** (*Effective Isotropic Radiated Power*):

```
EIRP = P_tx + G_tx(θ)      (en dBm y dBi)
```

Ejemplo: 90 dBm con 30 dBi en el lóbulo principal → EIRP de 120 dBm. Por un lóbulo lateral a −8 dBi → 82 dBm.

## En este proyecto

- Interfaz `AntennaPattern` con `gainDbi(offsetAz, offsetEl)`; implementación `GaussianAntennaPattern` (Tarea 6).
- JSON: `antenna.kind = gaussian` con `peakGainDbi`, `beamwidthAzDeg`, `beamwidthElDeg` y `sidelobeLevelDb`.
- El canal calcula `G_tx` hacia el receptor y el CSV la guarda en `truth_txGainDbi`, junto con `truth_eirpDbm`. Así
  se distingue si un pulso llegó por el lóbulo principal o por un lateral.
- El catálogo de ejemplo usa datos coherentes: `search` 30 dBi con 1,5° × 20° y SLL 38 (suelo −8 dBi); `track`
  44 dBi con 1° × 1° y SLL 50.

## Ideas clave

- La ganancia concentra energía; no la crea.
- Haz más estrecho ⇒ más ganancia: `G ≈ 10·log10(K/(θ_az·θ_el))`.
- Modelo gaussiano: parábola en dB con factor 12 y suelo `G_max − SLL`.
- EIRP = P_tx + G_tx en la dirección de interés.

---

[← 2.4 Frecuencia y modulación intrapulso](04-rf-y-modulacion-intrapulso.md) · [↑ Radar](README.md) · [Siguiente: 2.6 Barrido de antena →](06-barrido-de-antena.md)

# Revisión 5 (segunda ronda): dominio EW (ESM/ELINT, radar) del simulador a nivel de pulso

Fecha: 2026-10-24

Documentos revisados:

- Spec: `docs/superpowers/specs/2026-10-24-simulator-design.md` (versión revisada)
- Plan: `docs/superpowers/plans/2026-10-24-simulator.md` (versión revisada)
- Contexto: `docs/superpowers/reviews/2026-10-24-plan-review-5-ew-domain.md` (primera ronda, D1–D15),
  `docs/superpowers/specs/2026-10-23-pdw-attribute-grouping-design.md`, `src/SigInt/PulseDescriptors/`.

Enfoque: el mismo que en la primera ronda. Se comprueba si el modelo es correcto **dentro del alcance acordado**; no se
propone meter en la v1 nada de "Fuera de alcance", solo se señala dónde el diseño les cierra la puerta. Todos los
cálculos se han hecho con `python3 -I` (scripts en
`/tmp/claude-1000/-home-hfernandezs-develop-ews/bfa41cbf-50f4-4c97-b76e-d1394bb2f671/scratchpad/review5-round2/`:
`calc.py`, `calc2.py` y `golden.py`, este último una simulación independiente de la misión golden).

---

## Resumen y veredicto

**Veredicto: apto para implementar.** Los quince hallazgos de la primera ronda están resueltos o aceptados de forma
consciente y documentada (D2 se queda como limitación escrita, que era una de las dos opciones propuestas). La física
nueva es correcta: el ejemplo numérico de la spec §4 cuadra al centésimo de dB, las ganancias casan con los anchos de
haz y la misión golden está totalmente fijada. La he simulado de forma independiente y salen **exactamente** los
valores de la Tarea 16, Paso 5: 131 filas (18 de A1 y 113 de B1, 58 + 55), dos ráfagas de 9 pulsos, retardos de 100 069
y 66 713 ns, y amplitudes de −41,53, −47,56 y −47,65 dBm.

Quedan dos hallazgos de gravedad media:

1. **R2-D1, suelo de lóbulos laterales que viola la conservación de la energía.** El suelo `G_max − SLL` se describe
   como "lóbulo lateral medio", pero con los datos de ejemplo vale +13 dBi (`track`) y +5 dBi (`TestRadar_B`). Una antena
   cuyo nivel *medio* fuera de haz supera los 0 dBi radiaría más potencia de la que recibe. En las salidas actuales
   (golden y demo) no cambia nada, pero enseña un valor erróneo y sobrestima mucho el alcance de detección por lóbulos
   laterales en cuanto un escenario dependa de ellos.
2. **R2-D2, reparto sigint/sim.** La descripción intrínseca del modo queda partida en dos: `EmitterMode` está en
   `sigint`, pero `ScanSpec` (tipo y periodo del scan), `CatalogMode`, `EmitterType` y `Catalog` están en `sim::Config`.
   Es justo lo que querrá consultar un clasificador futuro en `sigint` (la "librería de emisores"), y `sigint` no puede
   depender de `sim`. Moverlos ahora sale barato; más adelante obligará a mover clases y tests entre librerías.

El resto son ajustes de reparto (funciones de propagación, dirección de llegada en `IncidentPulse`), restos de los
valores antiguos en un test, terminología y líneas para "Fuera de alcance".

| Gravedad | Nº | Hallazgos |
| --- | --- | --- |
| Crítica | 0 | — |
| Alta | 0 | — |
| Media | 2 | R2-D1, R2-D2 |
| Baja | 7 | R2-D3 – R2-D9 |

Errores: R2-D1, R2-D6. Mejoras para la v1: R2-D2, R2-D3, R2-D4, R2-D8, R2-D9. Para el futuro (solo documentación hoy):
R2-D5, R2-D7.

---

## Estado de D1–D15 (primera ronda)

| Id | Tema | Estado | Comentario |
| --- | --- | --- | --- |
| D1 | Ganancia frente a ancho de haz | **Resuelto** | search 1,5°×20° → 30 dBi (ideal 31,4; K = 30 000 → 30,0); track 1°×1° → 43 dBi (ideal 46,2; K = 25 000 → 44,0); A 30°×30° → 16 dBi (ideal 16,6); B 6°×6° → 30 dBi (ideal 30,6). Todas por debajo del límite ideal y dentro de 1–2 dB de la estimación práctica. La spec §5 documenta la regla. Los tests de antena (Tarea 6) llevan el comentario "valores de prueba, no físicos"; los de canal (Tarea 9) no (ver R2-D6). El aviso en el loader no se añadió (era opcional). **Pero** la coherencia del suelo de lóbulos laterales no se revisó: ver R2-D1. |
| D2 | Desvío en az/el | **Aceptado y documentado** | Spec §1 ("Fuera de alcance") y §4 paso 2.3, y comentario de la clase (Tarea 6). El texto de la limitación es correcto (factor `cos(el)`, cénit indefinido, error despreciable a centésimas de grado). En la golden y en la demo las elevaciones son ≤ 0,12°: el error es < 10⁻⁵ dB. |
| D3 | Fuente aleatoria y reinicio por segmento | **Resuelto** | Spec §1 y §4 (reglas del calendario): el estado determinista se reinicia y la fuente aleatoria pertenecerá al `Emitter`, sembrada con la semilla del escenario y el id. Correcto. |
| D4 | Rangos de elevación y sector | **Resuelto** | Elevaciones en [−90, 90], `widthDeg` en (0, 360), anchos de haz en (0, 180], con tests en las Tareas 14 y 15. |
| D5 | Golden infraespecificada | **Resuelto** | Todos los valores fijados (Tarea 16). Alturas 30 y 50 m: horizonte radar (4/3 de Tierra) de 35,6 km para A (está a 30 km) y de 42,2 km para B (a 20 km); los dos son visibles. Periodo comprimido declarado como tal. Verificación detallada abajo. |
| D6 | Solape de pulsos | **Resuelto (documentado)** | En "Fuera de alcance". `truth_overlap` no se añadió (era opcional). |
| D7 | Banda de RF del receptor | **Resuelto (documentado)** | En "Fuera de alcance". |
| D8 | Columnas de verdad | **Resuelto** | `truth_segmentIndex` y `truth_txGainDbi` añadidas. `truth_frequencyMHz`/`truth_pulseWidthUs` no: cuando llegue el ruido de medida cambiarán el formato del CSV y la golden. Es aceptable, pero conviene saberlo. |
| D9 | Comportamiento de los emisores | **Resuelto** | Sentido horario, sector bidireccional con dos iluminaciones, sliding creciente, `pulsesPerDwell` único, sincronía RF/PRI con `pulsesPerHop` = `pulsesPerDwell` y reaparición en `initialAzimuthDeg`: todo documentado. |
| D10 | Polarización y parámetro de la MOP | **Resuelto (documentado)** | En "Fuera de alcance". |
| D11 | Review Focus 2 | **Resuelto** | Ahora dice 23 dBi (desvío de 2° dentro del lóbulo principal) frente a 5 dBi de suelo. Correcto. |
| D12 | Constante de la FSPL y campo lejano | **Resuelto** | Constante redondeada documentada; d ≥ 1 m. Matiz residual en R2-D8. |
| D13 | amplitude frente a power | **Resuelto** | `amplitudeDbm` en el PDW y en el CSV, con la definición (pico, a la salida de la antena, sin pérdidas). |
| D14 | Extensibilidad (móvil, multitrayecto) | **Resuelto** | Los tres cambios de firma están anotados en la decisión de fondo 1. Matiz en R2-D4: la dirección de llegada se calcula en el receptor. |
| D15 | Pérdidas y suelo uniforme | **Resuelto (documentado)** | Pérdidas en "Fuera de alcance". El suelo uniforme se documenta como "lóbulo lateral medio, algo optimista en la parte trasera". Esa frase es precisamente la que hace que los valores de SLL de los ejemplos sean incoherentes (R2-D1). |

---

## Verificación de los datos de ejemplo nuevos

### Ejemplo numérico de la spec §4

| Magnitud | Spec | Calculado |
| --- | --- | --- |
| d | ≈ 25 000 m | 25 000,008 m |
| Retardo | ≈ 83 391 ns | 83 391 ns |
| FSPL (3 GHz) | ≈ 130 dB | 129,951 dB |
| AoA (receptor → emisor) | 36,87° / 0,05° | 36,870° / 0,0458° |
| Dirección emisor → receptor | 216,87° | 216,870° / −0,0458° |
| P_iso lóbulo principal (30 dBi) | ≈ −10 dBm | −9,95 dBm |
| P_iso suelo (0 dBi) | ≈ −40 dBm | −39,95 dBm |

Correcto. En la demo, el modo `search` (haz de 1,5°×20° con 2° de inclinación) pierde 0,13 dB por el desvío en
elevación; el modo `track` (43 dBi, apuntando a 216,87° con elevación 0) da P_iso = +2,76 dBm con una pérdida de
apuntamiento de 0,025 dB. Ver R2-D7 sobre ese +2,8 dBm.

### Catálogo de ejemplo (spec §5)

- **search**: 1 MW de pico, PW de 1 µs, PRI de 1,0–1,2 ms (alcance no ambiguo ≈ 150–180 km), rotación de 6 s (10 rpm).
  Tiempo en el haz a −3 dB: 1,5°/360° · 6 s = 25 ms, unos 22 pulsos por pasada. Realista para un radar de vigilancia
  en banda S.
- **track**: PRI de 250 µs (alcance no ambiguo 37,5 km), PW de 0,5 µs, pincel de 1°: realista.
- Ganancias coherentes (D1). **Suelo de lóbulos laterales incoherente** (R2-D1).

### Misión golden (Tarea 16): simulación independiente

| Comprobación | Plan | Simulado |
| --- | --- | --- |
| Filas totales | 131 | 131 |
| A1 / B1 | 18 / 113 | 18 / 113 |
| B1 por segmento | 58 + 55 | 58 + 55 |
| A1: d, retardo | 30 000,007 m, 100 069 ns | 30 000,0067 m, 100 069 ns |
| A1: pico / suelo | −41,53 / −66,53 dBm | −41,535 / −66,535 dBm |
| A1: ráfagas | 2 × 9, TOA 20 100 069…30 100 069 y 70 100 069…80 100 069 | idéntico |
| A1: AoA | az ≈ 0 | az 0,0000°, el 0,0382° |
| B1: d, retardo | 20 000,040 m, 66 713 ns | 20 000,0400 m, 66 713 ns |
| B1: primera fila | TOA 2 066 713, az 90 | 2 066 713, az 90,0000°, el 0,1146° |
| B1: amplitudes | −47,56 / −47,65 dBm | −47,5555 / −47,6514 dBm |
| B1: hueco | sin `truth_emissionNs` en [42, 62) ms | correcto; último t_e = 99,8 ms |

Detalles físicos que he comprobado:

- **Ráfagas de A1.** El haz pasa por 180° (dirección del receptor) en 25 y 75 ms. La condición `P_rx ≥ −60 dBm` exige
  `G_tx ≥ −2,47 dBi`, es decir, |Δaz| ≤ 37,2° (±5,17 ms). Los pulsos de los bordes (20 y 30 ms, Δaz = 36°) entran con
  1,18 dB de margen y los siguientes de fuera (18,5 y 31 ms, Δaz de 46,8° y 43,2°) quedan muy por debajo. La golden no
  depende de un redondeo frágil.
- **Ganancia de A1 en el centro de la ráfaga**: 16,000 dBi a t = 25 ms. El desvío en elevación (0,038°) es
  despreciable frente a 30°.
- **Apuntamiento de B.** La dirección exacta emisor → receptor es (270°, −0,114591°). El `float` de −0,1146 deja un
  desvío de 9·10⁻⁶°, así que G_tx = 30,000 dBi. La potencia de B no depende del ancho de haz, como se buscaba [N9].
- **Coherencia ganancia/ancho de haz**: A, 16 dBi para 30°×30° (ideal 16,6); B, 30 dBi para 6°×6° (ideal 30,6).
  Correcto. El suelo de A (−9 dBi) es físicamente coherente: la ganancia media sobre la esfera sale +0,29 dBi, dentro
  del error del modelo gaussiano. El de B (+5 dBi) no lo es (R2-D1), aunque no afecta a la salida porque B siempre
  apunta al receptor.
- **Margen de redondeo**: la amplitud de B a 9 GHz es −47,55547 dBm (en `float`, −47,555466). Queda a 4,7·10⁻⁴ dB de la
  frontera de redondeo de `{:.2f}`. No es un empate, así que la diferencia de último bit entre plataformas no lo
  cambia. Pero si alguien sustituye −147,55 por la constante exacta (−147,5522), la cifra pasa a −47,55. Es justo el
  tipo de cambio que la golden debe detectar, así que está bien.

### Valores esperados de los tests del plan con significado físico

Todos correctos:

- Tarea 5: circular de 6 s (90° a 1,5 s), cruce de 350° → 20°, sector {90, 60, 4 s}: 60/90/120/90/60, y sector
  centrado en 0°: 350/0/10.
- Tarea 6: 35/32/32/29/5/32 con {35, 2, 20, 30}.
- Tarea 8: secuencias 5, 6, 7, 9,5, 10,5 ms y 5, 6 | 7,5, 8,5, 10,5 ms; circular de 4 ms a 90° en 6 ms.
- Tarea 9: 1000 ns para 299,792458 m; 92,45 dB para (1 km, 1 GHz); Δaz con wrap 2° → 23 dBi; P_iso 32,55 dBm.
- Tarea 11: −73,01 → −70,01 (descartado), −73 → −70 (detectado), EIRP 122.
- Tarea 13: 2998 m → 10 000,25 ns → 10 000 ns; con P_tx 0 dBm, 0 dBi y 1 GHz llegan entre −82 y −102 dBm, muy por
  encima de −200.

La única incoherencia es de datos heredados (R2-D6).

---

## Hallazgos nuevos

### R2-D1: el suelo de lóbulos laterales viola la conservación de la energía en los datos de ejemplo

- **Gravedad:** Media
- **Tipo:** Error (datos de ejemplo y definición de SLL)
- **Descripción:** la spec define `SLL` como "nivel de lóbulos laterales en dB respecto al pico" y el suelo como "un
  lóbulo lateral medio" que cubre todas las direcciones. En la literatura, "SLL = −30 dB" suele referirse al **primer
  lóbulo lateral** (el de pico). El nivel **medio** fuera del haz, que es lo que representa un suelo uniforme, está
  mucho más abajo: típicamente entre −5 y −15 dBi en términos absolutos. Con los datos de ejemplo, el suelo queda por
  encima de 0 dBi en direcciones que cubren casi toda la esfera.
- **Justificación técnica:** la ganancia media de cualquier antena sobre la esfera es la eficiencia, ≤ 1 (≤ 0 dBi).
  Integrando numéricamente el modelo (gaussiano + suelo, rejilla de 0,25°):

  | Antena | G_max | Suelo `G_max − SLL` | Ganancia media en la esfera | Exceso de energía | SLL para media ≈ 0 dBi |
  | --- | --- | --- | --- | --- | --- |
  | spec `search` (1,5°×20°) | 30 dBi | 0 dBi | +2,6 dBi | ×1,8 | ≈ 37–38 dB (suelo ≈ −7,4 dBi) |
  | spec `track` (1°×1°) | 43 dBi | **+13 dBi** | **+13,1 dBi** | **×20** | ≈ 47 dB (suelo ≈ −3,5 dBi) |
  | golden `TestRadar_A` (30°×30°) | 16 dBi | −9 dBi | +0,3 dBi | ≈ 1 | 25–30 dB (ya correcto) |
  | golden `TestRadar_B` (6°×6°) | 30 dBi | +5 dBi | +6,2 dBi | ×4 | ≈ 50 dB (el lóbulo principal ya se lleva el 99 % de la energía porque 30 dBi está en el límite ideal) |

  Consecuencia operativa: el alcance de detección por lóbulos laterales escala con `10^(ΔG/20)`. Un suelo 13–20 dB
  demasiado alto multiplica ese alcance por 4,5–10. Hoy no cambia ninguna salida (la demo detecta los lóbulos
  laterales igualmente a −70 dBm, porque con un suelo de −7,4 dBi P_iso = −47,3 dBm; y B apunta siempre al receptor).
  Pero el usuario copiará estos valores a escenarios donde sí importan, y un deinterleaver evaluado con lóbulos
  laterales demasiado fuertes verá ráfagas que no existirían.
- **Cambio sugerido:**
  - Spec §4 paso 2.4: precisar que el suelo es el **nivel medio** de los lóbulos laterales y traseros, no el del primer
    lóbulo, y que debe cumplir aproximadamente `G_max − SLL ≲ −5 dBi` (orden de magnitud). Así, `SLL ≈ G_max + 5…15`
    para antenas directivas.
  - Datos: `search` SLL 38–40; `track` SLL 50; `TestRadar_B` SLL 50 (o bajar B a 28 dBi y SLL 40). `TestRadar_A` puede
    quedarse en 25. **La golden no cambia** (A no se toca y B solo se ve por el lóbulo principal), así que el cambio no
    afecta a `golden.csv`.
  - Spec §4, ejemplo numérico: con SLL 38, el suelo da P_iso ≈ −48 dBm en lugar de −40. La conclusión ("con −70 dBm se
    reciben todos los pulsos") sigue siendo cierta.
  - Opcional, como en D1: comentario o aviso (no error) cuando `peakGainDbi − sidelobeLevelDb > 0`.
  - Alternativa de modelo (no necesaria): parametrizar el suelo en dBi absolutos (`sidelobeFloorDbi`) en lugar de
    relativo al pico, que es más difícil de equivocar.
- **Afecta a:** spec §4 (paso 2.4 y ejemplo), §5 (catálogo de ejemplo); plan Tarea 16 (`TestRadar_B.json`,
  `scenarios/catalog/SearchRadar_X.json`).

### R2-D2: la descripción intrínseca del emisor queda partida entre `sigint` y `sim`

- **Gravedad:** Media
- **Tipo:** Mejora para v1 (reparto de librerías)
- **Descripción:** la regla del usuario ("clases que definen una señal, una parte de ella o su tratamiento" → `sigint`)
  lleva a `sigint` los generadores, la antena y `EmitterMode`, pero deja en `sim::Config`:
  - `ScanSpec` / `ScanKind`: tipo de scan, periodo, elevación y anchura del sector;
  - `CatalogMode` (`EmitterMode` + `ScanSpec`), `EmitterType` (nombre + modos) y `Catalog`.

  Desde el dominio, esas cuatro clases **son** la librería de emisores (*emitter library*, EPL): los parámetros
  intrínsecos de cada tipo y modo (RF, PRI, PW, MOP, potencia, antena, **tipo y periodo de scan**). El tipo y el periodo
  de scan (ASP, *antenna scan period*) son parámetros que un ESM mide a partir de la envolvente de amplitud, y uno de
  los rasgos más discriminantes para clasificar. El propio documento de agrupación del PDW
  (`2026-10-23-pdw-attribute-grouping-design.md` §2) separa **intrínsecos** (identifican al emisor y formarán el futuro
  *emitter descriptor*) de **extrínsecos**. El reparto catálogo/misión de la spec es exactamente esa frontera: el
  catálogo es lo intrínseco y la misión lo situacional. La frontera de librerías, en cambio, corta lo intrínseco por la
  mitad.
- **Justificación técnica:** un clasificador o un deinterleaver con librería que viva en `sigint` querrá iterar sobre
  tipos y modos y comparar con lo medido (RF, PRI, PW, periodo de scan). Hoy no puede: `sigint` no depende de `sim`, y
  la parte de scan del modo solo existe en `sim`. Cuando llegue, habrá que mover cinco clases (con sus tests R12) de
  `Simulator/Config` a `SigInt`, cambiar su namespace y retocar los loaders y los tests que las usan. Hacerlo ahora
  cuesta lo mismo que crearlas donde están: ninguna conoce JSON (solo los loaders y `JsonReader`).
- **Cambio sugerido** (de menor a mayor alcance):
  1. Mínimo: `ScanSpec` y `ScanKind` a `SigInt/Emission` (son parámetros intrínsecos de la señal) y `ScanSpec` como
     atributo de `EmitterMode`. Así `CatalogMode` sobra: un modo ya tiene su descripción de scan, y el `Segment` sigue
     guardando el `ScanPattern` concreto, orientado por la misión. Esto matiza la decisión de fondo 6 ("`ScanSpec` es un
     detalle de `Config`"): desde el dominio no es un detalle de configuración, es la mitad intrínseca del scan.
  2. Recomendado: además, `EmitterType` y `Catalog` a `sigint` (p. ej. `SigInt/Library` o `SigInt/Emission`). Los
     loaders siguen en `sim::Config`, que es lo único que conoce JSON.

  Si se prefiere no tocar nada, dejar escrito en la spec §3 ("Ubicación") que el catálogo pasará a `sigint` cuando haya
  un consumidor en `sigint`.
- **Afecta a:** spec §3 (decisión 6 y "Ubicación"); plan decisión 1 (tabla de reparto), decisión 3, Tareas 7 y 14.

### R2-D3: las funciones de propagación y el wrap angular son física reutilizable que hoy queda en `sim`

- **Gravedad:** Baja
- **Tipo:** Mejora para v1
- **Descripción:** `Propagation.h` (`propagationDelay`, `freeSpacePathLossDb`, `wrapOffsetDeg`) vive en
  `Simulator/Channel`. Son funciones libres sin dependencias de `sim`.
- **Justificación técnica:**
  - `wrapOffsetDeg` (diferencia angular en (−180, 180]) es la operación que necesita **cualquier** deinterleaver para
    agrupar por AoA (*AoA gating*). Sin ella, un pulso a 359° y otro a 1° se consideran separados 358°. El documento de
    agrupación del PDW ya prevé "la diferencia angular" como operación propia de `AngleOfArrival`.
  - `freeSpacePathLossDb` sirve para la **estimación pasiva de distancia por amplitud** (dada la EIRP de la
    librería, `d ≈ 10^((EIRP + G_rx − P_rx + 147,55 − 20·log10 f)/20)`), técnica clásica de ESM. `propagationDelay` y
    `kSpeedOfLightMps` servirán para TDOA.
- **Cambio sugerido:** mover `Propagation` a `SigInt` (p. ej. `SigInt/Geometry`, junto a `Units`), o al menos
  `wrapOffsetDeg` como operación de `AngleOfArrival` o de `Geometry`. `PropagationChannel` (el objeto que aplica el
  modelo al pulso simulado) se queda en `sim`.
- **Afecta a:** plan decisión 1 (tabla) y Tarea 9; spec §3 (tabla de componentes).

### R2-D4: `IncidentPulse` no lleva la dirección de llegada; el receptor la recalcula desde la posición verdadera del emisor

- **Gravedad:** Baja
- **Tipo:** Mejora para v1
- **Descripción:** según la spec §4 paso 3.3 y la Tarea 11, el AoA medido es
  `measureAoa(directionFromTo(posición, emitterPosition))`. El receptor lee `emitterPosition`, un dato de **verdad**
  guardado dentro del `EmittedPulse`, y reconstruye él mismo la geometría. Físicamente, la dirección de llegada es una
  propiedad de la **onda incidente** que fija el canal: es el canal quien conoce el camino de propagación.
- **Justificación técnica:** con multitrayecto (fuera de alcance), cada llegada tiene su propia dirección (la del punto
  de reflexión), distinta de la del emisor. Con un receptor que se mueve o tiene actitud (fuera de alcance), la
  dirección depende de la posición del receptor en t_a y de su orientación. En los dos casos, "el receptor calcula el
  AoA hacia la posición del emisor" da un resultado erróneo. Lo mismo pasará con un futuro diagrama de antena del
  receptor (DF, ganancia dependiente de la dirección). Hoy coinciden, porque solo hay camino directo.
- **Cambio sugerido:** añadir a `IncidentPulse` un `AngleOfArrival arrivalDirection_`, que el canal rellena con la
  dirección receptor → emisor (ya calcula la inversa en el paso 2.1). El receptor aplica `measureAoa` a ese campo, y la
  verdad (`truth_azimuthDeg`/`truth_elevationDeg`) sale del mismo campo. Es un atributo más y un test más en la
  Tarea 9.

  **Respuesta a la pregunta del reparto: ¿`IncidentPulse` está bien en `sigint`?** Sí, con matices. La parte de
  señal (t_a, f, PW, MOP, potencia isotrópica y, con este cambio, la dirección de llegada) es lo que mañana consumirá
  un generador de IQ o un modelo de receptor, ambos "tratamiento de señal". Pero `IncidentPulse` y `EmittedPulse` llevan
  también contabilidad del simulador y verdad: `emitterId`, `modeId`, `segmentIndex` (un concepto del calendario, que
  es de `sim`), `emitterPulseIndex`, `distanceM`, `txGainDbi`, la posición del emisor y el puntero a su antena.
  Recomiendo dejarlas en `sigint` y documentar en su comentario de clase qué campos son **señal** y cuáles son
  **verdad**, para que ningún algoritmo futuro en `sigint` tome un `IncidentPulse` como entrada y lea la verdad sin
  darse cuenta. Los algoritmos de procesado deben consumir `PulseDescriptorWords`, nunca `IncidentPulse`.
- **Afecta a:** spec §4 (pasos 2.7 y 3.3); plan Tareas 7, 9 y 11.

### R2-D5: los generadores no sirven como descripción de librería para un clasificador

- **Gravedad:** Baja
- **Tipo:** Para el futuro (documentación hoy)
- **Descripción:** `EmitterMode` guarda los generadores como prototipos `const`, y eso los convierte de hecho en la
  descripción del modo. Para **generar**, eso es correcto. Para **reconocer**, una librería de emisores necesita otra
  cosa:
  - **Rangos y tolerancias**, no valores exactos: RF 2,9–3,1 GHz, PRI 990–1010 µs, stagger de 3 posiciones con
    valores ±1 %, periodo de scan 5,5–6,5 s.
  - **Comparación sin estado**: hoy `==` de un generador compara también `index_`, `currentNs_` o `pulsesInDwell_`. Un
    `StaggerPri` avanzado un pulso no es "igual" a la misma descripción.
  - **Acceso por tipo**: un clasificador que pregunte "¿es un stagger de valores X?" tendría que hacer `dynamic_cast`
    sobre la jerarquía de generadores.
- **Justificación técnica:** es la diferencia entre el modelo generativo (simulador) y el descriptor de emisor (ELINT)
  que ya anticipa `2026-10-23-pdw-attribute-grouping-design.md` (`EmitterDescriptor`, `Waveform`). No es un error
  del diseño actual, pero conviene no intentar que los generadores hagan las dos cosas.
- **Cambio sugerido:** una frase en la spec §3 que diga que `EmitterMode` es el modelo **generativo** del modo y que
  el futuro `EmitterDescriptor` (con rangos) será una clase distinta, que el loader podrá construir a partir del mismo
  JSON. Además, cuidado con los nombres: el futuro "emisor" que produzca un deinterleaver (un *emitter track* o
  hipótesis de emisor en `sigint`) no debería llamarse `Emitter`, para no confundirlo con `sim::Emitter`, aunque el
  namespace evite el choque de compilación.
- **Afecta a:** spec §3 (decisión 5 o "Ubicación").

### R2-D6: valores heredados de la ganancia antigua de 35 dBi en tests del plan

- **Gravedad:** Baja
- **Tipo:** Error (de coherencia de datos, no de lógica)
- **Descripción:**
  - Tarea 10, `WriteFormatsRow`: PDW con amplitud −5,0 dBm y verdad con `txGainDbi` 35 y `eirpDbm` 125. Son los
    valores del ejemplo antiguo de la spec (35 dBi). El ejemplo corregido da −9,95 dBm, 30 dBi y 120 dBm. El test es
    internamente coherente (125 − 129,95 ≈ −5), así que no falla, pero quien compare la fila con la spec §4 verá cifras
    que ya no salen.
  - Tarea 9: los tests de canal usan `{35, 2, 20, 30}` sin el comentario "valores de prueba, no físicos" que sí tiene
    la Tarea 6 (35 dBi con 2°×20° supera el límite ideal de 30,1 dBi).
- **Cambio sugerido:** en `WriteFormatsRow`, amplitud −9,95f, `txGainDbi` 30, `eirpDbm` 120 (fila esperada
  `…,-9.95,…,30.00,120.00`), o un comentario de que son valores arbitrarios. En la Tarea 9, el mismo comentario que en la
  Tarea 6.
- **Afecta a:** plan Tareas 9 y 10.

### R2-D7: saturación y rango dinámico del receptor no figuran en "Fuera de alcance"

- **Gravedad:** Baja
- **Tipo:** Para el futuro (una línea de documentación hoy)
- **Descripción:** el receptor acepta cualquier potencia por encima de la sensibilidad. En la demo, el modo `track`
  llega con P_rx ≈ +2,8 dBm (43 dBi a 25 km) y el lóbulo principal de `search` con −10 dBm. Un receptor ESM real tiene
  un rango dinámico finito (del orden de 50–70 dB sobre la sensibilidad, dependiendo de la arquitectura). Por encima
  satura: la amplitud medida se recorta y pueden aparecer espurios, lo que en el PDW se marca con un *flag* (el propio
  comentario de `PulseDescriptorWords.h` menciona "saturación").
- **Justificación técnica:** la saturación degrada la medida de amplitud, que es la base del análisis de scan, y
  genera falsos pulsos en lóbulos espurios. Es un efecto realista que un deinterleaver debe tolerar, del mismo tipo que
  el solape de pulsos (D6). El diseño no lo impide: el receptor ya decide qué escribe y cómo rellena el PDW.
- **Cambio sugerido:** añadir a "Fuera de alcance" una línea: "Rango dinámico del receptor (saturación, flags de
  calidad en el PDW)".
- **Afecta a:** spec §1.

### R2-D8: d ≥ 1 m solo garantiza una FSPL positiva por encima de unos 24 MHz

- **Gravedad:** Baja
- **Tipo:** Mejora para v1 (validación o documentación)
- **Descripción:** la FSPL es ≥ 0 si `d ≥ λ/(4π)`. Con d = 1 m, eso exige `f ≥ c/(4π·1 m) ≈ 23,9 MHz`. La validación
  admite cualquier frecuencia > 0: con `frequencyMHz: 1` y un emisor a 1 m, la FSPL vale −27,5 dB y el receptor
  recibiría 27 dB **más** de lo emitido.
- **Justificación técnica:** es un caso extremo y casi académico, pero la spec dice que una errata no debe pasar en
  silencio. Un `frequencyMHz: 3` en lugar de `3000` (errata de unidad) es plausible. A 25 km no daría FSPL negativa,
  pero sí 70 dB menos de pérdida de la que corresponde.
- **Cambio sugerido:** limitar las frecuencias a un rango físico de radar/ESM (p. ej. [30 MHz, 300 GHz], o al menos
  ≥ 1 MHz), con un test más en la Tarea 14. Si no, documentar en §5 que la regla d ≥ 1 m presupone f ≳ 24 MHz.
- **Afecta a:** spec §5 (validación, regla 2); plan Tarea 14.

### R2-D9: `AngleOfArrival` se usa para direcciones que no son de llegada

- **Gravedad:** Baja
- **Tipo:** Mejora para v1 (terminología)
- **Descripción:** la spec §2 guarda en `AngleOfArrival` la dirección del haz del emisor (`beamDirection_`,
  `FixedScan::pointing_`, `ScanPattern::pointingAt`) y la dirección emisor → receptor. En EW, "ángulo de llegada" es
  la dirección desde la que el **receptor** ve llegar la señal. La dirección de apuntamiento de un haz es otra
  magnitud. Usar el mismo tipo es correcto técnicamente (mismas invariantes de rango y normalización), pero el nombre
  confunde a quien lee `ScanPattern::pointingAt` y recibe un "ángulo de llegada".
- **Justificación técnica:** la claridad terminológica importa en un proyecto de aprendizaje, y lo hará más cuando
  convivan en `sigint` el AoA medido, la dirección del haz y la dirección verdadera.
- **Cambio sugerido** (barato): un alias `using Direction = AngleOfArrival;` en `Geometry.h` (o una clase
  `Direction` de la que `AngleOfArrival` sea un uso), empleado en scans, haces y `directionFromTo`. `AngleOfArrival`
  se reserva para el PDW y la medida del receptor. Si no se quiere tocar, una nota en la spec §2.
- **Afecta a:** spec §2; plan Tareas 1, 5 y 7 (solo nombres).

---

## Evaluación del reparto sigint/sim desde el dominio

| Pieza | Ubicación | Valoración |
| --- | --- | --- |
| `PulseDescriptorWords`, `AngleOfArrival`, `IntrapulseModulation` | sigint | Correcto: es la interfaz entre el receptor y el procesado. |
| `Time`, `Position`, geometría | sigint | Correcto, y además necesario. Las conversiones ENU ↔ WGS84/ECEF futuras irán aquí y las usará la geolocalización. |
| Generadores PRI/RF/PW, antena, `EmitterMode` | sigint | Correcto como **modelo generativo** de la señal intrínseca. Para reconocer emisores hará falta un descriptor con rangos (R2-D5). |
| Scans (`ScanPattern` y derivados) | sigint | Correcto: describen la modulación de amplitud por el barrido, que es parte de la señal recibida. |
| `ScanSpec`, `CatalogMode`, `EmitterType`, `Catalog` | **sim** | **Incoherente** con la regla: son la mitad intrínseca del scan y la librería de emisores (R2-D2). |
| `EmittedPulse`, `IncidentPulse` | sigint | Aceptable si se documenta qué es señal y qué es verdad. `IncidentPulse` debería llevar la dirección de llegada (R2-D4). |
| `Propagation` (funciones) | **sim** | Mejor en sigint (R2-D3): ranging por amplitud, TDOA y *AoA gating*. |
| `PropagationChannel` | sim | Correcto: aplica el modelo del mundo al pulso simulado. |
| `Segment`, `Emitter` | sim | Correcto: el calendario y la posición de una instancia son situacionales (extrínsecos), no una propiedad del tipo de emisor. |
| `Receiver`, `GroundTruth`, escritores | sim | Correcto: el receptor simulado modela el hardware; con datos reales los PDW vendrán del equipo. Si en el futuro un algoritmo de `sigint` necesita las características del receptor (σ del AoA para dimensionar ventanas), serán parámetros de ese algoritmo, no el `sim::Receiver`. La evaluación (comparar la salida del deinterleaver con la verdad) puede vivir en `sim` o en una librería de herramientas que dependa de ambas, o leer el CSV. |

Frente a las extensiones de "Fuera de alcance":

- **Plataformas móviles**: las trayectorias son situacionales y van en `sim`. `EmittedPulse` ya lleva la posición en
  t_e. Sin problemas, salvo la dirección de llegada (R2-D4).
- **Varios receptores / TDOA**: el PDW no tiene `channelId`/`receiverId` (sí está en el comentario de
  `PulseDescriptorWords.h`). Un algoritmo de TDOA en `sigint` necesitará PDW etiquetados por sensor. Es una ampliación
  del PDW, no un cambio de reparto.
- **Aleatoriedad**: la fuente aleatoria en `Emitter` (sim) y los generadores en `sigint` con `next(rng&)` es
  compatible.
- **IQ**: un generador de muestras a partir de `IncidentPulse` encaja en `sigint`.
- **Multitrayecto**: ver R2-D4.

---

## Correcto desde el punto de vista del dominio

- Todo lo listado en la primera ronda sigue siendo válido: ENU, azimut desde el Norte horario con `atan2(ΔE, ΔN)`, AoA
  receptor → emisor, desvío con la dirección emisor → receptor, retardo d/c redondeado a ns, FSPL con la frecuencia de
  cada pulso, Friis en dB con el canal calculando la potencia isotrópica, sensibilidad como umbral determinista y
  modelo gaussiano con factor 12.
- **Ganancias coherentes con los anchos de haz** en todos los datos de ejemplo, y la regla `G ≈ 10·log10(K/(θ_az·θ_el))`
  documentada en la spec.
- **Ejemplo numérico de la spec §4** exacto, y con la conclusión correcta: la detección por lóbulos laterales a decenas
  de km es lo normal en ESM. Sigue siendo cierta con un suelo realista (R2-D1).
- **Misión golden**: geometría visible con curvatura real (horizonte de 35,6 y 42,2 km frente a 30 y 20 km), ráfagas
  limpias con margen (pico −41,5 dBm, suelo −66,5 dBm, umbral −60), B apuntando exactamente al receptor, cambio de RF
  por saltos de 3 y reinicio por segmento visibles, hueco `off` visible y recorte en `durationS`. Todos los valores
  esperados del Paso 5 coinciden con una simulación independiente.
- **Documentación de limitaciones** (desvío en az/el, suelo uniforme, campo lejano, sin solape, sin banda de RF, sin
  pérdidas): bien redactada y técnicamente exacta.
- **Columnas `truth_segmentIndex` y `truth_txGainDbi`**: permiten distinguir lóbulo principal de lateral y segmentos
  repetidos del mismo modo, que es lo que necesita un analista para validar un análisis de scan.
- **`amplitudeDbm`** con definición explícita (potencia de pico a la salida de la antena, sin pérdidas): terminología
  correcta para un PDW.
- **Sector bidireccional con dos iluminaciones desiguales**, **circular horario** y **reaparición en
  `initialAzimuthDeg`** tras un `off`: documentados y coherentes con las fórmulas.
- **Separación catálogo (intrínseco) / misión (situacional)**: es la frontera correcta del dominio. R2-D2 solo pide que
  la frontera de librerías la siga.

# Revisión numérica independiente (IV&V) del plan del simulador

Fecha: 2026-10-24
Documentos revisados: `docs/superpowers/specs/2026-10-24-simulator-design.md` (spec) y
`docs/superpowers/plans/2026-10-24-simulator.md` (plan).

## Resumen y veredicto

**Veredicto: los valores esperados del plan son correctos.** Ningún valor esperado contradice las fórmulas de la
spec. Recalculé de forma independiente **97 valores** (más 6 comprobaciones de sensibilidad), con un script en Python
que implementa las fórmulas de la spec y replica la normalización en `float` de `AngleOfArrival`
(`wrap_angle`/`normalize`, emulando la precisión simple). Primero extraje las entradas y después comparé con los
valores esperados.

- **Discrepancias numéricas: 0** en los valores que el plan fija.
- **1 valor depende de cómo se escriba la comparación** (ida y vuelta a 180° en la Tarea 1): con `==` puede fallar por
  la precisión `float`.
- **1 test mal planteado** (Tarea 12, `RunDeliversPulsesInFlightAfterEnd`): el pulso llega antes de `duration`, así
  que el test no comprueba lo que dice su nombre.
- Varias **entradas sin especificar** (Tareas 7, 12 y 15), marcadas como *Duda*. Con supuestos razonables, el balance
  de enlace de la misión golden funciona sin ajustes: A produce ráfagas y B se recibe entero con 12 dB de margen.

Hallazgos: 1 Alta, 1 Media, 5 Baja y 3 Duda (ver la lista).

## Tabla de valores comprobados

Notación: ángulos en grados, tiempos en ns salvo que se indique otra unidad, potencias en dBm/dB. «calc.» es el valor
de mi script (los ángulos, ya convertidos a `float` por `AngleOfArrival`).

| Tarea | Test | Entradas | Esperado (plan) | Calculado | ¿Coincide? |
| --- | --- | --- | --- | --- | --- |
| 1 | secondsToTime | 1.5 s | 1 500 000 000 | 1 500 000 000 | Sí |
| 1 | microsecondsToTime | 1.0004 µs (×1e3 = 1000.4) | 1000 | 1000 | Sí |
| 1 | microsecondsToTime | 1.0006 µs (×1e3 = 1000.5999999999999) | 1001 | 1001 | Sí |
| 1 | timeToSeconds | 2.5e9 ns (con `/1e9` y con `*1e-9`) | 2.5 | 2.5 (0 ulp en los dos casos) | Sí |
| 1 | timeToMicroseconds | 1500 ns | 1.5 | 1.5 | Sí |
| 1 | distanceM | (0,0,0)→(3,4,0) | 5.0 (DOUBLE_EQ) | 5.0 exacto | Sí |
| 1 | directionFromTo az | (0,0,0)→(3,4,0) | 36.8699 ± 1e-3 | 36.869896 (float); 36.8698976 (double) | Sí |
| 1 | Cardinales | N (0,1,0), E (1,0,0), S (0,−1,0), W (−1,0,0) | 0, 90, 180, 270; el 0 | 0, 90, 180, 270; el 0 (exactos) | Sí |
| 1 | ReverseDiffersBy180 | 3-4-5, expresión `fmod(az+180, 360)` en float | 216.86990356 | 216.86990356 | Sí (0 ulp) |
| 1 | ReverseDiffersBy180 | 3-4-5, expresión con `180.0` (double) | 216.86989594 | 216.86990356 | **No con `==`** (difieren 7.6e-6; ver N2) |
| 1 | Elevación | (0,0,0)→(0,100,100) | 45 | 45.0 exacto | Sí |
| 1 | Vertical | (0,0,0)→(0,0,10) | el 90, sin NaN | az 0, el 90 | Sí |
| 3 | FixedPri | 1000 | 1000×3 | 1000×3 | Sí |
| 3 | StaggerPri | 1000,1200,1100 | 1000,1200,1100,1000 | ídem | Sí |
| 3 | SlidingPri | 100,130,10 | 100,110,120,130,100 | ídem | Sí |
| 3 | SlidingPri | 100,125,10 | 100,110,120,100 | ídem | Sí |
| 3 | DwellSwitchPri | {1000,2000}, 3 | 1000×3, 2000×3, 1000 | ídem | Sí |
| 4 | FixedRf | 3e9 | 3e9, 3e9 | ídem | Sí |
| 4 | ListRf | {1e9,2e9,3e9}, 2 | 1e9,1e9,2e9,2e9,3e9,3e9,1e9 | ídem | Sí |
| 4 | FixedPw | 500 ns | 500, 500 | ídem | Sí |
| 5 | FixedScan | (216.87, 0), t = 0 y 5 s | (216.87, 0) | (216.8699951, 0) (float de 216.87) | Sí (con NEAR / FLOAT_EQ) |
| 5 | Circular{0,6s,2} | t = 0 / 1.5 s / 6 s | 0 / 90 / 0; el 2 | 0 / 90 / 0 (360 → 0); el 2 | Sí |
| 5 | Circular{350,6s,0} | t = 0.5 s | 20 | 20.0 (380 → 20) | Sí |
| 5 | Sector{90,60,4s,0} | t = 0,1,2,3,4 s | 60, 90, 120, 90, 60 | 60, 90, 120, 90, 60 | Sí |
| 5 | Sector{0,20,4s,0} | t = 0,1,2 s | 350, 0, 10 | 350, 0, 10 | Sí |
| 6 | Gaussian{35,2,20,30} | (0,0) | 35 | 35 | Sí |
| 6 | ídem | (1,0) | 32 | 32 | Sí |
| 6 | ídem | (0,10) | 32 | 32 | Sí |
| 6 | ídem | (1,10) | 29 | 29 | Sí |
| 6 | ídem | (90,0) | 5 | parábola −24 265 → suelo 5 | Sí |
| 6 | ídem | (−1,0) | 32 | 32 | Sí |
| 7 | NextStartsAtSegmentStart | inicio 5 ms, FixedPri 1 ms | 5 ms, índice 0 | 5 ms, 0 | Sí |
| 7 | NextAdvancesByPri | ídem | 6 ms, índice 1 | 6 ms, 1 | Sí |
| 7 | NextSkipsOffSegment | [modo 2.5, off 2, modo 2] ms | 5, 6, 7, 9.5, 10.5 ms | 5, 6, 7, 9.5, 10.5 ms (11.5 ≥ fin → acaba) | Sí |
| 7 | NextResetsStateOnModeChange | Stagger{1,2,3} ms; 2.5 y 4 ms | 5, 6 \| 7.5, 8.5, 10.5 | 5, 6 \| 7.5, 8.5, 10.5 (8 ≥ 7.5; 13.5 ≥ 11.5) | Sí |
| 7 | NextPulseOnSegmentBoundary… | A de 2 ms desde 5 ms | pulso en 7 ms con modo B | B | Sí |
| 7 | NextStopsAtEnd | iEnd 8 ms | 5, 6, 7 y nullopt | 5, 6, 7 | Sí (ver N6) |
| 7 | NextUsesScanRelativeToSegmentStart | Circular{0,4ms,0}, t = 6 ms, inicio 5 ms | 90 | t' = 1 ms → 90 | Sí |
| 8 | propagationDelay | 299.792458 m | 1000 | 1000.0 → 1000 | Sí |
| 8 | propagationDelay | 0.1 m | 0 | 0.3336 → 0 | Sí |
| 8 | freeSpacePathLossDb | 1000 m, 1e9 Hz | 92.45 ± 1e-9 | 92.44999999999999 (err −1.4e-14) | Sí |
| 8 | wrapOffsetDeg | 358, −358, 180, −180, 10 | −2, 2, 180, 180, 10 | −2, 2, 180, 180, 10 | Sí |
| 8 | PropagateComputesArrivalTime | (0,299.792458,0) → origen, t_e 1 ms | 1 001 000 | 1 001 000 | Sí |
| 8 | PropagateComputesTxGainFromBeamOffset | RX en (1000,0,0), haz 89° | 32 | Δaz = 1 exacto → 32 | Sí |
| 8 | PropagateWrapsBeamOffset | RX a az 1° (R·sin1°, R·cos1°), haz 359° | 23 | az_ER = 1.0f exacto para R = 1…30 000 → Δaz 2 → 23 | Sí (ver N3, N4) |
| 8 | PropagateComputesIsotropicPower | 90 + 35 − FSPL(1000, 1e9) | 32.55 | 32.55000000000001 | Sí (con NEAR) |
| 9 | WriteFormatsRow | PDW y verdad del plan | `7,83391,3000.000000,1.000,-5.00,36.8700,0.0500,None,E1,search,3,0,25000.008,36.8700,0.0500,125.00` | idéntica (float(36.87) = 36.86999893 → «36.8700»; 25000.008 → «25000.008») | Sí |
| 10 | ReceiveDropsPulseBelowSensitivity | P_iso −73.01, G 3, sens −70 | descartado | −70.01 < −70 | Sí |
| 10 | ReceiveKeepsPulseAtSensitivity | P_iso −73, G 3 | detectado, −70 | −70.0 exacto (en double y en float) | Sí |
| 10 | ReceiveFillsPdwFromPulse | AoA (0,0,0)→(3,4,0) | 36.87 | 36.869896 | Sí (con NEAR ≥ 1e-3) |
| 10 | ReceiveFillsGroundTruth | 90 + 32 | 122 | 122 | Sí |
| 12 | RunDeliversEveryPulse | 299.792458 m, dur 3.5 ms, PRI 1 ms | TOA 0,1,2,3 ms + 1000 | 1000; 1 001 000; 2 001 000; 3 001 000 | Sí |
| 12 | RunOrdersByArrivalTime | A a 2998 m | retardo 10 000 | 10 000.25 → 10 000 | Sí |
| 12 | ídem | B a 299.792458 m, inicio 5 µs | llega a 6 µs; B antes que A | 6000 < 10 000 | Sí |
| 12 | RunDeliversPulsesInFlightAfterEnd | dur 1 ms, 2998 m | un registro, TOA 10 000 | 10 000 (pero 10 µs < 1 ms) | Valor sí; **test mal planteado** (N1) |
| 13 | ParseCatalogBuildsModes | primera PRI del stagger | 1000 µs | 1 000 000 ns | Sí |
| 13 | ParseCatalogConvertsMicrosecondsWithRounding | valueUs 1.0006 | 1001 ns | 1001 | Sí |
| 13 | ParseCatalogRejectsPwNotBelowMinPri | stagger [1000, 900], PW 900 | error | 900 ≥ 900 → error | Sí (formato del número: N7) |
| 13 | Ejemplo de la spec §5 | PW < PRI mínima | válido | 1 < 1000; 0.5 < 250 | Sí |
| 14 | ParseMissionBuildsEmittersAndReceiver | startS 5 | 5 s, modo search | 5 000 000 000 | Sí |
| 14 | ParseMissionChainsSegmentsFromStart | 5 + 40 + 10 | 55 s | 55 000 000 000 | Sí |
| 14 | ParseMissionAcceptsScheduleBeyondDuration | durationS 50 | último < 50 s | 44.9993 s (search; 36 364 pulsos) | Sí |
| 14 | Conversión periodS | 0.05 s | 50 000 000 | 0.05·1e9 = 50000000.0 → 50 000 000 | Sí |
| spec §4 | d | E (15000,20000,30), RX (0,0,10) | ≈ 25 000 | 25 000.008 | Sí |
| spec §4 | retardo | ídem | ≈ 83 391 | 83 391.05 → 83 391 | Sí |
| spec §4 | FSPL a 3 GHz | ídem | ≈ 130 | 129.951 | Sí |
| spec §4 | AoA RX→E | ídem | az ≈ 36.87, el ≈ 0.05 | 36.8699, 0.04584 | Sí |
| spec §4 | Haz E→RX | ídem | ≈ 216.87 | 216.8699 (el −0.0458) | Sí |
| spec §4 | P_iso lóbulo principal / laterales | 90 + 35 / 90 + 5 | ≈ −5 / ≈ −35 | −4.951 / −34.951 | Sí |
| spec §4 | Detección con −70 | laterales | todos recibidos | −34.95 ≥ −70 | Sí |
| spec §5 | Track apuntando a (216.87, 0) | haz 1°×1° | — | Δaz −9e-5, Δel −0.0458 → −0.025 dB | Coherente |
| spec §7 | Canal | 299,792458 m | 1000 ns | 1000 | Sí |
| 15 | Golden A: pico | 60 + 30 − FSPL(30 000.0017, 3 GHz) | ≥ −60 | −41.53 | Sí |
| 15 | Golden A: suelo | 60 + 5 − FSPL | < −60 (ráfagas) | −66.53 | Sí |
| 15 | Golden A: ráfaga | G_tx ≥ 11.53 dBi | ráfagas ≈ 50 ms | ±37.2° → ≈ 10.3 ms por vuelta; 9 pulsos/ráfaga (18 en 0.1 s) | Sí |
| 15 | Golden B: d y retardo | √(20000² + 40²) | — | 20 000.04 m; 66 712.95 → 66 713 ns | — |
| 15 | Golden B: P_rx (supuesto P_tx 60, G 30, G_rx 0) | 9000 / 9100 MHz | ≥ −60 | −47.56 / −47.65 | Sí |
| 15 | AoA de A / de B | RX→A, RX→B | ≈ 0 / ≈ 90 | 0.0000 (el −0.0191) / 90.0000 (el 0.1146) | Sí |

La salida completa del script, con las 97 líneas, se reproduce ejecutando el anexo.

## Hallazgos

### N1. Alta: el test de pulsos en vuelo no comprueba lo que dice su nombre

- **Ubicación:** Tarea 12, `RunDeliversPulsesInFlightAfterEnd`.
- **Descripción:** con `duration` = 1 ms y el emisor a 2998 m, el único pulso se emite en t = 0 y llega en
  10 000 ns = 10 µs, **mucho antes** del final (1 ms). El pulso no está en vuelo cuando se acaba la misión. Una
  implementación errónea que dejase de procesar eventos en `t ≥ duration` (justo lo que la spec §4 paso 4 prohíbe)
  pasaría el test.
- **Cálculo:** t_a = 0 + llround(2998 / c · 1e9) = 10 000 ns < 1 000 000 ns.
- **Corrección sugerida:** que la llegada sea posterior a `duration`. Por ejemplo, `duration` = 5 µs (5000 ns) con el
  emisor a 2998 m: solo se emite en 0 (el siguiente, en 1 ms, cae fuera), llega en 10 000 ns > 5000 ns y se espera
  exactamente un registro con TOA 10 000. Otra opción es `duration` = 1.005 ms: pulsos en 0 y 1 ms, y el segundo
  llega en 1.01 ms > 1.005 ms.

### N2. Media: comparar con `==` en la ida y vuelta a 180° es frágil con `float`

- **Ubicación:** Tarea 1, `DirectionFromToReverseDiffersBy180` («az(B→A) == fmod(az(A→B) + 180, 360)»).
- **Descripción:** `AngleOfArrival` guarda `float`. Que se cumpla la igualdad exacta depende de detalles de escritura:
  - Con `+ 180` (literal entero), la suma se hace en `float` y, para el triángulo 3-4-5, coincide (0 ulp).
  - Con `+ 180.0` (double), el esperado vale 216.8698959 y el medido 216.8699036: **difieren 7.6e-6** y
    `EXPECT_EQ`/`EXPECT_DOUBLE_EQ` fallan (268 millones de ulp en double).
  - Con otros puntos, la igualdad falla **incluso en `float`**: para (−7, 2, 0) hay 1 ulp de diferencia, porque la
    normalización en `normalize()` y la suma de 180 redondean en pasos distintos.
- **Corrección sugerida:** `EXPECT_FLOAT_EQ` (tolera 4 ulp; 0–1 ulp en todos los casos que probé) o
  `EXPECT_NEAR(…, 1e-4)`, como pide la spec §7 («ángulos con `EXPECT_NEAR`»). Lo mismo vale para el resto de
  comparaciones de ángulos (FixedScan 216.87 → 216.8699951 en `float`; AoA 36.87).

### N3. Baja: texto incoherente en el Review Focus 2

- **Ubicación:** plan, Review Focus 2 («Δaz = 2°, no 358°; la ganancia es casi la de pico»).
- **Descripción:** con la antena del test (θ_az = 2°), un desvío de 2° da 35 − 12·(2/2)² = **23 dBi**, 12 dB por
  debajo del pico. El valor esperado del test (23) es correcto; la frase «casi la de pico» no lo es.
- **Corrección sugerida:** «la ganancia es la de un desvío de 2° (23 dBi), no el suelo de lóbulos laterales (5 dBi)
  que daría 358°». Así queda claro qué distingue el test.

### N4. Baja: el test de wrap no fija las posiciones ni la tolerancia

- **Ubicación:** Tarea 8, `PropagateWrapsBeamOffset` («receptor en az 1° desde el emisor»).
- **Descripción:** no da coordenadas. Con (R·sin 1°, R·cos 1°, 0) el azimut sale exactamente `1.0f` para
  R = 1…30 000 y la ganancia vale exactamente 23. Con otras posiciones, el redondeo a `float` (ulp ≈ 3e-5 en 359°)
  daría un error en G de unos 1e-5 dB, y un `EXPECT_DOUBLE_EQ` fallaría.
- **Corrección sugerida:** fijar la posición (por ejemplo, `{1000·sin(1°), 1000·cos(1°), 0}`) y usar
  `EXPECT_NEAR(…, 1e-6)`.

### N5. Duda: parámetros de la misión golden sin especificar

- **Ubicación:** Tarea 15, misión golden.
- **Falta:** P_tx y antena de `TestRadar_B` (el Step 5 da por hecho una ganancia de pico de 30), `gainDbi` del
  receptor, `elevationDeg` e `initialAzimuthDeg` del scan circular de A, `startS` y duraciones de los segmentos de B
  (incluido el `off`), y la elevación con la que B «apunta al receptor».
- **Comprobación con supuestos** (G_rx = 0; B con P_tx = 60 y G = 30; scan de A con elevación 0):
  - A: pico −41.53 dBm ≥ −60 y suelo −66.53 dBm < −60, así que **hay ráfagas**. Cada ráfaga cubre ±37.2° alrededor
    del receptor, unos 10.3 ms de cada vuelta de 50 ms: 9 pulsos por ráfaga y 18 en 0.1 s, con cualquier azimut
    inicial de los que probé (0, 90 y 180).
  - B: −47.56 dBm (9000 MHz) y −47.65 dBm (9100 MHz), con 12.4 dB de margen, así que **se recibe entero**.
  - No hace falta ajustar nada. El margen de A en el suelo (6.5 dB por debajo de la sensibilidad) es suficiente.
- **Sugerencia:** fijar todos estos valores en el plan para que la referencia sea reproducible y el Step 5 se pueda
  verificar sin adivinar.

### N6. Baja: entradas incompletas en tests de la Tarea 7

- **Ubicación:** Tarea 7, `NextStopsAtEnd` y `NextSkipsOffSegment`.
- **Descripción:**
  - En `NextStopsAtEnd` no se da la duración del segmento. Si fuese ≤ 3 ms (es decir, si acabase en 8 ms o antes), el
    corte lo haría el fin del segmento y no `iEnd`, y el test no comprobaría `iEnd`.
  - En `NextSkipsOffSegment` no se da `iEnd` (tiene que ser > 10.5 ms).
- **Corrección sugerida:** un segmento de 10 ms en `NextStopsAtEnd` (termina en 15 ms > 8 ms) e `iEnd` = 100 ms en
  `NextSkipsOffSegment`.

### N7. Duda: formato del número en el mensaje de PW frente a PRI

- **Ubicación:** Tarea 13, mensaje `la PW máxima (<x> µs) debe ser menor que la PRI mínima (<y> µs)`, test
  `ParseCatalogRejectsPwNotBelowMinPri` («mensaje con 900 y 900»).
- **Descripción:** no se dice cómo se formatean `<x>` e `<y>`. Puede salir `900`, `900.000` o `900.0`, según se use
  `std::format("{}")` sobre un double o sobre `timeToMicroseconds(...)`. El test pide «texto exacto».
- **Sugerencia:** fijar el formato (por ejemplo, `{}` sobre el double en µs → `900`) y escribir el mensaje esperado
  completo en el plan.

### N8. Baja: entradas de potencia sin especificar en la Tarea 12

- **Ubicación:** Tarea 12, los tres tests.
- **Descripción:** la antena con SLL 0 hace que G_tx = G_max en cualquier dirección (el truco es correcto). Pero no se
  dan P_tx, f, G_rx ni la sensibilidad, y `RunOrdersByArrivalTime` tampoco da `duration`. La detección depende de
  P_tx + G_max − FSPL + G_rx ≥ sens.
- **Sugerencia:** fijar, por ejemplo, P_tx = 0 dBm, G = 0 dBi, f = 1 GHz y sensibilidad = −200 dBm, y
  `duration` = 0.5 ms en `RunOrdersByArrivalTime` para que solo haya los dos registros comparados.

### N9. Baja: la fórmula de verificación de B en el Step 5 depende de la elevación apuntada

- **Ubicación:** Tarea 15, Step 5 («powerDbm de B = P_tx + 30 − FSPL + G_rx»).
- **Descripción:** es exacta solo si el haz de B apunta también en elevación al receptor (−0.1146°). Si se configura
  `pointingElevationDeg` = 0, se pierden 12·(0.1146/θ_el)² dB: 1.8e-4 dB con θ_el = 30° (no se ve con `{:.2f}`), pero
  0.16 dB con θ_el = 1° (sí se ve).
- **Sugerencia:** apuntar B a (270, −0.1146) o elegir θ_el ≥ 5° (pérdida < 0.007 dB).

### N10. Baja: falta un caso de redondeo exacto en .5

- **Ubicación:** Tarea 1 (Review Focus 4).
- **Descripción:** los casos 1.0004 y 1.0006 no distinguen `std::llround` (redondea .5 alejándose de cero) de
  `std::nearbyint`/`std::lrint` (redondea .5 al par). Con 0.0025 µs → 2.5 ns, `llround` da 3 y `nearbyint` da 2.
- **Sugerencia (opcional):** añadir `microsecondsToTime(0.0025) == Time{3}` para fijar la regla del plan
  («`std::llround`»).

## Anexo A: script de verificación (`verify.py`)

```python
# Independent numeric verification of the simulator plan (formulas from the spec).
import math, struct

C = 299_792_458.0
NS = 1_000_000_000

def f32(x):                       # round a double to IEEE single (C++ float)
    return struct.unpack('f', struct.pack('f', x))[0]

def wrap_angle_f32(v, vmin, period):   # replica of AngleOfArrival::wrap_angle (float arithmetic)
    v, vmin, period = f32(v), f32(vmin), f32(period)
    off = f32(math.fmod(f32(v - vmin), period))
    if off < 0: off = f32(off + period)
    if off >= period: off = 0.0
    return f32(vmin + off)

def aoa(az, el):                  # AngleOfArrival(float az, float el) with normalize()
    az, el = f32(az), f32(el)
    el = wrap_angle_f32(el, -180, 360)
    if el > 90: el = f32(180 - el); az = f32(az + 180)
    elif el < -90: el = f32(-180 - el); az = f32(az + 180)
    return (wrap_angle_f32(az, 0, 360), el)

def llround(x):                   # C llround: half away from zero
    return int(math.floor(abs(x) + 0.5)) * (1 if x >= 0 else -1)

# ---- Units
def secondsToTime(s): return llround(s * 1e9)
def microsecondsToTime(us): return llround(us * 1e3)
def timeToSeconds_div(t): return t / 1e9
def timeToSeconds_mul(t): return t * 1e-9
def timeToMicroseconds_div(t): return t / 1e3

# ---- Geometry
def distanceM(a, b): return math.sqrt(sum((bi - ai) ** 2 for ai, bi in zip(a, b)))
def direction_double(a, b):
    dE, dN, dU = (b[0]-a[0]), (b[1]-a[1]), (b[2]-a[2])
    az = math.degrees(math.atan2(dE, dN))
    if az < 0: az += 360.0
    el = math.degrees(math.atan2(dU, math.hypot(dE, dN)))
    return az, el
def directionFromTo(a, b, normalize_in_double=True):
    dE, dN, dU = (b[0]-a[0]), (b[1]-a[1]), (b[2]-a[2])
    az = math.degrees(math.atan2(dE, dN))
    if normalize_in_double and az < 0: az += 360.0
    el = math.degrees(math.atan2(dU, math.hypot(dE, dN)))
    return aoa(az, el)

# ---- Generators
def take(gen, n): return [next(gen) for _ in range(n)]
def fixed(v):
    while True: yield v
def stagger(vs):
    i = 0
    while True: yield vs[i % len(vs)]; i += 1
def sliding(mn, mx, st):
    v = mn
    while True:
        yield v
        v = v + st
        if v > mx: v = mn
def dwell(vs, n):
    i = 0
    while True: yield vs[(i // n) % len(vs)]; i += 1

# ---- Scans (t in ns)
def circular(init, T, el, t): return aoa(init + 360.0 * t / T, el)
def sector(center, width, T, el, t):
    left = center - width / 2
    phase = (t % T) / T
    az = left + width * 2 * phase if phase < 0.5 else left + width * 2 * (1 - phase)
    return aoa(az, el)

# ---- Antenna
def gain(G, baz, bel, sll, daz, de):
    return max(G - 12 * ((daz / baz) ** 2 + (de / bel) ** 2), G - sll)

# ---- Channel
def delay(d): return llround(d / C * 1e9)
def fspl(d, f): return 20 * math.log10(d) + 20 * math.log10(f) - 147.55
def wrapOffset(x):
    r = math.fmod(x + 180.0, 360.0)
    if r <= 0: r += 360.0
    return r - 180.0

# ---- Emitter (half-open segments)
def emitter(start, schedule, end, nmax=10**6):
    """schedule: list of (modeId, duration_ns, pri_factory or None). yields (t, modeId)"""
    t0 = start; out = []
    for mode, dur, prif in schedule:
        seg_end = t0 + dur
        if prif is not None:
            pri = prif(); t = t0
            while t < seg_end and t < end:
                out.append((t, mode, t - t0))
                t += next(pri)
        t0 = seg_end
    return out

R = []
def rec(task, test, inputs, plan, mine, ok=None, note=""):
    if ok is None: ok = (plan == mine)
    R.append((task, test, inputs, plan, mine, ok, note))

ms = 1_000_000; us = 1000
# Task 1
rec(1,"secondsToTime","1.5 s",1_500_000_000,secondsToTime(1.5))
rec(1,"microsecondsToTime","1.0004 us",1000,microsecondsToTime(1.0004), note=repr(1.0004*1e3))
rec(1,"microsecondsToTime","1.0006 us",1001,microsecondsToTime(1.0006), note=repr(1.0006*1e3))
rec(1,"timeToSeconds (t/1e9)","2.5e9 ns",2.5,timeToSeconds_div(2_500_000_000))
rec(1,"timeToSeconds (t*1e-9)","2.5e9 ns",2.5,timeToSeconds_mul(2_500_000_000), note="ulps diff: %r" % (timeToSeconds_mul(2_500_000_000)-2.5))
rec(1,"timeToMicroseconds","1500 ns",1.5,timeToMicroseconds_div(1500))
rec(1,"distanceM","(0,0,0)->(3,4,0)",5.0,distanceM((0,0,0),(3,4,0)))
az = directionFromTo((0,0,0),(3,4,0))[0]
rec(1,"directionFromTo az","(0,0,0)->(3,4,0)","36.8699±1e-3",az, ok=abs(az-36.8699)<1e-3, note="double %.10f" % direction_double((0,0,0),(3,4,0))[0])
for name,p,exp in [("N",(0,1,0),0.0),("E",(1,0,0),90.0),("S",(0,-1,0),180.0),("W",(-1,0,0),270.0)]:
    a = directionFromTo((0,0,0),p)
    rec(1,"cardinal "+name,str(p),(exp,0.0),a)
# reverse: B->A vs fmod(az(A->B)+180,360), two implementation paths
fwd = directionFromTo((0,0,0),(3,4,0))[0]
rev_d = directionFromTo((3,4,0),(0,0,0),True)[0]
rev_f = directionFromTo((3,4,0),(0,0,0),False)[0]
exp_float = f32(math.fmod(f32(fwd+180.0), 360.0))
exp_double = math.fmod(fwd+180.0, 360.0)
rec(1,"reverse 180 (norm. double, cmp float expr)","3-4-5",exp_float,rev_d)
rec(1,"reverse 180 (norm. en AoA float, cmp float expr)","3-4-5",exp_float,rev_f)
rec(1,"reverse 180 (cmp vs double fmod)","3-4-5",exp_double,rev_d)
rec(1,"elevation 45","(0,0,0)->(0,100,100)",45.0,directionFromTo((0,0,0),(0,100,100))[1], note=repr(direction_double((0,0,0),(0,100,100))[1]))
rec(1,"straight up","(0,0,0)->(0,0,10)",(0.0,90.0),directionFromTo((0,0,0),(0,0,10)))
# Task 3
rec(3,"FixedPri","1000",[1000]*3,take(fixed(1000),3))
rec(3,"StaggerPri","1000,1200,1100",[1000,1200,1100,1000],take(stagger([1000,1200,1100]),4))
rec(3,"SlidingPri","100,130,10",[100,110,120,130,100],take(sliding(100,130,10),5))
rec(3,"SlidingPri","100,125,10",[100,110,120,100],take(sliding(100,125,10),4))
rec(3,"DwellSwitchPri","{1000,2000},3",[1000,1000,1000,2000,2000,2000,1000],take(dwell([1000,2000],3),7))
# Task 4
rec(4,"FixedRf","3e9",[3e9,3e9],take(fixed(3e9),2))
rec(4,"ListRf","{1e9,2e9,3e9},2",[1e9,1e9,2e9,2e9,3e9,3e9,1e9],take(dwell([1e9,2e9,3e9],2),7))
rec(4,"FixedPw","500 ns",[500,500],take(fixed(500),2))
# Task 5
S=NS
rec(5,"FixedScan","(216.87,0) t=0,5s",(216.87,0.0),aoa(216.87,0), ok=abs(aoa(216.87,0)[0]-216.87)<1e-4, note="float=%r" % f32(216.87))
for t,e in [(0,0.0),(1.5,90.0),(6,0.0)]:
    rec(5,"Circular{0,6s,2}","t=%gs"%t,(e,2.0),circular(0,6*S,2,secondsToTime(t)))
rec(5,"Circular{350,6s,0}","t=0.5s",(20.0,0.0),circular(350,6*S,0,secondsToTime(0.5)))
for t,e in [(0,60),(1,90),(2,120),(3,90),(4,60)]:
    rec(5,"Sector{90,60,4s,0}","t=%ds"%t,(float(e),0.0),sector(90,60,4*S,0,t*S))
for t,e in [(0,350),(1,0),(2,10)]:
    rec(5,"Sector{0,20,4s,0}","t=%ds"%t,(float(e),0.0),sector(0,20,4*S,0,t*S))
# Task 6
for o,e in [((0,0),35),((1,0),32),((0,10),32),((1,10),29),((90,0),5),((-1,0),32)]:
    rec(6,"Gaussian{35,2,20,30}",str(o),float(e),gain(35,2,20,30,*o))
# Task 7
P1 = lambda: fixed(1*ms)
r = emitter(5*ms,[("A",100*ms,P1)],10**18)
rec(7,"NextStartsAtSegmentStart","start 5ms",(5*ms,0),(r[0][0],0))
rec(7,"NextAdvancesByPri","",(6*ms,1),(r[1][0],1))
r = emitter(5*ms,[("A",2_500_000,P1),("off",2*ms,None),("A",2*ms,P1)],10**18)
rec(7,"NextSkipsOffSegment","[2.5,off2,2] ms",[5,6,7,9.5,10.5],[x[0]/ms for x in r])
ST = lambda: stagger([1*ms,2*ms,3*ms])
r = emitter(5*ms,[("A",2_500_000,ST),("B",4*ms,ST)],10**18)
rec(7,"NextResetsStateOnModeChange","stagger 1,2,3; 2.5ms,4ms",[5,6,7.5,8.5,10.5],[x[0]/ms for x in r])
r = emitter(5*ms,[("A",2*ms,P1),("B",10*ms,P1)],10**18)
m7 = [x[1] for x in r if x[0]==7*ms]
rec(7,"NextPulseOnSegmentBoundary","A 2ms, B",["B"],m7)
r = emitter(5*ms,[("A",100*ms,P1)],8*ms)
rec(7,"NextStopsAtEnd","iEnd 8ms",[5,6,7],[x[0]/ms for x in r])
rec(7,"NextUsesScanRelativeToSegmentStart","Circular{0,4ms,0} t=6ms",(90.0,0.0),circular(0,4*ms,0,6*ms-5*ms))
# Task 8
rec(8,"propagationDelay","299.792458 m",1000,delay(299.792458), note=repr(299.792458/C*1e9))
rec(8,"propagationDelay","0.1 m",0,delay(0.1), note=repr(0.1/C*1e9))
v=fspl(1000,1e9); rec(8,"FSPL","1000 m, 1e9 Hz","92.45±1e-9",v, ok=abs(v-92.45)<1e-9, note="err %.3e"%(v-92.45))
for x,e in [(358,-2),(-358,2),(180,180),(-180,180),(10,10)]:
    rec(8,"wrapOffsetDeg",str(x),float(e),wrapOffset(x))
rec(8,"PropagateComputesArrivalTime","d=299.792458, te=1ms",1*ms+1000,1*ms+delay(distanceM((0,299.792458,0),(0,0,0))))
azER,elER = directionFromTo((0,0,0),(1000,0,0)); beam=aoa(89,0)
rec(8,"PropagateComputesTxGainFromBeamOffset","RX E, beam 89",32.0,gain(35,2,20,30,wrapOffset(azER-beam[0]),elER-beam[1]))
th=math.radians(1); rx=(1000*math.sin(th),1000*math.cos(th),0)
azER,elER = directionFromTo((0,0,0),rx); beam=aoa(359,0)
g=gain(35,2,20,30,wrapOffset(azER-beam[0]),elER-beam[1])
rec(8,"PropagateWrapsBeamOffset","RX az 1°, beam 359",23.0,g, ok=abs(g-23)<1e-4, note="azER float=%r, err=%.2e (EXPECT_DOUBLE_EQ fallaría si err!=0)"%(azER,g-23))
rec(8,"PropagateComputesIsotropicPower","90+35-FSPL(1000,1e9)",32.55,90+35-fspl(1000,1e9), ok=abs(90+35-fspl(1000,1e9)-32.55)<1e-9)
# Task 9: CSV row
pdw_aoa = aoa(36.87,0.05)
row = ",".join([str(7),str(83391),"%.6f"%(3e9/1e6),"%.3f"%(1000/1e3),"%.2f"%f32(-5.0),"%.4f"%pdw_aoa[0],"%.4f"%pdw_aoa[1],"None","E1","search","3","0","%.3f"%25000.008,"%.4f"%pdw_aoa[0],"%.4f"%pdw_aoa[1],"%.2f"%125.0])
rec(9,"WriteFormatsRow","ver plan","7,83391,3000.000000,1.000,-5.00,36.8700,0.0500,None,E1,search,3,0,25000.008,36.8700,0.0500,125.00",row)
# Task 10
rec(10,"DropsBelowSensitivity","Piso -73.01, G 3",False,(-73.01+3)>=-70)
rec(10,"KeepsAtSensitivity","Piso -73, G 3",(True,-70.0),((-73.0+3)>=-70,f32(-73.0+3)))
a=directionFromTo((0,0,0),(3,4,0))[0]; rec(10,"FillsPdw AoA","(0,0,0)->(3,4,0)",36.87,a, ok=abs(a-36.87)<1e-3)
rec(10,"FillsGroundTruth eirp","90+32",122.0,90+32.0)
# Task 12
rec(12,"RunDeliversEveryPulse","299.79 m, dur 3.5ms",[0+1000,1*ms+1000,2*ms+1000,3*ms+1000],[t+delay(299.792458) for t,_,_ in emitter(0,[("A",10**12,P1)],3_500_000)])
dA=delay(2998); dB=delay(299.792458)
rec(12,"RunOrdersByArrivalTime: delay A","2998 m",10000,dA, note=repr(2998/C*1e9))
rec(12,"RunOrdersByArrivalTime: llegada B","inicio 5 us + 1000",6000,5000+dB)
inflight=[t+dA for t,_,_ in emitter(0,[("A",10**12,P1)],1*ms)]
rec(12,"RunDeliversPulsesInFlightAfterEnd","dur 1ms, 2998 m",[10000],inflight, note="llegada 10 us < duración 1 ms: el pulso NO está en vuelo al terminar")
# Task 13/14
rec(13,"valueUs 1.0006","",1001,microsecondsToTime(1.0006))
rec(13,"PwNotBelowMinPri","stagger [1000,900], PW 900",True, microsecondsToTime(900)>=min(microsecondsToTime(1000),microsecondsToTime(900)))
rec(14,"first next E1","startS 5",5*NS,secondsToTime(5))
r = emitter(secondsToTime(5),[("search",secondsToTime(40),lambda: stagger([1000*us,1200*us,1100*us])),("off",secondsToTime(10),None),("track",secondsToTime(30),lambda: fixed(250*us))],secondsToTime(120))
first_track=[x for x in r if x[1]=="track"][0][0]
rec(14,"ChainsSegmentsFromStart","5+40+10",55*NS,first_track)
r50 = emitter(secondsToTime(5),[("search",secondsToTime(40),lambda: stagger([1000*us,1200*us,1100*us])),("off",secondsToTime(10),None),("track",secondsToTime(30),lambda: fixed(250*us))],secondsToTime(50))
rec(14,"AcceptsScheduleBeyondDuration","durationS 50","< 50 s",r50[-1][0], ok=r50[-1][0]<50*NS, note="último pulso %.4f s (modo %s); pulsos totales %d"%(r50[-1][0]/NS,r50[-1][1],len(r50)))
rec(14,"periodS 0.05 -> ns","",50_000_000,secondsToTime(0.05), note=repr(0.05*1e9))

# Spec §4 numeric example
E=(15000,20000,30); RX=(0,0,10)
d=distanceM(E,RX); rec("spec§4","d","",'≈25000',d, ok=abs(d-25000)<1)
rec("spec§4","retardo ns","",83391,delay(d), note=repr(d/C*1e9))
F=fspl(d,3e9); rec("spec§4","FSPL","",'≈130',F, ok=abs(F-130)<0.5)
a=directionFromTo(RX,E); rec("spec§4","AoA RX->E","",'(≈36.87, ≈0.05)',a, ok=abs(a[0]-36.87)<0.01 and abs(a[1]-0.05)<0.005)
b=directionFromTo(E,RX); rec("spec§4","haz E->RX","",'≈216.87',b, ok=abs(b[0]-216.87)<0.01)
rec("spec§4","P_iso lóbulo principal","",'≈-5',90+35-F, ok=abs(90+35-F+5)<0.5)
rec("spec§4","P_iso lóbulos laterales","",'≈-35',90+5-F, ok=abs(90+5-F+35)<0.5)
rec("spec§4","detectado laterales con -70","",True,90+5-F>=-70)
rec("spec§4","Pérdida track (Δel) haz 216.87/0, bw 1°","",'~0',gain(38,1,1,30,wrapOffset(b[0]-f32(216.87)),b[1]-0)-38, ok=True, note="dB")

# Task 15 golden
RX=(0,0,10); A=(0,30000,0); B=(20000,0,50)
dAg=distanceM(A,RX); FA=fspl(dAg,3e9)
main=60+30-FA; side=60+5-FA
rec(15,"A: P_rx pico (G_rx=0)","60+30-FSPL",'>= -60',main, ok=main>=-60)
rec(15,"A: P_rx suelo","60+5-FSPL",'< -60 (para que haya ráfagas)',side, ok=side< -60)
need = -60 - (60 - FA)            # G_tx needed
half = 30*math.sqrt((30-need)/12)
rec(15,"A: semianchura de ráfaga (deg)","G_tx>=%.2f"%need,'-',half, ok=True, note="ráfaga ≈ %.1f ms de 50 ms, ≈%.1f pulsos (PRI media 1.25 ms)"%(2*half/360*50, 2*half/360*50/1.25))
dBg=distanceM(B,RX)
rec(15,"B: d","sqrt(20000²+40²)",'-',dBg, ok=True)
rec(15,"B: retardo ns","",'-',delay(dBg), ok=True, note=repr(dBg/C*1e9))
for f in (9e9,9.1e9):
    p=60+30-fspl(dBg,f)
    rec(15,"B: P_rx con P_tx=60 (supuesto), G=30, f=%g"%f,"",'>= -60',p, ok=p>=-60, note="FSPL=%.3f"%fspl(dBg,f))
rec(15,"az RX->A","",'≈0',directionFromTo(RX,A), ok=True)
rec(15,"az RX->B","",'≈90',directionFromTo(RX,B), ok=True)
bB=directionFromTo(B,RX); rec(15,"haz B->RX","",'-',bB, ok=True)

bad=0
for x in R:
    flag = "OK " if x[5] else "XX "
    if not x[5]: bad+=1
    print(flag, x[0], "|", x[1], "|", x[2], "| plan:", x[3], "| calc:", x[4], "|", x[6])
print("TOTAL", len(R), "discrepancias", bad)
```

## Anexo B: comprobaciones de sensibilidad (`extra.py`)

```python
import math, struct, sys
sys.path.insert(0, '/tmp/claude-1000/-home-hfernandezs-develop-ews/cc848326-c5c5-4091-905a-505249e185dd/scratchpad/numeric_review')
import io, contextlib
with contextlib.redirect_stdout(io.StringIO()):
    from verify import *
def ulps_f(a,b):
    ia=struct.unpack('i',struct.pack('f',a))[0]; ib=struct.unpack('i',struct.pack('f',b))[0]; return abs(ia-ib)
def ulps_d(a,b):
    ia=struct.unpack('q',struct.pack('d',a))[0]; ib=struct.unpack('q',struct.pack('d',b))[0]; return abs(ia-ib)
fwd=directionFromTo((0,0,0),(3,4,0))[0]; rev=directionFromTo((3,4,0),(0,0,0))[0]
e_d=math.fmod(fwd+180.0,360.0)
print("reverse: rev(float)=%r expected(double)=%r diff=%.3e"%(rev,e_d,rev-e_d))
print("  EXPECT_FLOAT_EQ ulps (float(expected) vs rev):", ulps_f(f32(e_d),rev))
print("  EXPECT_DOUBLE_EQ ulps:", ulps_d(rev,e_d))
# other pairs for reverse test with various points
for p in [(1,1,0),(3,4,0),(-7,2,0),(15000,20000,0),(0.3,-0.1,0),(123.4,-567.8,0)]:
    f=directionFromTo((0,0,0),p)[0]; r=directionFromTo(p,(0,0,0))[0]
    ef=f32(math.fmod(f32(f+180.0),360.0)); ed=math.fmod(f+180.0,360.0)
    print("  pair",p,"float-expr ulps",ulps_f(ef,r),"double-expr ulps(float)",ulps_f(f32(ed),r),"double diff %.2e"%(r-ed))
# wrap test sensitivity to receiver distance
for R in [1,10,100,1000,10000,30000]:
    th=math.radians(1); rx=(R*math.sin(th),R*math.cos(th),0)
    az,el=directionFromTo((0,0,0),rx); b=aoa(359,0)
    g=gain(35,2,20,30,wrapOffset(az-b[0]),el-b[1])
    print("wrap R=%g az=%r g=%r err=%.2e ulps_d=%d"%(R,az,g,g-23,ulps_d(g,23.0)))
# beam at 359 and receiver at 1 deg via aoa directly in float arithmetic (if wrapOffsetDeg computed in float)
print("358 offset float:", f32(f32(1.0)-f32(359.0)))
# llround half cases relevant for us->ns
for us in [0.0005,1.0005,0.0015,2.5e-3]:
    print("us",us,"x1e3=",repr(us*1e3),"llround",llround(us*1e3))
# Spec mission track gain toward RX
b=directionFromTo((15000,20000,30),(0,0,10))
print("track Δaz", wrapOffset(b[0]-f32(216.87)), "Δel", b[1])
# Spec §4 sanity of spec 'el ≈ 0,05'
print("el exact", math.degrees(math.atan2(20,25000)))
# Golden: A burst count over 0.1 s for some initial az (0) and stagger 1000/1500
def bursts(init):
    t=0; pri=stagger([1000_000,1500_000]); rows=[]
    rx=(0,0,10); A=(0,30000,0)
    azER,elER=directionFromTo(A,rx); F=fspl(distanceM(A,rx),3e9)
    while t<100_000_000:
        b=circular(init,50_000_000,0,t)
        g=gain(30,30,30,25,wrapOffset(azER-b[0]),elER-b[1])
        if 60+g-F>=-60: rows.append(t)
        t+=next(pri)
    return rows
for init in [0,90,180]:
    r=bursts(init); print("init",init,"detected A pulses",len(r),[round(x/1e6,1) for x in r])
```

Ejecución: `python3 -I verify.py` (97 comprobaciones; la única marcada XX es la variante con `180.0` en double de N2) y `python3 -I extra.py`.

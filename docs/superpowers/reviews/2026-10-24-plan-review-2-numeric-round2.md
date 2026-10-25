# Revisión numérica independiente (IV&V) del plan del simulador: segunda ronda

Fecha: 2026-10-24
Documentos revisados: `docs/superpowers/specs/2026-10-24-simulator-design.md` (spec, versión revisada) y
`docs/superpowers/plans/2026-10-24-simulator.md` (plan, versión revisada).
Referencia: `docs/superpowers/reviews/2026-10-24-plan-review-2-numeric.md` (primera ronda, hallazgos N1–N10).

## Resumen y veredicto

**Veredicto: los valores esperados del plan y de la spec son correctos.** He recalculado de forma independiente
**135 valores** con un script en Python (`verify2.py`, anexo A) y **8 más** compilando y ejecutando C++ con g++ 15.2 y
nlohmann/json 3.12.0 (`check.cpp` y `neg.cpp`, anexo C). En total, **143 comprobaciones**. El script implementa las
fórmulas de la spec y emula la normalización en `float` de `AngleOfArrival`. Además, reproduce la misión golden
**pulso a pulso**: segmentos semiabiertos, reinicio del estado por segmento, recorte en `durationS`, stagger, lista de
RF con `pulsesPerHop`, scan circular, antena gaussiana con suelo, FSPL con 147.55 y detección con `>=`.

- **Discrepancias en los valores esperados de los tests: 0.** Coinciden todos los valores fijados por el plan,
  incluida la golden completa: 131 filas (18 de A1 y 113 de B1, con 58 + 55), retardos, potencias, instantes de las
  ráfagas, frecuencias y el reinicio de la RF.
- **1 discrepancia de coherencia en la spec:** la antena `track` del catálogo de ejemplo (43 dBi con 1°×1°) cae fuera
  del rango que la propia spec da dos líneas más abajo (R2-N2). No afecta a ningún test.
- **N1–N10: los 10 resueltos.** N8 queda resuelto en lo esencial, pero deja un detalle abierto (R2-N4).
- **Hallazgos nuevos: 7** (1 Media, 5 Baja y 1 Duda). El más relevante (R2-N1): el test de `1e400` espera un mensaje
  que no se puede producir, porque nlohmann 3.12 rechaza `1e400` al parsear con una excepción `out_of_range` (no
  `parse_error`).
- La golden es **robusta frente a diferencias de último bit**. El valor formateado más cercano a una frontera de
  redondeo (la elevación de A1, 0.03819 → `0.0382`) está a 4.3·10⁻⁵ de ella, unas 10⁴ veces el ulp del `float`.

## Tabla de valores comprobados

Notación: tiempos en ns salvo que se indique otra unidad; ángulos en grados (los «calc.» de ángulos ya pasados por el
`float` de `AngleOfArrival`); potencias en dBm/dB.

| Tarea | Test | Entradas | Esperado (plan/spec) | Calculado | ¿Coincide? |
| --- | --- | --- | --- | --- | --- |
| 1 | secondsToTime | 1.5 s | 1 500 000 000 | 1 500 000 000 | Sí |
| 1 | microsecondsToTime | 1.0004 µs (×1e3 = 1000.4) | 1000 | 1000 | Sí |
| 1 | microsecondsToTime | 1.0006 µs (×1e3 = 1000.5999…) | 1001 | 1001 | Sí |
| 1 | microsecondsToTime [N10] | 0.0025 µs (×1e3 = 2.5 exacto; también `/1e-3`) | 3 | 3 con `llround`; 2 con `std::chrono::round` (comprobado en C++) | Sí (el test distingue bien) |
| 1 | timeToSeconds | 2.5e9 ns | 2.5 | 2.5 (`duration<double>` divide: exacto) | Sí |
| 1 | timeToMicroseconds | 1500 ns | 1.5 | 1.5 | Sí |
| 1 | distanceM | 3-4-5 | 5.0 | 5.0 | Sí |
| 1 | directionFromTo az | (0,0,0)→(3,4,0) | 36.8699 ± 1e-4 | 36.869896 | Sí |
| 1 | Cardinales N/E/S/W | (0,±1,0), (±1,0,0) | 0/90/180/270, el 0 | exactos | Sí (4 valores) |
| 1 | ReverseDiffersBy180 (NEAR 1e-4) | 3-4-5 | fmod(az+180.0, 360) = 216.86989594 | 216.86990356 (Δ 7.6e-6) | Sí |
| 1 | Elevación | (0,100,100) | 45 | 45.0 | Sí |
| 1 | Vertical | (0,0,10) | (0, 90) sin NaN | (0, 90) | Sí |
| 3 | FixedPri | 1000 | 1000×3 | ídem | Sí |
| 3 | StaggerPri | 1000,1200,1100 | 1000,1200,1100,1000 | ídem | Sí |
| 3 | SlidingPri | 100,130,10 | 100,110,120,130,100 | ídem | Sí |
| 3 | SlidingPri | 100,125,10 | 100,110,120,100 | ídem | Sí |
| 3 | DwellSwitchPri | {1000,2000},3 | 1000×3, 2000×3, 1000 | ídem | Sí |
| 3 | CloneKeepsState | stagger, avanzar 2 | clon y original → 1100 | 1100 / 1100; el clon sigue con 1000 | Sí |
| 4 | FixedRf / ListRf / FixedPw | plan | 3e9×2; 1e9,1e9,2e9,2e9,3e9,3e9,1e9; 500×2 | ídem | Sí (3 valores) |
| 5 | FixedScan | (216.87f, 0), t = 0 y 5 s | (216.87, 0) | (216.8699951, 0) | Sí con NEAR (2 valores) |
| 5 | Circular{0,6s,2} | t = 0 / 1.5 / 6 s | 0 / 90 / 0; el 2 | 0 / 90 / 0 (360 → 0); 2 | Sí (3) |
| 5 | Circular{350,6s,0} | t = 0.5 s | 20 | 20.0 | Sí |
| 5 | Sector{90,60,4s,0} | t = 0…4 s | 60, 90, 120, 90, 60 | ídem | Sí (5) |
| 5 | Sector{0,20,4s,0} | t = 0,1,2 s | 350, 0, 10 | ídem | Sí (3) |
| 6 | Gaussian{35,2,20,30} | (0,0) (1,0) (0,10) (1,10) (90,0) (−1,0) | 35, 32, 32, 29, 5, 32 | ídem (error 0) | Sí (6) |
| 8 | NextStartsAtSegmentStart | inicio 5 ms, seg. 100 ms, fin 100 ms | 5 ms, índice 0, seg. 0 | ídem | Sí |
| 8 | NextAdvancesByPri | ídem | 6 ms, índice 1 | ídem | Sí |
| 8 | NextSkipsOffSegment | [2.5, off 2, 2] ms, fin 100 ms | 5, 6, 7, 9.5, 10.5 ms; seg. 0,0,0,2,2 | ídem | Sí |
| 8 | NextResetsStateOnModeChange | Stagger{1,2,3} ms; 2.5 y 4 ms | 5, 6 \| 7.5, 8.5, 10.5 | ídem | Sí |
| 8 | NextPulseOnSegmentBoundary… | A 2 ms, B 10 ms | pulso en 7 ms con modo B | B | Sí |
| 8 | NextStopsAtEnd | seg. 10 ms (acaba en 15), fin 8 ms | 5, 6, 7 ms | ídem | Sí |
| 8 | NextUsesScanRelativeToSegmentStart | Circular{0,4ms,0}, t = 6 ms | 90 | 90 | Sí |
| 8 | NextDoesNotShareStateBetweenEmitters… | dos emisores, Stagger{1,2,3}, inicio 0, llamadas intercaladas | 0, 1, 3, 6 en ambos | ídem; con estado compartido saldría 0,1,4,6 / 0,2,3,6 (el test lo detecta) | Sí |
| 8 | NextReturnsNulloptWhenAllSegmentsOff | [off 5 ms] | nullopt | 0 pulsos | Sí |
| 8 | NextReturnsNulloptWhenStartAfterEnd | inicio 5, fin 5 | nullopt | 0 pulsos | Sí |
| 9 | propagationDelay | 299.792458 m / 0.1 m | 1000 / 0 | 1000 / 0 | Sí (2) |
| 9 | freeSpacePathLossDb | 1000 m, 1 GHz | 92.45 ± 1e-9 | 92.44999999999999 (−1.4e-14) | Sí |
| 9 | wrapOffsetDeg | 358, −358, 180, −180, 10 | −2, 2, 180, 180, 10 | ídem | Sí (5) |
| 9 | PropagateComputesArrivalTime | (0,299.792458,0), t_e 1 ms | 1 001 000 | 1 001 000 | Sí |
| 9 | PropagateComputesTxGainFromBeamOffset | RX (1000,0,0), haz 89° | 32 | 32 | Sí |
| 9 | PropagateWrapsBeamOffset [N4] | RX (1000·sin1°, 1000·cos1°, 0), haz (359, 0) | 23 | az_ER = 1.0f exacto → 23 | Sí |
| 9 | PropagateComputesIsotropicPower | 90 + 35 − FSPL(1000, 1e9) | 32.55 | 32.55000000000001 | Sí (NEAR) |
| 10 | Cabecera | spec §6 | 18 columnas | 18 | Sí |
| 10 | WriteFormatsRow | PDW y verdad del plan | `7,83391,3000.000000,1.000,-5.00,36.8700,0.0500,None,E1,search,0,3,0,25000.008,36.8700,0.0500,35.00,125.00` | idéntica (también con `std::format` real) | Sí |
| 10 | WriteWrapsAzimuthRoundedTo360 | 359.99997f (= 359.99996948) | `0.0000` | texto bruto `360.0000` → `0.0000` | Sí |
| 10 | WriteDoesNotPrintNegativeZero | el −0.00003f; amp −0.004f | `0.0000`, `0.00` | bruto `-0.0000`, `-0.00` (C++) → sin signo | Sí (2) |
| 11 | ReceiveDropsPulseBelowSensitivity | −73.01 + 3 | descartado | −70.01 < −70 | Sí |
| 11 | ReceiveKeepsPulseAtSensitivity | −73 + 3 | detectado, −70 | −70.0 exacto (double y float) | Sí |
| 11 | ReceiveKeepsPulseAboveSensitivity [F7] | −50 + 3 | detectado, −47 | −47.0 | Sí |
| 11 | ReceiveFillsPdwFromPulse | AoA 3-4-5 | 36.8699 ± 1e-4 | 36.869896 | Sí |
| 11 | ReceiveFillsGroundTruth | 90 + 32 | 122 | 122 | Sí |
| 12 | RunAllExecutesInTimeOrder / BreaksTies | 3,1,2 / A,B en 5 | 1,2,3 / A,B | ídem | Sí (2) |
| 13 | RunDeliversEveryPulse | 299.792458 m, dur. 3.5 ms | 1000; 1 001 000; 2 001 000; 3 001 000 | ídem | Sí |
| 13 | RunOrdersByArrivalTime | A 2998 m (10 000.25 → 10 000), B 299.79 m inicio 5 µs, dur. 0.5 ms | B 6000, A 10 000 (2 registros) | ídem | Sí |
| 13 | RunDeliversPulsesInFlightAfterEnd [N1] | dur. 5 µs, 2998 m | 1 registro, TOA 10 000 > 5000 | ídem | Sí |
| 13 | Potencias (P_tx 0, G 0 por SLL 0, f 1 GHz, sens −200) | 299.79 / 2998 m | detectadas | −81.99 / −101.99 dBm | Sí |
| 14 | ParseCatalogBuildsModes | 1.ª PRI 1000 µs; periodo 6 s | 1 000 000; 6·10⁹ | ídem | Sí (2) |
| 14 | ConvertsMicrosecondsWithRounding | 1.0006 | 1001 | 1001 | Sí |
| 14 | RejectsValueThatRoundsToZero | 0.0004 µs (0.4 ns) | 0 → error | 0 | Sí |
| 14 | RejectsPeriodThatRoundsToZero | 1e-10 s (0.1 ns) | 0 → error | 0 | Sí |
| 14 | RejectsTimeTooLarge | 1e7 s | > 10⁶ s → error | sí | Sí |
| 14 | RejectsPwNotBelowMinPri [N7] | stagger [1000, 900], PW 900 | `(900 µs)… (900 µs)` | `std::format("{}", 900.0)` = `900` (C++) | Sí |
| 14 | Mensaje con fracción | 1 000 500 ns | `1000.5` | `1000.5` (C++) | Sí |
| 14 | RejectsPwEqualToPriAfterRounding | 999.9996 / 1000.0004 µs | ambos 1000 ns → error | 999 999.6 → 1 000 000; 1 000 000.4 → 1 000 000 | Sí |
| 14 | RejectsElevationOutOfRange | mensaje con −90 / 90 | `debe estar entre -90 y 90` | `{}` de −90.0 = `-90` (C++) | Sí |
| 14 | RejectsNonFiniteNumber | `1e400` | `debe ser un número finito` | nlohmann lanza `out_of_range.406` al parsear | **No alcanzable** (R2-N1) |
| 14 | RejectsNegativeInteger | `pulsesPerHop: -1` | «uno de los dos» | `is_number_integer()` = true → `debe ser >= 1` (C++) | Determinable (R2-N6) |
| 14 | Spec §5: PW < PRI | search 1 < 1000; track 0.5 < 250 | válido | sí | Sí |
| 14 | Golden: PW < PRI | A 1 < 1000; B 0.5 < 700 | válido | sí | Sí |
| spec §5 | Coherencia G–θ `search` | 30 dBi, 1.5°×20° | K 25 000–30 000 → 29.2–30.0 dBi | K implícita 30 000 | Sí |
| spec §5 | Coherencia G–θ `track` | 43 dBi, 1°×1° | 44.0–44.8 dBi | K implícita 19 953 | **No** (R2-N2) |
| 16 | Coherencia G–θ golden A / B | 16 dBi 30°×30°; 30 dBi 6°×6° | «coherentes» | K 35 830 / 36 000 (entre la real y la ideal 41 253) | Sí (2) |
| 15 | ParseMissionBuildsEmittersAndReceiver | startS 5 | 5 s, `search` | 5·10⁹, search | Sí |
| 15 | ParseMissionChainsSegmentsFromStart | 5 + 40 + 10 | 55 s, segmento 2 | 55·10⁹, 2 | Sí |
| 15 | ParseMissionAcceptsScheduleBeyondDuration | durationS 50 | último < 50 s | 44.9993 s (36 364 pulsos) | Sí |
| spec §4 | d / retardo / FSPL | E (15000,20000,30), RX (0,0,10), 3 GHz | ≈25 000 / ≈83 391 / ≈130 | 25 000.008 / 83 391 / 129.951 | Sí (3) |
| spec §4 | AoA / haz | ídem | (≈36.87, ≈0.05) / ≈216.87 | (36.8699, 0.0458) / 216.8699 | Sí (2) |
| spec §4 | P_iso con G_max 30, SLL 30 | 90 + 30 − FSPL / 90 + 0 − FSPL | ≈ −10 / ≈ −40 | −9.951 / −39.951 | Sí (2) |
| spec §4 | Detección de laterales con −70 | | todos | −39.95 ≥ −70 | Sí |
| 16 | Filas totales / A1 / B1 | golden.json | 131 / 18 / 113 | 131 / 18 / 113 | Sí |
| 16 | B1 por segmento | | 58 / 55 | 58 / 55 | Sí |
| 16 | A1: d y retardo | (0,30000,30) → (0,0,10) | 30 000.007 m; 100 069 | 30 000.007; 100 069.25 → 100 069 | Sí (2) |
| 16 | A1: pico / suelo | 74 + 16 − FSPL / 74 − 9 − FSPL | −41.53 / −66.53 | −41.53 / −66.53 | Sí (2) |
| 16 | A1: ráfagas | stagger 1/1.5 ms, scan 50 ms desde 0° | 9 pulsos, 20 100 069 → 30 100 069 y 70 100 069 → 80 100 069 | ídem (80 pulsos emitidos) | Sí |
| 16 | A1: amplitud en 25 y 75 ms | haz en 180° | −41.53 | −41.53, −41.53 | Sí |
| 16 | A1: azimuthDeg | RX → A1 | ≈ 0 | `0.0000` en todas | Sí |
| 16 | A1: margen en los bordes de ráfaga | | — | 1.185 dB sobre −60 (G_tx −1.28 dBi a 36°) | Robusto |
| 16 | B1: d y retardo | (20000,0,50) → (0,0,10) | 20 000.040 m; 66 713 | 20 000.040; 66 712.95 → 66 713 | Sí (2) |
| 16 | B1: primera toaNs / primera fila del CSV | | 2 066 713; B1 | 2 066 713; B1 | Sí (2) |
| 16 | B1: azimuthDeg | | 90 | `90.0000` | Sí |
| 16 | B1: amplitudeDbm | 9000 / 9100 MHz | −47.56 / −47.65 | −47.5555 / −47.6515 (G_tx = 30.000000000000) | Sí |
| 16 | B1: frecuencias | lista, 3 por salto | 9000×3, 9100×3, … | ídem | Sí |
| 16 | B1: reinicio de RF | último del seg. 0 / primero del seg. 2 | reinicia a 9000 | 9100 → 9000 (sin reinicio sería 9100: el reinicio es observable) | Sí |
| 16 | Sin emisión en [42, 62) ms | | 0 filas | 0 | Sí |
| 16 | truth_segmentIndex de B1 | | 0 y 2 | {0, 2} | Sí |
| 16 | Recorte del último segmento | 62 + 0.7k < 100 ms | recortado | último pulso 99.8 ms (TOA 99 866 713) | Sí |
| 16 | Empates de toaNs A1/B1 | | — | 0 | Sí |
| 16 | txGain / eirp de B1 formateados | | — | `30.00` / `90.00` | Coherente |

La salida completa (135 líneas `OK`/`XX`) se obtiene ejecutando el anexo A. La única línea `XX` es la de R2-N2.

## Estado de los hallazgos de la primera ronda

| Id | Hallazgo | Estado | Dónde se resuelve |
| --- | --- | --- | --- |
| N1 | Test de pulsos en vuelo mal planteado | **Resuelto** | Tarea 13: duración 5 µs, llegada 10 000 > 5000 (verificado). |
| N2 | `==` en la ida y vuelta de 180° | **Resuelto** | Tarea 1: `EXPECT_NEAR(…, 1e-4)` «nunca ==»; Global Constraints fijan las tolerancias (Δ real 7.6e-6). |
| N3 | Texto del Review Focus 2 | **Resuelto** | «23 dBi con θ_az = 2°, no el suelo (5 dBi)». |
| N4 | Posición y tolerancia del test de wrap | **Resuelto** | Tarea 9: `{1000·sin(1°), 1000·cos(1°), 0}` y NEAR 1e-6. |
| N5 | Golden sin especificar | **Resuelto** | Tarea 16: catálogo, misión y valores de verificación completos; todos verificados pulso a pulso. |
| N6 | Entradas de los tests del emisor | **Resuelto** | Tarea 8: segmento de 100 ms y fin 100 ms por defecto; `NextStopsAtEnd` con segmento de 10 ms. |
| N7 | Formato del número en el mensaje PW/PRI | **Resuelto** | `std::format("{}", timeToMicroseconds(…))` → `900`, `1000.5` (comprobado en C++). |
| N8 | Potencias de los tests de `Simulation` | **Resuelto** (con un detalle abierto, R2-N4) | P_tx 0, antena con SLL 0, G_rx 0, sensibilidad −200, duraciones fijadas. |
| N9 | Elevación apuntada por B | **Resuelto** | `pointingElevationDeg: -0.1146`; desvío residual 8.4e-6° → pérdida ≈ 2e-11 dB. |
| N10 | Caso .5 de redondeo | **Resuelto** | `microsecondsToTime(0.0025) == 3`; 0.0025·1e3 es 2.5 exacto en double, así que el test sí distingue `llround` de `chrono::round`/`nearbyint`. |

## Hallazgos nuevos

### R2-N1. Media: el test de `1e400` espera un mensaje que nlohmann no deja producir

- **Ubicación:** plan, Tarea 14, `ParseCatalogRejectsNonFiniteNumber`, y en general la regla «Toda llamada que pueda
  lanzar (`parse`, `get<T>`) se hace dentro de un `try`».
- **Descripción:** nlohmann/json 3.12.0 **no** devuelve `inf` para `1e400`. Su parser lanza
  `json::out_of_range` (id 406, `number overflow parsing '1e400'`), que no es un `json::parse_error`. Dos
  consecuencias:
  1. El texto esperado `debe ser un número finito` es inalcanzable desde un fichero JSON. El plan ya prevé la
     alternativa («si nlohmann resultara rechazar `1e400`…»), así que el test queda indeterminado hasta que se ejecute.
  2. Si el loader captura solo `json::parse_error` (lo natural para «JSON mal formado»), la excepción
     `out_of_range` **escapa** sin convertirse en `ConfigError`, y se incumple el Review Focus 5.
- **Cálculo:** ejecutado con g++ 15.2 sobre el `json.hpp` 3.12.0 (anexo C): `parse(R"({"peakPowerDbm": 1e400})")`
  → `other json::exception (id 406): [json.exception.out_of_range.406] number overflow parsing '1e400'`. El código
  correspondiente está en `json.hpp`, en el parser (`out_of_range::create(406, …)` dentro de `parse_error`).
- **Corrección sugerida:** fijar el esperado a `X.json: JSON mal formado: [json.exception.out_of_range.406] number
  overflow parsing '1e400'` (o comprobar solo el prefijo `X.json: JSON mal formado:`). Exigir en el plan que el
  `try` de `parse` capture `nlohmann::json::exception` (la base común), no solo `parse_error`. La comprobación
  `std::isfinite` de `number` se mantiene como defensa, pero conviene decir que hoy no la alcanza ningún JSON.

### R2-N2. Baja: la antena `track` del catálogo de ejemplo no cumple la regla de coherencia de la spec

- **Ubicación:** spec §5, catálogo de ejemplo (`"peakGainDbi": 43` con 1°×1°) y el párrafo que le sigue
  («K ≈ 25 000–30 000 con eficiencia real»).
- **Cálculo:** `10·log10(25 000 / 1) = 43.98 dBi`, `10·log10(30 000) = 44.77 dBi` e ideal `10·log10(41 253) =
  46.15 dBi`. 43 dBi implica K ≈ 19 950, por debajo del rango. Las otras tres antenas sí encajan: `search` (30 dBi,
  K = 30 000), golden A (K = 35 830) y golden B (K = 36 000).
- **Impacto:** ninguno en los tests (el loader no lo comprueba). Es una incoherencia de texto.
- **Corrección sugerida:** `peakGainDbi: 44` en `track`, o ampliar el rango del texto («≈ 20 000–30 000»).

### R2-N3. Baja: el scan circular pierde precisión si el azimut se normaliza en `float` sin reducir antes la fase

- **Ubicación:** plan, Tarea 5 («`CircularScan` necesita la misma fracción `t / T` en `double`»), y spec §2
  («resolución ≈ 3·10⁻⁵° cerca de 360°»).
- **Descripción:** la fórmula `az = initial + 360·t'/T`, pasada a `AngleOfArrival` con `static_cast<float>` antes de
  normalizar, convierte a `float` un ángulo de muchas vueltas. Su ulp crece con el número de vueltas. La
  normalización de `AngleOfArrival` es exacta, pero el valor ya llega redondeado.
- **Cálculo** (diferencia frente a reducir la fase con `t' % T` en enteros, como hace el sector):
  - 120 s con T = 6 s (7200°): 1.4·10⁻⁴°. Despreciable.
  - 10⁶ s (máximo permitido) con T = 6 s: 0.074°.
  - 10⁶ s con T = 1 ms: el azimut no significa nada (ulp de 3.6·10¹¹° en `float` ≈ 4500°).
  - En la golden no cambia ninguna cifra impresa: comprobado en las 18 filas de A1.
- **Corrección sugerida:** calcular `phase = duration<double>(t' % T) / T` también en `CircularScan`, igual que en
  `SectorScan`. Así la afirmación de la spec §2 sobre la resolución se cumple siempre, y no solo en misiones cortas.

### R2-N4. Baja: en los tests de `Simulation` no se dice qué corta la emisión ni se dan la duración del segmento ni las posiciones

- **Ubicación:** plan, Tarea 13 (los tres tests de `Simulation`).
- **Descripción:** la «duración» (3.5 ms, 0.5 ms, 5 µs) es un atributo de `Mission`, pero el corte real lo hace
  `Emitter::endNs_` (Tarea 8, «nunca se devuelve un pulso con t ≥ `endNs_`»). En los tests, el `Emitter` se construye
  a mano y el plan no dice que su `endNs_` deba ser igual a la duración de la misión. Tampoco da la duración del
  segmento ni la dirección de las posiciones («a 2998 m»). La dirección no importa (con SLL 0, G = 0 dBi en cualquier
  dirección; verificado), pero los otros dos datos sí:
  - con un segmento de 1 ms o menos, `RunDeliversEveryPulse` daría 1 registro y no 4;
  - con `endNs_` mayor que la duración de la misión, `RunDeliversPulsesInFlightAfterEnd` registraría pulsos en 1 ms,
    2 ms, etc.
- **Corrección sugerida:** indicar «cada emisor con un único segmento de 1 s y `endNs_` = duración de la misión;
  posiciones `(0, d, 0)`». O bien decidir que `Simulation` impone la duración de `Mission` a sus emisores y probarlo.

### R2-N5. Baja: `numberInRange(clave, a, b)` no puede expresar los intervalos abiertos que pide la spec

- **Ubicación:** plan, Tarea 14 (`numberInRange`, mensaje `debe estar entre <a> y <b>`); spec §5 (`widthDeg` en
  (0, 360), anchos de haz en (0, 180], elevaciones en [−90, 90]).
- **Descripción:** hay una sola firma y un solo mensaje para tres tipos de intervalo. Los valores de los tests (400,
  200, 95) caen fuera del intervalo con cualquier interpretación, así que una implementación cerrada [0, 360] pasaría
  los tests aceptando `widthDeg: 0` (sector degenerado: el scan se queda quieto) o `beamwidthAzDeg: 0` (división por
  cero en `gainDbi` → `-inf`/NaN en el CSV).
- **Corrección sugerida:** dar a `numberInRange` los extremos abiertos o cerrados (o añadir `numberInOpenRange`) y
  añadir casos frontera: `widthDeg: 0`, `widthDeg: 360`, `beamwidthAzDeg: 0` → error; `beamwidthAzDeg: 180` y
  `elevationDeg: 90` → válidos. Si el mensaje se mantiene igual para todos, indicarlo; si no, fijar el texto
  (p. ej. `debe estar en (0, 360)`).

### R2-N6. Baja: el mensaje de `pulsesPerHop: -1` se puede fijar ya

- **Ubicación:** plan, Tarea 14, `ParseCatalogRejectsNegativeInteger` («`debe ser un entero` o `debe ser >= 1` …
  fijarlo al implementar»).
- **Cálculo:** en nlohmann 3.12, `-1` se guarda como `number_integer` y `is_number_integer()` devuelve `true`
  (comprobado en C++: `-1` → entero sí, sin signo no; `2.5` → entero no). Con el orden que pide el plan para
  `positiveInteger` (primero `is_number_integer()`, después el rango), el mensaje es **`debe ser >= 1`**.
- **Corrección sugerida:** escribir el esperado exacto
  `X.json: modes.<m>.rf.pulsesPerHop: debe ser >= 1`, para que el test no dependa de lo que salga.

### R2-N7. Duda: valores del test de autoasignación de `AngleOfArrival` y del resto de R12

- **Ubicación:** plan, Tareas 2–16 («R12 completos»).
- **Descripción:** no son valores numéricos del plan y no los he podido comprobar. Solo señalo que, en las clases
  con `AngleOfArrival` (`FixedScan`, `EmittedPulse`, `GroundTruth`, PDW), los valores de prueba deben estar ya
  normalizados y ser representables en `float` (p. ej. `216.87f`, no `216.87`). Si no, `EXPECT_FLOAT_EQ(get…, 216.87)`
  compara un `float` normalizado con un `double`. Funciona (4 ulp), pero un `EXPECT_EQ` fallaría. La regla ya está
  en Global Constraints («literales `float` con sufijo `f`»); no hay error, solo conviene vigilarlo al escribir los
  R12.

## Entradas sin especificar y tests sensibles a la forma de la comparación

- **Sin especificar:** el corte de los emisores en los tests de `Simulation` (R2-N4), los extremos abiertos o
  cerrados de `numberInRange` (R2-N5) y el esperado de `-1` (R2-N6).
- **Sensibles a cómo se implemente o se compare** (con lo que pide el plan, todos pasan):
  - `microsecondsToTime(0.0025)`: da 3 con `llround` y 2 con `std::chrono::round`. Es intencionado: el test fija la
    regla.
  - Ángulos: `ReverseDiffersBy180` necesita NEAR (Δ 7.6e-6). `FixedScan` 216.87 da 216.8699951 en `float`.
  - Golden: el formato `{:.2f}`/`{:.4f}` deja todos los valores a ≥ 4.3·10⁻⁵ de una frontera de redondeo. No
    depende del último bit de `atan2`/`log10`.
  - Mensajes de error con `std::format("{}", double)`: `900`, `1000.5`, `-90`, `0`, `180` (comprobado en C++). Si se
    formatease un `float` en lugar de un `double`, `{}` también da el texto más corto, así que no cambia nada en estos
    valores.
  - `1e400`: ver R2-N1.

## Anexo A: script de verificación (`verify2.py`)

Ubicación: `/tmp/claude-1000/-home-hfernandezs-develop-ews/bfa41cbf-50f4-4c97-b76e-d1394bb2f671/scratchpad/review2-round2/verify2.py`.
Ejecución: `python3 -I verify2.py` → `TOTAL 135 discrepancias 1` (la línea `XX` es R2-N2).

```python
# Round-2 independent numeric verification of the simulator plan/spec (formulas from the spec).
import math, struct, heapq

C = 299_792_458.0
NS = 1_000_000_000; MS = 1_000_000; US = 1000

def f32(x): return struct.unpack('f', struct.pack('f', x))[0]

def wrap_angle_f32(v, vmin, period):          # AngleOfArrival::wrap_angle (float)
    v, vmin, period = f32(v), f32(vmin), f32(period)
    off = f32(math.fmod(f32(v - vmin), period))
    if off < 0: off = f32(off + period)
    if off >= period: off = 0.0
    return f32(vmin + off)

def aoa(az, el):                              # AngleOfArrival(float, float) + normalize()
    az, el = f32(az), f32(el)
    el = wrap_angle_f32(el, -180, 360)
    if el > 90: el = f32(180 - el); az = f32(az + 180)
    elif el < -90: el = f32(-180 - el); az = f32(az + 180)
    return (wrap_angle_f32(az, 0, 360), el)

def llround(x): return int(math.floor(abs(x) + 0.5)) * (1 if x >= 0 else -1)
def half_even(x): return round(x)             # std::nearbyint / std::chrono::round

def secondsToTime(s): return llround(s * 1e9)
def microsecondsToTime(us): return llround(us * 1e3)
def timeToSeconds(t): return t / 1e9
def timeToMicroseconds(t): return t / 1e3

def distanceM(a, b): return math.sqrt(sum((bi - ai) ** 2 for ai, bi in zip(a, b)))
def direction(a, b):
    dE, dN, dU = b[0]-a[0], b[1]-a[1], b[2]-a[2]
    az = math.degrees(math.atan2(dE, dN))
    if az < 0: az += 360.0
    el = math.degrees(math.atan2(dU, math.hypot(dE, dN)))
    return aoa(az, el)

class Fixed:
    def __init__(s, v): s.v = v
    def next(s): return s.v
class Cyclic:                                  # stagger (n=1), dwellSwitch / list (n=per)
    def __init__(s, vs, n=1): s.vs, s.n, s.i, s.k = vs, n, 0, 0
    def next(s):
        v = s.vs[s.i]; s.k += 1
        if s.k >= s.n: s.k = 0; s.i = (s.i + 1) % len(s.vs)
        return v
class Sliding:
    def __init__(s, mn, mx, st): s.mn, s.mx, s.st, s.c = mn, mx, st, mn
    def next(s):
        v = s.c; s.c += s.st
        if s.c > s.mx: s.c = s.mn
        return v

def circular(init, T, el, t): return aoa(init + 360.0 * (t / T), el)
def circular_mod(init, T, el, t): return aoa(init + 360.0 * ((t % T) / T), el)
def sector(center, width, T, el, t):
    left = center - width / 2; ph = (t % T) / T
    return aoa(left + width * 2 * ph if ph < 0.5 else left + width * 2 * (1 - ph), el)
def fixedscan(az, el, t): return aoa(az, el)

def gain(G, baz, bel, sll, daz, de): return max(G - 12 * ((daz / baz) ** 2 + (de / bel) ** 2), G - sll)
def delay(d): return llround(d / C * 1e9)
def fspl(d, f): return 20 * math.log10(d) + 20 * math.log10(f) - 147.55
def wrapOffset(x):
    r = math.fmod(x + 180.0, 360.0)
    if r <= 0: r += 360.0
    return r - 180.0

# Emitter: half-open segments, per-segment reset, clip at end. mode=None -> off
def emitter(start, schedule, end):
    """schedule: [(modeId, dur, mode_dict or None, scan_fn)] ; yields pulses dicts"""
    out = []; t0 = start; idx = 0
    for si, (mid, dur, mode, scan) in enumerate(schedule):
        if t0 >= end: break
        seg_end = t0 + dur
        if mode is not None:
            pri, rf, pw = mode['pri'](), mode['rf'](), mode['pw']()
            t = t0
            while t < seg_end and t < end:
                out.append(dict(t=t, mode=mid, seg=si, idx=idx, f=rf.next(), pw=pw.next(),
                                beam=scan(t - t0), mp=mode))
                idx += 1
                p = pri.next(); assert p > 0; t += p
        t0 = seg_end
    return out

R = []
def rec(task, test, inputs, plan, mine, ok=None, note=""):
    if ok is None: ok = (plan == mine)
    R.append((task, test, inputs, plan, mine, ok, note))

# ---------------- Task 1
rec(1, "secondsToTime", "1.5 s", 1_500_000_000, secondsToTime(1.5))
rec(1, "microsecondsToTime", "1.0004", 1000, microsecondsToTime(1.0004), note=repr(1.0004e3))
rec(1, "microsecondsToTime", "1.0006", 1001, microsecondsToTime(1.0006), note=repr(1.0006e3))
rec(1, "microsecondsToTime (llround)", "0.0025 (x1e3=%r)" % (0.0025 * 1e3), 3, microsecondsToTime(0.0025),
    note="half-even (nearbyint/chrono::round) daria %d" % half_even(0.0025 * 1e3))
rec(1, "timeToSeconds", "2.5e9 ns", 2.5, timeToSeconds(2_500_000_000))
rec(1, "timeToMicroseconds", "1500 ns", 1.5, timeToMicroseconds(1500))
rec(1, "distanceM", "3-4-5", 5.0, distanceM((0,0,0),(3,4,0)))
az = direction((0,0,0),(3,4,0))[0]
rec(1, "directionFromTo az", "3-4-5", "36.8699±1e-4", az, ok=abs(az-36.8699) < 1e-4)
for n, p, e in [("N",(0,1,0),0.0),("E",(1,0,0),90.0),("S",(0,-1,0),180.0),("W",(-1,0,0),270.0)]:
    a = direction((0,0,0), p); rec(1, "cardinal "+n, str(p), (e, 0.0), a, ok=abs(a[0]-e) < 1e-4 and a[1] == 0)
fwd = direction((0,0,0),(3,4,0))[0]; rev = direction((3,4,0),(0,0,0))[0]
rec(1, "ReverseDiffersBy180 (NEAR 1e-4)", "3-4-5", math.fmod(fwd+180.0, 360.0), rev,
    ok=abs(rev - math.fmod(fwd+180.0, 360.0)) < 1e-4, note="diff %.2e" % (rev - math.fmod(fwd+180.0, 360.0)))
rec(1, "elevation", "(0,100,100)", 45.0, direction((0,0,0),(0,100,100))[1])
rec(1, "straight up", "(0,0,10)", (0.0, 90.0), direction((0,0,0),(0,0,10)))

# ---------------- Task 3 / 4
take = lambda g, n: [g.next() for _ in range(n)]
rec(3, "FixedPri", "1000", [1000]*3, take(Fixed(1000), 3))
rec(3, "StaggerPri", "1000,1200,1100", [1000,1200,1100,1000], take(Cyclic([1000,1200,1100]), 4))
rec(3, "SlidingPri", "100,130,10", [100,110,120,130,100], take(Sliding(100,130,10), 5))
rec(3, "SlidingPri", "100,125,10", [100,110,120,100], take(Sliding(100,125,10), 4))
rec(3, "DwellSwitchPri", "{1000,2000},3", [1000,1000,1000,2000,2000,2000,1000], take(Cyclic([1000,2000],3), 7))
g = Cyclic([1000,1200,1100]); g.next(); g.next(); import copy; c = copy.deepcopy(g)
rec(3, "CloneKeepsState", "stagger, avanzar 2", (1100, 1100, 1000), (c.next(), g.next(), c.next()))
rec(4, "FixedRf", "3e9", [3e9, 3e9], take(Fixed(3e9), 2))
rec(4, "ListRf", "{1e9,2e9,3e9},2", [1e9,1e9,2e9,2e9,3e9,3e9,1e9], take(Cyclic([1e9,2e9,3e9],2), 7))
rec(4, "FixedPw", "500 ns", [500, 500], take(Fixed(500), 2))

# ---------------- Task 5
near = lambda a, b, tol=1e-4: abs(a[0]-b[0]) < tol and abs(a[1]-b[1]) < tol
for t in (0, 5*NS):
    v = fixedscan(216.87, 0.0, t); rec(5, "FixedScan", "t=%d" % t, (216.87, 0.0), v, ok=near(v, (216.87, 0.0)))
for t, e in [(0, 0.0), (1.5, 90.0), (6, 0.0)]:
    v = circular(0, 6*NS, 2, secondsToTime(t)); rec(5, "Circular{0,6s,2}", "t=%gs" % t, (e, 2.0), v, ok=near(v, (e, 2.0)))
v = circular(350, 6*NS, 0, secondsToTime(0.5)); rec(5, "Circular{350,6s,0}", "t=0.5s", (20.0, 0.0), v, ok=near(v, (20.0, 0.0)))
for t, e in [(0,60),(1,90),(2,120),(3,90),(4,60)]:
    v = sector(90, 60, 4*NS, 0, t*NS); rec(5, "Sector{90,60,4s,0}", "t=%ds" % t, (e, 0.0), v, ok=near(v, (e, 0.0)))
for t, e in [(0,350),(1,0),(2,10)]:
    v = sector(0, 20, 4*NS, 0, t*NS); rec(5, "Sector{0,20,4s,0}", "t=%ds" % t, (e, 0.0), v, ok=near(v, (e, 0.0)))

# ---------------- Task 6
for o, e in [((0,0),35),((1,0),32),((0,10),32),((1,10),29),((90,0),5),((-1,0),32)]:
    v = gain(35,2,20,30,*o); rec(6, "Gaussian{35,2,20,30}", str(o), float(e), v, ok=abs(v-e) < 1e-9)

# ---------------- Task 8 Emitter
P1 = dict(pri=lambda: Fixed(1*MS), rf=lambda: Fixed(3e9), pw=lambda: Fixed(1*US))
FS = lambda t: fixedscan(0, 0, t)
r = emitter(5*MS, [("A", 100*MS, P1, FS)], 100*MS)
rec(8, "NextStartsAtSegmentStart", "inicio 5 ms", (5*MS, 0, 0), (r[0]['t'], r[0]['idx'], r[0]['seg']))
rec(8, "NextAdvancesByPri", "", (6*MS, 1), (r[1]['t'], r[1]['idx']))
r = emitter(5*MS, [("A", 2_500_000, P1, FS), ("off", 2*MS, None, None), ("A", 2*MS, P1, FS)], 100*MS)
rec(8, "NextSkipsOffSegment", "[2.5, off 2, 2] ms, fin 100", ([5,6,7,9.5,10.5],[0,0,0,2,2]),
    ([x['t']/MS for x in r], [x['seg'] for x in r]))
ST = dict(pri=lambda: Cyclic([1*MS,2*MS,3*MS]), rf=lambda: Fixed(3e9), pw=lambda: Fixed(1*US))
r = emitter(5*MS, [("A", 2_500_000, ST, FS), ("B", 4*MS, ST, FS)], 100*MS)
rec(8, "NextResetsStateOnModeChange", "stagger 1,2,3; 2.5 y 4 ms", [5,6,7.5,8.5,10.5], [x['t']/MS for x in r])
r = emitter(5*MS, [("A", 2*MS, P1, FS), ("B", 10*MS, P1, FS)], 100*MS)
rec(8, "NextPulseOnSegmentBoundary", "A 2 ms, B 10 ms", ["B"], [x['mode'] for x in r if x['t'] == 7*MS])
r = emitter(5*MS, [("A", 10*MS, P1, FS)], 8*MS)
rec(8, "NextStopsAtEnd", "seg 10 ms, fin 8 ms", [5,6,7], [x['t']/MS for x in r])
r = emitter(5*MS, [("A", 100*MS, P1, lambda t: circular(0, 4*MS, 0, t))], 100*MS)
v = [x['beam'] for x in r if x['t'] == 6*MS][0]
rec(8, "NextUsesScanRelativeToSegmentStart", "Circular{0,4ms,0}, t=6 ms", (90.0, 0.0), v, ok=near(v, (90.0, 0.0)))
e1 = emitter(0, [("A", 100*MS, ST, FS)], 100*MS); e2 = emitter(0, [("A", 100*MS, ST, FS)], 100*MS)
rec(8, "NextDoesNotShareStateBetweenEmitters", "stagger 1,2,3, inicio 0", ([0,1,3,6],[0,1,3,6]),
    ([x['t']/MS for x in e1[:4]], [x['t']/MS for x in e2[:4]]))
# shared-state bug model: interleaved on one generator -> what a buggy impl would give
g = Cyclic([1*MS,2*MS,3*MS]); ta = tb = 0; A_ = [0]; B_ = [0]
for _ in range(3): ta += g.next(); A_.append(ta//MS); tb += g.next(); B_.append(tb//MS)
rec(8, "  (modelo con estado compartido: el test lo detecta)", "", "distinto de 0,1,3,6", (A_, B_), ok=A_ != [0,1,3,6])
rec(8, "NextReturnsNulloptWhenAllSegmentsOff", "[off 5 ms]", 0, len(emitter(0, [("off", 5*MS, None, None)], 100*MS)))
rec(8, "NextReturnsNulloptWhenStartAfterEnd", "inicio 5, fin 5", 0, len(emitter(5*MS, [("A", 10*MS, P1, FS)], 5*MS)))

# ---------------- Task 9
rec(9, "propagationDelay", "299.792458", 1000, delay(299.792458))
rec(9, "propagationDelay", "0.1", 0, delay(0.1))
v = fspl(1000, 1e9); rec(9, "FSPL", "1000 m, 1 GHz", 92.45, v, ok=abs(v-92.45) < 1e-9, note="err %.1e" % (v-92.45))
for x, e in [(358,-2),(-358,2),(180,180),(-180,180),(10,10)]:
    rec(9, "wrapOffsetDeg", str(x), float(e), wrapOffset(x))
rec(9, "PropagateComputesArrivalTime", "(0,299.792458,0), te 1 ms", 1*MS + 1000, 1*MS + delay(distanceM((0,299.792458,0),(0,0,0))))
a = direction((0,0,0),(1000,0,0)); b = aoa(89, 0)
v = gain(35,2,20,30,wrapOffset(a[0]-b[0]), a[1]-b[1]); rec(9, "PropagateComputesTxGainFromBeamOffset", "RX E, haz 89", 32.0, v, ok=abs(v-32) < 1e-6)
th = math.radians(1); a = direction((0,0,0),(1000*math.sin(th),1000*math.cos(th),0)); b = aoa(359, 0)
v = gain(35,2,20,30,wrapOffset(a[0]-b[0]), a[1]-b[1]); rec(9, "PropagateWrapsBeamOffset", "az 1.0f=%r, haz 359" % a[0], 23.0, v, ok=abs(v-23) < 1e-6)
v = 90 + 35 - fspl(1000, 1e9); rec(9, "PropagateComputesIsotropicPower", "", 32.55, v, ok=abs(v-32.55) < 1e-6)

# ---------------- Task 10 CSV
def fmt(x, p): s = "%.*f" % (p, x); return s[1:] if s.startswith('-') and float(s) == 0 else s
def fmt_az(x): s = fmt(x, 4); return "0.0000" if s == "360.0000" else s
pa = aoa(36.87, 0.05)
row = ",".join(["7","83391","%.6f" % (3e9/1e6), "%.3f" % (1000/1e3), fmt(f32(-5.0),2), fmt_az(pa[0]), fmt(pa[1],4), "None",
                "E1","search","0","3","0", "%.3f" % 25000.008, fmt_az(pa[0]), fmt(pa[1],4), fmt(35.0,2), fmt(125.0,2)])
exp = "7,83391,3000.000000,1.000,-5.00,36.8700,0.0500,None,E1,search,0,3,0,25000.008,36.8700,0.0500,35.00,125.00"
rec(10, "WriteFormatsRow (18 col.)", "plan", exp, row, note="%d columnas" % len(row.split(',')))
hdr = "pulseId,toaNs,frequencyMHz,pulseWidthUs,amplitudeDbm,azimuthDeg,elevationDeg,intrapulseModulation,truth_emitterId,truth_modeId,truth_segmentIndex,truth_emitterPulseIndex,truth_emissionNs,truth_distanceM,truth_azimuthDeg,truth_elevationDeg,truth_txGainDbi,truth_eirpDbm"
rec(10, "cabecera", "18 columnas", 18, len(hdr.split(',')))
w = aoa(359.99997, 0)[0]
rec(10, "WriteWrapsAzimuthRoundedTo360", "359.99997f -> %r, raw '%.4f'" % (w, w), "0.0000", fmt_az(w))
rec(10, "WriteDoesNotPrintNegativeZero el", "-0.00003f raw '%.4f'" % f32(-0.00003), "0.0000", fmt(aoa(0, -0.00003)[1], 4))
rec(10, "WriteDoesNotPrintNegativeZero amp", "-0.004f raw '%.2f'" % f32(-0.004), "0.00", fmt(f32(-0.004), 2))

# ---------------- Task 11
rec(11, "ReceiveDropsPulseBelowSensitivity", "-73.01 + 3", False, (-73.01 + 3) >= -70, note=repr(-73.01+3))
rec(11, "ReceiveKeepsPulseAtSensitivity", "-73 + 3", (True, -70.0), ((-73.0+3) >= -70, f32(-73.0+3)))
rec(11, "ReceiveKeepsPulseAboveSensitivity", "-50 + 3", (True, -47.0), ((-50.0+3) >= -70, f32(-50.0+3)))
a = direction((0,0,0),(3,4,0))[0]; rec(11, "ReceiveFillsPdwFromPulse AoA", "3-4-5", 36.8699, a, ok=abs(a-36.8699) < 1e-4)
rec(11, "ReceiveFillsGroundTruth eirp", "90 + 32", 122.0, 90 + 32.0)

# ---------------- Task 12 (scheduler) - pure ordering
evs = []; seq = 0
for t in (3, 1, 2): heapq.heappush(evs, (t, seq, t)); seq += 1
rec(12, "RunAllExecutesInTimeOrder", "3,1,2", [1,2,3], [heapq.heappop(evs)[2] for _ in range(3)])
evs = []; heapq.heappush(evs, (5, 0, "A")); heapq.heappush(evs, (5, 1, "B"))
rec(12, "RunAllBreaksTiesByInsertionOrder", "A,B en 5", ["A","B"], [heapq.heappop(evs)[2] for _ in range(2)])

# ---------------- Task 13 Simulation (P_tx 0, G 0 (SLL 0), f 1 GHz, G_rx 0, sens -200)
def sim(emitters, dur):
    rows = []
    for pos, start in emitters:
        for p in emitter(start, [("m", 10**12, dict(pri=lambda: Fixed(1*MS), rf=lambda: Fixed(1e9), pw=lambda: Fixed(1*US)), FS)], dur):
            d = distanceM(pos, (0,0,0)); a = direction(pos, (0,0,0))
            g = gain(0, 2, 20, 0, wrapOffset(a[0]-p['beam'][0]), a[1]-p['beam'][1])
            prx = 0 + g - fspl(d, 1e9) + 0
            if prx >= -200: rows.append((p['t'] + delay(d), pos))
    return sorted(rows)
r = sim([((0,299.792458,0), 0)], 3_500_000)
rec(13, "RunDeliversEveryPulse", "299.79 m, dur 3.5 ms", [1000, 1_001_000, 2_001_000, 3_001_000], [x[0] for x in r])
r = sim([((0,2998,0), 0), ((0,299.792458,0), 5000)], 500_000)
rec(13, "RunOrdersByArrivalTime", "A 2998 m t0=0; B 299.79 m t0=5 us; dur 0.5 ms", [6000, 10000], [x[0] for x in r],
    note="retardo A = %r ns" % (2998/C*1e9))
r = sim([((0,2998,0), 0)], 5000)
rec(13, "RunDeliversPulsesInFlightAfterEnd", "dur 5 us, 2998 m", [10000], [x[0] for x in r], note="10000 > 5000: en vuelo")
rec(13, "  potencias detectadas", "P_rx a 299.79 / 2998 m", ">= -200", (-fspl(299.792458,1e9), -fspl(2998,1e9)), ok=True)

# ---------------- Task 14 catalog
rec(14, "ParseCatalogBuildsModes 1a PRI", "1000 us", 1_000_000, microsecondsToTime(1000))
rec(14, "ParseCatalogBuildsModes periodo", "6 s", 6*NS, secondsToTime(6.0))
rec(14, "ConvertsMicrosecondsWithRounding", "1.0006", 1001, microsecondsToTime(1.0006))
rec(14, "RejectsValueThatRoundsToZero", "valueUs 0.0004 (%r ns)" % (0.0004*1e3), 0, microsecondsToTime(0.0004))
rec(14, "RejectsPeriodThatRoundsToZero", "periodS 1e-10 (%r ns)" % (1e-10*1e9), 0, secondsToTime(1e-10))
rec(14, "RejectsTimeTooLarge", "periodS 1e7", True, secondsToTime(1e7) > secondsToTime(1e6))
rec(14, "RejectsPwNotBelowMinPri", "stagger[1000,900], PW 900", "900 / 900", "%s / %s" % (
    ("%g" % timeToMicroseconds(microsecondsToTime(900))), ("%g" % timeToMicroseconds(min(microsecondsToTime(1000), microsecondsToTime(900))))))
pw = microsecondsToTime(999.9996); pr = microsecondsToTime(1000.0004)
rec(14, "RejectsPwEqualToPriAfterRounding", "999.9996 / 1000.0004", (1_000_000, 1_000_000, True), (pw, pr, pw >= pr))
rec(14, "mensaje con 1000.5", "1 000 500 ns", "1000.5", "%r" % timeToMicroseconds(1_000_500))
rec(14, "spec §5 PW<PRI", "search 1<1000, track 0.5<250", True, microsecondsToTime(1.0) < 1_000_000 and microsecondsToTime(0.5) < 250_000)
rec(14, "golden PW<PRI", "A 1<1000; B 0.5<700", True, 1000 < 1_000_000 and 500 < 700_000)
# antenna coherence (spec §5): G ≈ 10 log10(K/(θaz θel)), K 25000-30000 (41253 ideal)
for name, G, ta, te in [("search", 30, 1.5, 20), ("track", 43, 1.0, 1.0), ("golden A", 16, 30, 30), ("golden B", 30, 6, 6)]:
    lo, hi, ideal = (10*math.log10(K/(ta*te)) for K in (25000, 30000, 41253))
    rec(14, "coherencia G/θ " + name, "%g dBi, %gx%g" % (G, ta, te), "[%.2f, %.2f] (ideal %.2f)" % (lo, hi, ideal), G,
        ok=lo - 0.05 <= G <= ideal, note="K implícita = %.0f" % (10**(G/10)*ta*te))

# ---------------- Task 15 mission example
SRCH = dict(pri=lambda: Cyclic([1000*US,1200*US,1100*US]), rf=lambda: Fixed(3e9), pw=lambda: Fixed(1*US))
TRK = dict(pri=lambda: Fixed(250*US), rf=lambda: Fixed(3.1e9), pw=lambda: Fixed(500))
def spec_mission(dur):
    return emitter(secondsToTime(5), [("search", secondsToTime(40), SRCH, lambda t: circular(0, 6*NS, 2, t)),
                                      ("off", secondsToTime(10), None, None),
                                      ("track", secondsToTime(30), TRK, lambda t: fixedscan(216.87, 0, t))], dur)
r = spec_mission(secondsToTime(120))
rec(15, "BuildsEmitters: 1er pulso", "startS 5", (5*NS, "search"), (r[0]['t'], r[0]['mode']))
ft = [x for x in r if x['mode'] == 'track'][0]
rec(15, "ChainsSegmentsFromStart", "5+40+10", (55*NS, 2), (ft['t'], ft['seg']))
r50 = spec_mission(secondsToTime(50))
rec(15, "AcceptsScheduleBeyondDuration", "durationS 50", "< 50 s", r50[-1]['t'], ok=r50[-1]['t'] < 50*NS,
    note="último %.6f s (%s), %d pulsos" % (r50[-1]['t']/NS, r50[-1]['mode'], len(r50)))

# ---------------- spec §4 numeric example (G_max 30, SLL 30)
E = (15000, 20000, 30); RX = (0, 0, 10)
d = distanceM(E, RX); F = fspl(d, 3e9)
rec("§4", "d", "", "≈25000", d, ok=abs(d-25000) < 1)
rec("§4", "retardo", "", 83391, delay(d))
rec("§4", "FSPL", "", "≈130", F, ok=abs(F-130) < 0.5)
a = direction(RX, E); rec("§4", "AoA", "", "(≈36.87, ≈0.05)", a, ok=abs(a[0]-36.87) < .01 and abs(a[1]-.05) < .005)
b = direction(E, RX); rec("§4", "haz E->RX", "", "≈216.87", b, ok=abs(b[0]-216.87) < .01)
rec("§4", "P_iso principal", "90+30-FSPL", "≈-10", 90+30-F, ok=abs(90+30-F+10) < .5)
rec("§4", "P_iso laterales", "90+0-FSPL", "≈-40", 90+0-F, ok=abs(90-F+40) < .5)
rec("§4", "detección laterales con -70", "", True, 90-F >= -70)

# ---------------- Task 16 golden mission, pulse by pulse
RX = (0, 0, 10); GRX = 0.0; SENS = -60.0; DUR = secondsToTime(0.1)
A_POS = (0, 30000, 30); B_POS = (20000, 0, 50)
A_ANT = (16, 30, 30, 25); B_ANT = (30, 6, 6, 25)
A_MODE = dict(pri=lambda: Cyclic([microsecondsToTime(1000), microsecondsToTime(1500)]), rf=lambda: Fixed(3000e6),
              pw=lambda: Fixed(microsecondsToTime(1.0)), P=74, ant=A_ANT, mod="None")
B_MODE = dict(pri=lambda: Fixed(microsecondsToTime(700)), rf=lambda: Cyclic([9000e6, 9100e6], 3),
              pw=lambda: Fixed(microsecondsToTime(0.5)), P=60, ant=B_ANT, mod="LFM")
A_TPER = secondsToTime(0.05)
pa = emitter(secondsToTime(0), [("search", secondsToTime(0.1), A_MODE, lambda t: circular(0, A_TPER, 0, t))], DUR)
pb = emitter(secondsToTime(0.002), [("track", secondsToTime(0.04), B_MODE, lambda t: fixedscan(270, -0.1146, t)),
                                    ("off", secondsToTime(0.02), None, None),
                                    ("track", secondsToTime(0.04), B_MODE, lambda t: fixedscan(270, -0.1146, t))], DUR)
rows = []; all_pulses = []
for eid, pos, pulses in (("A1", A_POS, pa), ("B1", B_POS, pb)):
    for p in pulses:
        d = distanceM(pos, RX); er = direction(pos, RX)
        G, ta, te, sll = p['mp']['ant']
        g = gain(G, ta, te, sll, wrapOffset(er[0] - p['beam'][0]), er[1] - p['beam'][1])
        piso = p['mp']['P'] + g - fspl(d, p['f']); prx = piso + GRX
        all_pulses.append((eid, p, prx))
        if prx >= SENS:
            rows.append(dict(toa=p['t'] + delay(d), eid=eid, p=p, prx=prx, d=d, g=g, aoa=direction(RX, pos)))
rows.sort(key=lambda r: r['toa'])
nA = sum(r['eid'] == 'A1' for r in rows); nB = sum(r['eid'] == 'B1' for r in rows)
nB0 = sum(r['eid'] == 'B1' and r['p']['seg'] == 0 for r in rows); nB2 = sum(r['eid'] == 'B1' and r['p']['seg'] == 2 for r in rows)
rec(16, "filas totales / A1 / B1", "", (131, 18, 113), (len(rows), nA, nB))
rec(16, "B1 por segmento", "", (58, 55), (nB0, nB2))
rec(16, "pulsos emitidos A1 / B1", "", "-", (len(pa), len(pb)), ok=True)
dA = distanceM(A_POS, RX); dB = distanceM(B_POS, RX)
rec(16, "A1 d / retardo", "", ("30000.007", 100069), ("%.3f" % dA, delay(dA)), note=repr(dA/C*1e9))
FA = fspl(dA, 3e9)
rec(16, "A1 pico / suelo", "74+16-FSPL / 74-9-FSPL", ("-41.53", "-66.53"), ("%.2f" % (74+16-FA), "%.2f" % (74+16-25-FA)))
Arows = [r for r in rows if r['eid'] == 'A1']
b1 = [r['toa'] for r in Arows if r['toa'] < 50*MS]; b2 = [r['toa'] for r in Arows if r['toa'] >= 50*MS]
rec(16, "A1 ráfagas (n, primero, último)", "", ((9, 20_100_069, 30_100_069), (9, 70_100_069, 80_100_069)),
    ((len(b1), b1[0], b1[-1]), (len(b2), b2[0], b2[-1])))
pk = [r for r in Arows if r['p']['t'] in (25*MS, 75*MS)]
rec(16, "A1 amplitud en 25/75 ms", "", "-41.53", ["%.2f" % r['prx'] for r in pk], ok=all("%.2f" % r['prx'] == "-41.53" for r in pk))
rec(16, "A1 azimuthDeg", "", "≈0 (0.0000)", sorted({fmt_az(r['aoa'][0]) for r in Arows}), ok={fmt_az(r['aoa'][0]) for r in Arows} == {"0.0000"})
marg = sorted(abs(prx - SENS) for eid, p, prx in all_pulses if eid == 'A1')[:3]
rec(16, "A1 margen mínimo a la sensibilidad (dB)", "", "> 0.01", ["%.3f" % m for m in marg], ok=marg[0] > 0.01)
rec(16, "B1 d / retardo", "", ("20000.040", 66713), ("%.3f" % dB, delay(dB)), note=repr(dB/C*1e9))
Brows = [r for r in rows if r['eid'] == 'B1']
rec(16, "B1 primera toaNs", "", 2_066_713, Brows[0]['toa'])
rec(16, "primera fila del CSV", "", "B1", rows[0]['eid'])
rec(16, "B1 azimuthDeg", "", {"90.0000"}, {fmt_az(r['aoa'][0]) for r in Brows})
amp = {}
for r in Brows: amp.setdefault(r['p']['f'], set()).add("%.2f" % f32(r['prx']))
rec(16, "B1 amplitudeDbm por f", "", {9000e6: {"-47.56"}, 9100e6: {"-47.65"}}, amp,
    note="P exactas: %.5f / %.5f; G_tx min %.12f" % (60+30-fspl(dB, 9e9), 60+30-fspl(dB, 9.1e9), min(r['g'] for r in Brows)))
fs0 = [int(r['p']['f']/1e6) for r in Brows if r['p']['seg'] == 0]; fs2 = [int(r['p']['f']/1e6) for r in Brows if r['p']['seg'] == 2]
rec(16, "B1 frecuencias grupos de 3", "", "9000x3,9100x3...", fs0[:7], ok=fs0[:7] == [9000]*3 + [9100]*3 + [9000])
rec(16, "B1 reinicio de RF al segundo segmento", "", (9100, 9000), (fs0[-1], fs2[0]),
    note="sin reinicio el primero del seg. 2 sería %d" % [9000, 9100][(58 // 3) % 2])
rec(16, "ninguna fila con emisión en [42, 62) ms", "", 0, sum(42*MS <= r['p']['t'] < 62*MS for r in rows))
rec(16, "truth_segmentIndex de B1", "", {0, 2}, {r['p']['seg'] for r in Brows})
rec(16, "B1 último segmento recortado", "", "62+0.7k < 100", (Brows[-1]['p']['t'], Brows[-1]['toa']), ok=Brows[-1]['p']['t'] < DUR)
rec(16, "toaNs empates entre A1 y B1", "", 0, len(rows) - len({r['toa'] for r in rows}))
rec(16, "filas con toaNs >= durationS (en vuelo)", "", "-", sum(r['toa'] >= DUR for r in rows), ok=True)
rec(16, "B1 txGainDbi formateado", "", "30.00", {fmt(r['g'], 2) for r in Brows}, ok={fmt(r['g'], 2) for r in Brows} == {"30.00"})
rec(16, "B1 eirp formateado", "", "90.00", {fmt(60 + r['g'], 2) for r in Brows}, ok={fmt(60 + r['g'], 2) for r in Brows} == {"90.00"})

# ---------------- extra: circular scan precision for long missions (t/T vs (t%T)/T)
for tsec, T in [(120, 6*NS), (1e6, 6*NS), (1e6, 1*MS)]:
    t = secondsToTime(tsec) + 1_234_567
    v1 = circular(0, T, 0, t)[0]; v2 = circular_mod(0, T, 0, t)[0]
    raw = 360.0 * (t / T)
    rec("extra", "CircularScan t/T vs t%T", "t=%gs, T=%gs" % (tsec, T/NS), "-", (v1, v2), ok=True,
        note="diff %.3e deg; ulp(float(raw=%.4g))=%.3g deg" % (abs(v1 - v2), raw, abs(f32(raw) - raw) if raw < 3e38 else 0))

bad = 0
for x in R:
    flag = "OK " if x[5] else "XX "
    bad += not x[5]
    print(flag, x[0], "|", x[1], "|", x[2], "| plan:", x[3], "| calc:", x[4], "|", x[6])
print("TOTAL", len(R), "discrepancias", bad)
```

## Anexo B: robustez de la golden frente al redondeo (`boundary.py`)

```python
# Distance of each golden CSV value to the nearest rounding boundary of its format (fragility of the golden file)
import io, contextlib, sys
sys.path.insert(0, '.')
with contextlib.redirect_stdout(io.StringIO()):
    import verify2 as v
def dist(x, p): s = x * 10**p; return abs(abs(s) % 1 - 0.5) / 10**p
worst = []
for r in v.rows:
    for name, x, p in [("amplitudeDbm", v.f32(r['prx']), 2), ("txGain", r['g'], 2), ("eirp", r['p']['mp']['P'] + r['g'], 2),
                       ("distanceM", r['d'], 3), ("az", r['aoa'][0], 4), ("el", r['aoa'][1], 4)]:
        worst.append((dist(x, p), name, r['eid'], r['p']['t'], x))
worst.sort()
for w in worst[:6]: print("%.3e %s %s t=%d x=%r" % w)
diff = 0
for r in [r for r in v.rows if r['eid'] == 'A1']:
    t = r['p']['t']; b2 = v.circular_mod(0, v.A_TPER, 0, t)
    er = v.direction(v.A_POS, v.RX)
    g2 = v.gain(16, 30, 30, 25, v.wrapOffset(er[0] - b2[0]), er[1] - b2[1])
    if "%.2f" % r['g'] != "%.2f" % g2: diff += 1
print("A1 rows whose txGain text changes with t%T:", diff)
```

Resultado: distancia mínima 4.3·10⁻⁵ (elevación de A1, 0.0381927 → `0.0382`); 0 filas cambian con `t % T`.

## Anexo C: comprobaciones en C++ (`check.cpp`, `neg.cpp`)

Compilados con `g++ -std=c++23` (GCC 15.2) contra el `json.hpp` de nlohmann/json 3.12.0.

```cpp
// check.cpp
#include <nlohmann/json.hpp>
#include <format>
#include <iostream>
#include <chrono>
#include <cmath>
int main(){
  try { auto j = nlohmann::json::parse(R"({"peakPowerDbm": 1e400})"); std::cout<<"parsed "<<j.dump()<<"\n"; }
  catch (const nlohmann::json::parse_error& e) { std::cout<<"parse_error: "<<e.what()<<"\n"; }
  catch (const nlohmann::json::exception& e) { std::cout<<"other json::exception (id "<<e.id<<"): "<<e.what()<<"\n"; }
  using namespace std::chrono;
  std::cout<<std::format("[{}] [{}] [{}] [{}] [{}]\n", duration<double,std::micro>(nanoseconds{900000}).count(),
                         duration<double,std::micro>(nanoseconds{1000500}).count(), -90.0, 0.0, 180.0);
  std::cout<<std::format("{} {}\n", llround(0.0025*1e3), round<nanoseconds>(duration<double,std::micro>(0.0025)).count());
  std::cout<<std::format("{:.4f} {:.4f} {:.2f} {:.2f} {:.4f} {:.3f}\n", 359.99997f, -0.00003f, -0.004f, -5.0f, 36.87f, 25000.008);
  std::cout<<std::format("{}\n", duration<double>(nanoseconds{2500000000}).count());
}
// Output:
// other json::exception (id 406): [json.exception.out_of_range.406] number overflow parsing '1e400'
// [900] [1000.5] [-90] [0] [180]
// 3 2
// 360.0000 -0.0000 -0.00 -5.00 36.8700 25000.008
// 2.5
```

```cpp
// neg.cpp
#include <nlohmann/json.hpp>
#include <iostream>
int main(){ auto j = nlohmann::json::parse(R"({"a": -1, "b": 2.5})");
 std::cout << j["a"].is_number_integer() << j["a"].is_number_unsigned() << j["b"].is_number_integer() << "\n"; }
// Output: 100  (-1: integer yes, unsigned no; 2.5: integer no)
```

# Revisión 5 — Dominio EW (ESM/ELINT, radar) del simulador a nivel de pulso

Fecha: 2026-10-24

Documentos revisados:

- Spec: `docs/superpowers/specs/2026-10-24-simulator-design.md`
- Plan: `docs/superpowers/plans/2026-10-24-simulator.md`
- Contexto: `docs/superpowers/specs/2026-10-23-pdw-attribute-grouping-design.md`,
  `src/SigInt/PulseDescriptors/include/PulseDescriptorWords.h`, `AngleOfArrival.cpp` (normalización).

Enfoque: ¿el diseño modela bien la realidad física y operativa **dentro del alcance acordado**? No se propone meter en
la v1 nada de la lista "Fuera de alcance"; solo se señala dónde el diseño les cierra (o casi) la puerta.

Las cifras "típicas" que aparecen son **órdenes de magnitud** de la literatura general de radar/EW, no datos de ningún
radar real concreto. Los cálculos se han comprobado con Python.

---

## Resumen y veredicto

**Veredicto: el diseño es físicamente correcto en lo esencial y apto para la v1.** No hay errores de signo ni de
convención: ENU, azimut desde el Norte horario con `atan2(ΔE, ΔN)`, AoA receptor→emisor, retardo d/c, FSPL, Friis en
dB, potencia de pico, ganancia del receptor y umbral de sensibilidad están bien planteados, y el ejemplo numérico de
la spec §4 es correcto al décimo de dB.

Los hallazgos son de tres tipos:

1. **Coherencia de los datos de ejemplo**: las ganancias de pico no casan con los anchos de haz (hasta 13 dB de
   diferencia en la misión golden), y la misión golden está infraespecificada y es poco realista (1200 rpm, emisor por
   debajo del horizonte radar). No rompen el código, pero un analista que lea esos ficheros aprende valores erróneos.
2. **Modelo de antena**: usar Δaz/Δel en coordenadas az/el sobrestima la atenuación cuando el haz o el receptor están
   lejos del horizonte; es barato corregirlo ya en la v1 calculando los desvíos en el sistema del haz.
3. **Extensibilidad**: el reinicio de estado "clonando el prototipo" repetirá la misma secuencia aleatoria en cada
   segmento cuando llegue el jitter; faltan validaciones de rango de elevación/sector; el solape de pulsos
   (*pulse-on-pulse*) no está ni modelado ni en la lista "Fuera de alcance".

| Gravedad | Nº | Hallazgos |
| --- | --- | --- |
| Crítica | 0 | — |
| Alta | 0 | — |
| Media | 6 | D1, D2, D3, D4, D5, D6 |
| Baja | 9 | D7 – D15 |

Errores (algo que está mal): D1, D4, D5, D11. Mejoras opcionales para la v1: D2, D6, D7, D8, D9, D10, D12, D13, D15.
Para el futuro: D3, D14.

---

## Hallazgos

### D1 — Ganancias de pico incoherentes con los anchos de haz

- **Gravedad:** Media
- **Tipo:** Error (en los datos de ejemplo de spec y plan)
- **Descripción:** `peakGainDbi`, `beamwidthAzDeg` y `beamwidthElDeg` se dan como parámetros independientes, y los
  valores de los ejemplos no son físicamente compatibles entre sí.
- **Justificación técnica:** la directividad de una antena de haz único es aproximadamente
  `G ≈ 10·log10(K / (θ_az · θ_el))` con θ en grados, K ≈ 41 253 (ideal) y K ≈ 25 000–30 000 con eficiencia y
  lóbulos reales (orden de magnitud):

  | Ejemplo | θ_az × θ_el | G declarada | G ideal (K = 41 253) | G práctica (≈ 65 %) |
  | --- | --- | --- | --- | --- |
  | Spec `search` | 1,5° × 20° | 35 dBi | 31,4 dBi | 29,5 dBi |
  | Spec `track` | 1° × 1° | 38 dBi | 46,2 dBi | 44,3 dBi |
  | Golden `TestRadar_A` | 30° × 30° | 30 dBi | 16,6 dBi | 14,7 dBi |
  | Tests de antena/canal | 2° × 20° | 35 dBi | 30,1 dBi | 28,3 dBi |

  La golden se desvía 13–15 dB: una antena de 30°×30° no puede tener 30 dBi. `search` supera el límite ideal (imposible),
  `track` queda corto (posible pero raro para un pincel de 1°).
- **Cambio sugerido:**
  - Corregir los valores de ejemplo: p. ej. `search` 1,5°×20° → ≈ 30 dBi; `track` 1°×1° → ≈ 43 dBi; golden con 30 dBi →
    anchos ≈ 6°×6° (o mantener 30°×30° y bajar a ≈ 15 dBi, ajustando P_tx).
  - Opcional: una comprobación de coherencia en el loader, como **aviso** (no error, para no impedir casos de prueba
    deliberadamente artificiales como SLL = 0): `peakGainDbi ≤ 10·log10(41253/(θ_az·θ_el)) + 1 dB`.
  - En los tests unitarios de antena y canal los valores (35, 2, 20, 30) no importan físicamente; se pueden dejar, pero
    conviene un comentario "valores de prueba, no físicos".
- **Afecta a:** spec §5 (catálogo de ejemplo), §4 (ejemplo numérico, que pasaría a ≈ −10 dBm de lóbulo principal);
  plan Tarea 15 (golden, `scenarios/catalog/SearchRadar_X.json`); opcional Tarea 13 (aviso).

### D2 — Desvío del haz en coordenadas az/el en lugar del sistema del haz

- **Gravedad:** Media
- **Tipo:** Mejora para v1
- **Descripción:** `Δaz = wrap(az_ER − az_haz)`, `Δel = el_ER − el_haz` es correcto solo cerca del horizonte. Un grado
  de azimut a elevación `el` corresponde a `cos(el)` grados de arco reales, y en el cénit el azimut está indefinido.
- **Justificación técnica:** ángulo real fuera de eje para dos direcciones con la misma elevación `el` separadas Δaz
  (cálculo con producto escalar de vectores unitarios):

  | el del haz y del receptor | Δaz | Ángulo real | Pérdida modelo (θ = 1°) | Pérdida real (θ = 1°) |
  | --- | --- | --- | --- | --- |
  | 2° | 5° | 4,997° | 300 dB → suelo | 299,6 dB → suelo |
  | 30° | 5° | 4,33° | 300 dB | 225 dB |
  | 60° | 5° | 2,50° | 300 dB | 75 dB |
  | 80° | 10° | 1,73° | 1200 dB | 36 dB |

  Caso concreto relevante: pincel de 2° apuntando a el = 60°, receptor desviado Δaz = 1° a la misma elevación → el
  modelo da −3 dB y la realidad −0,75 dB. En el escenario de la v1 (todo a pocas decenas de metros de altura y decenas
  de km) las elevaciones son de ~0,05° y el error es despreciable; aparece con un receptor elevado (aerotransportado en
  posición fija) o un modo `track` con elevación alta. Además, un haz que apunte casi al cénit (`pointingElevationDeg`
  ≈ 90) haría que Δaz salte de forma arbitraria.
- **Cambio sugerido:** calcular los desvíos en el sistema local del haz y mantener la interfaz
  `gainDbi(offsetAz, offsetEl)` (así el gaussiano no cambia y un sinc² o una tabla futura también encajan):

  ```
  b = (cos el_b · sin az_b,  cos el_b · cos az_b,  sin el_b)   // eje del haz (ENU)
  h = (cos az_b, −sin az_b, 0)                                 // "derecha" del haz (azimut creciente)
  v = h × b                                                    // "arriba" del haz
  r = vector unitario emisor → receptor
  offsetAz = atan2(r·h, r·b)        offsetEl = asin(r·v)
  ```

  A elevación 0 coincide con la fórmula actual (los tests de las Tareas 6 y 8 siguen valiendo) y no tiene singularidad
  en el cénit. Si se prefiere no tocarlo, documentar en la spec la limitación ("válido para |el| pequeñas") para que no
  sorprenda.
- **Afecta a:** spec §4 paso 2.3; plan Tarea 8 (`PropagationChannel::propagate`, un test con el haz a el = 60°).

### D3 — El reinicio de estado por clonación repetirá la secuencia aleatoria en cada segmento

- **Gravedad:** Media
- **Tipo:** Para el futuro (pero condiciona el diseño de hoy)
- **Descripción:** "cada segmento empieza con su estado a cero" se implementa clonando `pri`, `rf` y `pw` del prototipo
  del modo (Tarea 7). Cuando llegue la aleatoriedad (jitter de PRI, agilidad aleatoria de RF, ambas en "Fuera de
  alcance"), si el generador lleva su propio motor aleatorio, el clon copiará también la semilla: **cada segmento del
  mismo modo producirá exactamente el mismo jitter**, y dos emisores del mismo tipo también. Un deinterleaver podría
  "aprenderse" ese patrón repetido, que no existe en la realidad.
- **Justificación técnica:** en un emisor real el jitter es (pseudo)aleatorio y no correlado entre activaciones; repetir
  la secuencia introduce una periodicidad artificial detectable por histogramas de diferencias de TOA.
- **Cambio sugerido (sin implementar nada aleatorio ahora):** dejar escrito en la spec que el estado *determinista* de
  la secuencia (índice de stagger, posición de sliding) se reinicia por segmento, pero la **fuente aleatoria** no
  pertenece al generador: la tendrá el `Emitter` (o la `Simulation`), sembrada desde la semilla del escenario y el id
  del emisor, y se pasará a `next(...)` cuando haga falta. Así la interfaz `clone()` sigue sirviendo.
- **Afecta a:** spec §3 (decisión de fondo 5) y §4 (reglas del calendario); plan Tarea 7 (comentario de diseño).

### D4 — Faltan validaciones de rango de elevación y anchura de sector

- **Gravedad:** Media
- **Tipo:** Error (validación incompleta)
- **Descripción:** la validación (§5) no limita `elevationDeg` (circular, sector), `pointingElevationDeg` (fijo) ni
  `widthDeg` (sector). `AngleOfArrival` **pliega** la elevación sobre el polo: un `elevationDeg: 95` (errata de 9,5 o
  de 5) se convertiría silenciosamente en el = 85° con el azimut girado 180°, es decir, un haz apuntando hacia atrás.
  Un `widthDeg` > 360 genera una onda triangular que da varias vueltas, sin sentido físico.
- **Justificación técnica:** la propia spec dice que "una errata no debe ignorarse en silencio". El plegado es correcto
  para normalizar *direcciones medidas*, pero no para *parámetros de configuración*.
- **Cambio sugerido:** añadir a la regla 2 de validación: `elevationDeg`, `pointingElevationDeg` ∈ [−90, 90];
  `0 < widthDeg ≤ 360` (o `< 360`; un sector de 360° es un circular). Opcional: `beamwidth*Deg` ≤ 180.
  Un test por regla en las Tareas 13 y 14.
- **Afecta a:** spec §5 (Validación); plan Tareas 13 y 14.

### D5 — Misión golden infraespecificada y poco realista

- **Gravedad:** Media
- **Tipo:** Error (en la especificación de la Tarea 15)
- **Descripción:** varios parámetros que determinan la salida no están fijados y otros no son realistas:
  - No se dan `initialAzimuthDeg` ni `elevationDeg` del scan de A, `gainDbi` del receptor, P_tx ni antena de B, ni las
    duraciones de los segmentos de B. "El ejecutor ajusta P_tx o la sensibilidad si hace falta" convierte la golden en
    algo que depende de quién la ejecute; y la verificación del Paso 5 usa "P_tx + 30" para B, dando por hecho una
    antena de 30 dBi que no está escrita.
  - **Periodo de scan de 0,05 s = 1200 rpm.** Los radares de vigilancia giran del orden de 5–60 rpm (periodos de
    1–12 s). Con 30° de haz y PRI media 1,25 ms solo caben ≈ 3,3 pulsos dentro del haz a −3 dB.
  - **A está a 0 m de altura y a 30 km**: el horizonte radar (4/3 de Tierra) con antenas a 0 y 10 m es
    `4,12·(√0 + √10) ≈ 13 km`. El modelo plano no lo ve (la curvatura está fuera de alcance, correcto), pero el
    escenario sería imposible en la realidad. B (50 m, 20 km; horizonte ≈ 42 km) y el ejemplo de la spec (30 m,
    25 km; horizonte ≈ 36 km) sí son visibles.
- **Justificación técnica (con los valores del plan, G_rx = 0):** FSPL(30 km, 3 GHz) = 131,5 dB; lóbulo principal
  60 + 30 − 131,5 = −41,5 dBm; lóbulos laterales 60 + 5 − 131,5 = −66,5 dBm < −60 → **sí hay ráfagas limpias**. La
  ráfaga dura mientras G_tx ≥ 11,5 dBi, es decir, |Δaz| ≤ 37,2°: ≈ 10,3 ms por vuelta, ≈ 8 pulsos detectados por
  ráfaga, 2 ráfagas en 0,1 s si el haz pasa por 180° (A está al Norte del receptor, así que el haz debe apuntar al Sur).
  Para B: FSPL(20 km, 9 GHz) = 137,6 dB → con 30 dBi basta P_tx ≥ 47,6 dBm; retardo ≈ 66 713 ns; para apuntar al
  receptor, `pointingAzimuthDeg` = 270 y `pointingElevationDeg` ≈ −0,11 (con 0 la pérdida es despreciable).
  El comportamiento descrito se produce, pero solo si el ejecutor acierta los huecos.
- **Cambio sugerido:** fijar en el plan **todos** los valores de la golden (p. ej. A: altura 30 m, `initialAzimuthDeg`
  0, `elevationDeg` 0, antena coherente según D1, ajustando P_tx para conservar ≈ −40 dBm de pico; receptor
  `gainDbi` 0; B: P_tx 60 dBm, antena `{30, 6, 6, 25}`, apuntando a (270, −0,11), segmentos p. ej. [on 0,04 s, off
  0,02 s, on 0,04 s]); y escribir en la misión un comentario o nota de que el periodo de 0,05 s está **comprimido a
  propósito** para que la golden sea corta. Dejar el "ajusta si hace falta" solo como comprobación, no como grado de
  libertad.
- **Afecta a:** plan Tarea 15 (descripción de la misión golden y Paso 5).

### D6 — El solape de pulsos (*pulse-on-pulse*) no está ni modelado ni declarado fuera de alcance

- **Gravedad:** Media
- **Tipo:** Mejora para v1 (solo documentación) / Para el futuro (modelo)
- **Descripción:** cada pulso se detecta de forma independiente. Un receptor real tiene tiempo muerto y pierde o mezcla
  pulsos que se solapan en tiempo (TOA_2 < TOA_1 + PW_1 + tiempo de recuperación). Con muchos emisores es uno de los
  efectos que más estresa a un deinterleaver real, y no aparece en "Fuera de alcance".
- **Justificación técnica:** con N emisores de PRI media T y PW τ, la fracción de pulsos solapados crece
  aproximadamente con `N·τ/T`; con 20 emisores de τ = 1 µs y T = 1 ms es del orden del 2 %, y en entornos densos
  mucho más. En la golden (2 emisores) es despreciable.
- **Cambio sugerido:** añadir a "Fuera de alcance" una línea: "Solape de pulsos y tiempo muerto del receptor (pulsos
  perdidos o fusionados)". El diseño no lo impide: el `Receiver` ya tiene estado y recibe en orden de llegada; bastaría
  recordar el fin del último pulso. Opcional en la v1: columna de verdad `truth_overlap` (1 si solapa con otro pulso
  detectado) para que el analista sepa que esos pulsos, en la realidad, no serían limpios.
- **Afecta a:** spec §1 (Fuera de alcance), §6 opcional.

### D7 — El receptor no tiene banda de cobertura de RF

- **Gravedad:** Baja
- **Tipo:** Mejora para v1
- **Descripción:** el receptor detecta cualquier frecuencia (la golden mezcla 3 y 9 GHz). Todo receptor ESM real cubre
  una banda finita (del orden de 0,5–18 GHz o subbandas).
- **Justificación técnica:** sin banda no se pueden simular escenarios donde un emisor queda fuera de cobertura, que es
  algo que un clasificador debe tolerar.
- **Cambio sugerido:** `frequencyMinMHz`/`frequencyMaxMHz` opcionales en el receptor (por defecto, sin límite), con la
  condición de detección `fMin ≤ f ≤ fMax && P_rx ≥ S`. Un test más en la Tarea 10. Si no se quiere en la v1,
  añadirlo a "Fuera de alcance".
- **Afecta a:** spec §4 paso 3 y §5 (misión); plan Tareas 10 y 14.

### D8 — Columnas de verdad que echaría de menos un analista ELINT

- **Gravedad:** Baja
- **Tipo:** Mejora para v1
- **Descripción:** la salida actual permite validar un deinterleaver (emisor, índice de pulso, t_e). Para validar un
  clasificador o un análisis de scan faltan algunas verdades baratas de añadir:
  - `truth_txGainDbi` o `truth_beamOffsetDeg` (desvío respecto al eje del haz): distingue lóbulo principal de lóbulo
    lateral. `truth_eirpDbm` lo contiene implícitamente, pero hay que restar P_tx, que no está en el CSV.
  - `truth_segmentIndex`: dos segmentos del mismo modo no se distinguen solo con `truth_modeId`.
  - `truth_frequencyMHz`, `truth_pulseWidthUs`: hoy coinciden con la medida; cuando llegue el ruido harán falta y
    añadirlas ahora evita cambiar el formato después.
  - (futuro, varios receptores) `receiverId` o un CSV por receptor.
- **Lo que no hace falta:** `truth_pri` (se deduce de `truth_emissionNs` consecutivos del mismo emisor) ni un registro
  de pulsos no detectados (los huecos en `truth_emitterPulseIndex` ya los delatan).
- **Cambio sugerido:** añadir al menos `truth_txGainDbi` y `truth_segmentIndex`; las demás, a criterio.
- **Afecta a:** spec §6; plan Tareas 9 y 10 (`GroundTruth`, cabecera del CSV).

### D9 — Parámetros de comportamiento de los emisores que conviene precisar

- **Gravedad:** Baja
- **Tipo:** Mejora para v1 (sobre todo documentación; los parámetros nuevos son opcionales con valor por defecto)
- **Descripción y justificación:**
  - **Sentido de giro del circular:** solo horario. La mayoría de radares giran en horario visto desde arriba, pero no
    todos; un `"direction": "cw" | "ccw"` (por defecto `cw`) es una línea de código y un test.
  - **Sectorial:** la spec modela el bidireccional (ida y vuelta en un periodo), que es el típico mecánico. Existe
    también el unidireccional con retorno rápido (*flyback*), típico de barridos electrónicos y raster. Basta con
    documentar que "sector" = bidireccional y que el unidireccional queda para el futuro. Conviene también dejar
    escrito que, con el bidireccional, un receptor que no esté en el centro del sector ve **dos** iluminaciones por
    periodo a intervalos desiguales (es correcto y es una firma útil para el analista).
  - **Sliding:** el modelo es diente de sierra creciente (min → max y salto a min), que es el más común. Existen
    decreciente y triangular. Opcional `"profile": "up" | "down" | "triangle"`.
  - **Dwell & switch:** un único `pulsesPerDwell` para todos los valores. En la práctica cada dwell suele durar un
    número de pulsos o un tiempo propio por PRF; opcional permitir una lista `pulsesPerDwell` de la misma longitud que
    `valuesUs`. Además, en radares reales el cambio de RF suele ir sincronizado con el de PRI (por CPI); con
    generadores independientes se consigue poniendo `pulsesPerHop` = `pulsesPerDwell`, lo que conviene documentar.
  - **Continuidad del scan entre segmentos:** con "estado a cero" una antena mecánica que pasa por `off` y vuelve a
    `search` reaparece en `initialAzimuthDeg`, cuando en la realidad seguiría girando. Es aceptable porque la misión
    fija el azimut inicial, pero hay que documentarlo.
- **Cambio sugerido:** documentar los cinco puntos en la spec §4/§5; añadir solo el sentido de giro si se quiere algo
  de código.
- **Afecta a:** spec §4 (fórmulas del scan, reglas del calendario), §5 (tabla de `kind`); plan Tareas 3 y 5.

### D10 — Campos descriptivos que podrían estar ya en el catálogo

- **Gravedad:** Baja
- **Tipo:** Mejora para v1
- **Descripción:** el comentario del PDW lista `polarization` y `modulation_parameter`. Igual que
  `intrapulseModulation`, se podrían copiar como dato descriptivo al pulso sin efecto físico, y serían rasgos útiles
  para un clasificador.
- **Justificación técnica:** sin el parámetro de la MOP (ancho de banda del chirp, nº de chips), saber solo "LFM" vale
  poco para clasificar. La polarización sí tendría efecto físico (pérdida por desadaptación: 3 dB lineal↔circular,
  teóricamente infinita entre ortogonales), pero eso debe esperar.
- **Cambio sugerido:** opcional; si se añaden, que sean opcionales en el JSON. **PRF frente a PRI:** mantener PRI, que
  es la magnitud natural para el deinterleaving y para el TOA; no hace falta aceptar PRF.
- **Afecta a:** spec §5; plan Tareas 2 y 13.

### D11 — Incoherencia en el Review Focus 2 del plan

- **Gravedad:** Baja
- **Tipo:** Error (de texto)
- **Descripción:** el Review Focus 2 dice que con el haz en 359° y el receptor en 1° "la ganancia es casi la de pico",
  pero el test correspondiente de la Tarea 8 usa θ_az = 2° y espera 35 − 12·(2/2)² = **23 dBi** (−12 dB, nada que ver
  con el pico). El test es correcto; el texto no.
- **Cambio sugerido:** "Δaz = 2°, no 358°; la ganancia es la del lóbulo principal (23 dBi con θ_az = 2°), no la del
  suelo de lóbulos laterales".
- **Afecta a:** plan, Review Focus 2.

### D12 — Constante de la FSPL y su dominio de validez

- **Gravedad:** Baja
- **Tipo:** Mejora para v1 (documentación)
- **Descripción y justificación:**
  - `20·log10(4π/c) = −147,5522`. Usar −147,55 introduce 0,002 dB, despreciable; está bien, pero conviene documentar
    que es redondeada (el test de 92,45 ± 1e-9 depende de que se use exactamente 147,55; si alguien la calcula a partir
    de c, el test fallará por 0,0022 dB).
  - La FSPL es de campo lejano. Por debajo de `d ≈ λ/(4π)` (≈ 8 mm a 3 GHz) sale negativa y el receptor recibiría más de
    lo emitido. La validación solo exige d ≠ 0. En la práctica es irrelevante, pero la regla 6 podría ser
    `d > 1 m` (o "mayor que unas pocas λ") en lugar de `d ≠ 0`.
- **Cambio sugerido:** nota en la spec §4 paso 2.5; opcional endurecer la regla 6 de validación.
- **Afecta a:** spec §4 y §5; plan Tareas 8 y 14.

### D13 — "amplitude" frente a "power"

- **Gravedad:** Baja
- **Tipo:** Mejora para v1
- **Descripción:** el PDW llama `amplitudeDbm_` al atributo y el CSV `powerDbm`. En la literatura de PDW es habitual
  llamar "amplitud de pulso" (PA) a un nivel expresado en dBm, así que no es un error, pero dos nombres para lo mismo
  confunden. Además conviene precisar *qué* potencia es: potencia de pico del pulso a la salida de la antena del
  receptor (P_iso + G_rx), sin pérdidas de receptor.
- **Cambio sugerido:** usar el mismo nombre en los dos sitios (p. ej. `amplitudeDbm` en ambos, o `powerDbm` en ambos)
  y documentar la definición en el `///<`.
- **Afecta a:** spec §6; plan Tareas 2 y 9.

### D14 — Puntos de extensibilidad para plataformas móviles, varios receptores y multitrayecto

- **Gravedad:** Baja
- **Tipo:** Para el futuro
- **Descripción:** el `EmittedPulse` autocontenido **sí** funciona con varios receptores (el canal se invoca una vez
  por receptor con el mismo pulso) y con plataformas móviles (lleva la posición del emisor y la dirección del haz en
  t_e, que es exactamente lo que fija la física: el pulso sale de ahí y en esa dirección). El AoA del receptor se
  calcula hacia `emitterPosition` en t_e, que también es lo correcto (el receptor ve la posición *retardada* del
  emisor). Hay tres detalles que conviene dejar anotados:
  1. `propagate(pulse, const Position& receiverPosition)` recibe una posición fija. Con un receptor móvil hay que
     resolver la ecuación de tiempo-luz `|R(t_a) − P_e(t_e)| = c·(t_a − t_e)` (converge en 2–3 iteraciones) y la ganancia
     del emisor se evalúa hacia `R(t_a)`. La firma tendrá que recibir algo consultable en el tiempo.
  2. La dirección del haz como `AngleOfArrival` (2 grados de libertad) no tiene giro alrededor del eje (*roll*). Para
     un haz asimétrico (abanico, θ_az ≠ θ_el) en una plataforma que alabea, la orientación de la elipse importa. En
     tierra el sistema del haz de D2 lo resuelve; en móvil hará falta una orientación completa (matriz o cuaternión).
     Además, en móvil el AoA medido es relativo al rumbo/actitud de la plataforma, no al ENU.
  3. Con multitrayecto un pulso emitido genera varias llegadas: `propagate` tendría que devolver una lista.
  Ninguno cierra la puerta; son cambios de firma localizados. La resolución de 1 ns (≈ 0,3 m) es suficiente para
  TDOA/geolocalización futura.
- **Cambio sugerido:** añadir una nota breve en la spec (decisión de fondo 1) con estos tres puntos.
- **Afecta a:** spec §3.

### D15 — Pérdidas del sistema y suelo de lóbulos laterales uniforme

- **Gravedad:** Baja
- **Tipo:** Mejora para v1
- **Descripción y justificación:**
  - La ecuación de Friis no incluye pérdidas (L_tx, L_rx, atmosféricas, polarización), que en la realidad suman del
    orden de varios dB. Un `lossesDb` opcional en el receptor (por defecto 0) permite ajustar el balance sin tocar la
    sensibilidad.
  - El suelo `G_max − SLL` es igual en todas las direcciones, incluida la trasera. Es una simplificación razonable
    (lóbulo lateral medio), pero optimista detrás de la antena: los lóbulos traseros reales suelen estar varios dB por
    debajo del lateral medio. Para la v1 basta con documentarlo.
- **Cambio sugerido:** documentar ambos en la spec §4; `lossesDb` opcional si se quiere.
- **Afecta a:** spec §4 pasos 2.4 y 3.

---

## Correcto desde el punto de vista del dominio

- **ENU** (X = Este, Y = Norte, Z = Arriba), **azimut desde el Norte en sentido horario** con `atan2(ΔE, ΔN)` y
  **elevación** con `atan2(ΔU, √(ΔE²+ΔN²))`: es la convención estándar en navegación y en EW. El caso del cénit
  (`atan2(0,0) = 0`) no da NaN.
- **AoA como dirección receptor → emisor**, y el desvío de antena calculado con la dirección **emisor → receptor**
  (`az_ER`): los dos sentidos están bien elegidos y no hay error de signo. El ejemplo da 36,87° y 216,87°, que difieren
  en 180° como deben.
- **Retardo d/c** con c exacta y redondeo a ns; tiempo entero en ns para que las PRI no deriven: decisión acertada.
- **FSPL** `20·log10(d) + 20·log10(f) − 147,55` (d en m, f en Hz): correcta para campo lejano (−147,5522 exacto).
  Evaluarla con la frecuencia **de cada pulso** es correcto para RF ágil.
- **Friis en dB** `P_rx = P_tx + G_tx(θ) − FSPL + G_rx`, con el canal calculando la potencia isotrópica y el receptor
  sumando su ganancia: correcto y buena separación de responsabilidades.
- **P_tx como potencia de pico** (1 MW = 90 dBm): es la magnitud que importa para detectar pulsos; la potencia media no
  interviene.
- **Ganancia del emisor evaluada en t_e con la dirección del haz en t_e**: es lo físicamente correcto (el haz que
  importa es el del instante en que el pulso sale).
- **Sensibilidad como umbral determinista** `P_rx ≥ S`: equivale a P_d = 1 por encima del umbral; razonable sin ruido.
- **Gaussiano en dB con factor 12**: `12·(1/2)² = 3 dB` a medio ancho de haz (el exacto es 12,04); es el modelo
  habitual de primer orden. La suma de los dos ejes es la de un gaussiano elíptico, correcta.
- **Haz abanico** (1,5° × 20° en `search`, elevación inclinada 2°) frente a **pincel** (1° × 1° en `track`): los dos
  casos típicos están bien representados con el mismo modelo.
- **Antena del emisor y dirección del haz en el ENU del escenario**: correcto para emisores fijos en tierra.
- **Ejemplo de la spec §4**: d = 25 000,008 m, retardo 83 391 ns, FSPL 129,95 dB, P_iso −4,95 dBm (principal) y
  −34,95 dBm (laterales). Correcto. Y la conclusión de que con −70 dBm se reciben todos los pulsos por lóbulos
  laterales a 25 km es **realista**: la detección por lóbulos laterales a decenas de km es lo normal en ESM. La spec lo
  advierte, lo cual es didácticamente valioso.
- **Tipos de PRI** (fija, stagger, sliding, dwell & switch), **RF fija y por lista con `pulsesPerHop`**, **scan fijo,
  circular y sectorial**: cubren los casos básicos que se enseñan en ELINT. La validación `PW_max < PRI_min` es la
  coherencia física correcta.
- **Calendario por segmentos** con intervalos semiabiertos, modo `off` y recorte en `durationS`, y entrega de los pulsos
  en vuelo: modela bien los cambios de modo y el silencio de emisión.
- **TOA como flanco de subida** en el receptor: coherente, porque t_e es el flanco de subida en la emisión y el retardo
  es el mismo para todo el pulso.
- **Separación medida / verdad** en el CSV, con advertencia de que las `truth_` no se usan como entrada, y orden de
  llegada con desempate determinista: exactamente lo que se necesita para evaluar un deinterleaver.
- **PRI no está en el PDW**: correcto; es un parámetro del emisor que el deinterleaver deduce.
- **La golden produce ráfagas** con los valores del plan (≈ 8 pulsos por ráfaga, laterales a −66,5 dBm por debajo de
  −60 dBm), aunque haya que fijar los huecos de D5.

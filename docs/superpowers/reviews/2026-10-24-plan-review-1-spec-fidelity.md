# Revisión 1 del plan del simulador: fidelidad entre spec y plan

Fecha: 2026-10-24
Spec: `docs/superpowers/specs/2026-10-24-simulator-design.md`
Plan: `docs/superpowers/plans/2026-10-24-simulator.md`

## Resumen

**Veredicto: apto, con cambios menores antes de ejecutar.** El plan cubre todos los requisitos de la spec. Fórmulas,
columnas del CSV, mensaje de error de ejemplo, reglas de calendario y comportamiento al final de la simulación
coinciden con la spec, y los valores esperados de los tests son correctos (los he recalculado). No hay contradicciones
graves. Hay un hueco serio, el **redondeo a ns frente a la validación `> 0`**, que puede colgar la simulación. Hay
además tres desviaciones de diseño que el plan no declara como decisiones: posición sin instante, el enum `ScanKind`
en el dominio y que `Simulation` no carga la configuración. El resto son ambigüedades de detalle.

Hallazgos: 0 críticos, 1 alto, 4 medios, 12 bajos, y 3 dudas.

## Tabla de trazabilidad

| Sección de la spec | Requisito | Tarea / paso del plan | Estado |
| --- | --- | --- | --- |
| §1 Alcance | Varios emisores, un receptor, fijos | T7, T10, T12 (`Mission`) | OK (ver F2 sobre la "puerta abierta" a móviles) |
| §1 Alcance | Determinista, AoA con error 0 | T10 (`measureAoa` identidad), T11 (desempate) | OK |
| §1 Alcance | Modelo de potencia completo | T6, T8, T10 | OK |
| §1 Fuera de alcance | Puerta abierta: posición consultada en un instante | — | **Falta** (F2) |
| §1 Fuera de alcance | Puerta abierta: otros scans como clase nueva | T5 / decisión 3 | Parcial (F3) |
| §2 Unidades | SI, grados, `nanoseconds`, `double`, AoA `float` | Global Constraints, T1 (`Units.h`) | OK |
| §2 Unidades | Unidad en el nombre de la clave/columna; loaders convierten a SI | T13, T14, T9 | OK |
| §2 Coordenadas | ENU, azimut desde el Norte en sentido horario, `atan2(ΔE, ΔN)`, elevación | T1 (`directionFromTo` y sus tests) | OK |
| §2 Coordenadas | AoA = receptor → emisor | T10 (`directionFromTo(posición, emitterPosition)`) | OK |
| §3 Eventos discretos | Cola por `(instante, secuencia)` | T11 | OK |
| §3 Eventos | Emit / Arrival | T12 (acciones `std::function`) | OK (refinamiento) |
| §3 Componentes | `Position` / geometría: "función única" que da dirección y distancia | T1 (`distanceM` + `directionFromTo`) | Desviación menor (F8) |
| §3 Componentes | `PriGenerator` Fixed/Stagger/Sliding/DwellSwitch | T3 | OK |
| §3 Componentes | `RfGenerator` Fixed/List, `PwGenerator` Fixed | T4 | OK |
| §3 Componentes | `ScanPattern` Fixed/Circular/Sector relativo al segmento | T5 | OK |
| §3 Componentes | `AntennaPattern::gainDbi`, `GaussianAntennaPattern` | T6 | OK |
| §3 Componentes | `EmitterMode` = composición de generadores | T7 (`ScanSpec` en lugar de `ScanPattern`) | Desviación declarada (decisión 3, F3) |
| §3 Componentes | `Emitter`, `PropagationChannel`, `Receiver` | T7, T8, T10 | OK |
| §3 Componentes | `PulseRecordWriter` + `CsvPulseRecordWriter` sobre `std::ostream&` | T9 | OK |
| §3 Componentes | `EventScheduler` sin conocimiento del dominio | T11 | OK |
| §3 Componentes | `Simulation` monta y ejecuta hasta vaciar la cola | T12 | OK |
| §3 Componentes | `CatalogLoader`, `MissionLoader`, únicos con nlohmann | T13, T14 (funciones libres), grep en T13 paso 4 | OK (nombres distintos, F14) |
| §3 Decisión 1 | `EmittedPulse` autocontenido | T7 (`EmittedPulse`) | OK |
| §3 Decisión 2 | Dominio sin JSON | Global Constraints, T13 paso 4 | OK |
| §3 Decisión 3 | PDW + `GroundTruth`; PDW completado según la spec de agrupación | T2, T9 | OK (F6 sobre `modulationParameter`) |
| §3 Decisión 4 | El canal da P_iso; el receptor suma G_rx | T8, T10 | OK |
| §3 Decisión 5 | Composición; extensión = clase nueva | T3–T6 | Parcial (F3) |
| §3 Ubicación | `src/SigInt/PulseDescriptors/`; `src/Simulator/{Geometry,Emitter,Channel,Receiver,Engine,Config}` | T1–T14 | OK, más el componente nuevo `Runner` (F4) |
| §3 Ubicación | nlohmann con `proj_fetch_external`, solo en `Config` | T13 | OK |
| §3 Ubicación | Ejecutable `ews <mision.json> <salida.csv>` | T15 | OK |
| §4 Paso 0 | `Simulation` carga catálogo y misión y programa un Emit por emisor | T12 + T15 (`runMission`) | Desviación no declarada (F4) |
| §4 Paso 1 | Campos del `EmittedPulse` | T7 | OK |
| §4 Paso 1 | Siguiente Emit en `t_e + PRI` | T7 (`next()`), T12 | OK |
| §4 Calendario | Primer pulso al inicio del segmento | T7 `NextStartsAtSegmentStart` | OK |
| §4 Calendario | Fuera del segmento → siguiente segmento | T7 `NextResetsStateOnModeChange`, `NextPulseOnSegmentBoundary…` | OK |
| §4 Calendario | Estado a cero en cada segmento | T7 (clonar `pri`/`rf`/`pw`, scan sin estado) | OK |
| §4 Calendario | Segmentos `off` no emiten | T7 `NextSkipsOffSegment` | OK |
| §4 Calendario | Nada en instantes ≥ `durationS` | T7 `NextStopsAtEnd`, T14 `…BeyondDuration` | OK |
| §4 Scan | Fórmulas de fijo, circular y sectorial | T5 (fórmula explícita del sector y tests) | OK |
| §4 Paso 2 | Retardo redondeado, wrap a (−180, 180], gaussiano, FSPL, P_iso, `IncidentPulse` | T8 | OK |
| §4 Paso 3 | `P_rx`, detección `≥`, descartados no se escriben, AoA, PDW + verdad | T10 | OK |
| §4 Paso 4 | Vaciar la cola; pulsos en vuelo se entregan | T12 `RunDeliversPulsesInFlightAfterEnd` | OK |
| §5 Organización | `scenarios/catalog/`, `scenarios/missions/demo_01.json` | T15 | OK (solo `SearchRadar_X`; `FireControl_Y` era ilustrativo) |
| §5 Catálogo | Claves y `kind` de cada bloque | T13 | OK |
| §5 Catálogo | `intrapulseModulation` descriptivo | T2, T13 | OK, con regla extra (F6) |
| §5 Misión | Claves, `catalogDir` relativo, encadenado desde `startS`, `off` reservado, parámetros por scan | T14 | OK (F5 sobre `positionM`) |
| §5 Validación 1 | Claves desconocidas | T13 `finish()`, `…RejectsUnknownKey`; T14 `…ExtraSegmentParameter` | OK |
| §5 Validación 2 | Rangos | T13 (`NonPositiveValues`, `NegativeSidelobeLevel`, `EmptyList`, `SlidingMinNotBelowMax`, `PulsesPerDwellBelowOne`), T14 (`NegativeStart`, `NonPositiveDuration`) | OK, con hueco (F1) |
| §5 Validación 3 | PW máx < PRI mín | T13 `…RejectsPwNotBelowMinPri` | OK |
| §5 Validación 4 | Referencias, ids únicos, tipos únicos, sin modo `off` | T13, T14 | OK |
| §5 Validación 5 | Parámetros de segmento exactos | T14 `Missing…` / `Extra…` | OK |
| §5 Validación 6 | d = 0 | T14 `…EmitterAtReceiverPosition` | OK |
| §5 Validación 7 | Recortar, no error | T14 `…AcceptsScheduleBeyondDuration` | OK |
| §5 Errores | Acumular y lanzar `ConfigError` | T13 (`ConfigError`, `JsonReader`), `…AccumulatesErrors` en T13 y T14 | OK (F11) |
| §5 Errores | Fichero + ruta; mensaje de ejemplo | T13 (formato), T14 `…RejectsUnknownMode` (mensaje exacto) | OK (F10) |
| §5 Errores | Catálogo antes que misión | T14 `loadMission` | OK |
| §5 Errores | `main` captura, imprime y sale con ≠ 0 | T15 (código 1) | OK, con códigos extra (F12) |
| §6 Salida | Una fila por pulso detectado, en orden de llegada, cabecera | T9, T10, T12 | OK |
| §6 Salida | Separador `.`, precisión fija | T9 (`std::format`, sin `L`) | OK |
| §6 Salida | 16 columnas en el orden de la spec | T9 (cabecera literal) | OK (comprobado columna a columna) |
| §6 Salida | `truth_eirpDbm = P_tx + G_tx` | T10 | OK |
| §7 Unitarios | Casos clave por componente | T1–T14 | OK salvo "receptor por encima" (F7) |
| §7 Unitarios | `EXPECT_EQ` para tiempos, `EXPECT_NEAR` para ángulos y potencias | — | Ambiguo (F15) |
| §7 Integración | Golden: dos emisores, pocos segundos, en `tests/` | T15 | OK con matices (F9) |

## Hallazgos

### F1 — Alta — La validación `> 0` no dice si se aplica antes o después de redondear a ns

- **Ubicación:** spec §5 Validación 2 y "Una vez arrancada, la simulación no puede fallar por la configuración"; plan,
  Global Constraints ("Conversión de unidades del JSON a `Time` con redondeo al ns más cercano") y T13 (`JsonReader`,
  `positiveNumber`).
- **Descripción:** si `positiveNumber` comprueba el `double` del JSON y luego se convierte con `llround`, un
  `valueUs: 0.0004` pasa la validación y da una PRI de **0 ns**. Con eso `Emitter::next()` no avanza nunca y la
  simulación se cuelga (o genera infinitos eventos en el mismo instante). Con `periodS` redondeado a 0, `CircularScan` y
  `SectorScan` dividen por cero, y una PW de 0 ns sale en el CSV como `0.000`. Algo parecido pasa con la regla 3:
  comparar PW y PRI en µs (`double`) o en ns redondeados puede dar resultados distintos en el límite. Y no se dice qué
  ocurre con valores que desbordan `int64` en ns (`durationS: 1e12`).
- **Evidencia:** spec: "PRI, PW, frecuencias, periodos, […] y `durationS` > 0"; "la simulación no puede fallar por la
  configuración". Plan: "`microsecondsToTime(1.0004)` → `Time{1000}`" y "`positiveNumber`… añaden… y devuelven
  `std::nullopt`", sin indicar el orden.
- **Cambio sugerido:** en T13, fijar que los valores de tiempo se validan **después** de convertirlos a `Time`
  (`> 0 ns`) y que la regla 3 compara en `Time`. Añadir un rango máximo (o un error si hay desbordamiento) y el test
  `ParseCatalogRejectsValueRoundingToZero` (`valueUs: 0.0004`).

### F2 — Media — La "puerta abierta" a plataformas móviles se cierra en las interfaces

- **Ubicación:** spec §1 Fuera de alcance; plan T7 (`Emitter::get_position`), T8 (`propagate(iPulse,
  iReceiverPosition)`), T10 (`Receiver::get_position`).
- **Descripción:** la spec pide que la posición se consulte **en un instante** aunque hoy sea constante. En el plan la
  posición es un atributo sin tiempo, tanto en el emisor como en el receptor. Además el canal recibe la posición del
  receptor sin saber de qué instante es. El receptor calcula el AoA con su posición fija y la del emisor en t_e. Con
  plataformas móviles habría que cambiar las firmas de tres componentes.
- **Evidencia:** spec: "Plataformas móviles (la posición se consulta en un instante, aunque hoy sea constante)". Plan:
  "`const Position& get_position(void) const;`".
- **Cambio sugerido:** declarar `positionAt(Time)` (hoy devuelve la constante) en `Emitter` y `Receiver`, o un tipo
  `Trajectory` con implementación `StaticTrajectory`. Si no, anotarlo como decisión consciente en "Decisiones a
  confirmar" y aceptar el coste del cambio futuro.

### F3 — Media — Decisión 3: `ScanKind` en el dominio va contra "extensión = clase nueva"

- **Ubicación:** spec §3 Decisión 5 y §1 ("otros scans (cónico, raster)"); plan, decisión 3 y T5 (`enum class
  ScanKind`, `struct ScanSpec`).
- **Descripción:** la decisión resuelve bien la tensión real entre "el modo tiene su scan" y "la orientación la da la
  misión". Pero al poner un `enum` y un `struct` con campos de todos los scans (`period`, `elevationDeg`, `widthDeg`)
  en `Emitter/`, añadir un scan cónico obliga a tocar el enum, el struct y el `switch` del loader. No basta con una
  clase nueva que implemente `ScanPattern`.
- **Evidencia:** spec: "Cada extensión futura es una clase nueva que implementa una interfaz existente". Plan:
  "`enum class ScanKind : std::uint8_t { Fixed, Circular, Sector };`".
- **Cambio sugerido:** dejar `ScanSpec` como detalle privado de `Config` (ya que el loader es quien combina catálogo y
  segmento), de modo que `EmitterMode` no tenga scan y el dominio solo vea el `ScanPattern` del `Segment`. Otra opción
  es una interfaz `ScanFactory` en el modo (`make(segmentParams)`). Cualquiera de las dos debería anotarse en la spec.

### F4 — Media — `Simulation` no carga la configuración y aparece un componente `Runner` no previsto

- **Ubicación:** spec §4 Paso 0 y §3 Ubicación; plan T12 (`Simulation(Mission, PulseRecordWriter&)`) y T15
  (`src/Simulator/Runner/`, `runMission`).
- **Descripción:** la spec dice que `Simulation` carga el catálogo y la misión, y enumera seis componentes. El plan
  hace que `Simulation` reciba la `Mission` ya construida y crea `Runner` para la carga. Es coherente con la Decisión 2
  (`Simulation` testeable sin ficheros) y probablemente mejor, pero contradice la letra del Paso 0 y no está en
  "Decisiones a confirmar".
- **Evidencia:** spec: "`Simulation` carga el catálogo y la misión, construye los objetos…"; "con los componentes
  `Geometry`, `Emitter`, `Channel`, `Receiver`, `Engine` y `Config`". Plan: "Create: `src/Simulator/Runner/include/MissionRunner.h`".
- **Cambio sugerido:** añadirla como decisión 6 y actualizar §3/§4 de la spec cuando el usuario la apruebe.

### F5 — Media — No se valida que `positionM` tenga exactamente 3 números

- **Ubicación:** spec §5 Misión ("`positionM`: [x, y, z]") y "Todo se valida al cargar"; plan T13 (`JsonReader`:
  `number`, `array`…) y T14.
- **Descripción:** no hay regla, mensaje ni test para `positionM` con 2 o 4 elementos, o con elementos que no sean
  números (receptor y emisores). Un implementador puede leer `[0]`, `[1]`, `[2]` sin comprobar la longitud. Si lo hace
  con `operator[]` es comportamiento indefinido, y con `at` lanza una excepción de nlohmann, que es justo lo que
  intenta evitar el Review Focus 5.
- **Evidencia:** spec: `"positionM": [15000, 20000, 30]`. En el plan no aparece ningún mensaje del tipo "debe tener 3
  elementos".
- **Cambio sugerido:** añadir a `JsonReader` una lectura `position` (lista de 3 números), con su mensaje y el test
  `ParseMissionRejectsBadPosition`.

### F6 — Baja — `IntrapulseModulation` cerrada: regla de validación nueva no declarada; `modulationParameter` aplazado

- **Ubicación:** spec §5 ("`intrapulseModulation` es un dato descriptivo que se copia al pulso") y §3 Decisión 3 (PDW
  "siguiendo `2026-10-23-pdw-attribute-grouping-design.md`"); plan T2 y T13 (`ParseCatalogRejectsUnknownModulation`).
- **Descripción:** el plan limita los valores a 6 nombres exactos, sensibles a mayúsculas, y rechaza el resto. Es
  razonable, pero es alcance extra y no figura en "Decisiones a confirmar". La spec de agrupación trata la modulación
  como grupo "tipo + parámetro" (segunda en el orden de extracción). El plan solo implementa el tipo, como `enum`
  suelto.
- **Evidencia:** spec de agrupación: "Modulación intrapulso (tipo + parámetro): la invariante más fuerte". Plan:
  "`enum class IntrapulseModulation : std::uint8_t { None, Lfm, Nlfm, Bpsk, Barker, Fsk };`".
- **Cambio sugerido:** añadirlo a las decisiones y anotar en T2 que `modulationParameter_` queda aplazado de forma
  consciente.

### F7 — Baja — Falta el caso "por encima de la sensibilidad" en el receptor

- **Ubicación:** spec §7 (Receptor: "por debajo, igual y por encima"); plan T10 paso 1.
- **Descripción:** hay tests para −73.01 (descarta) y −73 (igual). El caso "por encima" solo se cubre de forma
  implícita en `ReceiveFillsPdwFromPulse`, cuya P_iso no se indica.
- **Cambio sugerido:** añadir `ReceiveKeepsPulseAboveSensitivity`, o fijar en `ReceiveFillsPdwFromPulse` una P_iso por
  encima y comprobar `amplitudeDbm`.

### F8 — Baja — Geometría en dos funciones en lugar de "función única"

- **Ubicación:** spec §3 Componentes (`Position` / geometría); plan T1 (`distanceM`, `directionFromTo`).
- **Descripción:** la spec pide una única función que devuelva dirección **y** distancia. El plan las separa. No
  cambia el resultado, pero sí la interfaz que se pidió.
- **Evidencia:** spec: "función única que devuelve dirección (`AngleOfArrival`) y distancia entre dos puntos". Plan:
  dos firmas separadas.
- **Cambio sugerido:** o una función que devuelva un struct `{direction, distanceM}`, o anotar el cambio en la spec.

### F9 — Baja — La misión golden está poco especificada y no coincide del todo con la spec

- **Ubicación:** spec §7 Integración; plan T15.
- **Descripción:** (a) la spec dice "pocos segundos" y el plan pone `durationS` 0.1 s; (b) la spec dice "en `tests/`"
  y el plan usa `src/Simulator/Runner/tests/data/` (puede que sea lo que se quería decir, pero conviene confirmarlo);
  (c) faltan datos para que dos implementadores generen la misma misión: P_tx y antena de B, `gainDbi` del receptor,
  `initialAzimuthDeg` de A y duraciones de los segmentos de B. El paso 5 da por hecho que la ganancia de B es 30
  ("P_tx + 30 − FSPL"), pero la antena de B no se especifica.
- **Cambio sugerido:** escribir el JSON de la misión golden en el plan, o al menos todos sus valores, y ajustar la
  duración o la spec.

### F10 — Baja — Detalles del formato de error sin fijar

- **Ubicación:** spec §5 Gestión de errores; plan T13 ("`<fichero>: <ruta>.<clave>: <mensaje>`") y T14.
- **Descripción:** (a) ¿`<fichero>` es el nombre base o la ruta tal como se pasó? La spec muestra el nombre base
  (`demo_01.json`), pero `loadMission`/`loadCatalog` no dicen qué pasan como `iFileName`. (b) Con las claves de raíz,
  `<ruta>.<clave>` daría `.type`, o `type` si se trata el caso vacío. (c) Falta la ruta del error de la regla 3 (¿
  `modes.search`? ¿`modes.search.pw.widthUs`?) y la de los elementos de lista (`valuesUs[1]`, `positionM[2]`).
- **Cambio sugerido:** fijar en T13: nombre base del fichero, ruta sin punto inicial en la raíz, índices `[i]`, y la
  ruta concreta del error de coherencia PW/PRI.

### F11 — Baja — La acumulación de errores se corta entre fases

- **Ubicación:** spec §5 ("La validación acumula todos los errores"; "Se carga primero el catálogo y después la
  misión"); plan T14 (`readCatalogDir` lanza; `loadMission`).
- **Descripción:** si el catálogo tiene errores, `loadCatalog` lanza y no se informa de los errores de la misión. Si
  falta `catalogDir`, tampoco. Es compatible con "primero el catálogo" pero conviene decirlo. Tampoco se dice que un
  fichero de misión inexistente o ilegible produzca `ConfigError`: el Review Focus 5 solo menciona `catalogDir`.
- **Cambio sugerido:** anotar en T14 que la acumulación es por fase, y añadir `LoadMissionRejectsMissingFile` →
  `ConfigError`.

### F12 — Baja — `main`: códigos de salida extra y orden apertura/carga sin fijar

- **Ubicación:** spec §5 ("`main` captura `ConfigError`… código de salida distinto de 0"); plan T15.
- **Descripción:** los códigos 2 (uso) y 3 (fichero de salida) son alcance extra razonable. Lo que no se fija es si el
  `ofstream` se abre antes de cargar la misión. Si se abre antes, un `ConfigError` deja el CSV truncado o vacío; si se
  abre después, no.
- **Cambio sugerido:** fijar el orden: cargar y validar primero, y abrir el fichero después. `runMission` podría
  recibir la ruta, o dividirse en carga y ejecución.

### F13 — Baja — Contradicción interna del plan en el Review Focus 2

- **Ubicación:** plan, Review Focus 2 frente a T8 `PropagateWrapsBeamOffset`.
- **Descripción:** el Review Focus dice "la ganancia es casi la de pico". El test, con θ_az = 2°, espera 23 dBi (35 −
  12), que no es "casi la de pico". El test es correcto según la fórmula de la spec. El texto confunde.
- **Cambio sugerido:** cambiar el texto por "Δaz = 2° (no 358°): ganancia 23 dBi, no el suelo de 5 dBi".

### F14 — Baja — El plan no cumple del todo su propia decisión 2 (R12) ni la convención de ficheros

- **Ubicación:** plan, decisión 2 (las clases de comportamiento mantienen R12) y Global Constraints ("Cada clase en 3
  ficheros `include/<C>.h`, `src/<C>.cpp`, `tests/ut_<C>.cpp`"); T7, T10, T13.
- **Descripción:** hay funciones públicas sin test: `Emitter::get_id`, `Emitter::get_position`,
  `Receiver::get_position`, `Catalog::add` y `Catalog::find`. Los ficheros `include/Catalog.h` + `src/CatalogLoader.cpp`
  + `tests/ut_CatalogLoader.cpp` no siguen el patrón `<C>`. `JsonReader` no tiene test (se dice expresamente) y su
  cabecera va en `src/`. Además los nombres `CatalogLoader`/`MissionLoader` de la spec pasan a ser funciones libres.
- **Cambio sugerido:** o añadir esos tests y un `Catalog.cpp`/`ut_Catalog.cpp`, o declarar estas excepciones en la
  decisión 2.

### F15 — Baja — `EXPECT_NEAR` (spec) frente a `EXPECT_DOUBLE_EQ` (R12) sin resolver

- **Ubicación:** spec §7 ("ángulos y potencias con `EXPECT_NEAR`"); `how_to_write_a_class.md` R12 ("Para
  `float`/`double`, `EXPECT_FLOAT_EQ` / `EXPECT_DOUBLE_EQ`"); plan T1 (`EXPECT_DOUBLE_EQ(distanceM…)`), T6 y T10 (no
  se indica la macro).
- **Descripción:** las dos reglas chocan y el plan no dice cuál manda en cada caso. Un implementador puede usar
  `DOUBLE_EQ` en la antena o en el canal y tener tests frágiles por el redondeo.
- **Cambio sugerido:** fijarlo en Global Constraints: R12 (`*_EQ`) para las clases de valor y `EXPECT_NEAR` con
  tolerancia explícita para los cálculos físicos.

### F16 — Baja — Decisión 4 (ids): cobertura incompleta

- **Ubicación:** plan, decisión 4 y T13/T14.
- **Descripción:** solo hay test para un id de tipo inválido (`"Radar X"`). No hay tests para id de emisor, de
  receptor ni para nombres de modo, que son claves de objeto JSON y necesitan una comprobación aparte. La regla tampoco
  se refleja en la spec, que es la fuente de verdad.
- **Cambio sugerido:** añadir `ParseMissionRejectsInvalidId` y un caso de nombre de modo inválido, y llevar la regla a
  §5 Validación de la spec cuando se apruebe.

### F17 — Baja — Listas vacías en la misión sin definir

- **Ubicación:** spec §5 Validación 2 ("listas no vacías"); plan T13/T14.
- **Descripción:** queda abierto si `emitters: []` y `schedule: []` son error (la regla habla de "listas" en general)
  o si son válidos (CSV solo con cabecera; emisor que no emite). Dos implementadores pueden hacer cosas distintas.
- **Cambio sugerido:** decidirlo y añadir un test en T14.

## Decisiones a confirmar: evaluación

| # | Decisión | ¿Contradice la spec? | Valoración |
| --- | --- | --- | --- |
| 1 | Namespace `sim` | No. La spec no fija el namespace y R3 obliga a preguntar. | Refinamiento legítimo. |
| 2 | Alcance de `how_to_write_a_class.md` según el tipo de clase | No contradice la spec, que no menciona las reglas, pero sí se separa de R8 ("Por cada clase") del fichero de reglas. | Legítimo y necesario (aplicar los cinco accesores a `EventScheduler` o a `Emitter` no tiene sentido). Ver F14: el plan no lo cumple del todo. |
| 3 | Scan construido por segmento (`ScanSpec` + parámetros del segmento) | Contradice la letra de §3 (tabla: `EmitterMode` compone los generadores; Decisión 5). Resuelve una tensión que la propia spec deja (§5 regla de reparto). | Refinamiento legítimo en el fondo, pero la forma (`ScanKind` en el dominio) va contra la Decisión 5. Ver F3. |
| 4 | Ids limitados a `[A-Za-z0-9_-]+` | No contradice. Añade una regla de validación que la spec no tiene, y la spec tampoco dice nada de escapar texto en el CSV, así que cubre un hueco real. Los ejemplos de la spec (`SearchRadar_X`, `E1`, `RX1`, `search`) cumplen la regla. | Legítimo. Debe llevarse a la spec (§5 Validación). Ver F16. |
| 5 | `std::chrono::nanoseconds` también en el PDW | No. Es lo que ya fija la spec §2 ("Tiempo como entero en nanosegundos (`std::chrono::nanoseconds`)"). Solo se aparta del comentario orientativo de `PulseDescriptorWords.h` (`uint64_t`). | Legítimo. Más que una decisión nueva, es aplicar la spec. |

**Decisiones que el plan toma y no declara** (conviene añadirlas a la lista): `Simulation` sin carga + `Runner` (F4);
modulación cerrada (F6); intervalos semiabiertos en las fronteras (coherente con la spec, que dice "fuera del
segmento", pero sin precisar la frontera); `SlidingPri` con un paso que no divide el rango (`{100,125,10}` →
100, 110, 120, 100); redondeo `llround` en la conversión JSON → `Time`; precisiones del CSV; códigos de salida 2 y 3;
catálogo como "todos los `*.json` de la carpeta, ordenados por nombre"; `EventScheduler::schedule` que lanza
`std::logic_error` con instantes pasados.

## Alcance extra (lo que el plan añade sin que la spec lo pida)

- Componente `Runner` y la función `runMission` (T15).
- `enum IntrapulseModulation` con conversión desde y hacia texto y validación de valores (T2, T13).
- Regla de formato de ids (decisión 4).
- Códigos de salida 2 y 3, y el mensaje de uso (T15).
- `EventScheduler::schedule` lanza con instantes pasados; `now()` y `empty()` públicos (T11).
- `clone()` en los generadores (T3, T4), como forma de aplicar "estado a cero" por segmento.
- Tests extra de geometría (elevación 45°, vertical sin NaN) y de wrap de scan en 0°/360°.
- Mensajes de error concretos en T13/T14 (la spec solo da uno de ejemplo).
- `readCatalogDir` como función separada (T14).
- Sección "Reparto de trabajo (modo aprendizaje)" y la rama `feature/simulator` (proceso, no producto).

## Dudas

- **D1 — Precisión `float` en cálculos intermedios.** La spec §2 dice que el AoA se convierte a `float` "solo al
  final", pero la tabla de §3 hace que la función de geometría devuelva `AngleOfArrival` (`float`). El plan sigue la
  tabla: la dirección del haz (`EmittedPulse::beamDirection`) y la dirección emisor → receptor del canal también son
  `float`, así que Δaz/Δel se calculan con unos 1e-5° de resolución. El efecto en la ganancia es despreciable, pero hay
  una tensión dentro de la propia spec que conviene resolver.
- **D2 — `amplitudeDbm_` como `float` en el PDW.** La spec dice "potencias en `double`" y solo menciona el AoA como
  excepción. El comentario de `PulseDescriptorWords.h` recomienda `float` en dBm. Como el PDW es el final del
  recorrido, probablemente sea aceptable; no lo cuento como hallazgo.
- **D3 — Claves JSON duplicadas.** nlohmann se queda en silencio con la última. La spec no lo exige, pero va en el
  mismo sentido que la regla 1 ("no debe ignorarse en silencio"), sobre todo para nombres de modo repetidos dentro de
  un tipo.

## Verificado sin problemas

- **Fórmulas:** dirección (`atan2(ΔE, ΔN)`), elevación, retardo con redondeo, wrap a (−180, 180] (incluido −180 →
  180), ganancia gaussiana con suelo, FSPL con −147.55, `P_iso`, `P_rx`, EIRP de verdad. Coinciden en Global
  Constraints, T6, T8 y T10.
- **Valores esperados recalculados:** 3-4-5 → 36.8699°; `freeSpacePathLossDb(1000, 1e9)` = 92.45; P_iso 32.55;
  ganancias 32/29/5/23; `propagationDelay(299.792458)` = 1000 ns y `(0.1)` = 0; 2998 m → 10 000 ns; secuencias de T3
  y T4; scans de T5 (incluidos los cruces de 0°/360°); calendarios de T7 (`NextSkipsOffSegment` → 5, 6, 7, 9.5, 10.5;
  `NextResetsStateOnModeChange` → 5, 6, 7.5, 8.5, 10.5); 5 + 40 + 10 = 55 s en T14; fila de ejemplo del CSV en T9.
- **CSV:** las 16 columnas, en el orden y con los nombres exactos de §6; `std::format` sin `L` garantiza el
  separador `.`; `\n` como fin de línea.
- **Mensaje de error de ejemplo:** T14 lo reproduce literalmente (salvo el nombre del fichero del test).
- **Calendario:** primer pulso al inicio del segmento, paso al siguiente segmento, estado a cero (clonado + scan sin
  estado y relativo al segmento), `off`, corte en `durationS`, recorte sin error.
- **Final:** vaciado de la cola y entrega de pulsos en vuelo (T12 `RunDeliversPulsesInFlightAfterEnd`).
- **Reglas de validación 1 a 7:** todas tienen al menos un test (con los matices de F1, F5 y F17).
- **Aislamiento de nlohmann:** dependencia `PRIVATE_EXTERNAL` (la admite `.cmake/Deps.cmake`) y comprobación con
  `grep` en T13. Las cabeceras en `src/` de un componente se añaden como include privado (`.cmake/BuildComponent.cmake`).
- **PDW:** atributos con la unidad en el nombre (R7), `aoa_` como `AngleOfArrival` según la spec de agrupación,
  `to_string` con etiquetas según R10.
- **Determinismo:** desempate por número de secuencia, tests de orden en T11 y T12, y golden file.
- **Ejemplo de la spec §5:** se usa tal cual en T13/T14 y en `scenarios/`.

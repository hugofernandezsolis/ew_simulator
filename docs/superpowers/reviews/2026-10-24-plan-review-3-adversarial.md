# Revisión adversarial del plan del simulador (abogado del diablo)

Fecha: 2026-10-24
Documentos revisados: `specs/2026-10-24-simulator-design.md`, `plans/2026-10-24-simulator.md`,
`src/SigInt/PulseDescriptors/` (`AngleOfArrival`).

Cálculos de apoyo hechos con `python3 -I` (FSPL, separación angular real frente a la fórmula, formato de `float`,
límites de `int64` en ns).

## Resumen y veredicto

El diseño de fondo aguanta bien: el desempate por número de secuencia hace la simulación determinista, el retardo
nunca es negativo (no hay llegadas en el pasado), los intervalos semiabiertos están bien definidos y el wrap de
azimut está cubierto por tests. **Pero la validación del loader trabaja sobre los `double` del JSON y no sobre los
valores ya convertidos a `Time`**, y eso abre la puerta a un bucle infinito, a divisiones por cero y a desbordamientos
de `int64` con entradas que pasan todas las reglas de la spec. Además, la `const` del prototipo compartido
(`shared_ptr<const EmitterMode>`) no protege a los generadores, y hay varios huecos de validación de JSON (enteros,
longitud de `positionM`) que pueden acabar en comportamiento indefinido.

**Veredicto: apto para ejecutar tras corregir A1–A3** (cambios pequeños y localizados en las Tareas 1, 7, 13 y 14).
El resto son mejoras de robustez o aclaraciones.

| Gravedad | Nº | Hallazgos |
| --- | --- | --- |
| Crítica | 1 | A1 |
| Alta | 2 | A2, A3 |
| Media | 5 | A4, A5, A6, A7, A8 |
| Baja | 7 | A9 – A15 |

## Hallazgos

### A1 — Valores positivos que se redondean a 0 ns: bucle infinito y división por cero (Crítica)

- **Escenario.** Catálogo con `"pri": {"kind": "fixed", "valueUs": 0.0004}`. También: `"stepUs": 0.0004` en
  `sliding`, `"periodS": 1e-10` en un scan, `"durationS": 1e-10` en un segmento, `"widthUs": 0.0004`.
- **Comportamiento previsto.** La regla 2 de la spec (§5) exige `> 0` y el plan (Tarea 13) la comprueba con
  `positiveNumber` sobre el `double` leído: `0.0004 > 0` pasa. Después `microsecondsToTime(0.0004)` =
  `llround(0.4)` = **0 ns**. Consecuencias:
  - **PRI 0 ns** → en `Emitter::next` el siguiente `t = t + 0` nunca llega al fin del segmento → el emisor genera
    pulsos infinitos en el mismo instante; el planificador nunca vacía la cola → **cuelgue** y memoria creciente
    (cada Emit programa un Arrival).
  - **`stepUs` 0 ns** en `SlidingPri` → `min, min+0, …` nunca supera `max`: no cuelga, pero la PRI es fija en
    `min` en silencio.
  - **Periodo de scan 0 ns** → `SectorScan` hace `t mod T` con `T = 0` (división entera por cero en
    `std::chrono::operator%`: comportamiento indefinido, típicamente SIGFPE). `CircularScan` divide un `double` por 0
    → `inf` → `AngleOfArrival` aplica `fmod(inf, 360)` = **NaN** → Δaz NaN → `std::max(NaN, suelo)` devuelve NaN o
    el suelo según el orden de los argumentos → el pulso se descarta o se registra con potencia de suelo, sin aviso.
  - **Segmento de 0 ns** → `[inicio, inicio)` está vacío, pero si `next()` aplica "el primer pulso sale en
    `inicio_k`" sin comprobar `inicio_k < fin_k`, emite un pulso en un segmento que no existe. El plan no fija esa
    comprobación.
  - Variante de la regla 3 (PW < PRI mínima): `widthUs: 999.9996` y `valueUs: 1000.0004` cumplen la regla en `double`
    pero tras el redondeo ambos valen 1000 ns (PW == PRI).
- **Esperado.** `ConfigError` con ruta: `X.json: modes.search.pri.valueUs: debe ser > 0 (tras redondear a 1 ns)`.
- **Cambio sugerido.**
  - Tarea 13/14: validar los rangos **después** de convertir a `Time` (`> 0 ns`), y comparar PW con PRI mínima
    también en `Time`. Nuevo test `ParseCatalogRejectsValueThatRoundsToZero` (`valueUs: 0.0004`) y uno para
    `periodS: 1e-10`.
  - Tarea 7: en el comentario de `next()`, fijar como precondición `pri->next() > 0` y que un segmento de duración 0 no
    emite; test `NextSkipsZeroDurationSegment`. Opcional: `assert(pri > Time::zero())` en `Emitter` como red de
    seguridad (si se cuela, mejor un fallo que un cuelgue).

### A2 — Desbordamiento de `int64` en ns y números infinitos (Alta)

- **Escenario.** `"durationS": 1e10` (≈ 317 años; el máximo de `int64` en ns es 9,22·10⁹ s ≈ 292 años). O `startS`
  y duraciones de segmento válidas una a una cuya **suma** desborda (p. ej. 3 segmentos de 4·10⁹ s). O `"valueUs":
  1e400`: según tengo entendido nlohmann/json parsea un literal fuera de rango como `inf` sin dar error (conviene
  comprobarlo con un test, no lo he verificado). O una posición `[1e19, 0, 0]`: `propagationDelay` hace
  `llround(3,3·10¹⁰ s en ns)` y desborda.
- **Comportamiento previsto.** `std::llround` de un valor no representable (o de `inf`/NaN) da un resultado no
  especificado (en x86, `LLONG_MIN`) → `durationS` negativa → no se emite nada, o `startS` negativo. Las sumas
  `inicio_k + duración_k` en `std::chrono::nanoseconds` son desbordamiento de entero con signo: **comportamiento
  indefinido**, que UBSan de `ci-Debug` sí detectaría si hubiera un test, pero no lo hay. Un `inf` que llegue a la
  geometría produce NaN en la salida (`nan` en el CSV) o en la comparación con la sensibilidad (siempre falsa →
  descarte silencioso).
- **Esperado.** Error de configuración: `durationS: debe ser finito y <= <límite>`.
- **Cambio sugerido.**
  - Tarea 1: documentar la precondición de `secondsToTime`/`microsecondsToTime` (finito y dentro de rango) y que el
    loader la garantiza.
  - Tarea 13/14: `JsonReader::number` rechaza no finitos (`std::isfinite`). Fijar un límite superior razonable
    (p. ej. `durationS ≤ 10⁶ s`, posiciones `|x| ≤ 10⁸ m`) y validar que `startS + Σ duraciones` no lo supera
    (o recortarlo a `durationS` antes de sumar, ya que la regla 7 dice que lo que excede se recorta). Tests
    `ParseMissionRejectsDurationTooLarge`, `ParseMissionRejectsNonFiniteNumber` (`1e400`).

### A3 — El prototipo compartido no está protegido por `const` (Alta)

- **Escenario.** Dos emisores `E1` y `E2` del mismo tipo `SearchRadar_X` en la misión. Ambos `Segment` apuntan al
  mismo `std::shared_ptr<const EmitterMode>`.
- **Comportamiento previsto.** `const EmitterMode` hace `const` el **puntero** `std::unique_ptr<PriGenerator> pri`,
  no el objeto apuntado: `mode->pri->next()` **compila** sobre el prototipo. Si `Emitter::next` (pieza 👤, donde el
  error es fácil) llama por despiste a `segment.mode->pri->next()` en vez de a su clon, `E1` y `E2` avanzan la misma
  secuencia stagger y se roban valores el uno al otro. Ningún test del plan lo detecta: todos los de la Tarea 7 usan
  un único emisor, y la Tarea 12 usa `FixedPri` (donde avanzar o no da igual).
- **Esperado.** Que el compilador impida avanzar el prototipo, y un test que lo demuestre.
- **Cambio sugerido.**
  - Tarea 7: declarar en `EmitterMode` `std::unique_ptr<const PriGenerator> pri` (ídem `rf`, `pw`). `clone()` es
    `const`, así que sigue funcionando; `next()` deja de compilar sobre el prototipo. El comentario "never advanced"
    pasa a estar garantizado por el tipo.
  - Tarea 7: test `NextDoesNotShareStateBetweenEmittersOfSameMode`: dos `Emitter` con el mismo `shared_ptr` a un modo
    con `StaggerPri{1,2,3 ms}`; intercalar llamadas a `next()` y comprobar que ambos dan 0, 1, 3, 6 ms.

### A4 — Enteros del JSON: negativos, decimales y fuera de rango en `uint32_t` (Media)

- **Escenario.** `"pulsesPerHop": -1`, `"pulsesPerDwell": 2.5` o `"pulsesPerDwell": 1e10`.
- **Comportamiento previsto.** El plan solo menciona lecturas `number`/`positiveNumber`. Si el entero se obtiene con
  `get<std::uint32_t>()`, nlohmann hace un `static_cast` (hasta donde sé): `-1` → 4 294 967 295, `2.5` → 2, `1e10`
  → valor truncado. La regla "≥ 1" se comprueba sobre el resultado ya convertido y **pasa**. El emisor se queda con
  la misma RF durante 4 mil millones de pulsos sin que nadie se entere.
- **Esperado.** `pulsesPerHop: debe ser un entero >= 1`.
- **Cambio sugerido.** Tarea 13: añadir a `JsonReader` una lectura `positiveInteger` que exige `is_number_integer()`
  (o un `double` con parte fraccionaria nula), comprueba el rango **antes** de convertir y añade el mensaje fijo
  `debe ser un entero`. Tests `ParseCatalogRejectsNegativeInteger` y `ParseCatalogRejectsFractionalInteger`.

### A5 — La fórmula gaussiana usa Δaz en grados de azimut: falla a elevaciones altas y en el cenit (Media)

- **Escenario.** Scan fijo con `pointingAzimuthDeg: 0, pointingElevationDeg: 60`, haz `{35, 2, 20, 30}`, y el
  receptor visto desde el emisor en (az 4°, el 60°).
- **Comportamiento previsto.** Δaz = 4°, Δel = 0 → `35 − 12·(4/2)²` = −13 → suelo, **5 dBi**. La separación angular
  real entre las dos direcciones es **2,0°** (Δaz·cos el), con la que la ganancia sería 23 dBi: 18 dB de error.
  Peor cerca del cenit: haz (0°, 89°) y receptor en (90°, 89°) están a 1,41° reales; la fórmula da suelo (5 dBi) en
  lugar de 29 dBi. Y si el receptor está **justo encima** del emisor, `atan2(0, 0)` = 0 hace que el azimut del
  receptor sea 0° por convenio: la ganancia depende del azimut del haz aunque físicamente el desvío sea solo
  `90 − el_haz`.
- **Esperado.** O bien una ganancia basada en la separación angular real, o una limitación documentada.
- **Cambio sugerido.** En la v1, con escenarios de superficie, `el_ER` ≈ 0 y el error es despreciable: basta
  **documentarlo** en la spec §4 paso 2 ("aproximación válida para elevaciones pequeñas") y en el comentario de
  `GaussianAntennaPattern`. Si se quiere arreglar ya: en `PropagationChannel`, usar `Δaz·cos(el_ER)` como desvío
  horizontal (cambio de una línea, sin tocar la interfaz de la antena). En ambos casos, añadir en la Tarea 8 un test
  que fije el comportamiento elegido a el = 60°. Opcional: validar `pointingElevationDeg` y `elevationDeg` en
  [−90, 90] (ver A10).

### A6 — `positionM` con longitud distinta de 3 o con elementos no numéricos (Media)

- **Escenario.** `"positionM": [15000, 20000]` o `"positionM": [1, "2", 3]` o `"positionM": {}`.
- **Comportamiento previsto.** El plan valida que sea lista (`array`) pero no fija la longitud ni el tipo de cada
  elemento. Si el loader accede con `operator[]` sobre un `const nlohmann::json` fuera de rango, es comportamiento
  indefinido (nlohmann solo hace un `assert`); con `.at()` lanza `out_of_range`, que **escapa sin ruta** si no se
  envuelve. Lo mismo aplicaría a cualquier futura lista de longitud fija.
- **Esperado.** `demo.json: emitters[0].positionM: debe ser una lista de 3 números`.
- **Cambio sugerido.** Tarea 14: lectura `position` en `JsonReader` que comprueba tamaño 3 y que cada elemento es
  número finito; tests `ParseMissionRejectsPositionWithWrongLength` y `ParseMissionRejectsNonNumericPosition` (para
  emisor y receptor). Revisar igual cada elemento de `valuesUs` y `frequenciesMHz` (`[1000, "1200"]`).

### A7 — Lambdas del planificador que capturan `this` o referencias: `Simulation` movible (Media)

- **Escenario.** El plan no dice si los Emit iniciales se programan en el constructor de `Simulation` o en `run()`,
  ni qué capturan las lambdas. Si se programan en el constructor capturando `this` (o `&emitters_[i]`,
  `&receiver_`), y luego se devuelve la `Simulation` por valor desde una función (por ejemplo en `runMission`), el
  objeto se mueve y las lambdas apuntan al original destruido → **uso tras liberación** (ASan lo detectaría en
  `ci-Debug`, pero ningún test construye y mueve una `Simulation`).
- **Matiz.** Mover el `std::vector<Emitter>` (de `Mission` a la `Simulation`) **no** invalida referencias a sus
  elementos: el vector movido conserva el mismo bloque de memoria. El peligro es `this` y los miembros que no son
  elementos de un vector (`receiver_`, `channel_`, `scheduler_`).
- **Esperado.** Imposible de usar mal.
- **Cambio sugerido.** Tarea 12: fijar en el plan que (1) los eventos iniciales se programan en `run()`, (2) las
  lambdas capturan `this` y el **índice** del emisor, y el pulso por valor, (3) `Simulation` tiene copia y movimiento
  `= delete` (encaja con la decisión 2: clase de comportamiento). Así un mal uso no compila.

### A8 — Errores del sistema de ficheros que escapan como excepciones sin ruta (Media)

- **Escenario.** Variantes que el plan no prueba (solo prueba carpeta inexistente):
  - fichero de misión inexistente (`ews no_existe.json out.csv`);
  - `catalogDir` que apunta a un **fichero** y no a una carpeta;
  - un `*.json` del catálogo sin permiso de lectura, un enlace simbólico roto o una **carpeta** llamada `X.json`;
  - `SearchRadar_X.JSON` (mayúsculas): el filtro `*.json` lo ignora en silencio y luego la misión falla con "el
    tipo no existe", lo que despista;
  - catálogo vacío (carpeta sin `.json`), o `"catalogDir": "."` o `""`: se cargaría la **propia misión** como un
    tipo del catálogo y saldrían errores de "falta la clave type" en un fichero que no es de catálogo.
- **Comportamiento previsto.** `std::filesystem::directory_iterator` y `file_size`/lectura lanzan
  `std::filesystem::filesystem_error`; si no se capturan, `main` (que solo captura `ConfigError`) termina con
  `std::terminate` y sin mensaje útil.
- **Esperado.** `ConfigError` con el fichero y un mensaje en español; código de salida 1.
- **Cambio sugerido.** Tarea 13/14: envolver todo acceso a disco en `loadCatalog`/`loadMission` y convertirlo en
  `ConfigError`; filtrar solo ficheros regulares; decidir y documentar si la extensión se compara sin distinguir
  mayúsculas (recomiendo aceptar solo `.json` exacto pero **avisar** como error de los `.JSON`); error explícito
  `el catálogo '<dir>' no contiene ningún fichero .json`. Tests `LoadMissionRejectsMissingFile`,
  `LoadCatalogRejectsEmptyDirectory`, `LoadCatalogRejectsCatalogDirThatIsAFile`. Como red de seguridad, que `main`
  capture también `std::exception` (código distinto, p. ej. 4).

### A9 — El CSV puede escribir `360.0000` y `-0.0000` (Baja)

- **Escenario.** AoA con azimut `float` 359.99997 (el mayor `float` por debajo de 360 es 359.9999695): está en
  [0, 360), pero `{:.4f}` lo escribe como **`360.0000`**. Del mismo modo, una elevación de −0.00003° sale
  `-0.0000` y una potencia de −0.004 dBm, `-0.00`.
- **Comportamiento previsto.** La salida es reproducible, pero viola el rango documentado del azimut y un
  procesador posterior que valide `az < 360` lo rechazaría; `-0.0000` ensucia los diffs del golden.
- **Esperado.** Azimut siempre en [0, 360) también en el texto.
- **Cambio sugerido.** Tarea 9: al formatear, si el valor redondeado es 360, escribir 0; normalizar `-0` a `0`
  tras redondear. Tests `WriteWrapsAzimuthRoundedTo360` y `WriteDoesNotPrintNegativeZero`.

### A10 — Rangos angulares y anchos sin validar (Baja)

- **Escenario.** `"elevationDeg": 95`, `"pointingElevationDeg": 200`, `"widthDeg": 400`, `"beamwidthAzDeg": 720`.
- **Comportamiento previsto.** No hay crash: `AngleOfArrival` pliega 95° a 85° y gira el azimut 180°, lo que
  físicamente es la misma dirección, así que Δaz/Δel salen coherentes (lo comprobé: el plegado no rompe el wrap de
  Δaz). Pero casi seguro es una errata del usuario, y un sector de 400° recorre dos veces parte del círculo.
- **Cambio sugerido.** Tarea 13/14: elevaciones en [−90, 90]; `widthDeg` en (0, 360]; anchos de haz en (0, 360].
  Mensaje `debe estar entre <a> y <b>`. Un test por regla. Los azimuts (`initialAzimuthDeg`, `centerAzimuthDeg`)
  pueden quedar libres porque se normalizan.

### A11 — Pulsos solapados: en el cambio de segmento y en el receptor (Baja, aclaración)

- **Escenario 1.** Modo con PRI 1 ms y PW 1 µs; segmento A de 2,0001 ms seguido de B. Pulsos de A en 0, 1, 2 ms; el
  primero de B en 2,0001 ms. El mismo emisor emite dos pulsos separados 0,1 µs, **menos que su PW**: se solapan.
- **Escenario 2.** Dos emisores cuyos pulsos llegan al receptor solapados en el tiempo: el receptor genera dos PDW
  limpios, como si tuviera canales infinitos.
- **Comportamiento previsto.** Es lo que dicen la spec y el plan, pero ninguno lo declara, y la regla 3 ("PW < PRI")
  da a entender que el emisor nunca se solapa consigo mismo.
- **Cambio sugerido.** Spec §4 y §1 "Fuera de alcance": añadir "solapamiento de pulsos en el receptor (bloqueo,
  pulsos fusionados)" y aclarar que en un cambio de segmento el hueco puede ser menor que la PRI e incluso que la
  PW. No requiere código.

### A12 — Claves duplicadas en un objeto JSON se aceptan en silencio (Baja)

- **Escenario.** `{"kind": "fixed", "valueUs": 1000, "valueUs": 2000}`.
- **Comportamiento previsto.** nlohmann se queda con el último valor sin avisar. Va contra el espíritu de la regla 1
  ("una errata no debe ignorarse en silencio").
- **Cambio sugerido.** Tarea 13: detectar duplicados con el *parser callback* de `nlohmann::json::parse` (evento
  `key`) o aceptarlo y documentarlo. Si se detecta, test `ParseCatalogRejectsDuplicateKey`.

### A13 — Distancias muy pequeñas: FSPL negativa y retardo 0 ns (Baja)

- **Escenario.** Emisor a 0,005 m del receptor con f = 3 GHz, o a 10 m con `frequencyMHz: 0.000001` (1 Hz).
- **Comportamiento previsto.** La FSPL es negativa cuando `d < λ/(4π)` (0,008 m a 3 GHz; 23,9 m a 1 MHz) → `P_rx >
  P_tx + G_tx`, físicamente imposible (campo cercano). Con `d < 0,15 m` el retardo es 0 ns: la llegada coincide con
  la emisión; el planificador lo admite (`iAt == now()` no lanza) y el orden sigue siendo determinista, así que esto
  último no es un fallo. La regla 6 compara `d == 0` exacto: `d = 1e-12` pasa.
- **Cambio sugerido.** Spec §5 regla 6: sustituir "d = 0" por "d ≥ d_min" (p. ej. 1 m, o mejor `d > λ/(4π)` para
  cada frecuencia del modo) y documentar el modelo como válido solo en campo lejano. Test en la Tarea 14.

### A14 — Casos de calendario sin test, aunque el diseño probablemente los resiste (Baja)

- **Escenario.** (a) emisor cuyo calendario es solo `off`; (b) `startS ≥ durationS`; (c) `"schedule": []`;
  (d) `"emitters": []`; (e) el calendario termina antes de `durationS` (¿el emisor se calla o repite el
  calendario?).
- **Comportamiento previsto.** (a) y (b): `next()` debe devolver `nullopt` sin bucles; con la máquina de estados del
  plan, termina porque la lista de segmentos es finita, pero es pieza 👤 y no hay test. (c) y (d): "listas no vacías"
  (regla 2) es ambiguo: ¿se aplica a `schedule` y `emitters`? (e): la spec no dice que el calendario se repita, así
  que se calla, pero un usuario podría esperar lo contrario.
- **Cambio sugerido.** Tarea 7: tests `NextReturnsNulloptWhenAllSegmentsOff` y `NextReturnsNulloptWhenStartAfterEnd`.
  Tarea 14: decidir y probar `schedule` vacío (recomiendo error) y `emitters` vacío (recomiendo aceptarlo: CSV con
  solo la cabecera, útil para pruebas). Spec §5: una frase: "al terminar el último segmento el emisor queda en
  silencio".

### A15 — El golden file depende de la libm (Baja)

- **Escenario.** Compilar en otra plataforma o con otra versión de glibc/libstdc++.
- **Comportamiento previsto.** `atan2`, `log10` y `std::format` no garantizan el mismo último bit en todas las
  plataformas; un valor cerca de una frontera de redondeo de `{:.4f}` puede cambiar un dígito y romper la
  comparación byte a byte aunque el código sea correcto.
- **Cambio sugerido.** Tarea 15: dejar escrito que el golden es válido para la toolchain del CI; si alguna vez
  falla por un dígito en la última cifra, comparar columna a columna con tolerancia en vez de regenerar a ciegas.

## Descartados (ataques probados que el diseño resiste)

- **Llegadas en el pasado.** El retardo es `round(d/c) ≥ 0`, así que `t_a ≥ t_e = now()`; `schedule` solo rechaza
  `< now()`. Con posiciones fijas no hay forma de violarlo.
- **Eventos simultáneos.** Emit y Arrival en el mismo ns, o dos llegadas en el mismo ns de emisores distintos: el
  orden lo da la secuencia de inserción, que depende solo del orden de los emisores en la misión y del orden de los
  eventos previos. Determinista. Un Emit nunca escribe, así que su orden relativo con un Arrival no cambia la salida.
- **Retardo 0 ns** (d < 0,15 m): ver A13; el planificador lo admite y el orden sigue siendo correcto.
- **Segmento más corto que una PRI.** Sale un pulso en el inicio y el siguiente instante cae fuera → se pasa al
  siguiente segmento. Lo cubren `NextResetsStateOnModeChange` y `NextSkipsOffSegment` (comprobé a mano las
  secuencias 5, 6 | 7.5, 8.5, 10.5 y 5, 6, 7, 9.5, 10.5 ms).
- **PRI enorme** (mayor que la misión): un solo pulso y luego `nullopt`; con los límites de A2, sin desbordamiento.
- **`sliding` con un paso que no divide el rango.** Cubierto por `SlidingPri{100, 125, 10}`.
- **Listas de un solo elemento** en `stagger`, `dwellSwitch` y `list`: el índice cíclico `i % 1` funciona.
- **Errores de redondeo acumulados en el calendario.** Cada duración se convierte a `Time` por separado y se suma
  como entero (las 55 s de `ParseMissionChainsSegmentsFromStart` son exactas).
- **Elevación plegada por `AngleOfArrival`.** Plegar (az, 95°) a (az+180°, 85°) es la misma dirección física, y
  `wrapOffsetDeg` absorbe el giro de 180° en Δaz. No da resultados incoherentes (solo es una probable errata, A10).
- **Precisión `float` del AoA.** Cerca de 360° la resolución del `float` es ≈ 3·10⁻⁵°, muy por debajo de cualquier
  ancho de haz realista y de la precisión `{:.4f}` del CSV (salvo el caso del redondeo a 360, A9).
- **`sidelobeLevelDb = 0`, ganancias negativas, anchos de haz muy pequeños.** `max(...)` da el suelo (antena
  isotrópica en el primer caso); con θ diminuto el cociente puede dar `inf` y `G − inf = −inf`, que `max` convierte
  en el suelo. Sin NaN mientras Δaz sea finito.
- **Vida de los prototipos tras destruir el catálogo.** `Segment` y `EmittedPulse` guardan `shared_ptr`, así que los
  modos, scans y antenas sobreviven a `Catalog` aunque `loadMission` lo destruya al salir.
- **Mover `Emitter` dentro del `vector` del `Mission`.** Al mover un `Emitter` se mueve su `vector<Segment>`, que
  conserva su bloque de memoria: un índice o puntero interno al segmento activo sigue valiendo. (Recomiendo de todos
  modos guardar un índice, no un puntero.)
- **Números enteros frente a flotantes** en claves reales (`"peakPowerDbm": 90`): `get<double>()` acepta enteros y
  el ejemplo de la spec ya lo prueba en `ParseCatalogBuildsModes`. El problema es el sentido contrario (A4).
- **NaN literal en el JSON.** JSON estándar no admite `NaN` ni `Infinity`; nlohmann lo rechaza como JSON mal formado
  (cubierto por `ParseCatalogRejectsMalformedJson`). La vía real de entrada de no finitos es `1e400` (A2).
- **Ids con caracteres raros en el CSV.** La decisión 4 del plan (`[A-Za-z0-9_-]+`) impide comas, comillas y saltos
  de línea; `intrapulseModulation` sale de una tabla fija.
- **`catalogDir` relativo cuando la misión se pasa sin carpeta** (`ews demo.json …`): `parent_path()` vacío más
  `../catalog` da una ruta relativa al directorio actual, que es lo correcto.
- **Pulsos en vuelo tras `durationS`.** Aparecen con `toaNs > durationS`; es el comportamiento pedido (spec §4
  paso 4) y está probado (`RunDeliversPulsesInFlightAfterEnd`).

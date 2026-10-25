# Revisión 4 del plan del simulador: C++23, build y convenciones

Fecha: 2026-10-24
Plan revisado: `docs/superpowers/plans/2026-10-24-simulator.md`
Enfoque: ¿compila y funciona cada tarea de verdad en este repo (CMake propio, `-Werror`, sanitizers, clang-tidy) y respeta
`.claude/rules/how_to_write_a_class.md`?

Método: lectura de `.cmake/*.cmake`, `CMakeLists.txt`, `CMakePresets.json`, `.github/workflows/*.yml`, `.clang-tidy`
y `src/SigInt/PulseDescriptors/`. Las dudas de compilación se comprobaron con ficheros sueltos en el scratchpad
(`g++ 15.2 -std=c++23 -Wall -Wextra -Wpedantic -Wshadow -Wconversion [-Werror] [-fsanitize=address,undefined]`, los
flags reales de `ci-Debug` según `compile_commands.json`), con GoogleTest 1.17 del `_deps` ya descargado y con el
tarball real de nlohmann/json 3.12.0. No se ha tocado el repo ni `.build/`.

## Resumen y veredicto

**Veredicto: el plan es ejecutable con el sistema de build actual sin tocar `.cmake/`, pero tiene varios fallos que
romperán la compilación con `-Werror` o el lint, y dos trampas de corrección.** La estructura (librería `Simulator` con
componentes `Geometry`, `Emitter`, `Channel`, `Receiver`, `Engine`, `Config`, `Runner`), los comandos `ctest -R`, la
ruta del binario, `PRIVATE_EXTERNAL` y `__FILE__` son correctos. Lo que falla es C++ de detalle que el plan no anticipa:

- **Alta (6):** agregados sin `{}` → `-Wmissing-field-initializers`; `double → float` al construir `AngleOfArrival` y en
  los literales de los tests; `to_string(IntrapulseModulation)` ocultado por el `to_string` miembro de
  `PulseDescriptorWords`; un `~Emitter()` declarado quita el movimiento y rompe `Mission`/`Simulation`; el patrón
  `top()/pop()/action()` de `priority_queue`; `operator[]` const de nlohmann aborta (crash) con una clave ausente.
- **Media (9)**, **Baja (6)**. Total: 21 hallazgos.

Ninguna es crítica en el sentido de "hay que rediseñar": todas se arreglan con una línea en el plan.

---

## Hallazgos

### C1 — Alta — Agregados con miembros sin `{}` → `-Wmissing-field-initializers` con `-Werror`

- **Tarea/paso:** 5 (`ScanSpec`), 7 (`EmitterMode`, `Segment`, `EmittedPulse`), 8 (`IncidentPulse`), 9 (`GroundTruth`),
  12 (`ReceiverSpec`, `Mission`), 13 (`EmitterType`); todos los tests que los construyen.
- **Descripción:** la decisión 2 dice que los mensajes internos se inicializan con designated initializers. GCC (con
  `-Wextra`) avisa por **cada miembro omitido que no tenga inicializador por defecto**. Los miembros con `{}` no avisan;
  los que el plan declara sin llaves (`std::string emitterId;`, `Position emitterPosition;`,
  `sigint::AngleOfArrival beamDirection;`, `std::shared_ptr<...> antenna;`, `std::unique_ptr<...> pri;`,
  `ScanSpec scan;`, `ReceiverSpec receiver;`, `std::vector<Emitter> emitters;`…) sí. En los tests es lo normal omitir
  campos (p. ej. `EmittedPulse{.emitterId = "E1", .emissionTime = 5ms}`), así que la compilación falla en `ci-Debug`.
- **Evidencia:** prueba en scratchpad (`t3_agg.cpp`):
  `warning: missing initializer for member 'EmittedPulse::modeId' [-Wmissing-field-initializers]` (también
  `emitterPosition`, `beamDirection`, `antenna`, `EmitterMode::antenna`); los campos con `{}` omitidos
  (`frequencyHz`, `peakPowerDbm`) no generan aviso. Plan, líneas 341-361, 412-416, 453-456, 564-565, 613.
- **Cambio sugerido:** en la decisión 2, "todo campo de un agregado lleva `{}`" (es lo que ya pide R7: "Siempre
  inicializados con llaves"). Corregir los bloques de interfaz del plan para que todos los campos lo lleven. Recordar
  también que los designated initializers tienen que ir **en orden de declaración** (en C++ es error, no aviso).

### C2 — Alta — Conversiones `double → float` (`-Wfloat-conversion`, incluido en `-Wconversion`)

- **Tarea/paso:** 1 (`directionFromTo`), 5 (scans y sus tests), 7 (`beamDirection`), 8 (`PropagateWrapsBeamOffset`),
  10 (`amplitudeDbm_`, AoA medido), 13-14 (loaders), y los tests de todas ellas.
- **Descripción:** `AngleOfArrival(const float&, const float&)` y `PulseDescriptorWords::amplitudeDbm_` son `float`;
  la geometría y las potencias son `double`. Tres formas de caer:
  1. Código: `return sigint::AngleOfArrival(azDeg, elDeg);` con `double` → aviso → error.
  2. Literales en los tests: `FixedScan{{216.87, 0}}` (Tarea 5, paso 1) avisa aunque sea constante:
     `changes value from '2.1687e+2' to '2.16869995e+2f'`.
  3. `EXPECT_FLOAT_EQ(aoa.get_azimuthDeg(), 36.87)`: el literal `double` se convierte a `float` en tu código (no en la
     cabecera de gtest) y también avisa. `EXPECT_NEAR` no avisa.
- **Evidencia:** scratchpad `t1_aoa.cpp` y `t4.cpp` (tres avisos `-Wfloat-conversion`). El test canónico ya lo
  esquiva usando `45.5f` (`src/SigInt/PulseDescriptors/tests/ut_AngleOfArrival.cpp:43`).
- **Cambio sugerido:** añadir a Global Constraints: "la conversión a `float` se hace solo con
  `static_cast<float>(…)` en el punto de construcción del `AngleOfArrival`/PDW (Geometry, scans, Receiver); en los
  tests, literales `float` con sufijo `f` o `EXPECT_NEAR`". Clang-tidy `bugprone-narrowing-conversions` (activo en
  `lint`) exige lo mismo.

### C3 — Alta — `to_string(mod)` dentro de `PulseDescriptorWords::to_string` no compila

- **Tarea/paso:** 2, paso 3.
- **Descripción:** dentro de una función miembro, la búsqueda no cualificada de `to_string` encuentra primero el
  miembro `PulseDescriptorWords::to_string(void) const` y **se detiene**; además, cuando la búsqueda ordinaria
  encuentra un miembro de clase, la ADL se desactiva. Así que `std::format("…{}", to_string(this->get_intrapulseModulation()))`
  da "no matching function". Es un error que desconcierta mucho si no se conoce la regla.
- **Evidencia:** scratchpad `t4.cpp`: `error: no matching function for call to 'sigint::Pdw::to_string(const sigint::IntrapulseModulation&) const'`.
- **Cambio sugerido:** indicar en la Tarea 2 que se llame cualificado: `sigint::to_string(...)`. (Fuera de la clase,
  p. ej. en `CsvPulseRecordWriter`, la ADL sí funciona.)

### C4 — Alta — Un destructor declarado en `Emitter` elimina el constructor de movimiento

- **Tarea/paso:** 7 (`Emitter`), 12 (`Mission`, `Simulation(Mission iMission, …)`), 14 (`parseMission` devuelve
  `Mission`).
- **Descripción:** el plan dice "`Emitter` es movible y no copiable (tiene `unique_ptr`)", pero la plantilla de clase
  (R5 sección `DESTRUCTORS`, R8 `~C();`) lleva a declarar `~Emitter();`. En C++, **declarar el destructor suprime el
  movimiento implícito**; como la copia ya está borrada por el `unique_ptr`, `Emitter` deja de ser movible:
  `std::vector<Emitter>::emplace_back`, mover `Mission` y pasarla por valor a `Simulation` no compilan. Lo mismo
  aplicaría a cualquier clase de comportamiento con `unique_ptr` y destructor declarado.
- **Evidencia:** scratchpad `t3_agg.cpp`: `error: use of deleted function 'Emitter::Emitter(const Emitter&)'` al hacer
  `emplace_back` y `Mission m2 = std::move(m)`.
- **Cambio sugerido:** en la decisión 2, para las clases de comportamiento que se guardan en contenedores o se mueven:
  declarar explícitamente `Emitter(Emitter&&) noexcept = default;`, `Emitter& operator=(Emitter&&) noexcept = default;`
  y `= delete` las de copia (en `CONSTRUCTORS`/`OPERATORS`), o no declarar destructor. Es un buen momento para que el
  usuario aprenda la "regla de cero/cinco".

### C5 — Alta — `EventScheduler::runAll`: orden `top()`/`pop()`/acción y copia del `std::function`

- **Tarea/paso:** 11, paso 3 (pieza 👤), con consecuencias en 12.
- **Descripción:** `std::priority_queue::top()` devuelve `const&`. Dos trampas:
  1. Si se ejecuta `q.top().action()` y después `q.pop()`, la acción programa eventos nuevos (`push`), que reordenan el
     heap y pueden **realocar el vector**: la referencia queda colgando (UB, ASan lo verá) y el `pop()` posterior quita
     otro evento. Hay que sacar el evento, hacer `pop()`, actualizar `now_` y **después** ejecutar.
  2. Sacarlo con `auto ev = q.top();` **copia** el `std::function` y con él el `IncidentPulse` capturado (strings,
     `shared_ptr`) en cada evento. Y clang-tidy `performance-unnecessary-copy-initialization` (activo en `lint`) puede
     sugerir convertirlo en referencia… lo que reintroduce la trampa 1.
- **Evidencia:** plan, línea 536 ("Cola: `std::priority_queue` de `{Time at; std::uint64_t sequence; std::function<void()> action;}`");
  `.clang-tidy` (`performance-*`, `WarningsAsErrors: "*"`).
- **Cambio sugerido:** documentar en la Tarea 11 el patrón: `Event ev = std::move(const_cast<Event&>(q.top())); q.pop();
  now_ = ev.at; ev.action();` (el `const_cast` es seguro porque se hace `pop()` justo después), o usar un
  `std::vector<Event>` con `std::push_heap`/`std::pop_heap` y mover desde `back()`. Añadir un test
  `RunAllExecutesEventsScheduledDuringRun` con varias inserciones dentro de la acción (fuerza realocación con ASan).

### C6 — Alta — `operator[]` const de nlohmann con clave ausente aborta (no lanza)

- **Tarea/paso:** 13 (`JsonReader`, 👤), 14; Review Focus 5 ("nunca … un crash").
- **Descripción:** el plan dice que se envuelven "`parse`, `get<T>`" porque pueden lanzar, pero no avisa de que
  `const json::operator[](key)` con una clave inexistente **no lanza: es un `assert`** (abort en Debug, UB en Release).
  `JsonReader` trabaja naturalmente con `const json&`, así que es fácil caer.
- **Evidencia:** scratchpad `t7.cpp`, nlohmann 3.12.0: `json.hpp:2174: ... operator[](...) const: Assertion
  'it != m_data.m_value.object->end()' failed.` → `Aborted`.
- **Cambio sugerido:** en la Tarea 13, "el acceso a claves se hace solo con `find()`/`contains()` (o `at()` dentro del
  `try`); `operator[]` prohibido en `JsonReader`". Comprobar `is_object()` antes de buscar claves (en un no-objeto
  `find` devuelve `end()`, pero `items()` se comporta distinto).

### C7 — Media — Fixture R12 con puntero llamado como la clase → `-Wshadow` en los tests

- **Tarea/paso:** todos los `ut_*.cpp` de clases de comportamiento (3-12, 15).
- **Descripción:** R12 manda un miembro `Emitter* emitter;` en el fixture. Los tests de comportamiento necesitan
  objetos configurados de forma distinta en cada test y lo natural es escribir `Emitter emitter{…};` dentro del
  `TEST_F`. El cuerpo del test es un método de una clase derivada del fixture, así que la variable local **oculta al
  miembro** y GCC avisa (error con `-Werror`).
- **Evidencia:** scratchpad `t6.cpp`: `warning: declaration of 'emitter' shadows a member of 'EmitterTest_A_Test' [-Wshadow]`.
  El test canónico lo esquiva con otro nombre (`AngleOfArrival aoa(...)`, `ut_AngleOfArrival.cpp:43`).
- **Cambio sugerido:** decir en la decisión 2 cómo se aplica R12 a clases sin constructor por defecto: el fixture
  construye en `SetUp` un objeto "típico" con argumentos (p. ej. `Receiver` con un `RecordingWriter` miembro del
  fixture) y los objetos locales de cada test usan otro nombre (`custom`, `sut`…). Para los módulos de funciones libres
  (`Units`, `Geometry`, `Propagation`, loaders, `runMission`) no hay clase: indicar si se usa un fixture vacío o `TEST`.

### C8 — Media — División de `std::chrono::duration` entre sí es **entera**

- **Tarea/paso:** 5 (`CircularScan`, `SectorScan` 👤: "`phase = (t mod T) / T`").
- **Descripción:** con `Time = nanoseconds`, `(t % T) / T` devuelve un `long` (cociente entero), es decir **0** para
  toda `t < T`. Si se asigna a `double` sin cast, `-Wconversion` avisa (bien); si el usuario lo "arregla" con
  `static_cast<double>((t % T) / T)`, el aviso desaparece y el scan queda congelado en el ángulo inicial.
- **Evidencia:** plan, línea 285; scratchpad `t2_conv.cpp` (las variantes correctas compilan limpias).
- **Cambio sugerido:** escribir en la Tarea 5 la forma recomendada:
  `std::chrono::duration<double>(t % T) / T` (o `static_cast<double>((t % T).count()) / static_cast<double>(T.count())`).
  Los tests de la Tarea 5 ya lo detectarían, pero conviene explicarlo antes porque es pieza 👤.

### C9 — Media — Conversiones enteras: `int64 → double`, `size_t → uint32_t` y lo que añade clang-18

- **Tarea/paso:** 1 (`timeToSeconds`, `timeToMicroseconds`), 3 (`DwellSwitchPri`), 4 (`ListRf`), 9 (formato), 12-14.
- **Descripción:**
  - `t.count() / 1e9` → `long → double` avisa con GCC `-Wconversion`.
  - Un índice `std::uint32_t idx_` actualizado con `(idx_ + 1) % values_.size()` → `size_t → uint32_t` avisa.
  - La CI compila también con **clang-18** (`.github/workflows/ci.yml:35`), cuyo `-Wconversion` incluye
    `-Wsign-conversion` y `-Wshorten-64-to-32`: `int`/`uint32_t` usados como índice de `std::vector`, restas
    `size() - 1`, etc. GCC local no los ve, así que "compila sin avisos en `ci-Debug`" (Global Constraints) no basta.
- **Evidencia:** scratchpad `t2_conv.cpp`: `conversion from '...::rep' {aka 'long int'} to 'double' may change value`
  y `conversion from '...::size_type' {aka 'long unsigned int'} to 'uint32_t' may change value`.
- **Cambio sugerido:** `std::chrono::duration<double>(t).count()` para las conversiones a segundos/µs; índices como
  `std::size_t` y solo los parámetros de configuración (`iPulsesPerDwell`, `iPulsesPerHop`) como `uint32_t`, comparados
  contra un contador del mismo tipo. Añadir a "Comandos" una compilación con clang
  (`CXX=clang++ cmake --preset ci-Debug -B .build/ci-Debug-clang` o similar) o, como mínimo, avisar de que la CI la hará.

### C10 — Media — `Catalog::find(std::string_view)` sobre `std::map<std::string, …>` no compila

- **Tarea/paso:** 13 (`Catalog`), 14 (búsqueda de modos si se hace con `string_view`).
- **Descripción:** `std::map<std::string, T>::find` solo acepta `string_view` si el comparador es transparente
  (`std::less<>`). Con el `std::less<std::string>` por defecto, falla.
- **Evidencia:** scratchpad `t4.cpp`: `no type named 'type' in 'struct std::__has_is_transparent<std::less<std::string>, std::string_view>'`.
- **Cambio sugerido:** fijar en el plan `std::map<std::string, EmitterType, std::less<>>` (y lo mismo en
  `EmitterType::modes` si se busca con `string_view`). Buen tema para explicar "heterogeneous lookup".

### C11 — Media — Lectura de enteros desde JSON: `get<std::uint32_t>()` trunca y da la vuelta

- **Tarea/paso:** 13 (`pulsesPerDwell`, `pulsesPerHop`, mensaje `debe ser >= 1`).
- **Descripción:** nlohmann convierte con `static_cast`: `2.7` → `2` y `-1` → `4294967295`, sin excepción. Si
  `JsonReader` ofrece `number()` que devuelve `double` y luego se convierte, o usa `get<uint32_t>()` directamente, la
  validación `>= 1` no detecta ni el `-1` ni el `2.7`.
- **Evidencia:** scratchpad `t7.cpp`: salida `2 4294967295 0` (el `0` es `is_number_integer()` de `2.7`).
- **Cambio sugerido:** añadir a `JsonReader` una lectura `positiveInteger` que exija `is_number_integer()` (o
  `is_number_unsigned()`) y rango, con un mensaje nuevo (`debe ser un entero`), y su test
  (`ParseCatalogRejectsNonIntegerPulsesPerDwell`).

### C12 — Media — Detalles de la dependencia nlohmann/json en `dependencies.cmake`

- **Tarea/paso:** 13, paso "Modify `.cmake/dependencies.cmake`".
- **Descripción:**
  1. `dependencies.cmake` hoy solo tiene GoogleTest **dentro de** `if(PROJ_ENABLE_TESTS)`. nlohmann tiene que ir
     **fuera** del `if`: lo necesita la librería, no solo los tests (con `-DBUILD_TESTING=OFF`, en la release, no se
     descargaría y `proj_load_dependencies` daría `fatal: ... no es un target`).
  2. `FIND_PACKAGE nlohmann_json` hace que FetchContent pruebe antes `find_package(nlohmann_json)` **sin versión**: en
     una máquina con `nlohmann-json3-dev` del sistema (3.11.x) usará esa en silencio, no la 3.12.0 del plan.
     `proj_fetch_external` no admite pasar versión (`NAMES ${ARG_FIND_PACKAGE}`, `External.cmake`). Hoy no está
     instalada en esta máquina (`/usr/include/nlohmann` no existe).
  3. Las cabeceras de nlohmann **no** llegan como `-isystem` (`JSON_SystemInclude` es `OFF` por defecto, al contrario
     que gtest, que sí sale como `-isystem` en `compile_commands.json`), así que los `.cpp` de `Config` compilan
     `json.hpp` con `-Wshadow -Wconversion -Werror`. Con GCC 15 compila limpio (verificado); con clang-18 no lo he
     podido comprobar.
- **Evidencia:** `.cmake/dependencies.cmake` (todo dentro de `if(PROJ_ENABLE_TESTS)`); `.cmake/External.cmake`
  (`FIND_PACKAGE_ARGS NAMES`); tarball descargado: `json/CMakeLists.txt:50` (`JSON_SystemInclude ... OFF`).
- **Cambio sugerido:** escribir en el plan el bloque completo, fuera del `if`, y opcionalmente
  `set(JSON_SystemInclude ON CACHE BOOL "" FORCE)` antes de llamarlo (mismo patrón que `INSTALL_GTEST` en
  `proj_setup_googletest`). Sobre la versión: o quitar `FIND_PACKAGE` (descarga siempre la 3.12.0, lo más
  reproducible) o aceptar la del sistema y decirlo.

### C13 — Media — La decisión 2 no encaja del todo con R1-R12

- **Tarea/paso:** decisión 2 y Global Constraints; Tareas 3-6 (interfaces), 1/8/13-15 (funciones libres), 13
  (`Catalog`).
- **Descripción:**
  1. **R11 sin accesores.** La decisión aplica R11 a las clases de comportamiento pero les quita los accesores; R11
     obliga a leer atributos "siempre a través de los accesores". Es imposible cumplirla tal cual.
  2. **R7 con referencias.** `Receiver` guarda `PulseRecordWriter&`: un miembro referencia no admite `{}` (R7
     "Siempre inicializados con llaves") ni asignación.
  3. **Interfaces.** "Cada clase en 3 ficheros" (Global Constraints) choca con "interfaz, sin `.cpp` salvo el
     destructor" (Tarea 3) y con que no hay `ut_PriGenerator.cpp`. No está claro si el destructor va en `.cpp` o
     `= default` en el `.h`.
  4. **Módulos de funciones libres** (`Units`, `Geometry`, `Propagation`, `MissionLoader`, `MissionRunner`): R4, R5,
     R9 y R12 hablan de clases; la decisión no dice qué se aplica.
  5. **`Catalog`.** `Catalog.h` + `CatalogLoader.cpp` + `ut_CatalogLoader.cpp` rompe la regla de nombres, y
     `Catalog::add`/`find` no tienen test propio (R12: "todas las funciones públicas tienen al menos un test").
- **Evidencia:** `how_to_write_a_class.md` R7 (línea 182), R11 (líneas 253-262), R12 (líneas 289, 296); plan líneas
  23-31, 58-61, 190, 594-596.
- **Cambio sugerido:** completar la decisión 2: (a) en clases de comportamiento, R11 no aplica (acceso directo a
  `this->x_`) o se usan getters privados; (b) referencias guardadas como puntero `PulseRecordWriter* writer_ {}`
  (cumple R7 y deja la clase asignable); (c) interfaces: `.h` + `.cpp` con el destructor `= default`, sin `ut_`;
  (d) módulos de funciones libres: R1-R3, R6, R2 y tests con `TEST` (o fixture vacío); (e) separar `Catalog.h/.cpp`
  con `ut_Catalog.cpp` y dejar `CatalogLoader.h/.cpp` para `parseCatalog`/`loadCatalog`.

### C14 — Media — Ciclo de vida en `Simulation`: qué capturan las acciones

- **Tarea/paso:** 12.
- **Descripción:** las acciones de `EventScheduler` serán lambdas que capturan algo para llegar al emisor y al
  receptor. Es seguro si capturan `this` + índice del emisor y `Simulation` guarda `Mission`, `Receiver`,
  `PropagationChannel` y `EventScheduler` como miembros, porque `mission_.emitters` no cambia de tamaño durante
  `run()`. Es inseguro si capturan referencias a un `Mission`/vector local, o si `Simulation` se mueve o se copia
  después de programar eventos (el `this` capturado quedaría colgando). El plan no lo dice.
- **Evidencia:** plan, líneas 566-573.
- **Cambio sugerido:** en la Tarea 12: "las acciones capturan `[this, index]` (Emit) y `[this, incident = std::move(...)]`
  (Arrival); `Simulation` borra copia y movimiento (`= delete`)". `Receiver` con `PulseRecordWriter*` (C13) vive dentro
  de `Simulation`; el escritor lo posee `runMission`, que sobrevive a la simulación: correcto.

### C15 — Media — El lint (`clang-tidy` bugprone/performance, errores) no aparece en el plan

- **Tarea/paso:** todas; el workflow `lint.yml` revisa todo `src/` (también los tests).
- **Descripción:** checks que el plan va a activar casi seguro:
  - `bugprone-unchecked-optional-access`: `emitter.next()->emissionTime` en los tests (Tareas 7, 14) y los
    `std::optional` que devuelve `JsonReader`. No sé con seguridad si la versión 18 entiende `ASSERT_TRUE(p.has_value())`;
    hay que comprobarlo.
  - `performance-unnecessary-value-param`: los parámetros por valor (`std::string iId`, `std::vector<Segment>
    iSchedule`, `std::function<void()> iAction`, `Mission iMission`, `EmitterType iType`) tienen que moverse.
  - `bugprone-narrowing-conversions`: los mismos sitios que C2/C9, incluso donde GCC no avisa.
- **Evidencia:** `.clang-tidy` (`bugprone-*`, `performance-*`, `WarningsAsErrors: "*"`); `.cmake/Tools.cmake:30-53`.
- **Cambio sugerido:** añadir a "Comandos" `cmake --build --preset Release --target lint` (o el preset que use
  `lint.yml`) y pasarlo al cerrar cada tarea, o al menos en las 7, 11, 13 y 15.

### C16 — Baja — El prototipo `EmitterMode` se puede modificar a través de un `shared_ptr<const>`

- **Tarea/paso:** 7, 13.
- **Descripción:** `const EmitterMode` hace const el `unique_ptr`, no el objeto apuntado: `mode->pri->next()`
  compila y avanzaría el prototipo del catálogo, compartido por todos los emisores del mismo tipo. El diseño (clonar
  al entrar en el segmento) es correcto, pero nada lo impide.
- **Cambio sugerido:** `std::unique_ptr<const PriGenerator> pri {};` (igual `rf`, `pw`). `clone()` ya es `const` y
  la conversión `unique_ptr<FixedPri>` → `unique_ptr<const PriGenerator>` funciona en el designated initializer.

### C17 — Baja — Helpers con el mismo nombre en varios `ut_*.cpp` del mismo componente

- **Tarea/paso:** 3-7 (todos en `Emitter/tests`, un solo ejecutable), 13-14 (`Config/tests`).
- **Descripción:** cada componente genera **un** ejecutable con todos sus `ut_*.cpp` (`Tests.cmake`). Si dos ficheros
  definen en `namespace sim` una función `makeMode()` o una clase `RecordingWriter`/`TestMode` con métodos inline,
  la función da error de enlace; la clase es una violación ODR silenciosa. Pasará con el catálogo de ejemplo que
  comparten `ut_CatalogLoader.cpp` y `ut_MissionLoader.cpp`.
- **Cambio sugerido:** helpers de test en un `namespace {}` anónimo dentro de cada `ut_*.cpp`.

### C18 — Baja — Rendimiento por pulso (no merece la pena en la v1)

- **Tarea/paso:** 7, 8, 10, 11, 12.
- **Descripción:** por cada pulso: `EmittedPulse` copia `emitterId`/`modeId` del emisor; `IncidentPulse` copia el
  `EmittedPulse` entero (`propagate` recibe `const&` y lo guarda por valor); la lambda de Arrival lo vuelve a capturar;
  `std::function` reserva memoria en el heap porque la captura pasa de 16 bytes; `GroundTruth` copia otra vez los dos
  strings; y el `shared_ptr<const AntennaPattern>` hace incrementos/decrementos atómicos. Los ids cortos (≤ 15
  caracteres) caben en el SSO y no reservan memoria. Orden de magnitud: unos 500 000 pulsos en una misión de 120 s,
  con 4-5 reservas pequeñas cada uno: muy por debajo de un segundo. Los elementos de la `priority_queue` son pequeños
  (unos 48 bytes); el contenido grande va dentro del `std::function`.
- **Cambio sugerido:** nada en la v1. Si más adelante importa: mover en vez de copiar (`propagate(EmittedPulse&&)`,
  capturas con `std::move`), puntero crudo `const AntennaPattern*` (el modo lo mantiene vivo) y
  `std::move_only_function` (C++23, ya disponible en GCC 13).

### C19 — Baja — `now()` frente a la convención `get_`

- **Tarea/paso:** 11.
- **Descripción:** si `EventScheduler` guarda `Time now_ {}`, su getter según la convención del repo es `get_now()`.
  `empty()` es un cálculo, no un atributo, y puede quedarse así.
- **Cambio sugerido:** `get_now()` o un atributo con otro nombre (`currentTime_` → `get_currentTime()`).

### C20 — Baja — `main` solo captura `ConfigError`

- **Tarea/paso:** 15.
- **Descripción:** `std::filesystem::filesystem_error` (permisos al listar `catalogDir`), `std::bad_alloc` o una
  excepción de nlohmann que se escape del `JsonReader` terminarían en `std::terminate` sin mensaje.
  `bugprone-exception-escape` también mira `main`.
- **Cambio sugerido:** un `catch (const std::exception&)` final con un código de salida propio (p. ej. 4) y el
  `what()` en `stderr`.

### C21 — Baja — El golden file se compara byte a byte en 9 combinaciones de CI

- **Tarea/paso:** 15.
- **Descripción:** la referencia se genera con `ci-Debug` (GCC) y se compara en gcc-13, gcc-14 y clang-18 ×
  Debug/Release/RelWithDebInfo. Con `-std=c++23` (sin extensiones, así que GCC no contrae FMA), x86-64 sin `-march`
  y la misma glibc, debería salir idéntica. Pero un valor que caiga justo en la frontera de redondeo de `{:.2f}`/`{:.4f}`
  podría cambiar si algún día se añade `-march=native` o se compila en otra plataforma.
- **Cambio sugerido:** ninguno ahora; si falla en CI, mirar primero esto antes de "regenerar la referencia".

---

## Verificado sin problemas

- **Descubrimiento de librería y componentes.** `src/Simulator/` se descubre como librería (`Components.cmake`,
  `proj_discover_libraries`) y cada subcarpeta con `include/`, `src/` o `tests/` como componente. Se crea **un solo
  target** `ews_Simulator` (alias `ews::Simulator`) con las fuentes de todos los componentes (`BuildComponent.cmake`).
  Un componente con solo `include/` (solo interfaces) es válido: sus cabeceras entran en el `FILE_SET`. La librería
  solo sería `INTERFACE` si no tuviera ningún `.cpp` (no pasa desde la Tarea 1).
- **Tests.** Un ejecutable por componente, `ews_Simulator_<Componente>_tests`, enlazado a `ews::Simulator` y
  `GTest::gtest_main`, con `TEST_PREFIX "Simulator.<Componente>."` (`Tests.cmake`). El patrón
  `ctest --preset ci-Debug -R '^Simulator\.<Componente>\.'` es correcto y el test preset `ci-Debug` existe. `tests/data/`
  no molesta: el glob de tests no es recursivo y solo coge `.cpp`.
- **`ci-Debug`** = `Debug` (sanitizers ASan+UBSan) + `ci` (`PROJ_WARNINGS_AS_ERRORS=ON` → `-Werror`), confirmado en
  `compile_commands.json`. Flags reales: `-Wall -Wextra -Wpedantic -Wshadow -Wconversion`. **No** están activos
  `-Wfloat-equal`, `-Wold-style-cast`, `-Wnon-virtual-dtor` ni (en GCC) `-Wsign-conversion`, así que el `==` sobre
  `float`/`double` de R8 y los casts estilo C no rompen la compilación con GCC (ver C9 para clang).
- **Binario.** `add_executable(ews)` en el directorio raíz, sin `RUNTIME_OUTPUT_DIRECTORY` → `.build/ci-Debug/ews`
  (existe ya). Las rutas de la Tarea 15, pasos 4 y 7, son correctas.
- **Dependencias.** `src/Simulator/deps.cmake` con `proj_depends(LIBRARIES SigInt)` enlaza `ews::SigInt` como `PUBLIC`
  (los tests ven `AngleOfArrival.h`); `src/deps.cmake` con `LIBRARIES Simulator` arrastra SigInt de forma transitiva.
  `dependencies.cmake` se incluye antes de construir las librerías, así que `nlohmann_json::nlohmann_json` existe
  cuando `proj_load_dependencies` lo comprueba.
- **nlohmann/json.** La URL `…/v3.12.0/json.tar.xz` existe (114 KB), trae `CMakeLists.txt` que define el alias
  `nlohmann_json::nlohmann_json` (línea 117) y, como subproyecto, deja `JSON_BuildTests` y `JSON_Install` en `OFF`.
  `json.hpp` (multi-header y single-header) compila sin avisos con los flags del proyecto, `-Werror` y sanitizers en
  GCC 15; `parse(std::string_view)` funciona; el mensaje de error de parseo es el esperado
  (`[json.exception.parse_error.101] …`). `items()` recorre en orden alfabético (determinista).
- **`PRIVATE_EXTERNAL`.** En una librería estática, CMake propaga la dependencia privada solo como `$<LINK_ONLY:…>`:
  los tests de `Config` no reciben las cabeceras de nlohmann, pero no las necesitan (solo usan `Catalog.h`,
  `MissionLoader.h` y `ConfigError.h`). `src/Simulator/Config/src/JsonReader.h` es visible para todos los `.cpp` de la
  librería (cada `src/` es `PRIVATE include`) y no para los tests. El `grep` de la Tarea 13, paso 4, es una buena
  comprobación.
- **`__FILE__` en el test golden.** Ninja recibe rutas absolutas (`-c /home/.../ut_*.cpp` en `compile_commands.json`)
  y la CI usa ccache sin `base_dir` ni `-ffile-prefix-map`: `std::filesystem::path(__FILE__).parent_path() / "data"`
  funciona en local y en la CI.
- **Nombres de cabecera.** Todos los `include/` de la librería y de SigInt comparten un único espacio de nombres de
  includes (`<Units.h>`, `<Geometry.h>`…). Ninguno de los nombres del plan se repite ni choca con cabeceras del sistema.
- **`-Wshadow` y `distanceM`.** Que el campo `IncidentPulse::distanceM`/`GroundTruth::distanceM` se llame igual que
  la función libre `sim::distanceM` no genera aviso, ni siquiera con una variable local del mismo nombre (GCC no avisa
  cuando se oculta una función).
- **Polimorfismo.** Destructor virtual de la interfaz definido fuera de línea, `clone()` con
  `std::make_unique<FixedPri>(*this)` y conversión `unique_ptr<Derived>` → `unique_ptr<Base>` dentro de un designated
  initializer: compila sin avisos (no salta `-Wdeprecated-copy` por tener destructor declarado).
- **Tiempo.** `Time{std::llround(x * 1e9)}`: `long long` → `nanoseconds::rep` (`long`, 64 bits en LP64) no avisa.
  Enums con `std::uint8_t` cumplen `performance-enum-size`.
- **C++23 en la CI.** Todo lo que usa el plan (`std::format`, `std::optional`, designated initializers,
  `std::filesystem`) está en GCC 13, que es el compilador más antiguo de la matriz.
- **`Receiver` con `PulseRecordWriter`.** El escritor (y su `ostream`) los crea `runMission` y viven más que
  `Simulation`: la propiedad es correcta (el problema de la referencia es solo de convención, C13).

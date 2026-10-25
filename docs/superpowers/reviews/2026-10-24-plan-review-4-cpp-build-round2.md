# Revisión 4 (segunda ronda) del plan del simulador: C++23, build y convenciones

Fecha: 2026-10-24
Plan revisado: `docs/superpowers/plans/2026-10-24-simulator.md` (con la spec `docs/superpowers/specs/2026-10-24-simulator-design.md`)
Ronda anterior: `docs/superpowers/reviews/2026-10-24-plan-review-4-cpp-build.md` (C1–C21)

## Método

En lugar de probar solo ficheros sueltos, monté en el scratchpad una **copia del sistema de build del repo**
(`CMakeLists.txt`, `CMakePresets.json`, `.cmake/`, `.clang-tidy`, `.clang-format`, `src/SigInt/PulseDescriptors`,
`src/Dummy_Lib`) con el reparto nuevo y clases mínimas, pero con R8 completo, de cada patrón nuevo:

```
/tmp/claude-1000/-home-hfernandezs-develop-ews/bfa41cbf-50f4-4c97-b76e-d1394bb2f671/scratchpad/review4-round2/ews/
  src/SigInt/{PulseDescriptors,Geometry,Emission}      Units, Position, Geometry, PriGenerator (interfaz), FixedPri,
                                                       StaggerPri, EmitterMode (shared_ptr<const I>), IncidentPulse (distanceM_)
  src/Simulator/{Emitter,Engine,Receiver,Config,Runner} Emitter (unique_ptr<I> + shared_ptr<const I>), EventScheduler
                                                       (Event anidado privado, std::function), PulseRecordWriter (interfaz),
                                                       CsvPulseRecordWriter (std::ostream*), ConfigError (runtime_error),
                                                       Catalog (std::map<…, std::less<>>), JsonReader (src/, nlohmann),
                                                       CatalogLoader, MissionRunner
  src/Simulator/deps.cmake, src/deps.cmake, .cmake/dependencies.cmake con el bloque exacto de la Tarea 14
```

Con eso ejecuté los comandos del plan tal cual: `cmake --preset ci-Debug` + build + `ctest` (GCC 15.2, `-Werror`,
ASan+UBSan), `CXX=clang++-21 cmake --preset ci-Debug -B .build/ci-Debug-clang` (clang-18 no está instalado; sí
clang-21), una tercera build con clang y las **cabeceras de libstdc++ 13** (paquete `libstdc++-13-dev` descargado con
`apt-get download` y usado con `-nostdinc++`, que es la biblioteca que usan gcc-13 y clang-18 en `ubuntu-24.04`),
`-DBUILD_TESTING=OFF`, y el lint del plan (`cmake --preset Release -DPROJ_CLANG_TIDY=… && cmake --build --preset
Release --target lint`, clang-tidy 21.1.8). Los casos que deben fallar están en `…/review4-round2/st/st.cpp`
(compilados con g++ 15, clang++-21 y clang++-21 + libstdc++ 14). No he tocado el repo ni `.build/`.

## Resumen y veredicto

**Veredicto: el plan es ejecutable y el sistema de build lo soporta sin tocar `.cmake/`. Los 21 hallazgos de la
primera ronda están resueltos (C7 y C15 con matices). Pero la decisión 2 (R8 en todas las clases) trae tres problemas
nuevos de gravedad alta: dos rompen la CI o el lint sin que se note en local, y uno es un fallo de corrección
silencioso.** Ninguno obliga a rediseñar; todos se arreglan con unas líneas en la decisión 2 o en Global Constraints.

- **Alta (3):** `std::format` sobre `vector`/`map` compila en local (GCC 15) y falla en la CI (libstdc++ 13/14);
  `this->get_x()` dentro de un método no `const` llama al getter por valor (clona el `unique_ptr`, copia `Mission`):
  el estado no avanza y la simulación puede quedarse en bucle; el constructor de movimiento de toda clase derivada
  (`Base(std::move(iOther))` y luego `iOther.set_x()`) y el de `ConfigError` hacen fallar el lint.
- **Media (6):** uso tras mover en los tests de movimiento con objetos locales; `unchecked-optional-access` no entiende
  `ASSERT_TRUE(p.has_value())`; `EventScheduler::Event` choca con R5, R8 y R12; `ConfigError` (fixture marcado por
  `bugprone-throw-keyword-missing`; setters públicos de `message_`); `format-check` no aparece en el plan y la plantilla
  de fixture de R12 no pasa `.clang-format`; `to_string` de atributos que `std::format` no sabe formatear.
- **Baja (6).** Total: 15 hallazgos.

---

## Estado de C1–C21

| Id | Estado | Comentario |
| --- | --- | --- |
| C1 agregados sin `{}` | Resuelto (ya no aplica) | Ya no hay agregados ni designated initializers: todo son clases R7 con `{}`. |
| C2 `double → float` | Resuelto | Global Constraints, "Conversiones numéricas". `directionFromTo` con `static_cast<float>` compila limpio. |
| C3 lookup de `to_string` | Resuelto | Tarea 2, "Trampa de lookup". Reaparece en `ScanSpec` (ver R2-C9). |
| C4 destructor quita el movimiento | Resuelto | R8 declara el movimiento `noexcept`; `std::vector<Emitter>` crece moviendo (test `VectorOfEmittersGrows`). |
| C5 `runAll` | Resuelto | `push_heap`/`pop_heap`, mover desde `back()`, `pop_back()` y después ejecutar. Con 100 eventos programados dentro de una acción pasa con ASan. |
| C6 `operator[]` const de nlohmann | Resuelto | Tarea 14, "Acceso a claves solo con `find()`/`contains()`". |
| C7 `-Wshadow` en fixtures | Resuelto, con matiz | Nombres `custom`/`other`. Pero mover desde un local hace saltar el lint: R2-C4. |
| C8 división entera de `duration` | Resuelto | Tarea 5 lo explica. |
| C9 conversiones enteras y clang | Resuelto | Índices `size_t`, `duration<double>`, comando con clang. Detalles del comando en R2-C13. |
| C10 `std::less<>` | Resuelto | `Catalog::find(std::string_view)` compila y funciona. |
| C11 enteros desde JSON | Resuelto | `positiveInteger` con `is_number_integer()` antes de convertir. |
| C12 nlohmann en `dependencies.cmake` | Resuelto | Verificado: fuera del `if`, sin `FIND_PACKAGE`, sale como `-isystem …/_deps/nlohmann_json-src/include` en `compile_commands.json` y también configura y compila con `-DBUILD_TESTING=OFF`. |
| C13 decisión 2 frente a R1–R12 | Resuelto | Punteros en vez de referencias, interfaces con `.cpp` y sin `ut_`, módulos de funciones libres, `Catalog` separado de `CatalogLoader`. |
| C14 capturas de `Simulation` | Resuelto | `[this, index]`, `[this, incident = std::move(incident)]`, copia/movimiento `= delete`. La init-capture con el mismo nombre no avisa con `-Wshadow` (GCC 15 y clang 21). |
| C15 lint | Resuelto, con matiz | Comando en "Comandos" y en las Tareas 8, 12, 14 y 16. Falta `format-check` (R2-C8). |
| C16 prototipo modificable | Resuelto | `shared_ptr<const I>`: `mode.get_pri()->next()` no compila; `clone()` sí. |
| C17 helpers con el mismo nombre | Resuelto | `namespace {}` en cada `ut_*.cpp`. |
| C18 rendimiento | Sin cambio (correcto) | Ahora el riesgo real de rendimiento es otro: R2-C2. |
| C19 `now()` | Resuelto | `currentTimeNs_` → `get_currentTimeNs()`. |
| C20 `main` solo captura `ConfigError` | Resuelto | Código 4 para `std::exception`. |
| C21 golden en 9 combinaciones | Resuelto | Nota en la Tarea 16. |

---

## Hallazgos nuevos

### R2-C1 — Alta — `std::format` de `vector`/`map` compila en local y rompe la CI

- **Tarea/paso:** decisión 2 + R10 (`to_string` con todos los atributos); Tareas 3 (`StaggerPri`, `DwellSwitchPri`),
  4 (`ListRf`), 8 (`Emitter::schedule_`), 13 (`Mission::emitters_`), 14 (`ConfigError::errors_`,
  `EmitterType::modes_`, `Catalog::types_`), 12 (`EventScheduler::events_`, aunque el plan ya dice que muestra el
  número de eventos).
- **Descripción:** R10 pide `std::format` con todos los atributos. Lo natural es `std::format("[Values: {}]",
  this->get_valuesNs())`. El formateo de rangos (P2286, `__cpp_lib_format_ranges`) llega a libstdc++ en **GCC 15**: en
  esta máquina compila y los tests pasan. La CI compila con gcc-13, gcc-14 y clang-18 sobre `ubuntu-24.04`, que usan
  libstdc++ 13/14, sin formateo de rangos: **error de compilación solo en la CI**. Con `vector<Segment>`,
  `vector<Emitter>` o `map<…, EmitterType>` falla también en local (sus elementos no tienen `formatter`).
- **Evidencia:** `st/st.cpp -DA_RANGES` (`std::format("{} {} {} {}", vector<Time>, vector<double>, map<string,double,
  less<>>, vector<string>)`): g++ 15 OK, clang++-21 OK, clang++-21 con cabeceras de libstdc++ 14:
  `format:4076: error: static assertion failed … std::formatter must be specialized`. La build completa de la copia,
  que une las listas a mano, compila con libstdc++ 13 y pasan los 92 tests.
- **Cambio sugerido:** en Global Constraints, "`to_string` nunca formatea un contenedor con `std::format`: los elementos
  se unen a mano (bucle o `std::ranges` + `std::string`), con un formato fijo por clase (p. ej. `Values: [1000, 1200]`).
  Para contenedores de clases, cada elemento con su `to_string()`". Fijar en cada tarea el texto esperado del
  `to_string`, como ya se hace con `Position` y el PDW.

### R2-C2 — Alta — `this->get_x()` en un método no `const` llama al getter por valor: clona, copia y no avanza el estado

- **Tarea/paso:** decisión 2 ("en sus accesores, `T get_x(void)` clonan") + R11 ("siempre a través de los
  accesores"). Tareas 3–4 (`next()` de los generadores), 8 (`Emitter::next`, 👤), 11 (`Receiver::receive`),
  12 (`runAll`), 13 (acciones Emit/Arrival de `Simulation`).
- **Descripción:** R8 da dos getters: `T get_x(void)` y `const T& get_x(void) const`. Dentro de un método **no
  `const`**, `this->get_x()` elige **siempre** el primero (por valor). Con los tipos nuevos eso es grave:
  - `unique_ptr<I>`: `this->get_pri()->next()` en `Emitter::next()` avanza un **clon** temporal. Compila sin avisos y
    sin lint; el generador del emisor nunca avanza. Con `FixedPri` los tests pasan; con `StaggerPri` el emisor emite
    siempre el primer valor.
  - `Mission`/`std::vector<Emitter>`: en la acción Emit de `Simulation` (el lambda captura `this` no `const`),
    `this->get_mission().get_emitters()[index].next()` copia **toda la misión** (con copia profunda de los
    generadores) en cada evento y avanza la copia: el emisor real nunca avanza, cada Emit vuelve a programar el mismo
    pulso en el mismo instante y `run()` **no termina**.
  - `std::vector<Time>`/`std::vector<Segment>`: `this->get_valuesNs()[i]` en `StaggerPri::next()` o
    `this->get_schedule()` en `Emitter::next()` copian el vector en cada pulso (unos 500 000 en una misión de 120 s).
  El texto del plan apunta en esta dirección: la Tarea 13 dice "`mission_.emitters_` no cambia de tamaño", pero no
  explica cómo acceder conforme a R11.
- **Evidencia:** test `Simulator.Emitter.EmitterTest.PriGetterReturnsClone` de la copia: dos llamadas a
  `emitter->get_pri()->next()` devuelven 1 ms y 1 ms; `emitter->next()` (con `this->set_pri()->next()`) devuelve 1 ms y
  2 ms. Ni GCC, ni clang, ni clang-tidy dicen nada (`ut_Emitter.cpp` y `Emitter.cpp` pasan el lint).
- **Cambio sugerido:** añadir a la decisión 2 (y a R11 si el usuario quiere): "dentro de la clase, para **modificar**
  un atributo se usa su reference setter (`this->set_pri()->next()`,
  `this->set_mission().set_emitters()[index].next()`); para **leer** en un método no `const`, la sobrecarga `const`
  (`std::as_const(*this).get_valuesNs()[i]`, o un `const auto& values = std::as_const(*this).get_valuesNs();`). El
  getter por valor es para quien usa la clase desde fuera". Añadir a la Tarea 8 un test que cubra el error:
  `NextAdvancesStaggerPri` (con `StaggerPri{1,2,3 ms}` y un solo segmento: 0, 1, 3, 6 ms). Ya existe algo parecido
  en `NextDoesNotShareStateBetweenEmittersOfSameMode`; basta con decir por qué importa.

### R2-C3 — Alta — El constructor de movimiento de las clases derivadas no pasa el lint

- **Tarea/paso:** todas las implementaciones de interfaces (Tareas 3–6 y 10: `FixedPri`, `StaggerPri`, `SlidingPri`,
  `DwellSwitchPri`, `FixedRf`, `ListRf`, `FixedPw`, `FixedScan`, `CircularScan`, `SectorScan`,
  `GaussianAntennaPattern`, `CsvPulseRecordWriter`) y `ConfigError` (Tarea 14).
- **Descripción:** R8 + R11 llevan a `FixedPri(FixedPri&& iOther) noexcept : PriGenerator(std::move(iOther)),
  valueNs_(std::exchange(iOther.set_valueNs(), Time{}))`. clang-tidy lo marca como **`bugprone-use-after-move`** (usa
  `iOther` después de `std::move(iOther)`), y con `WarningsAsErrors: "*"` es un error. La alternativa natural,
  `PriGenerator(iOther)` (copia), la marca **`performance-move-constructor-init`**, y es justo lo que pasa en
  `ConfigError` con `std::runtime_error(iOther)`. Ni GCC ni clang avisan de nada: solo lo ve el lint de la CI.
- **Evidencia:** lint de la copia:
  `FixedPri.cpp:32:63: error: 'iOther' used after it was moved [bugprone-use-after-move]`,
  `CsvPulseRecordWriter.cpp:33:67: … [bugprone-use-after-move]`,
  `ConfigError.cpp:43:7: error: move constructor initializes base class by calling a copy constructor
  [performance-move-constructor-init]`. Variantes limpias en GCC, clang y lint: **omitir** la base en el constructor de
  movimiento (`StaggerPri`, `CsvPulseRecordWriter` corregido; la interfaz no tiene estado y no aparece ningún aviso,
  tampoco `-Wextra`), y en `ConfigError` **`std::runtime_error("")`** (el mensaje de la base no se usa porque `what()`
  está sobrescrito). `PriGenerator(static_cast<PriGenerator&&>(iOther))` también pasa, pero solo porque el check
  busca `std::move`: es engañar al lint.
- **Cambio sugerido:** en la decisión 2: "en las clases derivadas de una interfaz, el constructor de movimiento no
  inicializa la base (la interfaz no tiene estado) y la asignación de movimiento no llama a
  `Base::operator=(std::move(...))`; el constructor de copia sí puede llamar a `Base(iOther)`. En `ConfigError`, la
  base se construye siempre con `std::runtime_error("")`: su mensaje no se usa". Es buen material para explicar al
  usuario por qué un objeto movido "no existe" para el análisis estático.

### R2-C4 — Media — Los tests de movimiento con objetos locales hacen saltar `bugprone-use-after-move`

- **Tarea/paso:** decisión 2 ("los objetos locales con otra configuración usan otro nombre (`custom`, `other`…)") y R12
  ("los de movimiento [comprueban] que el origen queda con los valores por defecto"); todos los `ut_*.cpp` de clases.
- **Descripción:** `Position custom(1, 2, 3); Position moved(std::move(custom)); EXPECT_DOUBLE_EQ(custom.get_eastM(),
  0.0);` es exactamente lo que pide R12, y el lint lo rechaza. El test canónico (`ut_AngleOfArrival.cpp:352`) se libra
  porque mueve desde `*angleofarrival`: el check solo sigue variables, no expresiones `*ptr`.
- **Evidencia:** lint de la copia: `ut_Position.cpp:23:20: error: 'custom' used after it was moved` y
  `ut_EmitterMode.cpp:37:13: … 'custom' used after it was moved`. Los mismos tests sobre `*position`/`*emitter` pasan.
- **Cambio sugerido:** en la decisión 2: "los tests de movimiento (constructor y asignación) mueven siempre desde el
  objeto del fixture (`std::move(*emitter)`), que se configura antes con setters; nunca desde un local".

### R2-C5 — Media — `bugprone-unchecked-optional-access` no acepta `ASSERT_TRUE(p.has_value())`

- **Tarea/paso:** Tareas 8 (`Emitter::next()` devuelve `std::optional<EmittedPulse>`: casi todos sus tests), 15
  (`ParseMissionBuildsEmittersAndReceiver`, `ParseMissionChainsSegmentsFromStart`) y 14 (lecturas de `JsonReader`).
- **Descripción:** en la primera ronda dejé la duda (C15); ahora está comprobado. Con clang-tidy 21, tanto
  `ASSERT_TRUE(p.has_value()); p->…` como `ASSERT_NE(p, std::nullopt); p->…` como `p.value()` dan error. Solo pasa
  `if (!p.has_value()) { FAIL(); }` seguido de `p->…` (clang-tidy 18 no lo he podido probar; es improbable que sea
  más permisivo). En `.cpp` (`JsonReader`, loaders) el patrón `if (x.has_value())` sí se entiende.
- **Evidencia:** `src/Simulator/Engine/tests/ut_Optional.cpp` de la copia: las tres primeras formas dan
  `unchecked access to optional value [bugprone-unchecked-optional-access,-warnings-as-errors]`; la de `if … FAIL()`
  pasa.
- **Cambio sugerido:** en Global Constraints: "en los tests, un `std::optional` se comprueba con
  `if (!pulse.has_value()) { FAIL(); }` antes de usar `pulse->`; `ASSERT_TRUE` no basta para el lint". Para los tests
  de `Emitter` puede valer un helper `EmittedPulse nextOrFail(Emitter&)` en el `namespace {}`.

### R2-C6 — Media — `EventScheduler::Event` (anidado privado) no encaja con R5, R8 ni R12

- **Tarea/paso:** 12.
- **Descripción:**
  1. **Orden de declaración.** R5/R7 ponen los atributos en el último bloque `private:`. Pero `Event` aparece en firmas
     públicas de R8 (`set_events(const std::vector<Event>&)`, `std::vector<Event> get_events(void)`, constructor con
     todos los atributos), y un tipo tiene que estar declarado **antes** de usarse en una firma. Si se declara junto a
     los atributos, no compila. Hace falta un `private:` al principio de la clase, que la plantilla de R5 no tiene.
  2. **R8 y R12.** Los accesores públicos de `events_` usan un tipo que los tests no pueden nombrar
     (`EventScheduler::Event` es privado: solo `decltype(eventscheduler->get_events())`), y como `Event` no tiene
     `==` (`std::function`), `get_events() == …` no compila: los tests de setters, constructores y copia no pueden
     "comprobar todos los atributos". Además, `set_events()` público deja romper la invariante de heap.
- **Evidencia:** `st/st.cpp -DC_EVENT_AT_END`: `error: 'Event' was not declared in this scope` (GCC y clang);
  `-DK_EQ_DEFAULT_ON_VECTOR`: `no match for 'operator==' (operand types are 'const Ev' and 'const Ev')`. En la copia,
  con `Event` en un `private:` al principio, compila y el test por `decltype` funciona.
- **Cambio sugerido:** escribir en la decisión 2 la excepción de `EventScheduler`: `Event` va en un `private:` al
  principio de la clase (antes de las secciones de R5); los accesores de `events_` (y de `nextSequence_`, que también
  es invariante) son **privados** (excepción de R8 por invariante); el constructor "con todos los atributos" no
  existe o es privado; los tests de copia y movimiento comparan `empty()`, `get_currentTimeNs()` y el resultado de
  `runAll()`. Otra opción: `Event` público con `==` que compare solo `at` y `sequence`, pero da más trabajo y no aporta.

### R2-C7 — Media — `ConfigError`: el fixture de R12 no pasa el lint y `message_` tiene setters públicos

- **Tarea/paso:** 14.
- **Descripción:**
  1. El fixture `void SetUp(void) override {configerror = new ConfigError();}` lo marca
     **`bugprone-throw-keyword-missing`** ("exception object created but not thrown"). Un local
     (`const ConfigError custom(...)`) no lo dispara.
  2. La decisión 2 dice "su reference setter es privado" (el de `errors_`). Pero `message_` también es atributo y R8
     le da `set_message(const std::string&)` y `set_message(std::string&&)` públicos, con los que se rompe la caché
     (`what()` dejaría de coincidir con `errors_`).
  3. Detalles que sí funcionan: `ConfigError(void) : std::runtime_error("")` es obligatorio (la base no tiene
     constructor por defecto: error en GCC y clang); `what() const noexcept override` devolviendo
     `get_message().c_str()`; se captura como `std::exception` y como `ConfigError`; la asignación de movimiento
     `noexcept` que recalcula o mueve la caché no la marca `bugprone-exception-escape`.
- **Evidencia:** lint de la copia: `ut_ConfigError.cpp:10:48: error: suspicious exception object created but not
  thrown; did you mean 'throw ConfigError'? [bugprone-throw-keyword-missing]`; `st/st.cpp -DH_CFG_DEFAULT`:
  `no matching function for call to 'std::runtime_error::runtime_error()'`.
- **Cambio sugerido:** (a) en el fixture de `ConfigError`, `// NOLINT(bugprone-throw-keyword-missing)` con un
  comentario de por qué, o crearlo con `std::make_unique` (el `new` queda en una cabecera del sistema); (b) en la
  decisión 2: "los **cuatro** setters de `message_` y el reference setter de `errors_` son privados; `message_` solo
  se escribe en `refreshMessage()`, al que llaman los setters de `errors_`". Que el test `SetErrorsUpdatesWhat` cubra
  los dos setters públicos de `errors_`.

### R2-C8 — Media — `format-check` no aparece en el plan, y la plantilla de fixture de R12 no pasa `.clang-format`

- **Tarea/paso:** "Comandos", Global Constraints, todos los commits.
- **Descripción:** `lint.yml` ejecuta **`format-check`** antes que `lint`, y falla si un fichero de `src/` no sigue
  `.clang-format`. El plan solo menciona `lint`. Además, la plantilla de fixture de R12, copiada tal cual
  (`void SetUp(void) override {x = new X();}`), y los `if (…) x;` en una línea no cumplen `.clang-format` (estilo LLVM:
  `{ x = new X(); }` con espacios). El plan va a crear unos 40 `ut_*.cpp` con esa plantilla.
- **Evidencia:** `clang-format --dry-run` (21.1.8) sobre el código canónico del repo: 17 avisos
  `-Wclang-format-violations`, entre ellos `ut_AngleOfArrival.cpp:33:30` (llaves del `SetUp`), `:48:19` (alineación
  de `=`) y `AngleOfArrival.cpp:239:21` (`if` en una línea). No he podido comprobarlo con clang-format-18, que es el de
  la CI, pero las reglas implicadas (`BasedOnStyle: LLVM`) no han cambiado. Es posible que el repo ya falle hoy en
  `format-check`.
- **Cambio sugerido:** añadir a "Comandos" `cmake --build --preset Release --target format` (o `format-check`) antes
  de cada commit, y decidir con el usuario si la plantilla de R12 se adapta a `.clang-format` o si se aplica `format`
  después de escribir el fichero.

### R2-C9 — Media — `to_string` de atributos que `std::format` no sabe formatear

- **Tarea/paso:** R10 en las Tareas 2, 7, 8, 10, 11, 13 y 14.
- **Descripción:** además de los contenedores (R2-C1), `std::format("{}", x)` **no compila** (ni en GCC 15) con:
  `enum class ScanKind` (el plan no define `to_string(ScanKind)`; `IntrapulseModulation` sí lo tiene), `shared_ptr`
  y `unique_ptr`, y punteros que no son `void*` (`std::ostream* stream_`, `PulseRecordWriter* writer_`). Con `Time`
  sí compila, pero escribe `1000ns`, no `1000`: el plan lo concreta en el PDW (`count()`), no en el resto
  (`FixedPri`, `Segment`, `Emitter`, `Mission`…). Los punteros obligan a `static_cast<const void*>(p)`, y su
  `to_string` contiene una dirección que cambia en cada ejecución, así que el test de `to_string`/`<<` no puede comparar
  un texto fijo. Y llamar a un `to_string(ScanKind)` libre desde `ScanSpec::to_string` repite la trampa de lookup de
  C3.
- **Evidencia:** `st/st.cpp -DE_FMT_PTR`, `-DF_FMT_ENUM`, `-DF2_FMT_SHARED`: `static assertion failed: std::formatter
  must be specialized for each type being formatted` en los tres compiladores probados.
- **Cambio sugerido:** una línea en Global Constraints: "en `to_string`, `Time` con `.count()`, enums con su
  `sigint::to_string`/`sim::to_string` cualificado (añadir `to_string(ScanKind)` en la Tarea 14), punteros
  inteligentes con `p ? p->to_string() : "null"`, punteros no poseídos con `static_cast<const void*>` (su test
  comprueba solo el prefijo, o que el texto sea distinto de `"null"`)". Así el usuario no lo descubre a base de errores
  de plantillas de `<format>`, que son muy largos.

### R2-C10 — Baja — Firmas de R8 con punteros: `std::ostream* const&`, no `const std::ostream*&`

- **Tarea/paso:** 10 (`CsvPulseRecordWriter::stream_`), 11 (`Receiver::writer_`).
- **Descripción:** aplicando la tabla de R8 con `T = std::ostream*`, quedan `void set_stream(std::ostream* const&)` y
  `std::ostream* const& get_stream(void) const`. Escribir `const std::ostream*&` (lo que sale al copiar el patrón
  `const T&` a mano) es otro tipo y no compila en el getter. Y el getter `const` devuelve un puntero a `ostream` **no**
  `const` (constancia superficial), lo cual es correcto aquí, pero conviene que el usuario lo sepa.
- **Evidencia:** `st/st.cpp -DD_PTR_NAIVE`: `binding reference of type 'const std::ostream*&' to 'std::ostream* const'`.
  La versión correcta compila y pasa el lint en la copia.
- **Cambio sugerido:** escribir las cinco firmas de `stream_` en la Tarea 10 (o un `using StreamPtr = std::ostream*;`).

### R2-C11 — Baja — El `operator==` de la derivada oculta el de la base: `fixed == base` no compila

- **Tarea/paso:** 3 (test `EqualityOperatorIsFalseForDifferentDerivedTypes`).
- **Descripción:** R8 da a `FixedPri` su propio `operator==(const FixedPri&)`, que oculta el de la base. Con la base
  a la izquierda (`base == fixed`) funciona; con la derivada a la izquierda (`fixed == base`) **no compila**: el
  candidato invertido de C++20 no se usa porque la base declara también `operator!=` (P2468, C++23). El test del plan
  compara dos `const PriGenerator&`, que es lo correcto, así que solo afecta a quien escriba otra variante.
- **Evidencia:** primera build de la copia: `ut_FixedPri.cpp:51:22: error: no match for 'operator==' (operand types are
  'const sigint::FixedPri' and 'const sigint::PriGenerator')`.
- **Cambio sugerido:** una frase en la Tarea 3: "comparar siempre a través de la base, con los dos operandos como
  `const PriGenerator&`".

### R2-C12 — Baja — `typeid(*ptr)` con un puntero inteligente avisa en clang (`-Werror`)

- **Tarea/paso:** 3 (pieza 👤 `operator==`) y los `==` que comparan generadores apuntados (Tareas 7, 8).
- **Descripción:** `typeid(*this) == typeid(iOther)` (lo que pone el plan) es limpio. Pero si alguien escribe
  `typeid(*a) == typeid(*b)` con `unique_ptr`/`shared_ptr`, clang avisa con `-Wpotentially-evaluated-expression`
  (`operator*` es una llamada) y la CI de clang falla. GCC no dice nada.
- **Evidencia:** `st/st.cpp -DJ_TYPEID`: clang++-21, `error: expression with side effects will be evaluated despite
  being used as an operand to 'typeid' [-Werror,-Wpotentially-evaluated-expression]`; g++ OK.
- **Cambio sugerido:** "el `typeid` solo se usa en el `operator==` de la base; los `==` de las clases que contienen
  punteros comparan `*a == *b`".

### R2-C13 — Baja — Detalles de los comandos

- **Tarea/paso:** "Comandos".
- **Descripción y evidencia:**
  - `CXX=clang++-18 cmake --preset ci-Debug -B .build/ci-Debug-clang` funciona (el `-B` sustituye al `binaryDir` del
    preset; con `clang++-21` configura, compila y pasan los 92 tests de la copia). Pero en esta máquina no hay
    `clang++-18` ni `clang++` sin versión: solo `clang++-21`. Tal y como está escrito, el ejecutor concluirá "no está
    instalado" y se lo saltará.
  - Falta el comando para pasar los tests de esa build: el test preset `ci-Debug` apunta a `.build/ci-Debug`. Funciona
    `ctest --test-dir .build/ci-Debug-clang`.
  - El lint del plan funciona tal cual (`cmake --preset Release -DPROJ_CLANG_TIDY=$(command -v clang-tidy-18 ||
    command -v clang-tidy)`), pero tarda: 1 min 47 s con los 20 ficheros de la copia; con el proyecto completo
    (unos 100 `.cpp`) serán varios minutos. Para iterar: `clang-tidy -p .build/Release <ficheros de la tarea>`.
  - Que la CI compile con clang-18 y aquí solo haya clang-21 significa que un aviso que solo tenga clang-18 no se verá
    en local (poco probable).
- **Cambio sugerido:** `CXX=$(command -v clang++-18 || command -v clang++-21 || command -v clang++)`, añadir
  `ctest --test-dir .build/ci-Debug-clang` y la forma rápida del lint por ficheros.

### R2-C14 — Baja — Inconsistencias de nombres y de R11 en el texto

- **Tarea/paso:** 2, 7, 12, 13.
- **Descripción:**
  - La modulación se llama `intrapulseModulation_` en el PDW, `modulation_` en `EmitterMode` y `EmittedPulse`, e
    `intrapulseModulation` en el JSON y el CSV. No rompe nada, pero no sigue la idea de la decisión 10 (mismo nombre
    en el atributo y en la columna). Sugerencia: `intrapulseModulation_` en las tres clases.
  - `Event` (Tarea 12) tiene miembros `at`, `sequence`, `action` sin `_` ni accesores: es una excepción a la
    decisión 2 que no aparece en su lista. Añadirla junto a `EventScheduler` (ver R2-C6).
  - La Tarea 13 escribe `mission_.emitters_` (acceso directo), que R11 prohíbe; la forma conforme es
    `this->set_mission().set_emitters()[index]` (R2-C2).
  - Comprobado sin problemas: `currentTimeNs_`/`get_currentTimeNs`/`GetCurrentTimeNsReturnsTimeOfCurrentEvent`;
    `emissionTimeNs_`, `arrivalTimeNs_`, `durationNs_`, `startNs_`, `endNs_`, `nextEmissionNs_`, `periodNs_`,
    `valueNs_`/`valuesNs_`, `minNs_`/`maxNs_`/`stepNs_`/`currentNs_`, `widthNs_`, `toaNs_`, `pulseWidthNs_` se usan
    igual en todas las tareas y en los tests; las etiquetas de `to_string` del PDW (`Toa`, `PulseWidth`,
    `Amplitude`) siguen R10 (sin unidad).

### R2-C15 — Baja — `performance-inefficient-vector-operation` en bucles de los tests

- **Tarea/paso:** tests que llenan un vector en un bucle (p. ej. listas de emisores o de valores esperados).
- **Descripción:** `emplace_back`/`push_back` en un bucle sin `reserve()` da error en el lint, también en los tests.
  `RunAllExecutesEventsScheduledDuringRun` no lo dispara (llama a `schedule`, no a `push_back`).
- **Evidencia:** `ut_Emitter.cpp:63:32: error: 'emplace_back' is called inside a loop; consider pre-allocating …
  [performance-inefficient-vector-operation]`.
- **Cambio sugerido:** ninguno en el plan; tenerlo presente (`reserve()` antes del bucle).

---

## Verificado sin problemas

- **Descubrimiento con el reparto nuevo.** `Librería SigInt: Emission;Geometry;PulseDescriptors` y
  `Librería Simulator: Config;Emitter;Engine;Receiver;Runner`. Una sola librería por carpeta de `src/`: las
  dependencias **entre componentes de la misma librería** (Emission → Geometry → PulseDescriptors) no necesitan CMake,
  porque todos los `include/` son `BASE_DIRS` del mismo `FILE_SET` (la frase de la Tarea 2 es correcta).
  `src/Simulator/deps.cmake` con `proj_depends(LIBRARIES SigInt PRIVATE_EXTERNAL nlohmann_json::nlohmann_json)`
  enlaza bien y los tests de `Simulator` ven las cabeceras de `SigInt`. Sin ciclos.
- **Nombres de ctest y `-R`.** `SigInt.Emission.FixedPriTest.CloneKeepsState`,
  `Simulator.Engine.EventSchedulerTest.…`, `Simulator.Config.CatalogLoaderTest.…` (los `TEST(<Module>Test, …)` sin
  fixture también llevan el prefijo). `ctest --preset ci-Debug -R '^SigInt\.Emission\.'` y `'^Simulator\.Engine\.'`
  seleccionan exactamente los del componente. `tests/data/` no molesta.
- **nlohmann/json 3.12.0** sin `FIND_PACKAGE` y con `JSON_SystemInclude ON` fuera del `if`: descarga, `-isystem`,
  `JsonReader.h` en `Config/src/` visible para los `.cpp` de la librería y no para los tests, y configura y compila
  con `-DBUILD_TESTING=OFF` (el ejecutable funciona).
- **R8 completo sobre los tipos nuevos** compila sin avisos con GCC 15 y clang 21 (`-Werror`, ASan+UBSan) y con las
  cabeceras de libstdc++ 13, y pasa el lint con las correcciones de R2-C3/C4/C7:
  - `unique_ptr<I>`: `set_x(const unique_ptr&)` y `T get_x(void)` clonan (con un helper privado estático que admite
    nulo); `set_x(unique_ptr&&)` toma la propiedad; `std::exchange(iOther.set_x(), nullptr)` en el movimiento; la copia
    es profunda (`CopyConstructorCopiesDeep`). **El getter por valor de `unique_ptr` es posible** si clona (si no,
    `return this->p_;` no compila: `st.cpp -DG_UPTR_GET`).
  - `shared_ptr<const I>`: los cinco accesores, `==` sobre los objetos apuntados (dos nulos iguales).
  - `std::vector<Emitter>` con movimiento `noexcept` (crece moviendo), `std::map<std::string, T, std::less<>>`
    (`find(std::string_view)`), `std::function` dentro de `Event`, punteros no poseídos con `std::exchange(…, nullptr)`.
  - Interfaz con copia y movimiento `protected = default` (incluido `noexcept = default`), destructor virtual
    `= default` en el `.cpp`, `to_string` puro virtual, `operator<<` en la base y en la derivada (sin ambigüedad),
    `operator==` no virtual por `typeid` + `isEqual` protegido con `static_cast<const C&>`: funciona, y
    `FixedPri{1000} == StaggerPri{{1000}}` a través de la base da `false`.
  - `ConfigError` con R8: constructor por defecto con `std::runtime_error("")`, copia, movimiento `noexcept`,
    `what() const noexcept override` cacheado; `bugprone-exception-escape` no marca nada.
  - R12: fixture con puntero y `new`/`delete` en clases sin constructor por defecto útil (`Emitter`,
    `CsvPulseRecordWriter`, `EventScheduler`, `ConfigError`): funciona; autoasignación de copia y de movimiento con
    alias, sin `-Wself-assign`/`-Wself-move` y sin aviso de lint.
  - Los checks que preocupaban y no saltan: `bugprone-unhandled-self-assignment` (R8 comprueba `this != &iOther`),
    `performance-noexcept-move-constructor` (R8 pone `noexcept`), `performance-move-const-arg` (los setters `&&` de
    tipos triviales no usan `std::move`, como el código canónico), `bugprone-copy-constructor-init` (no salta aunque
    la copia de la derivada no inicialice la base, y GCC `-Wextra` tampoco avisa). `misc-*` y `cppcoreguidelines-*` no
    están activos en `.clang-tidy`.
- **`-Wshadow`.** Un atributo `distanceM_` (accesores `get_distanceM`/`set_distanceM`) y la función libre
  `sigint::distanceM` conviven, incluso con `const double distanceM = sigint::distanceM(...)` dentro de un método: sin
  aviso en GCC 15 ni clang 21. La init-capture `[payload = std::move(payload)]` tampoco avisa.
- **`EventScheduler`** con `push_heap`/`pop_heap`, mover desde `back()` y ejecutar después: 100 eventos programados
  desde una acción, sin errores de ASan.
- **`__FILE__`** sigue dando una ruta absoluta en la build del preset (test `RunMissionWritesHeaderAndRow`).

# Simulador de emisores y receptor: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ejecutable `ews <mision.json> <salida.csv>` que simula a nivel de pulso varios emisores fijos y un receptor, y
escribe un CSV con los pulsos detectados (PDW + verdad de terreno).

**Architecture:** Simulación por eventos discretos (cola de prioridad `(instante, secuencia)`). Emisor → canal de
propagación → receptor, con dependencias en un solo sentido. La descripción de la señal (unidades, geometría y
propagación, generadores, scans, antena, pulsos, librería de emisores) vive en la librería `SigInt`; el modelo del
mundo (emisores con calendario, canal, receptor, motor, carga de configuración) en la librería nueva `Simulator`. Los
loaders JSON son la única pieza que conoce nlohmann/json.

**Tech Stack:** C++23, CMake (sistema propio `.cmake/`), GoogleTest 1.17, nlohmann/json 3.12.0.

**Spec:** `docs/superpowers/specs/2026-10-24-simulator-design.md` (leerla entera antes de empezar; este plan no repite
sus fórmulas, las referencia por sección).

**Revisiones aplicadas:** `docs/superpowers/reviews/2026-10-24-plan-review-{1..5}-*.md` (primera ronda: `[A1]`,
`[C4]`, `[F9]`…) y `…-round2.md` (segunda ronda: `[R2-A1]`, `[R2-C3]`…). Los identificadores entre corchetes remiten
al hallazgo que motivó cada cambio.

## Decisiones

Todas confirmadas por el usuario el 24/10/2026, incluidos los ajustes de la segunda ronda. La decisión 2 se rehízo el
25/10/2026 al sustituir `how_to_write_a_class.md` por las reglas de `.claude/rules/cpp/` (C++ Core Guidelines); la
clasificación `struct`/`class` la confirmó el usuario ese día. El mismo 25/10/2026, tras revisar las reglas, el
usuario decidió: namespace = nombre de la librería en minúsculas (el antiguo namespace del simulador pasa a
`simulator`), una librería `Core` para lo transversal (`core::check_contract`), Regla del Cero por defecto, getter
siempre (también del estado), acceso directo a los atributos dentro de la clase, `{}` siempre, `[[nodiscard]]`,
banners solo con contenido y bugs con `check_contract` en lugar de
`std::logic_error`. Este plan ya lo aplica.

1. **Namespaces y librerías** (tabla de `headers.md`: el namespace es la librería en minúsculas). Todas las clases que
   definen una señal, una parte de ella o su tratamiento van en `sigint` (librería `src/SigInt/`, comentario
   `// Signals Intelligence`); las del simulador, en `simulator` (librería `src/Simulator/`, comentario
   `// Simulator`); lo transversal sin dominio, en `core` (librería `src/Core/`, **pendiente de crear**: la añade el usuario antes
   de la Tarea 3, primer uso de `check_contract`).
   Reparto:

   | Librería / componente | Namespace | Contenido |
   | --- | --- | --- |
   | `Core/Contracts` (pendiente) | `core` | `check_contract` (contrato en `errors.md`) |
   | `SigInt/Units` (nuevo) | `sigint` | `Time` y conversiones |
   | `SigInt/PulseDescriptors` (existe) | `sigint` | `PulseDescriptorWords`, `AngleOfArrival`, `IntrapulseModulation` |
   | `SigInt/Geometry` (nuevo) | `sigint` | `Position`, `Geometry` (`distance_m`, `direction_from_to`), `Propagation` (`propagation_delay`, `free_space_path_loss_db`, `wrap_offset_deg`) |
   | `SigInt/Emission` (nuevo) | `sigint` | generadores de PRI, RF y PW; `ScanSpec`; scans; antena; `EmitterMode`, `EmittedPulse`, `IncidentPulse` |
   | `SigInt/Library` (nuevo) | `sigint` | `EmitterType`, `Catalog` |
   | `Simulator/Emitter` | `simulator` | `Segment`, `Emitter` |
   | `Simulator/Channel` | `simulator` | `PropagationChannel` |
   | `Simulator/Receiver` | `simulator` | `GroundTruth`, `PulseRecordWriter`, `CsvPulseRecordWriter`, `Receiver` |
   | `Simulator/Engine` | `simulator` | `EventScheduler`, `ReceiverSpec`, `Mission`, `Simulation` |
   | `Simulator/Config` | `simulator` | `ConfigError`, loaders, `JsonReader` |
   | `Simulator/Runner` | `simulator` | `MissionRunner` |

   `Position`, la geometría y `Time` van a `SigInt` aunque no sean señal: las usan clases de señal, y dejarlas en
   `Simulator` crearía una dependencia circular. `Time` va en su propio componente para que tampoco haya ciclo entre
   `Geometry` (que usa `AngleOfArrival`) y `PulseDescriptors` (que usa `Time`) [R2-F13]. `Core` no depende de nada;
   `SigInt` depende solo de `Core`; `Simulator` depende de `SigInt` y `Core`.

   **Ajuste tras la segunda ronda** [R2-D2, R2-D3]: `ScanSpec`, `EmitterType`, `Catalog` y las
   funciones de propagación pasan de `simulator` a `sigint` aplicando la misma regla. `ScanSpec` (tipo y periodo del scan)
   es un parámetro de la señal. `EmitterType`/`Catalog` son la librería de emisores que consultará un clasificador.
   `wrap_offset_deg` y la FSPL las necesitará el procesado (agrupación por AoA, estimación de distancia). Desaparece
   `CatalogMode`.

2. **Reglas de código: `.claude/rules/cpp/`** (C++ Core Guidelines). Este apartado solo recoge cómo se aplican a los
   tipos del simulador; todo lo demás (nombres, cabeceras, Doxygen, banners, funciones especiales, tests) está en esos
   archivos.

   **Clasificación** (C.2, C.8; confirmada por el usuario el 25/10/2026):

   | Tipos | Forma | Notas |
   | --- | --- | --- |
   | `Position`, `PulseDescriptorWords`, `ScanSpec`, `EmittedPulse`, `IncidentPulse`, `GroundTruth`, `ReceiverSpec`, `EmitterMode`, `EmitterType`, `Segment`, `Mission` | `struct` agregado | Atributos públicos `camelCase` sin `_` y sin accesores; se construyen con *designated initializers* (`sigint::Position{.eastM = 3.0, .northM = 4.0}`). Lo que haya que validar lo valida el loader (decisión 11) |
   | `AngleOfArrival`, `Catalog`, `ConfigError`, `JsonReader` | `class` con invariante | |
   | `PriGenerator`, `RfGenerator`, `PwGenerator`, `ScanPattern`, `AntennaPattern`, `PulseRecordWriter` y sus implementaciones | `class`, jerarquía polimórfica | P1–P3 |
   | `Emitter`, `Receiver`, `CsvPulseRecordWriter`, `EventScheduler`, `Simulation` | `class` con estado | S1–S5 |
   | `Units`, `Geometry`, `Propagation`, `PointeeEquality`, `PropagationChannel`, `CatalogLoader`, `MissionLoader`, `MissionRunner` | funciones libres | M1 |
   | `IntrapulseModulation`, `ScanKind` | `enum class` | M1 |

   **Jerarquías polimórficas:**
   - **P1. Interfaz** (sin atributos): banners de `class`. `to_string` y los métodos de la interfaz son virtuales puros;
     destructor `virtual ~I() = default;` en el `.h`; constructores y asignaciones de copia y movimiento `protected` y
     `= default` (C.67: si fueran públicos permitirían *slicing*, copiar solo la parte base de un objeto derivado). Sin
     `ut_` propio: se prueba a través de sus implementaciones.
   - **P2. Igualdad polimórfica** (C.161): la interfaz define a mano el *hidden friend*
     `friend bool operator==(const I& iLhs, const I& iRhs) noexcept`, que devuelve
     `typeid(iLhs) == typeid(iRhs) && iLhs.is_equal(iRhs)`, con `virtual bool is_equal(const I& iOther) const noexcept = 0;`
     protegido. `typeid` solo se usa ahí; si alguien escribe `typeid(*ptr)` con un puntero inteligente, clang avisa
     [R2-C12]. Las implementaciones no declaran `==`: su `is_equal` hace `dynamic_cast<const C&>(iOther)` (nunca lanza,
     el tipo ya está comprobado; `static_cast` lo rechaza `cppcoreguidelines-pro-type-static-cast-downcast`) y compara
     todos los atributos. `PulseRecordWriter` no tiene `==` (S5).
   - **P3. Implementaciones**: `final`. Tienen tabla virtual, así que no son trivialmente copiables. Siguen la **Regla
     del Cero** (`classes.md`): no declaran ninguna de las cinco; el destructor implícito ya sobrescribe el virtual de
     la base, y la copia y el movimiento implícitos usan los de la base, protegidos pero accesibles desde la derivada.
     Son copiables: la base solo protege su propia copia contra el *slicing*. Los generadores con estado (PRI, RF y PW) ofrecen
     `std::unique_ptr<I> clone() const` (`std::make_unique<C>(*this)`): `Emitter` clona el prototipo del modo al entrar
     en cada segmento, así cada emisor empieza con su propio estado. Los scans y la antena son inmutables (todos sus
     métodos son `const`) y se comparten con `std::shared_ptr<const I>`, así que no necesitan `clone()`.

   **Clases con estado** [R2-F1, R2-A3]:
   - **S1. Configuración y estado inicial**: un constructor con los parámetros de configuración fija el estado inicial.
     Es el que usan el loader y los tests. El constructor por defecto da un objeto que no se debe usar sin configurar;
     si se usa, `core::check_contract` aborta el programa (S3).

     | Clase | Constructor de configuración | Estado inicial |
     | --- | --- | --- |
     | `StaggerPri` | `(valuesNs)` | `index_ = 0` |
     | `SlidingPri` | `(minNs, maxNs, stepNs)` | `currentNs_ = minNs` |
     | `DwellSwitchPri` | `(valuesNs, pulsesPerDwell)` | `index_ = 0`, `pulsesInDwell_ = 0` |
     | `ListRf` | `(frequenciesHz, pulsesPerHop)` | `index_ = 0`, `pulsesInHop_ = 0` |
     | `Emitter` | `(id, position, startNs, schedule, endNs)` | `segmentIndex_ = 0`, `segmentStartNs_ = startNs`, `nextEmissionNs_ = startNs`, `pulseIndex_ = 0`, `pri_ = rf_ = pw_ = nullptr` |
     | `Receiver` | `(id, position, gainDbi, sensitivityDbm, PulseRecordWriter& oWriter)` | `writer_ = &oWriter`, `nextPulseId_ = 0` |
     | `CsvPulseRecordWriter` | `(std::ostream& oStream)` | `stream_ = &oStream`; escribe la cabecera (solo este constructor) |
     | `EventScheduler` | el constructor por defecto | sin eventos, `nextSequence_ = 0`, `currentTimeNs_ = 0` |
     | `Simulation` | `(Mission iMission, PulseRecordWriter& oWriter)` | `receiver_` construido a partir de `mission_` y `oWriter`; planificador vacío |

     Los generadores sin estado (`FixedPri`, `FixedRf`, `FixedPw`) y los scans y la antena tienen igualmente un
     constructor con sus parámetros.
   - **S2. Accesores** (`classes.md`): getter `const` de **cada** atributo, de configuración y de estado (salvo los
     de tipo privado de la clase, `classes.md`), **sin setter**: la configuración queda fija tras la construcción y el estado solo lo cambian los métodos de la clase, y
     así nadie puede romper el estado (cambiar la lista de una `StaggerPri` dejaría `index_` fuera de rango). Dentro de
     la clase los atributos se usan directamente (`classes.md`): `pri_->next()`, `++nextPulseId_`,
     `mission_.emitters[index].next()`.
   - **S3. Robustez** [R2-A4, R2-A14]: los métodos no confían en el estado. Leen con `values[index % size]`, comparan
     contadores con `>=` y llaman a `core::check_contract` si encuentran un estado imposible (lista vacía, PRI ≤ 0,
     periodo ≤ 0, puntero nulo): es un bug y el programa se para, también en Release (`errors.md`). No un `assert`,
     que desaparece en Release y volvería a dejar el bucle infinito de A1. Cada caso tiene su *death test*
     (`<Función>AbortsWhen<Condición>`, en la suite `<Tipo>DeathTest`, `tests.md`). Las librerías que lo usan declaran
     `Core` en su `deps.cmake`.
   - **S4. Propiedad** [R2-A2]:
     - `Emitter` posee sus generadores activos como `std::unique_ptr<I>` (estado interno). Su getter devuelve
       `const I*` (`pri_.get()`): con `const std::unique_ptr<I>&` el `const` caería sobre el puntero y no sobre el
       objeto, y `e.get_pri()->next()` avanzaría el estado de un `const Emitter&`.
     - `Emitter` es **solo movible** porque sus `std::unique_ptr` lo son: **Regla del Cero**, no declara ninguna de las
       cinco (`classes.md`). Copiar un emisor a medio avanzar no tiene uso en el simulador, y así no hace falta escribir
       a mano una copia profunda. `Mission`, que
       guarda los emisores en un `std::vector`, no se puede copiar en la práctica (instanciar su copia no compila), pero
       `std::is_copy_constructible_v<Mission>` da `true`: la copia de `std::vector` no se borra, solo falla al
       instanciarse. Por eso `Mission` no lleva el `static_assert` de no copiable.
     - Un `std::vector<Emitter>` no se puede crear con una lista `{e1, e2}` (`std::initializer_list` copia): en tests y
       loader, `emplace_back` o `push_back(std::move(…))`.
     - Punteros a objetos externos no poseídos (`std::ostream* stream_`, `PulseRecordWriter* writer_`): se guardan como
       puntero porque un atributo referencia impediría asignar (C.12). La copia comparte el puntero, el `==` por
       defecto compara identidad y usar uno nulo es un bug (`core::check_contract`, S3).
   - **S5. Sin `==`**, como dice `classes.md` (se indica en el `@brief`): `EventScheduler` (`std::function` no es
     comparable), `Simulation` (contiene un `EventScheduler`), `PulseRecordWriter`/`CsvPulseRecordWriter` (la igualdad
     de dos escritores no tiene sentido), `Emitter` (comparar dos emisores a medio avanzar no tiene uso, y obligaría a
     leer su estado interno) y `Mission` (contiene emisores).
     - `EventScheduler` [R2-A8, R2-C6]: copia `= delete` (copiar acciones que capturan el `this` de otro objeto nunca
       tiene sentido, aunque `std::function` sea copiable: caso "solo movible aunque sus atributos sean copiables" de
       `classes.md`, así que declara las cinco); movimiento y destructor `= default`. El tipo anidado `Event` (`struct` con `at`, `sequence` y
       `action`) es un detalle de implementación: va en un bloque `private:` **al principio** de la clase, antes de los
       banners, porque las firmas lo usan; como tipo privado auxiliar no lleva `to_string`, `==` ni `<<`. `nextSequence_`
       y `currentTimeNs_` tienen su getter `const` (S2); `events_` no tiene accesores porque su tipo es privado
       (excepción de `classes.md`): se observa con `empty()`. `to_string` escribe
       el número de eventos pendientes y el tiempo actual (`[Events: 2, CurrentTime: 7000]`).
     - `Simulation` [A7, R2-A8]: copia y movimiento `= delete` (sus eventos capturan `this`) y destructor `= default`
       (las cinco, `cppcoreguidelines-special-member-functions`). Solo constructor por defecto y de configuración, y
       sin accesores: su estado lo gobierna `run()` y se observa a través del escritor. Sus tests de constructores
       comprueban `to_string`.

   **Igualdad con punteros inteligentes** (`classes.md`): el `==` por defecto de un `shared_ptr`/`unique_ptr` compara
   direcciones, y dos modos iguales en valor creados por separado serían distintos. `EmitterMode`, `Segment` y
   `EmittedPulse` (los tres `struct`) definen su `==` a mano comparando los objetos apuntados con
   `sigint::pointees_equal` (Tarea 3: dos nulos son iguales; uno nulo y otro no, distintos; si no, `*a == *b`;
   `noexcept`). `EmitterType` también, porque guarda un `std::map` de `shared_ptr<const EmitterMode>`: compara los
   nombres y, modo a modo, las claves y `pointees_equal` de los valores. Todos esos `==` son `noexcept`.
   `IncidentPulse` y `Catalog` usan `= default`, que delega en el `==` de `EmittedPulse` y de `EmitterType`.

   **`ConfigError`** [R2-A10, R2-F6, R2-C7]: hereda de `std::runtime_error`; su único atributo es `errors_` y el texto
   de `what()` lo guarda la base (no sobrescribe `what()`).
   - `explicit ConfigError(std::vector<std::string> iErrors)` inicializa la base con los errores unidos por `\n` antes
     de mover `iErrors` al atributo (la base se construye primero).
   - El constructor por defecto no puede ser `= default` (`std::runtime_error` no tiene constructor por defecto):
     delega en el anterior con una lista vacía.
   - `set_errors` asigna y recalcula el texto con `std::runtime_error::operator=(std::runtime_error(join(errors_)))`
     (invariante entre `errors_` y `what()`).
   - Regla del Cero: la copia y el movimiento implícitos copian o mueven la base y `errors_` a la vez, y eso mantiene la
     invariante.
   - `==` a mano comparando `errors_`: el `= default` quedaría borrado porque `std::runtime_error` no tiene `==`.
   - `to_string` → `[Errors: [<error>, <error>, …]]` (lista unida a mano). Copiar la excepción copia el
     `std::vector<std::string>` y en teoría puede lanzar; se acepta (solo pasa sin memoria) y se dice en el `@brief`.

   **`JsonReader`** (privado de `Config`, en `src/`): `class` con invariante. Sin `ut_` propio porque los tests no ven sus
   cabeceras ni las de nlohmann (`PRIVATE_EXTERNAL`); se prueba a través de los loaders.
   - Atributos: `const nlohmann::json* json_` y `std::vector<std::string>* errors_` (no poseídos, como en S4: un
     atributo referencia lo rechaza `cppcoreguidelines-avoid-const-or-ref-data-members`), `std::string fileName_`,
     `std::string path_` y `std::set<std::string, std::less<>> readKeys_`.
   - Invariante: `readKeys_` solo contiene claves que existen en el objeto `*json_`.
   - Constructor `JsonReader(std::string iFileName, std::string iPath, const nlohmann::json& iJson,
     std::vector<std::string>& ioErrors)`; los lectores hijos (`object`, `array`) se crean con la ruta extendida y la
     misma lista de errores. Getters de `fileName_` y `path_`; sin setters (configuración fija, S2).
   - Sin `==` (la igualdad de dos lectores no tiene sentido; se dice en el `@brief`, `classes.md`).

   **M1. Funciones libres y enums**: se les aplican `headers.md`, `naming.md` y `functions.md`; sus tests usan
   `TEST(<Módulo>Test, …)` sin fixture.

   **Convenciones de `to_string`** (`classes.md`) para los tipos que `std::format("{}")` no sabe escribir, o que
   escribe de forma que no conviene [R2-C1, R2-C9, R2-F7]:
   - **`Time`**: número de ns con `.count()`. Con `std::format("{}")` saldría `1000ns`.
   - **Enums**: con su `to_string` cualificado (`sigint::to_string(...)`; ver la trampa de lookup de la Tarea 2).
   - **Puntero inteligente**: `p ? p->to_string() : "null"`.
   - **Puntero no poseído**: `"set"` o `"null"`, sin la dirección, que cambia en cada ejecución.
   - **Contenedores**: **nunca** con `std::format` directamente. El formateo de rangos existe en la libstdc++ de GCC 15
     (local), pero no en la de GCC 13/14 ni con clang-18 (CI), así que compilaría en local y rompería la CI. Los
     elementos se unen a mano como `[a, b, c]`, cada uno con su formato (o su `to_string()`); un `map` como
     `[clave: valor, …]`.

   **Tests** (`tests.md`) [R2-C4, R2-C5, R2-C15]:
   - Los agregados se inicializan con *designated initializers* también en los tests
     (`modernize-use-designated-initializers`). En las descripciones de tests de este plan, una lista como
     `{3, 4, 0}` o `PDW {7, 83391 ns, …}` abrevia los valores en el orden de los atributos: en el código se escriben
     con sus nombres (`Position{.eastM = 3.0, .northM = 4.0, .upM = 0.0}`).
   - Fixture con el objeto como atributo, creado con el constructor por defecto (o, en un `struct`, con `{}`). Los
     objetos locales con otra configuración usan otro nombre (`custom`, `other`…) para no ocultar al miembro del
     fixture (`-Wshadow`) [C7].
   - `static_assert`: `std::is_aggregate_v` en todos los `struct`; `std::is_trivially_copyable_v` en los que lo son
     (`Position`, `ScanSpec`, `PulseDescriptorWords`); `!std::is_copy_constructible_v` en `Emitter` (por sus
     `std::unique_ptr`), `EventScheduler` y `Simulation` (no en `Mission`, ver S4); y los de movimiento `noexcept` en todos los tipos movibles (no en
     `Simulation`).
   - Los tests de movimiento comprueban el destino, nunca el origen (`bugprone-use-after-move`). Solo los tienen las
     funciones especiales declaradas (`EventScheduler`); las implícitas de la Regla del Cero no tienen test (`tests.md`).
   - Un `std::optional` se comprueba con `if (!pulse.has_value()) { FAIL(); }` antes de usar `pulse->`, porque
     `ASSERT_TRUE(p.has_value())` no basta para `bugprone-unchecked-optional-access`. En `ut_Emitter.cpp` y
     `ut_MissionLoader.cpp`, helper `sigint::EmittedPulse next_or_fail(simulator::Emitter&)` en el `namespace {}`.
   - Los vectores que se llenan en un bucle llevan antes un `reserve()` (`performance-inefficient-vector-operation`).

3. **El scan concreto se construye por segmento** (spec §3, decisión 6) [F3]. **Ajustado tras la segunda
   ronda** [R2-D2]: el modo guarda la parte intrínseca del scan (`ScanSpec`, en `sigint`) y el loader
   de la misión combina el `ScanSpec` del modo con los parámetros del segmento en el `ScanPattern` del `Segment`.
4. **Ids restringidos a `[A-Za-z0-9_-]+`** (tipo, modo, emisor, receptor). Evita tener que escapar comas o comillas
   en el CSV (spec §5).
5. **Tiempos como `std::chrono::nanoseconds`** (`sigint::Time`) también en el PDW (`toaNs`, `pulseWidthNs`), en
   lugar del `uint64_t` sugerido en el comentario de `PulseDescriptorWords.h` (spec §2).
6. **`Simulation` no carga ficheros; aparece el componente `Runner`** (spec §3, decisión 7) [F4, F12]. `main` carga,
   abre la salida y llama a `run_mission(Mission, std::ostream&)`.
7. **`IntrapulseModulation` como `enum` cerrado** de 6 valores con conversión desde y hacia texto; un valor
   desconocido en el JSON es error. El parámetro de la modulación queda aplazado [F6].
8. **Posiciones constantes** (sin `positionAt(Time)`) [F2]. Añadir trayectorias cambiará las firmas de `Emitter`,
   `Receiver` y `PropagationChannel`; la spec §1 y §3 lo dejan anotado.
9. **Desvío de antena en az/el** con la limitación documentada en la spec §4 paso 2.4, en lugar de calcularlo en el
   sistema del haz [A5, D2].
10. **Salida**: columna `amplitudeDbm` (mismo nombre que el atributo del PDW) y columnas de verdad
    `truth_segmentIndex` y `truth_txGainDbi` [D8, D13].
11. **Límites numéricos** (spec §5): tiempos ≤ 10⁶ s, posiciones ≤ 10⁸ m, d ≥ 1 m, elevaciones en [−90, 90],
    `widthDeg` en (0, 360), anchos de haz en (0, 180]; `emitters` vacía es válida y `schedule` vacía es error; las
    claves JSON repetidas no se detectan [A2, A10, A12, A13, A14, D4]. **Ampliado tras la segunda
    ronda**:
    - frecuencias en [30, 300 000] MHz [R2-D8];
    - potencias y ganancias en [−300, 300] y `sidelobeLevelDb` en [0, 300];
    - azimuts en [−360, 360] [R2-A6];
    - enteros en [1, 2³² − 1].

## Reparto de trabajo (modo aprendizaje)

Según `.claude/CLAUDE.md`, el usuario escribe el código salvo que pida lo contrario. Propuesta: el ejecutor prepara
ficheros, firmas, comentarios y tests; las piezas marcadas **👤** las escribe el usuario (el ejecutor deja el cuerpo
con `// TODO(usuario)` y se detiene a explicar). Si el usuario prefiere otro reparto, se ajusta antes de empezar.

| Pieza | Tarea | Por qué es buena para aprender |
| --- | --- | --- |
| 👤 `direction_from_to` | 1 | `atan2(ΔE, ΔN)`: el error de convención más típico |
| 👤 `operator==` + `is_equal` de `PriGenerator` y `FixedPri` | 3 | comparación polimórfica sin *slicing* |
| 👤 `SectorScan::pointing_at` | 5 | onda triangular, división de `duration` y wrap en 0°/360° |
| 👤 `GaussianAntennaPattern::gain_dbi` | 6 | parábola en dB y suelo de lóbulos |
| 👤 `Emitter::next` | 9 | máquina de estados de segmentos con intervalos semiabiertos y clonado de prototipos |
| 👤 comparador y bucle de `EventScheduler::run_all` | 13 | min-heap con `std::push_heap`/`std::pop_heap` y desempate |
| 👤 detección de claves desconocidas en `JsonReader` | 15 | acumulación de errores con ruta |

## Global Constraints

- C++23; compila sin avisos con `-Werror` en `ci-Debug` (GCC, sanitizers activos) **y con clang** (la matriz de CI
  compila con clang-18 y el lint usa LLVM 21; su `-Wconversion` incluye `-Wsign-conversion` y `-Wshorten-64-to-32`, que GCC no activa) [C9]. Pasa
  `format-check` y el lint (`clang-tidy`, `WarningsAsErrors: "*"`) [C15, R2-C8].
- Cada tipo en 3 ficheros `include/<T>.h`, `src/<T>.cpp`, `tests/ut_<T>.cpp` (nombre de `.h` único en todo `src/`) (salvo las interfaces, sin `ut_`;
  `JsonReader`, en `src/`; y `PointeeEquality`, solo cabecera: decisión 2), con las reglas de `.claude/rules/cpp/` y la
  clasificación y excepciones de la decisión 2. `@author Hugo Fernández Solís
  (hugofernandezsolis@gmail.com)`, `@date` = fecha real de creación. Después de escribir cada fichero se aplica
  `clang-format` (target `format`) [R2-C8].
- Accesores, solo en las `class`: `get_`/`set_` + nombre del atributo tal cual (`get_azimuthDeg`), nunca snake_case.
  Los `struct` no tienen accesores. Getter siempre y acceso directo dentro de la clase: decisión 2, S2.
- `[[nodiscard]]` en getters, `to_string`, funciones que calculan un valor y las que devuelven `std::optional`
  (`functions.md`); `{}` en toda inicialización (`expressions.md`).
- Un test por función bajo prueba; los getters que solo observan no cuentan.
- Unidades internas SI; tiempo `sigint::Time = std::chrono::nanoseconds`; ángulos en grados; geometría y potencias en
  `double` (salvo la amplitud del PDW, `float`); direcciones almacenadas en `sigint::AngleOfArrival` (`float`).
- ENU: X = Este, Y = Norte, Z = Arriba. Azimut desde el Norte, horario, [0, 360). Elevación [-90, 90], + arriba.
- c = 299 792 458 m/s. FSPL = `20·log10(d) + 20·log10(f) − 147.55` (constante redondeada a propósito). Ganancia:
  `max(G_max − 12·[(Δaz/θ_az)² + (Δel/θ_el)²], G_max − SLL)`.
- Conversión de unidades del JSON a `Time` con redondeo al ns más cercano (`std::llround`): primero el límite superior
  en `double`, después la conversión y por último el `> 0 ns` [A1, R2-A5].
- **Conversiones numéricas** [C2, C8, C9]:
  - `double → float` solo con `static_cast<float>(…)` en el punto donde se construye un `AngleOfArrival` o el PDW. En
    los tests, literales `float` con sufijo `f` (`216.87f`) o `EXPECT_NEAR`.
  - `Time → double`: `std::chrono::duration<double>(t).count()` (segundos) o `duration<double, std::micro>`; nunca
    `t.count() / 1e9` (`long → double` avisa).
  - La división de dos `duration` enteras es **entera**: para una fracción, `std::chrono::duration<double>(a) / b`.
  - Índices de contenedor como `std::size_t`; solo los parámetros de configuración (`pulsesPerDwell`,
    `pulsesPerHop`) y sus contadores como `std::uint32_t`.
- **Comparaciones en tests** [F15, N2]: tiempos con `EXPECT_EQ`; tests de accesores, valores por defecto, copia y
  movimiento con `EXPECT_FLOAT_EQ` / `EXPECT_DOUBLE_EQ`; resultados de cálculos físicos (ángulos calculados, ganancias, potencias)
  con `EXPECT_NEAR` (ángulos 1e-4, potencias y ganancias 1e-9 salvo que el test diga otra cosa).
- Parámetros que se guardan (`std::string`, `std::vector`, `std::function`, `Mission`…) se mueven al atributo
  (`performance-unnecessary-value-param`) [C15].
- Helpers de test dentro de un `namespace {}` anónimo en cada `ut_*.cpp`: todos los `ut_*.cpp` de un componente se
  enlazan en un único ejecutable y dos helpers con el mismo nombre violarían la ODR [C17].
- Solo `src/Simulator/Config/src/` incluye `<nlohmann/json.hpp>` (dependencia `PRIVATE_EXTERNAL`).
- Mensajes de error al usuario en español; identificadores y comentarios de código en inglés (como el código actual).

## Comandos

- Configurar y compilar: `cmake --preset ci-Debug && cmake --build --preset ci-Debug`
- Tests de un componente: `ctest --preset ci-Debug --timeout 60 -R '^<Librería>\.<Componente>\.'` (p. ej.
  `'^SigInt\.Emission\.'`, `'^Simulator\.Engine\.'`). El `--timeout` convierte un bucle infinito en un fallo [R2-A1].
- Todos los tests: `ctest --preset ci-Debug --timeout 60`
- Compilación y tests con clang (en esta máquina solo hay `clang++-21`; la CI usa clang-18) [R2-C13]:
  `CXX=$(command -v clang++-18 || command -v clang++-21 || command -v clang++) cmake --preset ci-Debug -B
  .build/ci-Debug-clang && cmake --build .build/ci-Debug-clang && ctest --test-dir .build/ci-Debug-clang --timeout 60`
- Formato (antes de cada commit): `cmake --build --preset Release --target format`, y comprobación como la CI:
  `--target format-check` [R2-C8].
- Lint (como `lint.yml`, LLVM 21; al cerrar las Tareas 9, 13, 15 y 17 como mínimo; tarda varios minutos):
  `cmake --preset Release -DPROJ_CLANG_TIDY=$(command -v clang-tidy-21 || command -v clang-tidy) && cmake --build
  --preset Release --target lint`. Para iterar sobre los ficheros de una tarea: `clang-tidy -p .build/Release
  <ficheros>`.

Los nombres de test en ctest son `<Librería>.<Componente>.<Fixture>.<Test>` (`.cmake/Tests.cmake:34`).

## Review Focus

1. **Scan que cruza 0°/360°** (sector centrado en 0°, circular con `initialAzimuthDeg` 350): el azimut sigue en
   [0, 360) y el barrido es continuo. Test en Tarea 5.
2. **Desvío de haz con wrap** (haz en 359°, receptor en 1°): Δaz = 2°, no 358°; la ganancia es la de un desvío de 2°
   dentro del lóbulo principal (23 dBi con θ_az = 2°), no el suelo de lóbulos laterales (5 dBi) que daría 358°
   [F13, D11, N3]. Test en Tarea 10.
3. **Pulso que cae exactamente en una frontera** (fin de segmento o `durationS`): los intervalos son semiabiertos
   `[inicio, fin)`; el pulso pertenece al segmento siguiente o no se emite. Test en Tarea 9.
4. **Valores del JSON que no son múltiplos de 1 ns** (`valueUs: 1.0004`): se redondean al ns más cercano y no se
   acumula error; un valor positivo que redondea a 0 ns es error, no un bucle infinito [A1]. Tests en Tarea 1
   (conversión) y Tarea 15 (loader).
5. **JSON mal formado, con tipos equivocados o con problemas de disco** (`"durationS": "120"`, fichero truncado,
   `catalogDir` inexistente, `positionM` de 2 elementos, `1e400`): `ConfigError` con fichero y ruta; nunca una
   excepción de nlohmann o de `std::filesystem` sin capturar, ni un `assert` de nlohmann, ni un crash. Tests en
   Tareas 15 y 16.
6. **Prototipos compartidos**: dos emisores del mismo tipo no comparten el estado de sus generadores [A3]. Test en
   Tarea 9.
7. **Comparación por valor y polimórfica**: dos modos con generadores iguales en valor pero distintos en memoria son
   iguales (`pointees_equal`), y `==` entre dos generadores de tipos distintos es `false` sin *slicing*. Tests en
   Tareas 3, 4, 5, 7, 8 y 9 [R2-F10].
8. **El estado avanza de verdad** en `Emitter`, `Receiver` y `Simulation`: una `StaggerPri` da 0, 1, 3, 6 ms y no
   0, 1, 2, 3, y `pulseId` cuenta. Tests en Tareas 9, 12 y 14 [R2-A1].

---

### Task 1: Unidades, geometría y propagación (`SigInt/Units`, `SigInt/Geometry`)

**Files:**
- Create: `src/SigInt/Units/include/Units.h`, `src/SigInt/Units/src/Units.cpp`, `src/SigInt/Units/tests/ut_Units.cpp`
- Create en `src/SigInt/Geometry/`: `Position` (`.h`, `.cpp`, `ut_`), y los módulos de funciones libres `Geometry` y
  `Propagation` (`include/<M>.h`, `src/<M>.cpp`, `tests/ut_<M>.cpp`).

**Interfaces** (namespace `sigint`):
- `Units.h`: `using Time = std::chrono::nanoseconds;` · `inline constexpr double speedOfLightMps = 299'792'458.0;`
  · `Time seconds_to_time(double iSeconds);` · `Time microseconds_to_time(double iMicroseconds);` ·
  `double time_to_seconds(Time iTime);` · `double time_to_microseconds(Time iTime);`
  Precondición documentada en el comentario de las dos primeras: argumento finito y con resultado representable en
  `int64` ns (≈ 292 años); el loader la garantiza comprobando el límite antes de convertir [A2, R2-A5].
- `Position` (`struct`, trivialmente copiable): `double eastM`, `northM`, `upM` (en ese orden). `to_string` →
  `"[East: {}, North: {}, Up: {}]"`.
- `Geometry.h` (dos funciones, spec §3) [F8]: `double distance_m(const Position& iFrom, const Position& iTo);` ·
  `AngleOfArrival direction_from_to(const Position& iFrom, const Position& iTo);` (👤; `static_cast<float>` al
  construir el `AngleOfArrival`).
- `Propagation.h` [R2-D3]: `Time propagation_delay(double iDistanceM);` (redondeado al ns más cercano) ·
  `double free_space_path_loss_db(double iDistanceM, double iFrequencyHz);` (147.55 a propósito, spec §4 paso 2.6) ·
  `double wrap_offset_deg(double iOffsetDeg);` (a (−180, 180]).

- [ ] **Step 1: Tests que fallan.**

```cpp
// ut_Units.cpp — TEST(UnitsTest, ...), one test per function
EXPECT_EQ(seconds_to_time(1.5), Time{1'500'000'000});
EXPECT_EQ(microseconds_to_time(1.0004), Time{1000});   // rounds down
EXPECT_EQ(microseconds_to_time(1.0006), Time{1001});   // rounds up
EXPECT_EQ(microseconds_to_time(0.0025), Time{3});      // .5 away from zero (llround, not lrint) [N10]
EXPECT_DOUBLE_EQ(time_to_seconds(Time{2'500'000'000}), 2.5);
EXPECT_DOUBLE_EQ(time_to_microseconds(Time{1500}), 1.5);

// ut_Geometry.cpp — TEST(GeometryTest, ...)
const Position origin{};
const Position northEast{.eastM = 3.0, .northM = 4.0, .upM = 0.0};
EXPECT_DOUBLE_EQ(distance_m(origin, northEast), 5.0);                         // DistanceIsEuclidean
// DirectionFromToMeasuresAzimuthFromNorthClockwise
EXPECT_NEAR(direction_from_to(origin, northEast).get_azimuthDeg(), 36.8699, 1e-4);
// DirectionFromToCardinalPoints: N→0, E→90, S→180, W→270 (elevación 0), EXPECT_NEAR 1e-4
// DirectionFromToReverseDiffersBy180: EXPECT_NEAR(az(B→A), fmod(az(A→B) + 180.0, 360.0), 1e-4) — nunca == [N2]
// DirectionFromToMeasuresElevation: {0,0,0}→{0,100,100} da elevación 45
// DirectionFromToStraightUp: {0,0,0}→{0,0,10} da azimut 0 y elevación 90 (sin NaN)

// ut_Propagation.cpp — TEST(PropagationTest, ...)
// PropagationDelayRoundsToNearestNs: 299.792458 m → 1000 ns; 0.1 m → 0 ns
// FreeSpacePathLossMatchesHandCalculation: (1000 m, 1e9 Hz) → 92.45 (EXPECT_NEAR 1e-9)
// WrapOffsetDegWrapsIntoHalfOpenRange: 358 → −2; −358 → 2; 180 → 180; −180 → 180; 10 → 10
```

`ut_Position.cpp`: los tests de un `struct` (`tests.md`): `static_assert` de agregado y trivialmente copiable, valores
por defecto, `to_string`, `==` (un caso por atributo) y `<<`.

- [ ] **Step 2:** compilar. Esperado: error de compilación (cabeceras inexistentes).
- [ ] **Step 3:** implementar (spec §2 y §4 paso 2). `direction_from_to` 👤. `time_to_seconds` y `time_to_microseconds` con
  `std::chrono::duration<double, …>` (Global Constraints).
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^SigInt\.(Units|Geometry)\.'`. Esperado: todos pasan.
- [ ] **Step 5:** commit `feat(sigint): add time units, ENU geometry and propagation functions`.

---

### Task 2: Completar `PulseDescriptorWords` e `IntrapulseModulation`

**Files:**
- Create: `src/SigInt/PulseDescriptors/include/IntrapulseModulation.h`, `.../src/IntrapulseModulation.cpp`,
  `.../tests/ut_IntrapulseModulation.cpp`
- Create: `src/SigInt/PulseDescriptors/include/PulseDescriptorWords.h`, `.../src/PulseDescriptorWords.cpp`,
  `.../tests/ut_PulseDescriptorWords.cpp` (el esqueleto con `dummy_` que había ya no existe en el árbol)

**Interfaces** (namespace `sigint`):
- `enum class IntrapulseModulation : std::uint8_t { None, Lfm, Nlfm, Bpsk, Barker, Fsk };`
- `std::string_view to_string(IntrapulseModulation iModulation);` → `"None"`, `"LFM"`, `"NLFM"`, `"BPSK"`,
  `"Barker"`, `"FSK"`.
- `std::optional<IntrapulseModulation> intrapulse_modulation_from_string(std::string_view iText);` (exacto, sensible a
  mayúsculas; `std::nullopt` si no coincide).
- `PulseDescriptorWords` (`struct`, trivialmente copiable), atributos en este orden: `std::uint64_t pulseId`,
  `Time toaNs`, `double frequencyHz`, `Time pulseWidthNs`, `float amplitudeDbm`, `AngleOfArrival aoa`,
  `IntrapulseModulation intrapulseModulation`. El `///<` de `amplitudeDbm` dice qué es: potencia de pico del pulso a la salida de la antena del receptor (spec §4
  paso 3) [D13]. `to_string` →
  `"[PulseId: {}, Toa: {}, Frequency: {}, PulseWidth: {}, Amplitude: {}, Aoa: {}, IntrapulseModulation: {}]"` (`Toa`
  y `PulseWidth` como número de ns, `Aoa` con `AngleOfArrival::to_string`).
- El comentario `@brief` de `PulseDescriptorWords` dice qué campos tiene un PDW y que el parámetro de la modulación
  queda aplazado (decisión 7).
- `PulseDescriptors` depende de `Units` (`Time`), en la misma librería: no hace falta tocar CMake.

**Trampa de lookup** [C3]: dentro de `PulseDescriptorWords::to_string`, una llamada no cualificada
`to_string(this->intrapulseModulation)` encuentra primero el miembro `to_string()`, se detiene y desactiva la
ADL: no compila. Llamar a `sigint::to_string(...)`. Fuera de la clase la ADL sí funciona.

- [ ] **Step 1: Tests que fallan.** `ut_IntrapulseModulation.cpp`: `ToStringReturnsCanonicalName` (los 6 valores),
  `FromStringParsesCanonicalName` (los 6), `FromStringRejectsUnknownText` (`"lfm"`, `""` → `nullopt`).
  `ut_PulseDescriptorWords.cpp`: tests de un `struct` para los 7 atributos (literales `float` con sufijo `f`).
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^SigInt\.PulseDescriptors\.'`. Esperado: todos pasan
  (incluidos los de `AngleOfArrival`).
- [ ] **Step 5:** commit `feat(sigint): add PulseDescriptorWords with simulator fields`.

---

### Task 3: Generadores de PRI (`SigInt/Emission`)

**Files:**
- Create: `src/SigInt/deps.cmake` con `proj_depends(LIBRARIES Core)` (primer uso de `core::check_contract`, S3).
- Create en `src/SigInt/Emission/`: `include/PriGenerator.h` + `src/PriGenerator.cpp` (interfaz), `FixedPri`,
  `StaggerPri`, `SlidingPri`, `DwellSwitchPri` (`include/`, `src/`, `tests/ut_*.cpp` cada una).
- Create en `src/SigInt/Emission/`: `include/PointeeEquality.h` (plantilla, solo cabecera) y
  `tests/ut_PointeeEquality.cpp`. Se incluye desde código de producción (Tareas 7 y 9), así que el lint estricto lo
  analiza (`tests.md`).

**Interfaces** (namespace `sigint`; P1, P2, P3 y S1-S3 de la decisión 2). Esquema sin banners ni Doxygen, que en el
código real van completos (`classes.md`):

```cpp
// PointeeEquality.h — true if both pointers are null, or both non-null and *iLhs == *iRhs
template <typename Pointer>
bool pointees_equal(const Pointer& iLhs, const Pointer& iRhs) noexcept;

class PriGenerator {
public:
  [[nodiscard]] virtual std::string to_string() const = 0;
  virtual Time next() = 0;                                   // PRI for the next pulse, advances the state
  [[nodiscard]] virtual std::unique_ptr<PriGenerator> clone() const = 0;   // copy with the same state
  virtual ~PriGenerator() = default;
  friend bool operator==(const PriGenerator& iLhs, const PriGenerator& iRhs) noexcept;  // typeid + is_equal
  friend std::ostream& operator<<(std::ostream& ioOs, const PriGenerator& iOther);     // delegates to to_string
protected:
  [[nodiscard]] virtual bool is_equal(const PriGenerator& iOther) const noexcept = 0;  // iOther has the same dynamic type
  PriGenerator& operator=(const PriGenerator& iOther) = default;
  PriGenerator& operator=(PriGenerator&& iOther) noexcept = default;
  PriGenerator() = default;
  PriGenerator(const PriGenerator& iOther) = default;
  PriGenerator(PriGenerator&& iOther) noexcept = default;
};
```

Implementaciones (`final`, Regla del Cero (P3), getters `const` de configuración y de estado y sin setters;
constructor de configuración y estado inicial en S1):

| Clase | Atributos (en orden) | Comportamiento de `next()` |
| --- | --- | --- |
| `FixedPri` | `Time valueNs_` | siempre `valueNs_` |
| `StaggerPri` | `std::vector<Time> valuesNs_`, `std::size_t index_` | `valuesNs_[index_ % size]`, cíclico |
| `SlidingPri` | `Time minNs_`, `Time maxNs_`, `Time stepNs_`, `Time currentNs_` | min, min+step, … mientras ≤ max; luego min |
| `DwellSwitchPri` | `std::vector<Time> valuesNs_`, `std::uint32_t pulsesPerDwell_`, `std::size_t index_`, `std::uint32_t pulsesInDwell_` | cada valor `pulsesPerDwell_` veces (cambio con `>=`), cíclico |

`clone()` = `std::make_unique<C>(*this)`; `is_equal` hace `dynamic_cast<const C&>(iOther)` (el tipo ya está comprobado)
y compara todos los atributos. `next()` usa directamente los atributos de estado (S2). Las precondiciones de
configuración (valores > 0 ns, min < max, paso > 0…) las garantiza el loader (Tarea 15). `next()` llama a
`core::check_contract` con una lista vacía (S3). `to_string`: por ejemplo
`StaggerPri` → `"[Values: [1000000, 1200000], Index: 0]"` (ns; lista unida a mano, decisión 2).

- [ ] **Step 1: Tests que fallan.** `ut_PointeeEquality.cpp` (`TEST(PointeeEqualityTest, …)`): dos nulos → `true`;
  uno nulo → `false`; dos `std::shared_ptr<const PriGenerator>` a `FixedPri{1000µs}` distintos en memoria → `true`;
  con `FixedPri{2000µs}` → `false`. En cada generador, los tests de `tests.md` para una `class` con Regla del Cero
  (`to_string`, getters, constructores, `==`, `<<`; la copia y el movimiento implícitos los validan los
  `static_assert`) y además
  (secuencias en µs):
  - `FixedPri{1000}` → 1000, 1000, 1000.
  - `StaggerPri{1000, 1200, 1100}` → 1000, 1200, 1100, 1000.
  - `SlidingPri{100, 130, 10}` → 100, 110, 120, 130, 100.
  - `SlidingPri{100, 125, 10}` → 100, 110, 120, 100 (no supera el máximo).
  - `DwellSwitchPri{{1000, 2000}, 3}` → 1000, 1000, 1000, 2000, 2000, 2000, 1000.
  - `CloneKeepsState`: avanzar 2, clonar, y el clon y el original devuelven el mismo siguiente valor; avanzar el clon
    no avanza el original.
  - `NextAbortsWhenValuesAreEmpty` en `StaggerPriDeathTest` y `DwellSwitchPriDeathTest` (objeto por defecto) [R2-A4].
  - En `ut_FixedPri.cpp`: `EqualityOperatorIsFalseForDifferentDerivedTypes` (`FixedPri{1000}` frente a
    `StaggerPri{{1000}}`, los dos como `const PriGenerator&`) (Review Focus 7).
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar. `operator==` de la base + `FixedPri::is_equal` 👤; el resto sigue el mismo patrón.
  `pointees_equal` también.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^SigInt\.Emission\.'`. Esperado: pasan.
- [ ] **Step 5:** commit `feat(sigint): add PRI generators`.

---

### Task 4: Generadores de RF y PW

**Files:**
- Create en `src/SigInt/Emission/`: `RfGenerator` (interfaz), `FixedRf`, `ListRf`, `PwGenerator` (interfaz),
  `FixedPw`, con sus `.h`, `.cpp` y `ut_*.cpp` (las interfaces sin `ut_`).

**Interfaces:** `RfGenerator` y `PwGenerator` siguen el patrón de `PriGenerator` (Tarea 3) con `double next_hz()`
(la unidad en el nombre, porque devuelve un `double` sin tipo) y `Time next()`.

| Clase | Atributos (en orden) | Comportamiento |
| --- | --- | --- |
| `FixedRf` | `double frequencyHz_` | siempre `frequencyHz_` |
| `ListRf` | `std::vector<double> frequenciesHz_`, `std::uint32_t pulsesPerHop_`, `std::size_t index_`, `std::uint32_t pulsesInHop_` | cada frecuencia `pulsesPerHop_` veces (cambio con `>=`), cíclico |
| `FixedPw` | `Time widthNs_` | siempre `widthNs_` |

- [ ] **Step 1: Tests que fallan:** los de `tests.md` (como en la Tarea 3) y además:
  - `FixedRf{3e9}` → 3e9, 3e9.
  - `ListRf{{1e9, 2e9, 3e9}, 2}` → 1e9, 1e9, 2e9, 2e9, 3e9, 3e9, 1e9.
  - `FixedPw{500ns}` → 500, 500.
  - `CloneKeepsState` en las tres.
  - `NextAbortsWhenFrequenciesAreEmpty` en `ListRfDeathTest` [R2-A4].
  - En `ut_FixedRf.cpp`: `EqualityOperatorIsFalseForDifferentDerivedTypes` (`FixedRf{1e9}` frente a
    `ListRf{{1e9}, 1}`) [R2-F9].
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^SigInt\.Emission\.'`. Esperado: pasan.
- [ ] **Step 5:** commit `feat(sigint): add RF and PW generators`.

---

### Task 5: `ScanSpec` y patrones de scan

**Files:**
- Create en `src/SigInt/Emission/`: `ScanSpec` (con el enum `ScanKind` y `to_string(ScanKind)` en su cabecera),
  `ScanPattern` (interfaz), `FixedScan`, `CircularScan`, `SectorScan`, con sus `.h`, `.cpp` y `ut_*.cpp`.

**Interfaces** (namespace `sigint`):
- `enum class ScanKind : std::uint8_t { Fixed, Circular, Sector };` · `std::string_view to_string(ScanKind iKind);`
  → `"Fixed"`, `"Circular"`, `"Sector"` [R2-C9].
- `ScanSpec` (`struct`, trivialmente copiable; parte intrínseca del scan, decisión 3): `ScanKind kind`, `Time periodNs`,
  `double elevationDeg`, `double widthDeg` (los dos últimos solo tienen sentido según el tipo).
- `ScanPattern` sigue el patrón de interfaz (Tarea 3) con
  `virtual AngleOfArrival pointing_at(Time iSinceSegmentStart) const = 0;`. Es inmutable y se comparte como
  `std::shared_ptr<const ScanPattern>`, así que no tiene `clone()` (P3).

| Clase | Atributos (en orden) |
| --- | --- |
| `FixedScan` | `AngleOfArrival pointing_` |
| `CircularScan` (solo horario) | `double initialAzimuthDeg_`, `Time periodNs_`, `double elevationDeg_` |
| `SectorScan` (bidireccional) | `double centerAzimuthDeg_`, `double widthDeg_`, `Time periodNs_`, `double elevationDeg_` |

`pointing_at` llama a `core::check_contract` si `periodNs_ <= 0` (S3) [R2-A4]. Los dos scans con periodo calculan la fase
reduciendo primero en enteros: `phase = std::chrono::duration<double>(t % T) / T` (en [0, 1)). Así un azimut de miles
de vueltas no pierde precisión al pasar a `float` [R2-N3]. **Ojo** [C8]: `(t % T) / T` con dos `nanoseconds` es una
división **entera** que vale 0 para todo `t < T`. Si se "arregla" con `static_cast<double>((t % T) / T)`, el aviso
desaparece y el scan se queda congelado.

- `CircularScan`: `az = initial + 360·phase`.
- `SectorScan::pointing_at` (spec §4, paso 1) 👤: con `left = center − width/2`: si `phase < 0.5`,
  `az = left + width·2·phase`; si no, `az = left + width·2·(1 − phase)`; resultado normalizado por `AngleOfArrival`.

- [ ] **Step 1: Tests que fallan:** los de `tests.md` en `ScanSpec` (`struct`) y en los tres scans (`class`), y además
  (ángulos con `EXPECT_NEAR(…, 1e-4)`; literales `float` con `f`) [C2]:
  - `ToStringReturnsKindName` para `ScanKind` (los 3).
  - `FixedScan{{216.87f, 0.0f}}` en t = 0 y t = 5 s → (216.87, 0).
  - `CircularScan{0, 6s, 2}`: t = 0 → 0°; t = 1.5 s → 90°; t = 6 s → 0°; elevación 2° siempre.
  - `CircularScan{350, 6s, 0}`, t = 0.5 s → 20° (cruza 360°, Review Focus 1).
  - `SectorScan{90, 60, 4s, 0}`: t = 0 → 60°; t = 1 s → 90°; t = 2 s → 120°; t = 3 s → 90°; t = 4 s → 60°.
  - `SectorScan{0, 20, 4s, 0}`: t = 0 → 350°; t = 1 s → 0°; t = 2 s → 10° (cruza 0°, Review Focus 1).
  - `PointingAtAbortsWhenPeriodIsZero` en `CircularScanDeathTest` y `SectorScanDeathTest` (objeto por defecto) [R2-A4].
  - En `ut_FixedScan.cpp`: `EqualityOperatorIsFalseForDifferentDerivedTypes` (`FixedScan` frente a `CircularScan`)
    [R2-F9].
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^SigInt\.Emission\.'`. Esperado: pasan.
- [ ] **Step 5:** commit `feat(sigint): add scan spec and fixed, circular and sector scan patterns`.

---

### Task 6: Diagrama de antena gaussiano

**Files:**
- Create en `src/SigInt/Emission/`: `AntennaPattern` (interfaz), `GaussianAntennaPattern` (`.h`, `.cpp`, `ut_`).

**Interfaces:** `AntennaPattern` sigue el patrón de interfaz con
`virtual double gain_dbi(double iOffsetAzDeg, double iOffsetElDeg) const = 0;`. Es inmutable y se comparte como
`std::shared_ptr<const AntennaPattern>`: sin `clone()` (P3).
`GaussianAntennaPattern` (`final`): atributos `double peakGainDbi_`, `double beamwidthAzDeg_`,
`double beamwidthElDeg_`, `double sidelobeLevelDb_`. El comentario de la clase recoge las limitaciones de la spec §4
paso 2 (desvíos en az/el, válido cerca del horizonte; suelo uniforme que representa el nivel **medio** de los lóbulos)
[A5, D15, R2-D1].

- [ ] **Step 1: Tests que fallan:** los de `tests.md` y además (`GaussianAntennaPattern{35, 2, 20, 30}`, con un
  comentario en el test: "valores de prueba, no físicos" [D1]; `EXPECT_NEAR(…, 1e-9)`):
  - desvío (0, 0) → 35.
  - (1, 0) → 32 (−3 dB a medio ancho en azimut).
  - (0, 10) → 32 (−3 dB a medio ancho en elevación).
  - (1, 10) → 29 (los dos ejes se suman).
  - (90, 0) → 5 (suelo: 35 − 30).
  - (−1, 0) → 32 (simétrico).
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar (fórmula de Global Constraints). 👤
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^SigInt\.Emission\.'`. Esperado: pasan.
- [ ] **Step 5:** commit `feat(sigint): add gaussian antenna pattern`.

---

### Task 7: `EmitterMode`, `EmittedPulse` e `IncidentPulse`

**Files:**
- Create en `src/SigInt/Emission/`: `EmitterMode`, `EmittedPulse`, `IncidentPulse` (`.h`, `.cpp`, `ut_` cada una).

**Interfaces** (namespace `sigint`; los tres son `struct` agregados, decisión 2):

| Tipo | Atributos (en orden) |
| --- | --- |
| `EmitterMode` (prototipo del catálogo, nunca avanza) | `double peakPowerDbm`, `IntrapulseModulation intrapulseModulation`, `std::shared_ptr<const PriGenerator> pri`, `std::shared_ptr<const RfGenerator> rf`, `std::shared_ptr<const PwGenerator> pw`, `ScanSpec scan`, `std::shared_ptr<const AntennaPattern> antenna` |
| `EmittedPulse` | `std::string emitterId`, `std::string modeId`, `std::size_t segmentIndex`, `std::uint64_t emitterPulseIndex`, `Time emissionTimeNs`, `double frequencyHz`, `Time pulseWidthNs`, `double peakPowerDbm`, `IntrapulseModulation intrapulseModulation`, `Position emitterPosition`, `AngleOfArrival beamDirection`, `std::shared_ptr<const AntennaPattern> antenna` |
| `IncidentPulse` | `EmittedPulse emitted`, `Time arrivalTimeNs`, `AngleOfArrival arrivalDirection` (receptor → emisor; la fija el canal) [R2-D4], `double distanceM`, `double txGainDbi` (G_tx hacia el receptor), `double isotropicPowerDbm` (P_tx + G_tx − FSPL) |

La modulación se llama `intrapulseModulation` en todos los tipos, como en el PDW, el JSON y el CSV [R2-F12, R2-C14].

Los generadores del prototipo son `shared_ptr<const …>` [A3, C16]. Como el `const` está en el **objeto apuntado**,
`mode.pri->next()` no compila (solo `clone()` es `const`), así que nadie puede avanzar el prototipo; y al ser
inmutables se pueden compartir al copiar el modo. `EmitterMode` y `EmittedPulse` definen `==` a mano con
`pointees_equal` (decisión 2): compara los objetos apuntados, no los punteros. `IncidentPulse` usa `= default`.

El comentario de clase de `EmittedPulse` e `IncidentPulse` separa los campos de **señal** (instantes, f, PW,
modulación, potencias, direcciones) de los de **verdad o contabilidad** (ids, índices, posición del emisor, antena,
distancia, G_tx), y avisa de que el procesado consume PDW, nunca estos pulsos (spec §3, decisión 8) [R2-D4].

- [ ] **Step 1: Tests que fallan:** los de `tests.md` para un `struct` en los tres. Además, en `ut_EmitterMode.cpp`:
  `EqualityOperatorComparesPointedGenerators` (dos modos con `FixedPri{1000}` distintos en memoria pero iguales en
  valor → `==` es `true`; con `FixedPri{2000}` → `false`) (Review Focus 7).
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^SigInt\.Emission\.'`. Esperado: pasan.
- [ ] **Step 5:** commit `feat(sigint): add emitter mode and pulse types`.

---

### Task 8: Librería de emisores (`SigInt/Library`)

**Files:**
- Create en `src/SigInt/Library/`: `EmitterType`, `Catalog` (`.h`, `.cpp`, `ut_` cada una).

**Interfaces** (namespace `sigint`) [R2-D2]:

| Tipo | Forma | Atributos (en orden) |
| --- | --- | --- |
| `EmitterType` | `struct` | `std::string name`, `std::map<std::string, std::shared_ptr<const EmitterMode>, std::less<>> modes` |
| `Catalog` | `class` (invariante: un tipo por nombre) | `std::map<std::string, EmitterType, std::less<>> types_` |

`std::less<>` hace que los `std::map` admitan `find(std::string_view)` (*heterogeneous lookup*) [C10]. `Catalog`
ofrece `Catalog() = default;`, `explicit Catalog(std::vector<EmitterType> iTypes);` (añade cada tipo con `add`), Regla del
Cero, `[[nodiscard]] const std::map<…>& get_types() const;` (sin setter: la invariante la mantiene `add`, y el
`@brief` lo dice),
`void add(EmitterType iType);` (precondición: el nombre no existe; el loader lo comprueba antes para dar su propio
mensaje, así que un duplicado aquí es un bug: `core::check_contract`, S3) y `const EmitterType* find(std::string_view iTypeName) const;` (`nullptr` si no existe).
`to_string` de los mapas: `[clave: valor, …]` unido a mano (decisión 2).

- [ ] **Step 1: Tests que fallan:** los de `tests.md` (`EmitterType` como `struct`, `Catalog` como `class`) y además
  `AddStoresType`, `AddAbortsWhenNameExists` (en `CatalogDeathTest`), `FindReturnsAddedType`, `FindReturnsNullptrWhenAbsent` [F14].
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^SigInt\.Library\.'`. Esperado: pasan.
- [ ] **Step 5:** commit `feat(sigint): add emitter library (types and catalogue)`.

---

### Task 9: Librería `Simulator`: `Segment` y `Emitter`

**Files:**
- Create: `src/Simulator/deps.cmake` con `proj_depends(LIBRARIES SigInt Core)`.
- Create en `src/Simulator/Emitter/`: `Segment`, `Emitter` (`.h`, `.cpp`, `ut_` cada una).

**Interfaces** (namespace `simulator`):

| Tipo | Atributos (en orden) |
| --- | --- |
| `Segment` (`struct`) | `std::string modeId` (`"off"` = silencio), `sigint::Time durationNs` (> 0), `std::shared_ptr<const sigint::EmitterMode> mode` (nulo si `off`), `std::shared_ptr<const sigint::ScanPattern> scan` (nulo si `off`; orientado por la misión) |
| `Emitter` (`class`) | configuración: `std::string id_`, `sigint::Position position_`, `sigint::Time startNs_`, `std::vector<Segment> schedule_`, `sigint::Time endNs_`; estado: `std::size_t segmentIndex_`, `sigint::Time segmentStartNs_`, `sigint::Time nextEmissionNs_`, `std::uint64_t pulseIndex_`, `std::unique_ptr<sigint::PriGenerator> pri_`, `std::unique_ptr<sigint::RfGenerator> rf_`, `std::unique_ptr<sigint::PwGenerator> pw_` |

`Emitter` (S1-S5): solo movible (Regla del Cero, S4) y sin `==`; getters `const` de todos los atributos (los de los
generadores devuelven `const I*`, S4), sin setters. Ofrece `std::optional<sigint::EmittedPulse> next();` (siguiente pulso en orden de emisión;
`nullopt` al terminar). Sus generadores activos son `unique_ptr` (estado propio, S4). Constructor de configuración y
estado inicial en S1.

**Contrato del estado** (comentario de la clase) [R2-A3]:
- `segmentIndex_ >= schedule_.size()` ⇒ terminado: `next()` devuelve `nullopt` **antes** de indexar.
- `pri_ == nullptr` ⇒ hay que entrar en el segmento `segmentIndex_`. Si es `off`, se salta al siguiente
  (`segmentStartNs_ += duración`, `++segmentIndex_`). Si tiene modo, se clonan `pri`, `rf` y `pw` del prototipo (así
  el estado empieza a cero) y `nextEmissionNs_ = segmentStartNs_`.
- Al salir de un segmento: `segmentStartNs_ += duración`, `++segmentIndex_` y los generadores vuelven a nulo.

Comportamiento de `next()` (spec §4 paso 1) 👤:
- El segmento k ocupa `[segmentStartNs_, segmentStartNs_ + duración_k)`.
- Pulso en t = `nextEmissionNs_`: `f = rf->next_hz()`, `pw = pw->next()`, `beam = scan->pointing_at(t −
  segmentStartNs_)`, siguiente `nextEmissionNs_ += pri->next()`. `next()` usa directamente los atributos de estado
  (`pri_->next()`, decisión 2, S2) [R2-A1].
- Si el siguiente t ≥ fin del segmento, se pasa al siguiente segmento.
- Nunca se devuelve un pulso con t ≥ `endNs_`.
- `emitterPulseIndex` cuenta desde 0 en todo el emisor, sin reiniciarse por segmento; `segmentIndex` es la posición
  del segmento en el calendario.
- Una PRI ≤ 0 es un bug (`core::check_contract`, S3): se para el programa y no se entra en un bucle infinito, también
  en Release [A1, R2-A14]. Death test `NextAbortsWhenPriIsNotPositive`.

- [ ] **Step 1: Tests que fallan.** `ut_Segment.cpp`: los de `tests.md` para un `struct`; en `==`, dos segmentos con
  modos iguales en valor creados por separado son iguales. `ut_Emitter.cpp`: los de `tests.md` para una `class` solo
  movible con Regla del Cero (`static_assert(!std::is_copy_constructible_v<Emitter>)` y los de movimiento `noexcept`,
  getters, constructores y `<<`; el movimiento implícito no tiene test) y además. Modo de prueba: `FixedPri{1ms}`, `FixedRf{3e9}`, `FixedPw{1µs}`,
  `FixedScan{{0.0f, 0.0f}}`. Salvo que se diga otra cosa: inicio 5 ms, un segmento de 100 ms y fin 100 ms [N6].
  Pulsos obtenidos con `next_or_fail` (decisión 2).
  - `NextStartsAtSegmentStart`: el primer pulso tiene `emissionTimeNs == 5ms`, índice 0 y `segmentIndex` 0.
  - `NextAdvancesByPri`: el segundo tiene 6 ms e índice 1.
  - `NextAdvancesStaggerPri` [R2-C2]: modo con `StaggerPri{1,2,3 ms}`, inicio 0 → 0, 1, 3, 6 ms. Si el estado de la
    PRI no avanzara, saldría 0, 1, 2, 3.
  - `NextFillsPulseFromMode`: f, PW, potencia, modulación, posición, `modeId`, `emitterId` y antena del pulso.
  - `NextSkipsOffSegment`: [modo 2.5 ms, off 2 ms, modo 2 ms], fin 100 ms → instantes 5, 6, 7, 9.5, 10.5 ms;
    `segmentIndex` 0, 0, 0, 2, 2.
  - `NextResetsStateOnModeChange`: modo con `StaggerPri{1,2,3 ms}`, segmentos de 2.5 ms y 4 ms → 5, 6 | 7.5, 8.5, 10.5 ms
    (el tercer pulso caería en 8 ms, fuera del primer segmento; el segundo empieza en 7.5 y reinicia la secuencia).
  - `NextPulseOnSegmentBoundaryBelongsToNextSegment` (Review Focus 3): segmentos A de 2 ms y B (10 ms) con modos de
    distinto `modeId` → el pulso en 7 ms tiene `modeId` de B.
  - `NextStopsAtEnd`: segmento de 10 ms (acaba en 15 ms) y fin 8 ms → pulsos 5, 6, 7 ms y luego `nullopt`; un pulso
    en exactamente 8 ms no se emite.
  - `NextUsesScanRelativeToSegmentStart`: con `CircularScan{0, 4ms, 0}` el pulso en 6 ms apunta a 90°.
  - `NextDoesNotShareStateBetweenEmittersOfSameMode` (Review Focus 6) [A3]: dos `Emitter` con el **mismo**
    `shared_ptr<const EmitterMode>` (`StaggerPri{1,2,3 ms}`), inicio 0; intercalar llamadas a `next()` → ambos dan
    0, 1, 3, 6 ms.
  - `NextReturnsNulloptWhenAllSegmentsOff` [A14]: calendario [off 5 ms] → `nullopt` en la primera llamada.
  - `NextReturnsNulloptWhenStartAfterEnd` [A14]: inicio 5 ms, fin 5 ms → `nullopt`.
  - `NextOnDefaultEmitterReturnsNullopt` y `NextWithSegmentIndexPastEndReturnsNullopt` [R2-A3].
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^Simulator\.Emitter\.'`. Esperado: pasan. Lint.
- [ ] **Step 5:** commit `feat(simulator): add Simulator library with segment schedule and emitter`.

---

### Task 10: Canal de propagación

**Files:**
- Create: `src/Simulator/Channel/include/PropagationChannel.h`, `src/PropagationChannel.cpp`,
  `tests/ut_PropagationChannel.cpp`.

**Interfaces** (namespace `simulator`; módulo de funciones libres, M1: sin estado no hace falta una clase):
`sigint::IncidentPulse propagate(const sigint::EmittedPulse& iPulse, const sigint::Position& iReceiverPosition);`
que usa las funciones de `sigint` de la Tarea 1 y rellena todos los campos de `IncidentPulse`, incluida la dirección
de llegada (spec §4 paso 2) [R2-D4].

- [ ] **Step 1: Tests que fallan** (`TEST(PropagationChannelTest, …)`; antena `{35, 2, 20, 30}` con el comentario "valores de
  prueba, no físicos" [R2-D6]; ganancias y potencias con `EXPECT_NEAR(…, 1e-6)`):
  - `PropagateComputesArrivalTime`: emisor en (0, 299.792458, 0), receptor en el origen, t_e = 1 ms → t_a = 1 ms +
    1000 ns.
  - `PropagateComputesArrivalDirection` [R2-D4]: emisor en (3, 4, 0), receptor en el origen → dirección de llegada
    36.8699° (`EXPECT_NEAR` 1e-4), elevación 0.
  - `PropagateComputesTxGainFromBeamOffset`: emisor en el origen, receptor al Este (1000, 0, 0), haz a 89° →
    `txGainDbi` = 32.
  - `PropagateWrapsBeamOffset` (Review Focus 2) [N4]: emisor en el origen, receptor en
    `{1000·sin(1°), 1000·cos(1°), 0}` (az 1° exacto en `float`), haz a (359°, 0) → `txGainDbi` = 35 − 12·(2/2)² = 23.
  - `PropagateComputesIsotropicPower`: P_tx 90, ganancia 35 (haz centrado), d = 1000, f = 1e9 →
    `isotropicPowerDbm` = 90 + 35 − 92.45 = 32.55.
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar (spec §4 paso 2).
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^Simulator\.Channel\.'`. Esperado: pasan.
- [ ] **Step 5:** commit `feat(simulator): add propagation channel`.

---

### Task 11: Registro de salida y escritor CSV

**Files:**
- Create en `src/Simulator/Receiver/`: `GroundTruth`, `PulseRecordWriter` (interfaz, sin `ut_`),
  `CsvPulseRecordWriter` (`.h`, `.cpp`, `ut_` cada una).

**Interfaces** (namespace `simulator`):

| Tipo | Atributos (en orden) |
| --- | --- |
| `GroundTruth` (`struct`) | `std::string emitterId`, `std::string modeId`, `std::size_t segmentIndex`, `std::uint64_t emitterPulseIndex`, `sigint::Time emissionTimeNs`, `double distanceM`, `sigint::AngleOfArrival trueAoa`, `double txGainDbi`, `double eirpDbm` |
| `CsvPulseRecordWriter` (`class`, `final`) | `std::ostream* stream_` (no poseído; S4) |

`PulseRecordWriter` sigue el patrón de interfaz (P1) con
`virtual void write(const sigint::PulseDescriptorWords& iPdw, const GroundTruth& iTruth) = 0;`, sin `==` ni `is_equal`
(S5). El constructor de configuración `explicit CsvPulseRecordWriter(std::ostream& oStream)` escribe la cabecera; el
constructor por defecto, no (S1). Getter `const` de `stream_`, sin setter. `write` con `stream_` nulo es un bug
(`core::check_contract`, S3).

Cabecera exacta (spec §6, 18 columnas):

```
pulseId,toaNs,frequencyMHz,pulseWidthUs,amplitudeDbm,azimuthDeg,elevationDeg,intrapulseModulation,truth_emitterId,truth_modeId,truth_segmentIndex,truth_emitterPulseIndex,truth_emissionNs,truth_distanceM,truth_azimuthDeg,truth_elevationDeg,truth_txGainDbi,truth_eirpDbm
```

Formatos de `std::format` (sin `L`, así el separador es siempre `.`): enteros sin decimales; `frequencyMHz` `{:.6f}`;
`pulseWidthUs` `{:.3f}`; `amplitudeDbm`, `truth_txGainDbi` y `truth_eirpDbm` `{:.2f}`; ángulos `{:.4f}`;
`truth_distanceM` `{:.3f}`. Fin de línea `\n`. Tras formatear [A9]: un azimut (medido o verdadero) cuyo texto sea
`360.0000` se escribe `0.0000`; cualquier valor cuyo texto sea un cero negativo (`-0.0000`, `-0.00`) se escribe sin el
signo.

- [ ] **Step 1: Tests que fallan:** los de `tests.md` en `GroundTruth` (`struct`) y en `CsvPulseRecordWriter` (`class`
  sin `==` y con Regla del Cero: `to_string`, getter, constructores y `<<`). Además, en `ut_CsvPulseRecordWriter.cpp` (con
  `std::ostringstream`):
  - `ConstructorWritesHeader`: el flujo contiene exactamente la cabecera + `\n`.
  - `WriteFormatsRow`: PDW {7, 83391 ns, 3e9 Hz, 1000 ns, −9.95f dBm, (36.87f, 0.05f), None} y verdad {E1, search, 0,
    3, 0 ns, 25000.008, (36.87f, 0.05f), 30.0, 120.0} (valores del ejemplo de la spec §4) [R2-D6] → segunda línea
    `7,83391,3000.000000,1.000,-9.95,36.8700,0.0500,None,E1,search,0,3,0,25000.008,36.8700,0.0500,30.00,120.00`.
  - `WriteWrapsAzimuthRoundedTo360` [A9]: AoA medido y verdadero con azimut `359.99997f` → las columnas `azimuthDeg` y
    `truth_azimuthDeg` son `0.0000`.
  - `WriteDoesNotPrintNegativeZero` [A9]: elevación `-0.00003f` y amplitud `-0.004f` → `0.0000` y `0.00`.
  - `WriteAbortsWhenStreamIsNull` [R2-A4] (en `CsvPulseRecordWriterDeathTest`): escritor por defecto → aborta.
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^Simulator\.Receiver\.'`. Esperado: pasan.
- [ ] **Step 5:** commit `feat(simulator): add CSV pulse record writer`.

---

### Task 12: Receptor

**Files:**
- Create: `src/Simulator/Receiver/include/Receiver.h`, `src/Receiver.cpp`, `tests/ut_Receiver.cpp`.

**Interfaces** (namespace `simulator`): atributos `std::string id_`, `sigint::Position position_`, `double gainDbi_`,
`double sensitivityDbm_`, `PulseRecordWriter* writer_` (no poseído, S4), `std::uint64_t nextPulseId_` (estado, S1-S2).
Getters `const` de todos los atributos, también `nextPulseId_` (S2); sin setters. Regla del Cero. Ofrece
`void receive(const sigint::IncidentPulse& iPulse);` (detecta, mide, escribe).

- `P_rx = isotropicPowerDbm + gainDbi`; se detecta si `P_rx ≥ sensitivityDbm`. `amplitudeDbm` del PDW =
  `static_cast<float>(P_rx)`.
- AoA medido = `measure_aoa(iPulse.arrivalDirection)`, donde `measure_aoa` es una función libre en un namespace
  anónimo de `Receiver.cpp` (no usa el estado del receptor: como método la rechazaría
  `readability-convert-member-functions-to-static`) y hoy devuelve su entrada
  (modelo de error 0). El receptor no reconstruye la geometría (spec §3, decisión 4) [R2-D4].
- `pulseId` empieza en 0 y solo avanza con los pulsos detectados (`++nextPulseId_`, decisión 2, S2).
- `GroundTruth`: `segmentIndex` del pulso, `txGainDbi` del `IncidentPulse`, `eirpDbm = peakPowerDbm + txGainDbi`,
  `trueAoa` = la dirección de llegada.
- `receive` con `writer_` nulo es un bug (`core::check_contract`, S3).

- [ ] **Step 1: Tests que fallan:** los de `tests.md` (`to_string`, getters, constructores, `==`, `<<`) y además
  (doble de prueba `RecordingWriter` en un `namespace {}` del
  propio test, que guarda las llamadas; receptor con G = 3 y sensibilidad −70):
  - `ReceiveDropsPulseBelowSensitivity`: P_iso −73.01 → 0 escrituras.
  - `ReceiveKeepsPulseAtSensitivity`: P_iso −73 → 1 escritura con `amplitudeDbm` −70.
  - `ReceiveKeepsPulseAboveSensitivity` [F7]: P_iso −50 → 1 escritura con `amplitudeDbm` −47.
  - `ReceiveFillsPdwFromPulse`: TOA = `arrivalTimeNs`, f, PW, modulación y AoA = dirección de llegada del pulso
    (36.87f, 0.05f).
  - `ReceiveFillsGroundTruth`: ids, `segmentIndex`, índice, `emissionTimeNs`, `distanceM`, `trueAoa`, `txGainDbi` =
    32, `eirpDbm` = 90 + 32 = 122.
  - `ReceiveNumbersDetectedPulsesOnly`: detectado, descartado, detectado → `pulseId` 0 y 1.
  - `ReceiveAbortsWhenWriterIsNull` [R2-A4] (en `ReceiverDeathTest`): receptor por defecto → aborta.
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^Simulator\.Receiver\.'`. Esperado: pasan.
- [ ] **Step 5:** commit `feat(simulator): add receiver with sensitivity and AoA measurement`.

---

### Task 13: Planificador de eventos

**Files:**
- Create: `src/Simulator/Engine/include/EventScheduler.h`, `src/EventScheduler.cpp`, `tests/ut_EventScheduler.cpp`.

**Interfaces** (namespace `simulator`; S5): atributos `std::vector<Event> events_` (heap), `std::uint64_t
nextSequence_`, `sigint::Time currentTimeNs_`; `Event` es un `struct` anidado privado (`sigint::Time at{};
std::uint64_t sequence{}; std::function<void()> action{};`) declarado al principio de la clase. Además de
`get_currentTimeNs()`:

```cpp
void schedule(sigint::Time iAt, std::function<void()> iAction);  // precondition iAt >= current time (check_contract)
void run_all();                                                   // until empty; actions may schedule more events
[[nodiscard]] bool empty() const;
```

`events_` se mantiene como heap con `std::push_heap`/`std::pop_heap` y un comparador que lo convierte en min-heap por
`(at, sequence)`. 👤 Se descarta `std::priority_queue` porque `top()` devuelve `const&` [C5]:

- El orden del bucle importa: `std::pop_heap(...)`, **mover** el evento desde `back()`, `pop_back()`, actualizar
  `currentTimeNs_` y **después** ejecutar la acción. Si se ejecuta la acción mientras el evento sigue en el
  contenedor, los `schedule` que haga la acción pueden realocar el vector y dejar la referencia colgando (ASan lo
  detecta).
- Copiar el evento en lugar de moverlo copiaría el `std::function` (y el pulso que captura) en cada evento.
- Dentro de `run_all`, `events_` se usa directamente (estado interno, decisión 2, S2) [R2-A1].

- [ ] **Step 1: Tests que fallan:** los de `tests.md` para una `class` solo movible y sin `==`
  (`static_assert(!std::is_copy_constructible_v<EventScheduler>)`, constructor por defecto, movimiento —comprobando
  `empty()`, `get_currentTimeNs()` y el resultado de `run_all()`— y `<<`) y además:
  - `RunAllExecutesInTimeOrder`: programar en 3, 1, 2 → ejecución 1, 2, 3.
  - `RunAllBreaksTiesByInsertionOrder`: A y B en t = 5 → A, B.
  - `RunAllExecutesEventsScheduledDuringRun`: la acción en t = 1 programa **100** eventos en t = 2…101 (fuerza
    realocaciones) → se ejecutan todos, en orden [C5].
  - `GetCurrentTimeNsReturnsTimeOfCurrentEvent`: dentro de la acción en t = 7, `get_currentTimeNs()` == 7.
  - `ScheduleAbortsWhenTimeIsInThePast` (en `EventSchedulerDeathTest`): dentro de la acción en t = 5, `schedule(4, …)`
    aborta.
  - `EmptyIsTrueAfterRunAll`.
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^Simulator\.Engine\.'`. Esperado: pasan. Lint.
- [ ] **Step 5:** commit `feat(simulator): add discrete event scheduler`.

---

### Task 14: `ReceiverSpec`, `Mission` y `Simulation`

**Files:**
- Create en `src/Simulator/Engine/`: `ReceiverSpec`, `Mission`, `Simulation` (`.h`, `.cpp`, `ut_` cada una).

**Interfaces** (namespace `simulator`):

| Tipo | Atributos (en orden) |
| --- | --- |
| `ReceiverSpec` (`struct`) | `std::string id`, `sigint::Position position`, `double gainDbi`, `double sensitivityDbm` |
| `Mission` (`struct`, solo movible, sin `==`) | `sigint::Time durationNs`, `ReceiverSpec receiver`, `std::vector<Emitter> emitters` |
| `Simulation` (`class`, S5) | `Mission mission_`, `Receiver receiver_`, `EventScheduler scheduler_` |

`Simulation(Mission iMission, PulseRecordWriter& oWriter)` construye en la lista de inicialización `mission_` (moviendo
`iMission`) y después `receiver_` a partir de **`mission_`**, nunca de `iMission`, que ya está movida (`mission_` se
declara antes) [R2-A9]. Ofrece `void run();` y ningún accesor de escritura (S5).

Flujo (spec §4) [R2-A7, R2-F3]:
- `run()` (no el constructor) pide a cada emisor su primer pulso y, si lo hay, programa un **Emit** con ese pulso en su
  `emissionTimeNs`.
- La acción Emit captura `[this, index, pulse = std::move(pulse)]`. Al ejecutarse: `propagate(pulse, …)` → programar
  **Arrival** con el `IncidentPulse` en su `arrivalTimeNs` → pedir al mismo emisor su siguiente pulso → si existe,
  programar otro Emit con él.
- La acción Arrival captura `[this, incident = std::move(incident)]` y llama al `receive` del receptor.
- Dentro de las acciones, los atributos se usan directamente (estado interno, decisión 2, S2):
  `mission_.emitters[index].next()`, `scheduler_.schedule(…)`, `receiver_.receive(…)` [R2-A1].
- Las lambdas nunca capturan referencias a variables locales ni a elementos sueltos [A7, C14].
  `mission_.emitters` no cambia de tamaño durante `run()`.
- `run()` termina cuando la cola está vacía.

- [ ] **Step 1: Tests que fallan:** en `ReceiverSpec`, los de `tests.md` para un `struct`. En `Mission` (`struct` solo
  movible y sin `==`): `static_assert` de agregado (no el de no copiable, decisión 2, S4), valores por defecto,
  `to_string` y `<<`. En
  `ut_Simulation.cpp`, los de `tests.md` para una `class` no copiable ni movible (`static_assert`, constructores y
  `<<`) y además:
  - Condiciones comunes [N8, R2-N4]: doble `RecordingWriter`; emisores con `FixedRf{1e9}`, `FixedPw{1µs}`, P_tx 0 dBm
    y antena `{0, 2, 20, 0}` (SLL 0: la ganancia vale 0 dBi en cualquier dirección); receptor en el origen con G
    0 dBi y sensibilidad −200 dBm, para que todo se detecte.
  - Cada emisor tiene un único segmento de 1 s y su fin (`endNs`) igual a la duración de la misión, y está en
    `(0, d, 0)`. PRI `FixedPri{1ms}` salvo que se diga otra cosa.
  - `RunDeliversEveryPulse`: un emisor a 299.792458 m, duración 3.5 ms, inicio 0 → 4 registros con TOA 0, 1, 2,
    3 ms + 1000 ns y `pulseId` 0, 1, 2, 3 [R2-A1].
  - `RunAdvancesEmitterState` [R2-A1]: emisor con `StaggerPri{1,2,3 ms}` a 299.792458 m, duración 7 ms → TOA 0, 1, 3,
    6 ms + 1000 ns. Si el estado del emisor no avanzara, el test se colgaría (el `--timeout` lo convierte en fallo)
    o repetiría TOA.
  - `RunOrdersByArrivalTime`: duración 0.5 ms; emisor A a 2998 m (retardo 10 000 ns) inicio 0; B a 299.792458 m
    inicio 5 µs → exactamente dos registros: el primero de B (llega a 6 µs), el segundo de A (10 µs).
  - `RunDeliversPulsesInFlightAfterEnd` [N1]: duración **5 µs**, emisor a 2998 m → solo se emite en t = 0 (el
    siguiente, en 1 ms, cae fuera), llega en 10 000 ns > 5000 ns y se registra: exactamente un registro con TOA
    10 000. Una implementación que dejase de procesar eventos en `t ≥ duración` fallaría.
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^Simulator\.Engine\.'`. Esperado: pasan.
- [ ] **Step 5:** commit `feat(simulator): add simulation engine`.

---

### Task 15: nlohmann/json, `ConfigError`, `JsonReader` y loader del catálogo

**Files:**
- Modify: `.cmake/dependencies.cmake` (añadir nlohmann/json), `src/Simulator/deps.cmake`.
- Create en `src/Simulator/Config/`: `ConfigError` (`.h`, `.cpp`, `ut_`); `include/CatalogLoader.h` +
  `src/CatalogLoader.cpp` + `tests/ut_CatalogLoader.cpp` (funciones libres); `src/JsonReader.h` +
  `src/JsonReader.cpp` (privado, sin `ut_`: decisión 2).

**Dependencia** [C12]. En `.cmake/dependencies.cmake`, **fuera** del `if(PROJ_ENABLE_TESTS)` (la necesita la
librería, también con `-DBUILD_TESTING=OFF`):

```cmake
# nlohmann/json, used by the Simulator's Config component. Always downloaded (no FIND_PACKAGE) so every machine builds
# against the same 3.12.0; its headers are marked as system headers so the project's warnings do not apply to them.
set(JSON_SystemInclude ON CACHE BOOL "" FORCE)
proj_fetch_external(nlohmann_json
  URL "https://github.com/nlohmann/json/releases/download/v3.12.0/json.tar.xz")
```

```cmake
# src/Simulator/deps.cmake
proj_depends(LIBRARIES SigInt Core PRIVATE_EXTERNAL nlohmann_json::nlohmann_json)
```

Sin `FIND_PACKAGE`, porque `proj_fetch_external` no admite versión y un `nlohmann-json3-dev` del sistema (3.11.x) se
usaría en silencio.

**Interfaces** (namespace `simulator`):
- `ConfigError` (hereda de `std::runtime_error`; decisión 2): atributo `std::vector<std::string> errors_`; `what()` =
  errores unidos por `\n`. Su `==` se escribe a mano comparando `errors_`: el `= default` quedaría borrado porque
  `std::runtime_error` no tiene `==`.
- Funciones libres:

```cpp
// Parse already-read files (name, content); throws ConfigError with every error found.
sigint::Catalog parse_catalog(const std::vector<std::pair<std::string, std::string>>& iFiles);
// Reads every regular *.json file (exact extension) in iDirectory, sorted by name, and calls parse_catalog.
sigint::Catalog load_catalog(const std::filesystem::path& iDirectory);
```

**`JsonReader`** (privado) 👤: envuelve un `nlohmann::json` con su ruta y una lista de errores compartida. Ofrece
lecturas tipadas que, ante una clave ausente, un tipo incorrecto o un rango inválido, añaden el error y devuelven
`std::nullopt` en lugar de lanzar. Un método `finish()` añade un error por cada clave no leída (claves desconocidas).

- **Lecturas:**
  - `number`: rechaza no finitos con `std::isfinite`. Es una defensa: desde un fichero JSON el parser ya rechaza
    `1e400` (R2-N1).
  - `time(clave, unidad)` [A1, R2-A5]: (1) `≤ 0` → `debe ser > 0`; (2) límite superior **en `double`**, antes de
    convertir; (3) conversión con `llround`; (4) `0 ns` → `debe ser > 0 tras redondear a 1 ns`.
  - `non_negative_time`: para `startS`.
  - `positive_integer` [A4, C11]: exige `is_number_integer()` y comprueba el rango [1, 2³² − 1] **antes** de convertir a
    `std::uint32_t` (`get<uint32_t>()` truncaría `2.5` y daría la vuelta a `-1`).
  - `number_in_range(clave, min, max, extremos, texto)` [R2-F4, R2-N5]: los extremos indican si cada uno está incluido
    (`[`) o excluido (`(`), y `texto` es el intervalo tal como sale en el mensaje.
  - `string`, `id` (`[A-Za-z0-9_-]+`), `object`, `array`.
  - `position` [F5, A6]: lista de exactamente 3 números finitos, cada uno en [−10⁸, 10⁸].
  - Cada elemento de una lista se valida con su ruta (`valuesUs[1]`).
- **Acceso a claves solo con `find()`/`contains()`**, comprobando antes `is_object()`. `operator[]` está prohibido en
  `JsonReader`: sobre un `const json` con una clave ausente no lanza, es un `assert` (aborta en Debug, UB en Release)
  [C6].
- **Excepciones de nlohmann:** toda llamada que pueda lanzar (`parse`, `get<T>`) se hace dentro de un `try` que captura
  **`nlohmann::json::exception`** (la base) y la convierte en error. Capturar solo `parse_error` dejaría escapar el
  `out_of_range.406` que lanza el parser con `1e400` [R2-N1].

**Formato de los errores** [F10]: `<fichero>: <ruta>: <mensaje>`.
- `<fichero>` es el **nombre base** (`demo_01.json`), también en `load_catalog`/`load_mission`.
- `<ruta>` sin punto inicial en la raíz (`type`, `modes.search.pri.valueUs`), índices entre corchetes
  (`valuesUs[1]`, `positionM[2]`). El error de coherencia PW/PRI va en la ruta del modo (`modes.search`).
- Sin ruta (fichero entero): `<fichero>: <mensaje>`.

Mensajes fijos usados por los tests:

| Situación | Mensaje |
| --- | --- |
| Falta la clave | `falta la clave obligatoria` |
| Tipo incorrecto | `debe ser un número` / `debe ser un texto` / `debe ser un objeto` / `debe ser una lista` |
| Número no finito | `debe ser un número finito` |
| Entero que no lo es (`2.5`, `3.0`) | `debe ser un entero` |
| Valor ≤ 0 donde debe ser positivo | `debe ser > 0` |
| `startS` negativo | `debe ser >= 0` |
| Lista vacía | `no puede estar vacía` |
| Tiempo positivo que redondea a 0 ns | `debe ser > 0 tras redondear a 1 ns` |
| Tiempo demasiado grande | `debe ser <= 1000000 s` |
| Fuera de intervalo | `debe estar en <intervalo>` (intervalos fijos: `[1, 4294967295]`, `[30, 300000]`, `[-300, 300]`, `[0, 300]`, `[-90, 90]`, `[-360, 360]`, `(0, 360)`, `(0, 180]`, `[-1e8, 1e8]`) |
| `positionM` mal formada | `debe ser una lista de 3 números` |
| Clave no leída | `clave desconocida` |
| `kind` desconocido | `kind desconocido '<valor>'` |
| Modulación desconocida | `modulación desconocida '<valor>'` |
| Id inválido | `id inválido '<valor>': solo se admiten letras, dígitos, '_' y '-'` |
| Modo `off` en el catálogo | `'off' es un nombre de modo reservado` |
| Tipo repetido | `el tipo '<nombre>' está repetido` |
| `sliding` | `minUs debe ser menor que maxUs` |
| PW/PRI | `la PW máxima (<x> µs) debe ser menor que la PRI mínima (<y> µs)`, con `<x>`/`<y>` = `std::format("{}", time_to_microseconds(…))` (`900`, `1000.5`) [N7] |
| JSON roto (sin ruta) | `JSON mal formado: <mensaje de nlohmann>` |
| Disco (sin ruta) [A8] | `el catálogo '<dir>' no existe o no es una carpeta` / `el catálogo '<dir>' no contiene ningún fichero .json` / `no se puede leer el fichero` |

`load_catalog` envuelve todo acceso a disco (`directory_iterator`, lectura) en un `try` y convierte
`std::filesystem::filesystem_error` en `ConfigError` [A8].

- [ ] **Step 1: Tests que fallan.**
  - Los de `tests.md` en `ConfigError` (`to_string`, setter, getter, constructores, `==`, `<<`; Regla del Cero),
    además de
    `WhatJoinsErrorsWithNewline` y `SetErrorsUpdatesWhat` [R2-C7].
  - `ut_CatalogLoader.cpp` (JSON en raw strings dentro de un `namespace {}`; cada test de error comprueba que
    `get_errors()` contiene el texto exacto `"<fichero>: <ruta>: <mensaje>"`):
    - `ParseCatalogBuildsModes`: el ejemplo `SearchRadar_X` de la spec §5 → tipo encontrado con modos `search` y
      `track`; `search` tiene potencia 90, `ScanSpec` Circular con periodo 6 s; el primer
      `modes.at("search")->pri->clone()->next()` es 1000 µs.
    - `ParseCatalogConvertsMicrosecondsWithRounding` (Review Focus 4): `valueUs: 1.0006` → 1001 ns.
    - `ParseCatalogRejectsUnknownKey`: `frecuencyMHz` → `X.json: modes.search.rf.frecuencyMHz: clave desconocida`.
    - `ParseCatalogRejectsMissingKey`, `ParseCatalogRejectsWrongType` (`"periodS": "6"`),
      `ParseCatalogRejectsUnknownKind`.
    - `ParseCatalogRejectsNonPositiveValues` [R2-F11]: `valueUs: 0` → `X.json: modes.search.pri.valueUs: debe ser > 0`.
    - `ParseCatalogRejectsValueThatRoundsToZero` (Review Focus 4) [A1]: `valueUs: 0.0004` →
      `X.json: modes.search.pri.valueUs: debe ser > 0 tras redondear a 1 ns`.
    - `ParseCatalogRejectsPeriodThatRoundsToZero` [A1]: `periodS: 1e-10` → mismo mensaje en
      `modes.search.scan.periodS`.
    - `ParseCatalogRejectsTimeTooLarge` [A2]: `periodS: 1e7` → `debe ser <= 1000000 s`.
    - `ParseCatalogRejectsNumberOverflow` [R2-N1]: `peakPowerDbm: 1e400` → `ConfigError` con un único error que
      empieza por `X.json: JSON mal formado: ` y contiene `out_of_range.406`.
    - `ParseCatalogRejectsNegativeSidelobeLevel`, `ParseCatalogRejectsEmptyList` (`valuesUs: []`),
      `ParseCatalogRejectsNonNumericListElement` (`valuesUs: [1000, "1200"]` → ruta `…valuesUs[1]`),
      `ParseCatalogRejectsSlidingMinNotBelowMax`.
    - Enteros [A4, R2-N6]: `pulsesPerDwell: 2.5` y `pulsesPerDwell: 3.0` → `debe ser un entero`;
      `pulsesPerHop: -1`, `pulsesPerDwell: 0` y `pulsesPerDwell: 4294967296` → `debe estar en [1, 4294967295]`.
    - Rangos, con sus extremos [D4, A10, R2-F4, R2-F8, R2-A6, R2-D8]:
      - `elevationDeg: 95` → `debe estar en [-90, 90]`; `elevationDeg: 90` → válido.
      - `widthDeg: 0`, `360` y `400` → `debe estar en (0, 360)`.
      - `beamwidthAzDeg: 0` y `200` → `debe estar en (0, 180]`; `beamwidthAzDeg: 180` → válido.
      - `frequencyMHz: 3` y `frequenciesMHz: [3000, 0]` → `debe estar en [30, 300000]`.
      - `peakPowerDbm: 1e300` → `debe estar en [-300, 300]`.
    - `ParseCatalogRejectsPwNotBelowMinPri`: stagger [1000, 900], PW 900 →
      `X.json: modes.search: la PW máxima (900 µs) debe ser menor que la PRI mínima (900 µs)`.
    - `ParseCatalogRejectsPwEqualToPriAfterRounding` [A1]: `widthUs: 999.9996`, `valueUs: 1000.0004` (ambos 1000 ns)
      → error de coherencia.
    - `ParseCatalogRejectsReservedOffMode`, `ParseCatalogRejectsDuplicateType`, `ParseCatalogRejectsInvalidId`
      (`"type": "Radar X"`), `ParseCatalogRejectsInvalidModeName` (`"modes": {"se arch": …}`) [F16],
      `ParseCatalogRejectsUnknownModulation`.
    - `ParseCatalogRejectsMalformedJson` (Review Focus 5): contenido `{"type": ` → `X.json: JSON mal formado: …`.
    - `ParseCatalogAccumulatesErrors`: dos ficheros con un error cada uno → `get_errors().size() == 2`.
    - `LoadCatalogRejectsMissingDirectory`, `LoadCatalogRejectsPathThatIsAFile`, `LoadCatalogRejectsEmptyDirectory`
      → `ConfigError` (sin crash). `LoadCatalogIgnoresNonJsonFiles` [R2-F8]: un `.txt` y una subcarpeta junto a un
      `.json` válido → un tipo. Carpetas temporales con `std::filesystem::temp_directory_path()` y un nombre único por
      test.
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^Simulator\.Config\.'`. Esperado: pasan. Además,
  `grep -rln nlohmann src --include=*.h --include=*.cpp | grep -v '^src/Simulator/Config/src/'` no devuelve nada
  [R2-F14]. Lint.
- [ ] **Step 5:** commit `feat(simulator): add JSON catalogue loader with accumulated validation`.

---

### Task 16: Loader de la misión

**Files:**
- Create: `src/Simulator/Config/include/MissionLoader.h`, `src/MissionLoader.cpp`, `tests/ut_MissionLoader.cpp`
  (funciones libres).

**Interfaces** (namespace `simulator`):
- Consumes: `sigint::Catalog`, `JsonReader`, `Emitter`, `Segment`, scans de la Tarea 5, `Mission`.
- Produces:

```cpp
// Reads only "catalogDir" from a mission file's content. Throws ConfigError if absent or malformed.
std::string read_catalog_dir(std::string_view iFileName, std::string_view iContent);
// Builds the mission against iCatalog; throws ConfigError with every error found.
Mission parse_mission(std::string_view iFileName, std::string_view iContent, const sigint::Catalog& iCatalog);
// Reads the file, loads the catalogue (catalogDir relative to the file) and parses the mission.
Mission load_mission(const std::filesystem::path& iMissionFile);
```

- **Construcción del scan de cada segmento**: el `ScanSpec` del modo más los parámetros del segmento (spec §5):
  - `Circular` → `initialAzimuthDeg` en [−360, 360];
  - `Sector` → `centerAzimuthDeg` en [−360, 360];
  - `Fixed` → `pointingAzimuthDeg` en [−360, 360] y `pointingElevationDeg` en [−90, 90];
  - `off` → ninguno.

  Rutas de error con índices: `emitters[0].schedule[2].mode`.
- **Construcción de los emisores** con el constructor de configuración de `Emitter` (S1), con fin = duración de la
  misión.
- **Recorte** (spec §5 regla 7) [A2, R2-A12]: se deja de acumular la suma de inicios en cuanto alcanza la duración de
  la misión. Los segmentos siguientes se validan, pero ni se suman ni se añaden al calendario, así que la suma nunca
  pasa de `2·10⁶ s`.
- **Acumulación por fase** [F11]: `read_catalog_dir` → `load_catalog` → `parse_mission`; si una fase lanza, las
  siguientes no se ejecutan. `load_mission` convierte los errores de disco (misión inexistente o ilegible) en
  `ConfigError` [A8].
- Geometría: cada emisor a d ≥ 1 m del receptor [A13].

Mensajes adicionales:
- `el modo '<m>' no existe en el tipo '<t>'`
- `el tipo '<t>' no existe en el catálogo`
- `el id '<id>' está repetido`
- `el emisor está a menos de 1 m del receptor`
- `no se puede leer el fichero` (sin ruta)

- [ ] **Step 1: Tests que fallan** (catálogo construido con `parse_catalog` del ejemplo de la spec, en un
  `namespace {}`; pulsos con `next_or_fail`, decisión 2):
  - `ParseMissionBuildsEmittersAndReceiver`: el ejemplo de la spec §5 → duración 120 s, receptor en (0, 0, 10) con
    sensibilidad −70, un emisor `E1`; su primer `next()` sale en 5 s con `modeId` `search`.
  - `ParseMissionChainsSegmentsFromStart` [R2-A1]: sobre una referencia local a `mission.emitters[0]`, avanzar
    hasta el primer pulso con `modeId` `track`, en un `for` acotado (máximo 100 000 iteraciones y `FAIL()` si se
    agota) → instante 5 + 40 + 10 = 55 s y `segmentIndex` 2.
  - `ParseMissionRejectsUnknownMode`: `"trak"` → `demo.json: emitters[0].schedule[2].mode: el modo 'trak' no existe en
    el tipo 'SearchRadar_X'` (mensaje exacto de la spec §5).
  - `ParseMissionRejectsUnknownType`, `ParseMissionRejectsDuplicateEmitterId`,
    `ParseMissionRejectsMissingSegmentParameter` (circular sin `initialAzimuthDeg`),
    `ParseMissionRejectsExtraSegmentParameter` (`off` con `initialAzimuthDeg` → `clave desconocida`),
    `ParseMissionRejectsNegativeStart`, `ParseMissionRejectsNonPositiveDuration`,
    `ParseMissionRejectsWrongType` (`"durationS": "120"`, Review Focus 5).
  - `ParseMissionRejectsDurationBeyondInt64` [R2-A5]: `durationS: 1e10` → `durationS: debe ser <= 1000000 s`.
  - `ParseMissionRejectsEmitterTooCloseToReceiver` [A13]: emisor a 0.5 m.
  - `ParseMissionRejectsInvalidEmitterId`, `ParseMissionRejectsInvalidReceiverId` (`"E 1"`, `"RX,1"`) [F16].
  - `ParseMissionRejectsPositionWithWrongLength` (`[15000, 20000]` → `emitters[0].positionM: debe ser una lista de 3
    números`), `ParseMissionRejectsNonNumericPosition` (receptor `[0, "0", 10]`) [F5, A6],
    `ParseMissionRejectsPositionOutOfRange` (`[2e8, 0, 0]` → `emitters[0].positionM[0]: debe estar en [-1e8, 1e8]`)
    [R2-F8].
  - `ParseMissionRejectsPointingElevationOutOfRange` [D4]: `pointingElevationDeg: 200` → `debe estar en [-90, 90]`.
  - `ParseMissionRejectsAzimuthOutOfRange` [R2-A6]: `initialAzimuthDeg: 1e10` → `debe estar en [-360, 360]`.
  - `ParseMissionRejectsEmptySchedule` [F17, A14]: `"schedule": []` → `no puede estar vacía`.
  - `ParseMissionAcceptsEmptyEmitters` [F17, A14]: `"emitters": []` → sin error, ningún emisor.
  - `ParseMissionAcceptsScheduleBeyondDuration`: `durationS` 50 con el ejemplo → sin error; el último pulso sale
    antes de 50 s.
  - `ParseMissionAccumulatesErrors`: tres errores en sitios distintos → `size() == 3`.
  - `ReadCatalogDirReturnsValue`, `ReadCatalogDirRejectsMissingKey`.
  - `LoadMissionRejectsMissingFile` [F11, A8]: ruta inexistente → `ConfigError`.
  - `LoadMissionRejectsMissingCatalogDir` (Review Focus 5): `catalogDir` apunta a una carpeta inexistente →
    `ConfigError`.
- [ ] **Step 2:** compilar. Esperado: error de compilación.
- [ ] **Step 3:** implementar.
- [ ] **Step 4:** `ctest --preset ci-Debug --timeout 60 -R '^Simulator\.Config\.'`. Esperado: pasan.
- [ ] **Step 5:** commit `feat(simulator): add mission loader`.

---

### Task 17: `MissionRunner`, ejecutable, escenario de ejemplo y golden file

**Files:**
- Create: `src/Simulator/Runner/include/MissionRunner.h`, `src/MissionRunner.cpp`,
  `tests/ut_MissionRunner.cpp`, `tests/data/catalog/TestRadar_A.json`, `tests/data/catalog/TestRadar_B.json`,
  `tests/data/missions/golden.json`, `tests/data/expected/golden.csv`.
- Create: `scenarios/catalog/SearchRadar_X.json`, `scenarios/missions/demo_01.json` (ejemplos de la spec §5).
- Modify: `src/main.cpp`, `src/deps.cmake` (`proj_depends(LIBRARIES Simulator)`).

**Interfaces** (namespace `simulator`, función libre):

```cpp
// Runs an already loaded mission and writes the CSV (header + one row per detected pulse) to oOutput.
void run_mission(Mission iMission, std::ostream& oOutput);
```

`main(int argc, char* argv[])`: `ews <mision.json> <salida.csv>`, en este orden [F12]:
1. Comprobar los argumentos.
2. `load_mission`.
3. Abrir el `std::ofstream`.
4. `run_mission`.
5. `close()` y comprobar el flujo: si falló la escritura (disco lleno, error de E/S), mensaje y código 3 [R2-A15].

Así un `ConfigError` no deja un CSV vacío. El escritor y su flujo se declaran antes que la simulación y viven más que
ella. Códigos de salida (spec §5):
- 0 éxito;
- 1 `ConfigError` (cada error en `stderr`, uno por línea);
- 2 uso incorrecto (imprime `uso: ews <mision.json> <salida.csv>`);
- 3 no se puede abrir o escribir el fichero de salida;
- 4 cualquier otra `std::exception` (imprime `what()`) [C20].

**Misión golden** (todos los valores fijados [F9, D5, N5, N9]; los periodos están comprimidos a propósito para que la
salida sea corta, no son realistas):

`tests/data/catalog/TestRadar_A.json`:

```json
{
  "type": "TestRadar_A",
  "modes": {
    "search": {
      "peakPowerDbm": 74,
      "intrapulseModulation": "None",
      "pri":     { "kind": "stagger", "valuesUs": [1000, 1500] },
      "rf":      { "kind": "fixed", "frequencyMHz": 3000 },
      "pw":      { "kind": "fixed", "widthUs": 1.0 },
      "scan":    { "kind": "circular", "periodS": 0.05, "elevationDeg": 0 },
      "antenna": { "kind": "gaussian", "peakGainDbi": 16,
                   "beamwidthAzDeg": 30, "beamwidthElDeg": 30, "sidelobeLevelDb": 25 }
    }
  }
}
```

`tests/data/catalog/TestRadar_B.json`:

```json
{
  "type": "TestRadar_B",
  "modes": {
    "track": {
      "peakPowerDbm": 60,
      "intrapulseModulation": "LFM",
      "pri":     { "kind": "fixed", "valueUs": 700 },
      "rf":      { "kind": "list", "frequenciesMHz": [9000, 9100], "pulsesPerHop": 3 },
      "pw":      { "kind": "fixed", "widthUs": 0.5 },
      "scan":    { "kind": "fixed" },
      "antenna": { "kind": "gaussian", "peakGainDbi": 30,
                   "beamwidthAzDeg": 6, "beamwidthElDeg": 6, "sidelobeLevelDb": 50 }
    }
  }
}
```

`tests/data/missions/golden.json`:

```json
{
  "catalogDir": "../catalog",
  "durationS": 0.1,
  "receiver": { "id": "RX1", "positionM": [0, 0, 10], "gainDbi": 0, "sensitivityDbm": -60 },
  "emitters": [
    { "id": "A1", "type": "TestRadar_A", "positionM": [0, 30000, 30], "startS": 0,
      "schedule": [
        { "mode": "search", "durationS": 0.1, "initialAzimuthDeg": 0 }
      ] },
    { "id": "B1", "type": "TestRadar_B", "positionM": [20000, 0, 50], "startS": 0.002,
      "schedule": [
        { "mode": "track", "durationS": 0.04, "pointingAzimuthDeg": 270, "pointingElevationDeg": -0.1146 },
        { "mode": "off",   "durationS": 0.02 },
        { "mode": "track", "durationS": 0.04, "pointingAzimuthDeg": 270, "pointingElevationDeg": -0.1146 }
      ] }
  ]
}
```

Antenas coherentes con sus anchos de haz (30°×30° → 16 dBi; 6°×6° → 30 dBi) [D1] y con suelos por debajo de 0 dBi
(A −9 dBi, B −20 dBi) [R2-D1]. A está a 30 m de altura para que sea visible desde el receptor con la curvatura real
[D5]. B apunta exactamente al receptor también en elevación (−0.1146°), así su potencia no depende del ancho de haz
[N9]. El último segmento de B acaba en 0.102 s y se recorta.

- [ ] **Step 1: Test que falla:** `RunMissionMatchesGoldenFile`: ejecuta
  `run_mission(load_mission(data/missions/golden.json), ostringstream)` y compara byte a byte con
  `data/expected/golden.csv`. Las rutas se calculan con `std::filesystem::path(__FILE__).parent_path() / "data"`.
- [ ] **Step 2:** compilar y ejecutar. Esperado: falla (falta `run_mission` o falta `golden.csv`).
- [ ] **Step 3:** implementar `run_mission` y `main`; actualizar `src/deps.cmake`.
- [ ] **Step 4:** generar la referencia: `.build/ci-Debug/ews src/Simulator/Runner/tests/data/missions/golden.json
  src/Simulator/Runner/tests/data/expected/golden.csv`.
- [ ] **Step 5: Verificar la referencia a mano** antes de darla por buena (valores calculados aparte con las fórmulas
  de la spec por dos revisores independientes; si algo no cuadra, el fallo está en el código y no en la referencia):
  - 131 filas de datos, con `pulseId` de 0 a 130 consecutivos [R2-A1]: 18 de A1 y 113 de B1 (58 en el primer
    segmento `track`, 55 en el segundo, recortado).
  - A1: d = 30 000.007 m, retardo 100 069 ns; pico −41.53 dBm y suelo −66.53 dBm (< −60, por eso hay ráfagas). Dos
    ráfagas de 9 pulsos, con `toaNs` de 20 100 069 a 30 100 069 y de 70 100 069 a 80 100 069 (el haz pasa por 180°
    en 25 ms y 75 ms); `azimuthDeg` ≈ 0.
  - B1: d = 20 000.040 m, retardo 66 713 ns; primera fila con `toaNs` 2 066 713; `azimuthDeg` 90;
    `amplitudeDbm` −47.56 (9000 MHz) y −47.65 (9100 MHz); frecuencias en grupos de 3 (9000×3, 9100×3…), reiniciadas
    a 9000 al empezar el segundo segmento; ninguna fila con `truth_emissionNs` en [42 000 000, 62 000 000);
    `truth_segmentIndex` 0 y 2.
- [ ] **Step 6:** `ctest --preset ci-Debug --timeout 60`. Esperado: todos los tests del proyecto pasan. Compilación
  con clang, `format-check` y lint (sección Comandos).
- [ ] **Step 7:** ejecutar el ejemplo: `.build/ci-Debug/ews scenarios/missions/demo_01.json /tmp/demo.csv`. Esperado:
  código 0 y CSV con cabecera. Con un `catalogDir` erróneo en una copia: código 1, mensaje con fichero y ruta, y
  ningún CSV creado. Sin argumentos: código 2.
- [ ] **Step 8:** commit `feat(simulator): add ews executable, example scenario and golden test`.

Nota [A15, C21]: la referencia es válida para la toolchain de la CI. Si la comparación falla en otra plataforma por
un dígito en la última cifra, revisarlo antes de regenerar la referencia a ciegas.

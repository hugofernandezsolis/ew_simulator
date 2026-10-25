# Reglas de C++ basadas en las C++ Core Guidelines: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sustituir `how_to_write_a_class.md` por una guía de C++ basada en las C++ Core Guidelines (8 archivos en
`.claude/rules/cpp/`), con `clang-format` y `clang-tidy` configurados para comprobarla, y migrar `Dummy` y
`AngleOfArrival`.

**Architecture:** Primero se configuran las herramientas: `lint` falla sobre el código actual, y ese es el "test en
rojo". Después se migra cada clase con sus tests por delante hasta que `lint`, `format-check` y `ctest` pasan. Al final
se escriben los archivos de reglas con la lista de exclusiones ya cerrada, y se actualiza la memoria.

**Tech Stack:** C++23, GCC, CMake ≥ 3.25 + Ninja (presets), GoogleTest, clang-format 21, clang-tidy 21.

**Spec:** `docs/superpowers/specs/2026-10-25-cpp-core-guidelines-rules-design.md` (el contenido normativo de cada
regla está en su sección 4; este plan no lo repite).

## Global Constraints

- C++23 (`CMAKE_CXX_STANDARD 23`), sin extensiones del compilador.
- Nombres: tabla de la spec, sección 4.2 (camelCase, `get_`/`set_` + atributo, prefijos `i`/`o`/`io`, `_` final en
  los atributos privados).
- `.clang-tidy` mantiene `WarningsAsErrors: "*"` y `HeaderFilterRegex: "/ews/src/"`.
- Cada check excluido en `.clang-tidy` o en el target `lint` de los tests lleva un comentario con su motivo.
- Desviaciones de las CG permitidas, y solo estas: NL.1, NL.16, SF.8, C.4, ES.23 (relajada) e I.24.
- `#pragma once`, las 4 secciones de includes y la cabecera `@file` de cada archivo se mantienen.
- **No hacer commits** salvo petición explícita del usuario (`CLAUDE.md` del repo y reglas del harness). Los pasos de
  commit de este plan quedan como "preparar el diff para revisión".
- El repo está en `/home/hfernandezs/develop/ews`; los presets compilan en `.build/<Preset>/`.

## Review Focus

1. **Archivos de test de componentes futuros:** cualquier `src/<Lib>/<Comp>/tests/*.cpp` nuevo debe recibir la
   configuración relajada de `lint`, no la estricta. Se comprueba en la Tarea 1, paso 5.
2. **`QualifierAlignment: Left` reescribe código:** después de `format` el código debe compilar y comportarse igual.
   Se comprueba en la Tarea 1, paso 6.
3. **`readability-identifier-naming` frente a nombres impuestos desde fuera:** `main`, las clases que generan las
   macros `TEST_F` y los métodos de GoogleTest (`SetUp`) no deben dar avisos. Se comprueba en las Tareas 1 y 2.
4. **Cabeceras incluidas desde un test:** un `.h` de producción tiene que pasar la configuración **estricta** aunque
   también se incluya desde un test. Se comprueba en la Tarea 3, paso 6.
5. **El agregado no debe dejar de serlo:** si a `Dummy` se le añade un constructor, tiene que fallar la compilación,
   no un test en ejecución. Se comprueba en la Tarea 2, paso 1.

---

### Tarea 1: configuración de `clang-format`, `clang-tidy` y del target `lint`

**Files:**
- Modify: `.clang-format`
- Modify: `.clang-tidy`
- Modify: `.cmake/Tools.cmake:28-62` (función `proj_add_tools_targets`) y su comentario de cabecera

**Interfaces:**
- Produces: `.clang-tidy` con los grupos de la spec (5.2) y la convención de nombres; target `lint` que ejecuta
  `clang-tidy` dos veces: producción con la configuración del archivo y tests con `--checks=` adicional. Las tareas 2 y
  3 usan `cmake --build --preset Release --target lint` como test.

- [ ] **Paso 1: añadir a `.clang-format`** `QualifierAlignment: Left`, `SortIncludes: CaseSensitive` (sustituye al
  `SortIncludes: false` actual) e `InsertNewlineAtEOF: true`, con un comentario de una línea que cite NL.26 para
  `QualifierAlignment`.

- [ ] **Paso 2: reescribir `.clang-tidy`** con los `Checks` de la spec (5.2): grupos `bugprone-*`,
  `cppcoreguidelines-*`, `misc-*`, `modernize-*`, `performance-*`, `readability-*`, los checks sueltos
  `google-explicit-constructor`, `google-global-names-in-headers`, `hicpp-exception-baseclass` y las 6 exclusiones
  iniciales, cada una con su motivo. `CheckOptions` de `readability-identifier-naming`:

  | Opción | Valor |
  |---|---|
  | `ClassCase`, `StructCase`, `EnumCase`, `EnumConstantCase`, `TypeAliasCase`, `TypedefCase`, `ConceptCase`, `TemplateParameterCase` | `CamelCase` |
  | `NamespaceCase`, `FunctionCase`, `MethodCase` | `lower_case` |
  | `MethodIgnoredRegexp` | `'^(get|set)_[a-z][a-zA-Z0-9]*$'` |
  | `PrivateMemberCase`, `PublicMemberCase`, `ParameterCase`, `LocalVariableCase`, `VariableCase`, `ConstexprVariableCase`, `GlobalConstantCase` | `camelBack` |
  | `PrivateMemberSuffix` | `'_'` |
  | `MacroDefinitionCase` | `UPPER_CASE` |

- [ ] **Paso 3: separar los tests en `lint`** (`.cmake/Tools.cmake`). Dividir `lint_files` en `lint_test_files`
  (ruta que contiene `/tests/`, con `list(FILTER … INCLUDE REGEX "/tests/")`) y el resto. El target `lint` lleva dos
  `COMMAND`: el de producción, igual que ahora, y el de tests con
  `--checks=${PROJ_LINT_TEST_CHECKS}`, donde `PROJ_LINT_TEST_CHECKS` es una variable local con la lista de exclusiones
  para tests, separada por comas y con el motivo de cada una en un comentario CMake. Lista inicial:
  `-readability-magic-numbers,-cppcoreguidelines-avoid-magic-numbers,-cppcoreguidelines-avoid-non-const-global-variables,-cppcoreguidelines-owning-memory,-cppcoreguidelines-pro-type-vararg,-cppcoreguidelines-special-member-functions,-misc-use-anonymous-namespace,-misc-use-internal-linkage,-readability-function-cognitive-complexity`.
  Si no hay ficheros de un grupo, su `COMMAND` no se añade. Actualizar el comentario `###` de cabecera del módulo para
  explicar la separación y la limitación aceptada (`clangd` no la conoce).

- [ ] **Paso 4: comprobar que el test está en rojo**

  Run: `cmake --preset Release && cmake --build --preset Release --target lint 2>&1 | grep -E "warning:|error:" | grep -v "warnings generated" | sed -E 's/.*\[([a-z0-9.,-]+)\]$/\1/' | sort | uniq -c | sort -rn`
  Expected: avisos en `Dummy.*`, `AngleOfArrival.*` y `main.cpp` (como mínimo `modernize-redundant-void-arg` y
  `readability-magic-numbers` en `AngleOfArrival.cpp`). Guardar la lista: es la entrada de las Tareas 2 y 3.
  Clasificar cada check de la lista: **choca con una regla adoptada** → añadirlo a las exclusiones con su motivo
  (`.clang-tidy`, o la lista de tests si solo aparece en tests); **problema real** → se corrige en la Tarea 2 o la 3.

- [ ] **Paso 5: comprobar la separación de los tests** (Review Focus 1)

  Run: `cmake --build --preset Release --target lint -v 2>&1 | grep -c -- "--checks="`
  Expected: `1` (un único comando con `--checks=`), y en esa línea solo aparecen ficheros con `/tests/`.

- [ ] **Paso 6: formatear y comprobar que nada cambia de comportamiento** (Review Focus 2)

  Run: `cmake --build --preset Release --target format && cmake --build --preset Debug && ctest --preset Debug`
  Expected: compila sin avisos y `100% tests passed, 0 tests failed out of 22`.

- [ ] **Paso 7: preparar el diff para revisión** (`git diff -- .clang-format .clang-tidy .cmake/Tools.cmake`), sin
  commit.

---

### Tarea 2: `Dummy` pasa a `struct` agregado

**Files:**
- Modify: `src/Dummy_Lib/Dummy_Component/include/Dummy.h`
- Modify: `src/Dummy_Lib/Dummy_Component/src/Dummy.cpp`
- Test: `src/Dummy_Lib/Dummy_Component/tests/ut_Dummy.cpp`

**Interfaces:**
- Consumes: el target `lint` de la Tarea 1.
- Produces: `struct dummy::Dummy` (ver el paso 3). Ningún otro código lo usa (`main.cpp` no lo incluye).

- [ ] **Paso 1: reescribir los tests (en rojo)** en `ut_Dummy.cpp`:

  ```cpp
  static_assert(std::is_aggregate_v<Dummy>);
  static_assert(std::is_trivially_copyable_v<Dummy>);
  static_assert(std::is_nothrow_move_constructible_v<Dummy>);
  static_assert(std::is_nothrow_move_assignable_v<Dummy>);
  ```
  Fixture `DummyTest` con `Dummy dummy{};`. Tests, en este orden:
  - `DefaultInitializationIsFalse`: `EXPECT_FALSE(dummy.dummy);`
  - `ToStringReturnsDummy`: `EXPECT_EQ((Dummy{.dummy = true}).to_string(), "[Dummy: true]");` y lo mismo con
    `false` → `"[Dummy: false]"`.
  - `EqualityOperator`: `true == true`, `false == false`, `!(true == false)`, con `Dummy{.dummy = …}`.
  - `OstreamOperatorProducesString`: `oss << Dummy{.dummy = true}` → `"[Dummy: true]"`.

  Se borran los tests de setter, getter y constructor con parámetro.

- [ ] **Paso 2: comprobar que falla**

  Run: `cmake --build --preset Debug 2>&1 | grep -m3 error`
  Expected: error de compilación (`is_aggregate_v<Dummy>` es falso o no existe el miembro `dummy`).

- [ ] **Paso 3: implementar el `struct`** en `Dummy.h`, sin banners. Orden: atributos primero y después funciones
  (decisión de este plan para los `struct`; la recoge `classes.md` en la Tarea 4):

  ```cpp
  struct Dummy {
    bool dummy{}; ///< Dummy flag (example attribute)

    std::string to_string() const;                                            // "[Dummy: {}]"
    friend bool operator==(const Dummy& iLhs, const Dummy& iRhs) noexcept = default;
    friend std::ostream& operator<<(std::ostream& oOs, const Dummy& iOther);  // definido en el .h, delega en to_string
  };
  ```
  Con un bloque Doxygen completo en cada función (`@brief` fijos: `Equal comparison operator`, `Ostream operator`) y
  el `@brief` de la clase actualizado. `Dummy.cpp` solo define `to_string` con `std::format`, sin banners. Sin
  `(void)`.

- [ ] **Paso 4: comprobar que pasa**

  Run: `cmake --build --preset Debug && ctest --preset Debug -R Dummy`
  Expected: `100% tests passed, 0 tests failed out of 4`.

- [ ] **Paso 5: `lint` y formato limpios para `Dummy`**

  Run: `cmake --build --preset Release --target format && cmake --build --preset Release --target lint 2>&1 | grep -E "Dummy.*(warning|error):"`
  Expected: sin salida. Para cada aviso: corregir el código o, si choca con una regla adoptada, excluir el check con su
  motivo (Tarea 1, paso 4). Ningún aviso sobre los nombres generados por `TEST_F` (Review Focus 3).

- [ ] **Paso 6: preparar el diff para revisión**, sin commit.

---

### Tarea 3: `AngleOfArrival` y `main.cpp` según las reglas nuevas

**Files:**
- Modify: `src/SigInt/PulseDescriptors/include/AngleOfArrival.h`
- Modify: `src/SigInt/PulseDescriptors/src/AngleOfArrival.cpp`
- Modify: `src/main.cpp`
- Test: `src/SigInt/PulseDescriptors/tests/ut_AngleOfArrival.cpp`

**Interfaces:**
- Consumes: el target `lint` de la Tarea 1.
- Produces: `sigint::AngleOfArrival` con la misma API pública salvo `==`, que pasa a
  `friend bool operator==(const AngleOfArrival& iLhs, const AngleOfArrival& iRhs) noexcept = default;` en la sección
  `FRIEND FUNCTIONS`, antes de `operator<<`. La sección `OPERATORS` queda vacía.

- [ ] **Paso 1: añadir el test de `noexcept` de la igualdad (en rojo)** en `ut_AngleOfArrival.cpp`, junto a los
  `static_assert` existentes:

  ```cpp
  static_assert(noexcept(std::declval<const AngleOfArrival&>() == std::declval<const AngleOfArrival&>()));
  ```
  Añadir `#include <utility>` si `misc-include-cleaner` lo pide.

- [ ] **Paso 2: comprobar que falla**

  Run: `cmake --build --preset Debug 2>&1 | grep -m1 "static assertion failed"`
  Expected: falla el nuevo `static_assert` (el `==` actual no es `noexcept`).

- [ ] **Paso 3: mover `==` a *hidden friend* `noexcept`** (firma en Interfaces) y quitar los `(void)` de
  `AngleOfArrival.h/.cpp` y de `main.cpp`.

- [ ] **Paso 4: sustituir los números mágicos de `normalize()`** por constantes en un namespace anónimo al principio
  de `AngleOfArrival.cpp`: `constexpr float fullTurnDeg = 360.0f;`, `constexpr float halfTurnDeg = 180.0f;` y
  `constexpr float poleElevationDeg = 90.0f;`. Los valores de `wrap_angle(…, -180.0f, 360.0f)` pasan a
  `-halfTurnDeg, fullTurnDeg`, y los de `wrap_angle(…, 0.0f, fullTurnDeg)` se mantienen.

- [ ] **Paso 5: comprobar que pasa**

  Run: `cmake --build --preset Debug && ctest --preset Debug -R AngleOfArrival`
  Expected: `100% tests passed, 0 tests failed out of 15`.

- [ ] **Paso 6: `lint` y formato limpios en todo el repo** (Review Focus 3 y 4)

  Run: `cmake --build --preset Release --target format && cmake --build --preset Release --target format-check && cmake --build --preset Release --target lint 2>&1 | grep -E "(warning|error):" | grep -v "warnings generated"`
  Expected: sin salida; `main.cpp` sin avisos de nombres. Para cada aviso: corregir o excluir con motivo. Comprobar en
  la salida de `lint -v` que `AngleOfArrival.h` se analiza también desde `AngleOfArrival.cpp`, con la configuración
  estricta.

- [ ] **Paso 7: preparar el diff para revisión**, sin commit.

---

### Tarea 4: archivos de reglas y memoria

**Files:**
- Create: `.claude/rules/cpp/principles.md`, `naming.md`, `headers.md`, `functions.md`, `classes.md`, `errors.md`,
  `expressions.md`, `tests.md`
- Delete: `.claude/rules/how_to_write_a_class.md`
- Modify: memoria en `/home/hfernandezs/.claude/projects/-home-hfernandezs-develop-ews/memory/`
  (`class-rules-apply-to-all.md`, `accessor-naming.md`, `one-function-per-test.md`, `MEMORY.md`)

**Interfaces:**
- Consumes: la lista final de exclusiones (`.clang-tidy` y `PROJ_LINT_TEST_CHECKS`) de las Tareas 1 a 3, y el código
  migrado como ejemplo de referencia.

- [ ] **Paso 1: escribir los 8 archivos.** Contenido = spec, sección 4 (4.1 → `principles.md` … 4.8 → `tests.md`).
  Frontmatter `paths:` `["src/**/*.h", "src/**/*.hpp", "src/**/*.cpp"]`, salvo `tests.md`: `["src/**/tests/**"]`.
  Cada regla en el formato **norma → ID → por qué → cómo se comprueba**. Además:
  - `principles.md` enumera las 6 desviaciones con su motivo y remite a `.clang-tidy` y a `.cmake/Tools.cmake` para
    la lista de checks excluidos.
  - `classes.md` incluye el anexo de banners y el orden de las secciones (R5 y R9 de `how_to_write_a_class.md`), con
    `operator==` y `operator<<` en `FRIEND FUNCTIONS`, y el orden de los `struct` fijado en la Tarea 2, paso 3
    (atributos y luego funciones, sin banners).
  - Los ejemplos de código coinciden con el código migrado (`Dummy` y `AngleOfArrival`).

- [ ] **Paso 2: borrar `.claude/rules/how_to_write_a_class.md`** y comprobar que no quedan referencias:

  Run: `grep -rn "how_to_write_a_class" --exclude-dir=.build --exclude-dir=.git . ; echo exit=$?`
  Expected: solo aparecen en `docs/superpowers/` (specs y planes históricos); `exit=0`.

- [ ] **Paso 3: actualizar la memoria.** `class-rules-apply-to-all`: las reglas de `class` no se aplican a los
  `struct` agregados (C.2/C.8). `accessor-naming`: los accesores solo existen en las `class` con invariante.
  `one-function-per-test`: las funciones especiales implícitas no tienen test. Actualizar las líneas de `MEMORY.md`.

- [ ] **Paso 4: preparar el diff para revisión**, sin commit.

---

### Tarea 5: verificación final

**Files:** ninguno.

- [ ] **Paso 1: Debug**

  Run: `cmake --preset Debug && cmake --build --preset Debug 2>&1 | grep -iE "warn|error"; ctest --preset Debug | tail -3`
  Expected: sin salida del `grep`; `100% tests passed, 0 tests failed out of 19` (4 de `Dummy` + 15 de
  `AngleOfArrival`).

- [ ] **Paso 2: Release (LTO)**

  Run: `cmake --preset Release && cmake --build --preset Release 2>&1 | grep -iE "warn|error"; ctest --preset Release | tail -3`
  Expected: igual que el paso 1.

- [ ] **Paso 3: herramientas**

  Run: `cmake --build --preset Release --target format-check && cmake --build --preset Release --target lint; echo exit=$?`
  Expected: `exit=0`.

- [ ] **Paso 4: informar al usuario** con un resumen de los cambios, la lista final de exclusiones con su motivo y
  cualquier aviso que se haya corregido en el código. Ofrecer el commit.

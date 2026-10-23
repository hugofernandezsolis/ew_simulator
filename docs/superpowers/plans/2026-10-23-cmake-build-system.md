# Sistema de compilación CMake: plan de implementación

> **Para agentes:** SUB-SKILL REQUERIDO: usar superpowers:subagent-driven-development (recomendado) o superpowers:executing-plans para implementar este plan tarea a tarea. Los pasos usan casillas (`- [ ]`) para seguimiento.

**Objetivo:** Crear el sistema CMake modular con autodetección de librerías y componentes, tests por componente, presets (Debug, Release, RelWithDebInfo) y compatibilidad con el CI actual.

**Arquitectura:** `CMakeLists.txt` mínimo que hace `include()` de módulos en `.cmake/`. Cada subcarpeta de `src/` es una librería (un target); sus subcarpetas con `include/`, `src/` o `tests/` son componentes (no son targets). Se trabaja en dos fases: primero se crean todos los targets y después se enlazan según los `deps.cmake`. Cada componente con tests genera su propio ejecutable GoogleTest.

**Tecnologías:** CMake ≥ 3.25 (probado con 4.2.3), Ninja, GCC 15.2, C++23, GoogleTest v1.17.0 vía FetchContent.

**Spec:** `docs/superpowers/specs/2026-10-23-cmake-build-system-design.md`

## Restricciones globales

- `cmake_minimum_required(VERSION 3.25)`; `CMakePresets.json` en `"version": 6`.
- `CMAKE_CXX_STANDARD 23`, `CMAKE_CXX_STANDARD_REQUIRED ON`, `CMAKE_CXX_EXTENSIONS OFF`.
- Warnings: `-Wall -Wextra -Wpedantic -Wshadow -Wconversion`; `-Werror` solo con `EWS_WARNINGS_AS_ERRORS=ON`. Los flags se aplican **por target**, nunca globales.
- Nombres de carpeta exactos: `include`, `src`, `tests`. Tests en `tests/*.cpp`.
- Opciones (prefijo `EWS_`): `EWS_BUILD_TESTS` (ON), `EWS_SANITIZERS` (OFF; ON en preset `Debug`), `EWS_COVERAGE` (OFF; ON en preset `Debug`), `EWS_WARNINGS_AS_ERRORS` (OFF).
- `binaryDir` de presets: `${sourceDir}/build/${presetName}`. El CI ejecuta `cmake --preset Debug`, `cmake --build build/Debug` y `cd build/Debug && ctest --verbose` y no se modifica.
- Targets: librería `<Libreria>` con alias `ews::<Libreria>`; tests `<Libreria>_<Componente>_tests`; ejecutable `ews`.
- Ficheros de CMake en `.cmake/` con extensión `.cmake`; `deps.cmake` en cada carpeta de librería.
- Fixtures de prueba: copiar el repo con `cp -r /home/hfernandezs/develop/ews $FX` y modificar la copia, con `FX=/tmp/claude-1000/-home-hfernandezs-develop-ews/17be40d6-2302-4cce-ac0a-008f23de718d/scratchpad/fx-<tarea>`. Nunca ensuciar el repo real con casos de prueba.
- El directorio `/home/hfernandezs/develop/ews` **no es un repositorio git** ahora mismo. Los pasos "Commit" aplican solo si se hace `git init`/hay repo; si no, se omiten.
- `CLAUDE.md` del proyecto pide que Claude no escriba código salvo petición explícita. La petición de crear los archivos CMake es explícita; el código C++ de `src/` **no se toca**.

## Foco de revisión

Entradas que el spec implica pero que ninguna tarea cubre de forma obvia; cada una tiene su test en la tarea que posee el código.

1. Librería con solo cabeceras (todos sus componentes solo tienen `include/`): debe ser `INTERFACE` y enlazarse sin error (Tarea 3).
2. Componente con `tests/` vacía o sin `.cpp`: no genera target y no es error (Tarea 4).
3. Añadir un `.cpp` nuevo a un componente: se detecta con `cmake --build` sin reconfigurar a mano (Tarea 3).
4. Editar un `deps.cmake`: la siguiente compilación reconfigura sola (Tarea 5).
5. `EWS_BUILD_TESTS=OFF`: no se descarga GoogleTest ni se crean targets de tests (Tarea 4).

---

### Task 1: Esqueleto, utilidades, flags y presets

**Archivos:**
- Crear: `CMakeLists.txt`, `.cmake/Macros.cmake`, `.cmake/CompilerFlags.cmake`, `CMakePresets.json`
- Modificar: `.gitignore` (añadir `CMakeUserPresets.json` en "Personal folders and files")

**Interfaces:**
- Produce (`Macros.cmake`): `ews_status(<msg>)`, `ews_warn(<msg>)`, `ews_fatal(<msg>)` (este último termina con `FATAL_ERROR`).
- Produce (`CompilerFlags.cmake`): `ews_configure_target(<target>)`, que aplica a un target no-INTERFACE los warnings (más `-Werror` si `EWS_WARNINGS_AS_ERRORS`). La Tarea 7 amplía esta función.
- Produce (`CMakeLists.txt`): `project(ews LANGUAGES CXX)`, las cuatro opciones `EWS_*` declaradas, estándar C++23 global, y los `include()` de los módulos en el orden: Macros, CompilerFlags, Sanitizers, Coverage, FetchContent, BuildComponent, Tests, Components, Executable. Los módulos que aún no existen se incluyen solo al crearlos en su tarea.
- Presets: base oculto (`Ninja`, `binaryDir`, `CMAKE_EXPORT_COMPILE_COMMANDS=ON`) y `Debug`, `Release`, `RelWithDebInfo` con sus build y test presets.

- [ ] **Paso 1: Verificar que falla.** `cd /home/hfernandezs/develop/ews && cmake --preset Release`. Esperado: error `Could not read presets` o `No such preset`.
- [ ] **Paso 2: Crear `.cmake/Macros.cmake`** con las tres funciones anteriores (prefijo de mensaje `[ews]`).
- [ ] **Paso 3: Crear `.cmake/CompilerFlags.cmake`** con `ews_configure_target`. Usa `target_compile_options(<t> PRIVATE ...)` con los warnings de las restricciones globales.
- [ ] **Paso 4: Crear `CMakeLists.txt`** con lo indicado en Interfaces.
- [ ] **Paso 5: Crear `CMakePresets.json`.** El preset `Debug` aún no activa sanitizers/coverage (Tarea 7). Los tres build presets y test presets usan `configurePreset` del mismo nombre.
- [ ] **Paso 6: Añadir `CMakeUserPresets.json` a `.gitignore`.**
- [ ] **Paso 7: Verificar.** `cmake --preset Debug && cmake --preset Release && cmake --preset RelWithDebInfo`. Esperado: tres configuraciones sin error, con `build/Debug/compile_commands.json`, `build/Release/` y `build/RelWithDebInfo/`. `cmake --list-presets` muestra los tres.
- [ ] **Paso 8: Commit** (si hay repo): `feat(cmake): esqueleto, flags y presets`.

---

### Task 2: GoogleTest con FetchContent

**Archivos:**
- Crear: `.cmake/FetchContent.cmake`
- Modificar: `CMakeLists.txt` (añadir su `include()`)

**Interfaces:**
- Produce: con `EWS_BUILD_TESTS=ON`, los targets `GTest::gtest` y `GTest::gtest_main` están disponibles tras el `include`. Con OFF, el módulo no hace nada (no descarga).
- Produce: `ews_fetch_external(<nombre> URL <url> [FIND_PACKAGE <paquete>])`, función auxiliar para añadir un repositorio con una línea. GoogleTest se declara con ella: tarball `https://github.com/google/googletest/archive/refs/tags/v1.17.0.tar.gz`, paquete `GTest`, `INSTALL_GTEST OFF`.

- [ ] **Paso 1: Verificar que falla.** `cmake --preset Debug && grep -ci gtest build/Debug/CMakeCache.txt`. Esperado antes de implementar: `0`.
- [ ] **Paso 2: Implementar `ews_fetch_external`** sobre `FetchContent_Declare(... FIND_PACKAGE_ARGS NAMES <paquete>)` + `FetchContent_MakeAvailable`.
- [ ] **Paso 3: Declarar GoogleTest** solo `if(EWS_BUILD_TESTS)`, y añadir el `include()` en `CMakeLists.txt`.
- [ ] **Paso 4: Verificar.** `cmake --preset Debug`. Esperado: sin error y `grep -ci googletest build/Debug/CMakeCache.txt` > 0 (o `GTest_DIR` resuelto). Con `-DEWS_BUILD_TESTS=OFF` en un directorio distinto: no aparece `googletest` en la salida.
- [ ] **Paso 5: Commit** (si hay repo): `feat(cmake): GoogleTest vía FetchContent`.

---

### Task 3: Autodetección y compilación de librerías

**Archivos:**
- Crear: `.cmake/BuildComponent.cmake`, `.cmake/Components.cmake`
- Modificar: `CMakeLists.txt` (`include()` de ambos)

**Interfaces:**
- Produce (`Components.cmake`):
  - `ews_discover_libraries(<out_var>)`: lista de subcarpetas directas de `${CMAKE_SOURCE_DIR}/src` (solo nombres, ordenadas).
  - `ews_discover_components(<libreria> <out_var>)`: lista de subcarpetas de la librería que contienen `include/`, `src/` o `tests/`. Las demás generan `ews_warn` con la ruta.
  - Validaciones con `ews_fatal`: librería sin ningún componente (mensaje con la ruta).
  - Al incluirse, recorre todas las librerías y llama a `ews_build_library`. Guarda la lista en la variable global `EWS_LIBRARIES`.
- Produce (`BuildComponent.cmake`): `ews_build_library(<nombre> COMPONENTS <c1> <c2> ...)`:
  - Fuentes: `file(GLOB_RECURSE ... CONFIGURE_DEPENDS)` sobre `src/<nombre>/<c>/src/*.cpp` de cada componente.
  - Con fuentes: `add_library(<nombre>)` (tipo según `BUILD_SHARED_LIBS`, estática por defecto). Sin fuentes: `add_library(<nombre> INTERFACE)`.
  - `add_library(ews::<nombre> ALIAS <nombre>)`.
  - `include/` de cada componente `PUBLIC` (`INTERFACE` en librerías INTERFACE) y `src/` `PRIVATE`.
  - Llama a `ews_configure_target(<nombre>)` solo si no es INTERFACE.

- [ ] **Paso 1: Verificar que falla.** `cmake --preset Debug && cmake --build build/Debug --target Network`. Esperado: `ninja: error: unknown target 'Network'`.
- [ ] **Paso 2: Implementar `ews_build_library`** según Interfaces.
- [ ] **Paso 3: Implementar `ews_discover_libraries`, `ews_discover_components` y el bucle de creación** en `Components.cmake`. Añadir ambos `include()`.
- [ ] **Paso 4: Verificar el caso real.** `cmake --preset Debug && cmake --build build/Debug --target Network`. Esperado: compila `Dummy.cpp` y produce `build/Debug/libNetwork.a`. Los warnings de `-Wconversion`/`-Wshadow` son aceptables (no rompen).
- [ ] **Paso 5: Test, librería solo de cabeceras.** En `$FX=…/fx-3a`: crear `src/HeaderOnly/Foo/include/Foo.h`. `cmake -S $FX -B $FX/build -G Ninja` termina sin error y `cmake --build $FX/build --target HeaderOnly` también.
- [ ] **Paso 6: Test, `.cpp` nuevo se detecta.** En `$FX=…/fx-3b`: configurar y compilar; añadir `src/Network/Dummy/src/Extra.cpp` con una función trivial; ejecutar solo `cmake --build $FX/build`. Esperado: compila `Extra.cpp` sin reconfigurar a mano.
- [ ] **Paso 7: Test, error de librería sin componentes.** En `$FX=…/fx-3c`: crear `src/Vacia/` con un archivo `x.txt`. `cmake -S $FX -B $FX/build -G Ninja`. Esperado: error con la ruta de `src/Vacia`.
- [ ] **Paso 8: Commit** (si hay repo): `feat(cmake): autodetección y construcción de librerías`.

---

### Task 4: Tests por componente

**Archivos:**
- Crear: `.cmake/Tests.cmake`
- Modificar: `.cmake/Components.cmake` (llamar a `ews_add_component_tests` tras crear cada librería, solo con `EWS_BUILD_TESTS`), `CMakeLists.txt` (`enable_testing()` si no está ya y `include()`)

**Interfaces:**
- Consume: `ews_build_library`, `ews_discover_components` (Tarea 3), `GTest::gtest_main` (Tarea 2), `ews_configure_target` (Tarea 1).
- Produce: `ews_add_component_tests(<libreria> <componente>)`:
  - Si `src/<lib>/<comp>/tests/*.cpp` (glob con `CONFIGURE_DEPENDS`) está vacío: no hace nada.
  - Si no: `add_executable(<lib>_<comp>_tests ...)`, enlaza con `<lib>` y `GTest::gtest_main`, llama a `ews_configure_target` y `gtest_discover_tests(<lib>_<comp>_tests TEST_PREFIX "<lib>.<comp>.")`.

- [ ] **Paso 1: Verificar que falla.** `cmake --preset Debug && cmake --build build/Debug && ctest --test-dir build/Debug`. Esperado: `No tests were found!!!`.
- [ ] **Paso 2: Implementar `ews_add_component_tests`** y engancharla desde `Components.cmake`.
- [ ] **Paso 3: Verificar el caso real.** `cmake --preset Debug && cmake --build --preset Debug && ctest --preset Debug`. Esperado: los tests de `ut_Dummy.cpp` aparecen con nombre `Network.Dummy.DummyTest.<caso>.*` y pasan (100% passed). Si el enlazado falla por `main`, ver "Interfaces" (`gtest_main` es lo previsto; el `main` está en `namespace ics`).
- [ ] **Paso 4: Test, `tests/` sin `.cpp`.** En `$FX=…/fx-4a`: crear `src/Network/Vacio/tests/.gitkeep` y `src/Network/Vacio/include/V.h`. Configura y compila sin error; `ctest -N` no lista nada de `Network.Vacio`.
- [ ] **Paso 5: Test, `EWS_BUILD_TESTS=OFF`.** `cmake -S $FX -B $FX/build-off -G Ninja -DEWS_BUILD_TESTS=OFF` sobre una copia: sin menciones a googletest en la salida y `ctest -N` lista 0 tests.
- [ ] **Paso 6: Commit** (si hay repo): `feat(cmake): tests por componente con GoogleTest`.

---

### Task 5: Dependencias entre librerías (`deps.cmake`)

**Archivos:**
- Crear: `.cmake/Deps.cmake` (lógica de `ews_depends` y comprobación de ciclos)
- Modificar: `.cmake/Components.cmake` (fase 2 tras crear todas las librerías), `CMakeLists.txt` (`include()` antes de `Components`)

**Interfaces:**
- Produce: `ews_depends([LIBRARIES <lib>...] [EXTERNAL <target>...] [PRIVATE_LIBRARIES <lib>...])`, que se llama desde un `deps.cmake`. Usa la variable `EWS_CURRENT_LIBRARY` fijada antes del `include()` del archivo.
- Produce: `ews_link_dependencies(<libreria>)`: si existe `src/<lib>/deps.cmake`, lo incluye con `EWS_CURRENT_LIBRARY` fijada y registra las aristas en la propiedad global `EWS_DEP_<lib>`; añade `set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS <ruta>)` para reconfigurar al editarlo.
- Produce: `ews_check_cycles(<lista_libs>)`: detecta ciclos y llama a `ews_fatal` con el camino completo (`A -> B -> A`).
- Visibilidad: `LIBRARIES` y `EXTERNAL` son `PUBLIC`; `PRIVATE_LIBRARIES` es `PRIVATE`. Los enlaces usan los alias `ews::<lib>`. Una librería nombrada inexistente es `ews_fatal` con el nombre mal escrito.
- Para librerías INTERFACE, `target_link_libraries` usa `INTERFACE` en lugar de `PUBLIC`.

- [ ] **Paso 1: Verificar que falla.** En `$FX=…/fx-5a`: crear `src/App/X/include/X.h`, `src/App/X/src/X.cpp` (incluye `<Dummy.h>`) y `src/App/deps.cmake` con `ews_depends(LIBRARIES Network)`. `cmake -S $FX -B $FX/build -G Ninja`. Esperado: error `Unknown CMake command "ews_depends"`.
- [ ] **Paso 2: Implementar** las tres funciones según Interfaces y la fase 2 en `Components.cmake` (primero `ews_check_cycles` sobre `EWS_LIBRARIES`, después `ews_link_dependencies` por cada una).
- [ ] **Paso 3: Test, dependencia válida.** Con el fixture del paso 1: configura y `cmake --build $FX/build --target App` compila, sin importar que `App` sea alfabéticamente anterior a `Network`.
- [ ] **Paso 4: Test, librería inexistente.** `fx-5b`: `ews_depends(LIBRARIES Netwrok)`. Esperado: error que menciona `Netwrok` y la librería que lo pide.
- [ ] **Paso 5: Test, ciclo.** `fx-5c`: `Network/deps.cmake` depende de `App` y `App` de `Network`. Esperado: error con el camino `Network -> App -> Network` (o equivalente).
- [ ] **Paso 6: Test, editar `deps.cmake` reconfigura.** En `fx-5a` ya compilado: cambiar `deps.cmake` (quitar la dependencia) y ejecutar solo `cmake --build $FX/build`. Esperado: aparece `Re-running CMake` y la compilación sigue.
- [ ] **Paso 7: Commit** (si hay repo): `feat(cmake): dependencias entre librerías con deps.cmake`.

---

### Task 6: Ejecutable `ews`

**Archivos:**
- Crear: `.cmake/Executable.cmake`
- Modificar: `CMakeLists.txt` (`include()` al final)

**Interfaces:**
- Consume: `EWS_LIBRARIES` (Tarea 3), `ews_configure_target` (Tarea 1).
- Produce: si existe `${CMAKE_SOURCE_DIR}/src/main.cpp`, `add_executable(ews src/main.cpp)` enlazado con `ews::<lib>` de **todas** las librerías, y `ews_configure_target(ews)`. Si no existe, no hace nada ni emite error.

- [ ] **Paso 1: Verificar que falla.** En `$FX=…/fx-6a`: crear `src/main.cpp` con un `main` mínimo que incluya `<Dummy.h>`. Configurar y `cmake --build $FX/build --target ews`. Esperado: `unknown target 'ews'`.
- [ ] **Paso 2: Implementar `Executable.cmake`** según Interfaces.
- [ ] **Paso 3: Verificar con `main.cpp`.** Repetir el paso 1: ahora compila y `$FX/build/ews` se ejecuta con código de salida 0.
- [ ] **Paso 4: Verificar sin `main.cpp` (caso real).** En el repo real, `cmake --preset Debug && cmake --build --preset Debug`: sin error y sin target `ews`.
- [ ] **Paso 5: Commit** (si hay repo): `feat(cmake): ejecutable ews`.

---

### Task 7: Sanitizers y Coverage

**Archivos:**
- Crear: `.cmake/Sanitizers.cmake`, `.cmake/Coverage.cmake`
- Modificar: `.cmake/CompilerFlags.cmake` (ampliar `ews_configure_target`), `CMakePresets.json` (preset `Debug`: `EWS_SANITIZERS=ON`, `EWS_COVERAGE=ON`), `CMakeLists.txt` (`include()` de ambos antes de `Components`)

**Interfaces:**
- Produce (`Sanitizers.cmake`): `ews_enable_sanitizers(<target>)`: con `EWS_SANITIZERS`, añade `-fsanitize=address,undefined -fno-omit-frame-pointer` como opciones de compilación **y de enlace** (PRIVATE).
- Produce (`Coverage.cmake`): `ews_enable_coverage(<target>)`: con `EWS_COVERAGE`, añade `--coverage` y `-O0` (compilación y enlace, PRIVATE). Define el target personalizado `coverage`: si `gcovr` existe, genera informe HTML en `${CMAKE_BINARY_DIR}/coverage/index.html`; si no, solo `ews_warn`, sin fallar.
- Modifica: `ews_configure_target` llama a ambas funciones.
- Ambas opciones son independientes; no hay exclusión entre ellas.

- [ ] **Paso 1: Verificar que falla.** `cmake --preset Debug` (tras añadir las opciones al preset) y `grep -c fsanitize build/Debug/compile_commands.json`. Esperado antes de implementar: `0`.
- [ ] **Paso 2: Implementar los dos módulos y ampliar `ews_configure_target`.**
- [ ] **Paso 3: Verificar flags.** Tras `cmake --preset Debug`: `grep -c fsanitize build/Debug/compile_commands.json` > 0 y `grep -c -- --coverage build/Debug/compile_commands.json` > 0. Con `cmake --preset Release`: ambos `0`.
- [ ] **Paso 4: Verificar que el caso real sigue verde.** `cmake --build --preset Debug && ctest --preset Debug`: 100% passed. Tras ejecutar los tests existen archivos `*.gcda` bajo `build/Debug`.
- [ ] **Paso 5: Test, ASan detecta un error.** En `$FX=…/fx-7`: añadir a `tests/ut_Dummy.cpp` un test que haga `new int[4]` sin `delete`, ejecutar `ctest`. Esperado: el test falla y la salida contiene `LeakSanitizer` o `AddressSanitizer`.
- [ ] **Paso 6: Test, sin `gcovr`.** Si `gcovr` no está instalado, `cmake --build build/Debug --target coverage` termina con aviso y código 0.
- [ ] **Paso 7: Commit** (si hay repo): `feat(cmake): sanitizers y coverage`.

---

### Task 8: Verificación final de extremo a extremo

**Archivos:** ninguno nuevo; solo correcciones puntuales si algo falla.

- [ ] **Paso 1: Replicar el CI desde cero.** `rm -rf build && cmake --preset Debug && cmake --build build/Debug && cd build/Debug && ctest --verbose`. Esperado: todo pasa sin modificar `.github/workflows/cmake-linux.yml`.
- [ ] **Paso 2: Presets de build y test.** `cmake --build --preset Release && ctest --preset Release`, y lo mismo con `RelWithDebInfo`. Esperado: compilan y los tests pasan.
- [ ] **Paso 3: Criterio "solo carpetas".** En `$FX=…/fx-8`: crear una librería `Core` con componente `Util` (cabecera, `.cpp` y `ut_Util.cpp`) sin tocar ningún `.cmake`. Esperado: aparece `Core`, su target de tests `Core_Util_tests` y `ctest` lo ejecuta.
- [ ] **Paso 4: `EWS_WARNINGS_AS_ERRORS`.** Configurar una copia con `-DEWS_WARNINGS_AS_ERRORS=ON`. Esperado: el aviso real de `-Wconversion`/`-Wshadow` (si lo hay) rompe la compilación; sin la opción, no.
- [ ] **Paso 5: Ruta con espacios.** Copiar el repo a `$FX/mi proyecto` y configurar/compilar con `Debug`. Esperado: sin errores.
- [ ] **Paso 6: Revisar el spec §13.** Comprobar los cinco criterios de éxito uno a uno y anotar el resultado.
- [ ] **Paso 7: Commit final** (si hay repo): `chore(cmake): verificación final`.

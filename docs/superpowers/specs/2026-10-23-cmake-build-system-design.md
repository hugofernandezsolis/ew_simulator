# Sistema de compilación CMake: diseño

Fecha: 2026-10-23

## 1. Objetivo

Definir un sistema de compilación CMake **modular, escalable y con autodetección** para el simulador EW (ver `2026-10-21-simulador-ew-pdw-design.md`). Debe permitir añadir librerías y componentes creando solo carpetas, sin editar ningún archivo CMake, y soportar varias configuraciones de compilación mediante presets.

### Fuera de alcance

- Instalación (`install()`), empaquetado (CPack) y exportación como paquete CMake.
- ONNX Runtime y cualquier dependencia externa distinta de GoogleTest (se añadirán cuando llegue el componente que las use).
- Compiladores distintos de GCC (la lógica de flags queda aislada para ampliarla después).
- Más de un ejecutable.

### Entorno de referencia

CMake 4.2.3, GCC 15.2, Ninja 1.13, WSL2 Ubuntu. El CI (`.github/workflows/cmake-linux.yml`) ejecuta `cmake --preset Debug`, `cmake --build build/Debug` y `ctest` en `build/Debug`; **debe seguir funcionando sin cambios**.

## 2. Modelo del proyecto

```
src/
  main.cpp                 # arranca el simulador; enlaza todas las librerías
  <Libreria>/              # LIBRERÍA: un target de CMake, compilada de forma independiente
    deps.cmake             # opcional: dependencias propias de la librería
    <Componente>/          # COMPONENTE: unidad de organización, NO es un target
      include/             # cabeceras públicas
      src/                 # fuentes (.cpp) y cabeceras privadas
      tests/               # tests GoogleTest (ut_*.cpp)
```

Ejemplo existente: librería `Network`, componente `Dummy`.

Reglas:

- **Librería** = cada subcarpeta directa de `src/`.
- **Componente** = subcarpeta directa de una librería que contiene `include/`, `src/` o `tests/`. Sin anidamiento intermedio.
- Los nombres de carpeta son exactamente `include`, `src` y `tests` (sin alias).
- Las subcarpetas de una librería sin ninguna de esas tres carpetas se ignoran con un aviso.
- Cada librería se compila de forma independiente y el ejecutable `ews` las enlaza todas.

## 3. Estructura de archivos

```
CMakeLists.txt          # versión mínima, proyecto, opciones; include() de los módulos en orden
CMakePresets.json       # presets de configure, build y test
.cmake/
  Macros.cmake          # utilidades pequeñas (logs, errores, comprobaciones)
  CompilerFlags.cmake   # estándar C++23 y warnings (por target)
  Sanitizers.cmake      # ASan + UBSan si EWS_SANITIZERS=ON
  Coverage.cmake        # gcov si EWS_COVERAGE=ON; target `coverage`
  FetchContent.cmake    # repositorios externos (hoy GoogleTest)
  Components.cmake      # autodetección, lectura de deps.cmake, enlazado
  BuildComponent.cmake  # cómo se compila UNA librería
  Tests.cmake           # cómo se compilan y registran los tests de UN componente
  Executable.cmake      # ejecutable `ews` desde src/main.cpp
```

`CMakeLists.txt` solo contiene la configuración global (`cmake_minimum_required`, `project`, opciones, `CMAKE_CXX_STANDARD 23`, `CMAKE_CXX_EXTENSIONS OFF`) y los `include()`.

Versión mínima: **CMake 3.25** (requisito de los presets versión 6; `ubuntu-latest` trae 3.28).

## 4. Autodetección (`Components.cmake`)

1. Listar subcarpetas directas de `src/`: cada una es una librería.
2. Dentro de cada librería, listar subcarpetas: las que tienen `include/`, `src/` o `tests/` son componentes.
3. Validar: nombres de librería únicos; cada librería con al menos un componente. Los errores indican la ruta exacta (`message(FATAL_ERROR ...)`).

Se trabaja en **dos fases** para que el orden de las carpetas no importe:

1. Crear los targets de todas las librerías.
2. Leer cada `deps.cmake` y enlazar.

### `deps.cmake`

Llamada a una función propia, para poder validar:

```cmake
ews_depends(
  LIBRARIES  Network Core      # otras librerías del proyecto
  EXTERNAL   fmt::fmt          # targets de FetchContent / find_package
)
```

- Si el archivo no existe, la librería no tiene dependencias.
- Una librería nombrada que no existe es un error con el nombre mal escrito.
- Se detectan ciclos entre librerías y se aborta mostrando el camino completo.
- Visibilidad por defecto: **PUBLIC**. Se podrá marcar alguna como PRIVATE.

## 5. Compilación de una librería (`BuildComponent.cmake`)

Misma función para todas las librerías.

- Fuentes: `file(GLOB_RECURSE ... CONFIGURE_DEPENDS)` sobre `<Libreria>/*/src/*.cpp`. Se usa glob porque la autodetección es un requisito; `CONFIGURE_DEPENDS` hace que los archivos nuevos se detecten al recompilar.
- Tipo: estática por defecto (`BUILD_SHARED_LIBS` lo cambia). Sin `.cpp`: librería `INTERFACE`. En ese caso los `.h`/`.hpp` de los `include/` se añaden como fuentes `PRIVATE` del target solo para que exista en la herramienta de build (`--target <Libreria>` funciona); no afectan a los consumidores.
- Includes: cada `include/` de sus componentes es `PUBLIC`; cada `src/` es `PRIVATE`.
- Target: `<Libreria>`, con alias `ews::<Libreria>`.
- Los flags de compilación se aplican **por target**, no globalmente, para no contaminar GoogleTest ni otras dependencias.

## 6. Tests (`Tests.cmake`)

Un ejecutable de tests **por componente**.

- Si el componente tiene `tests/*.cpp`: target `<Libreria>_<Componente>_tests`. Si no, se omite.
- Enlaza con la librería completa y con `GTest::gtest_main`. (El `main` de `ut_Dummy.cpp` está dentro de `namespace sigint` y por tanto no es el `main` del programa; `gtest_main` lo resuelve.)
- `gtest_discover_tests` registra cada `TEST` en `ctest`, con un prefijo que identifica librería y componente.
- Solo se crean con `EWS_BUILD_TESTS=ON` (por defecto ON). Con OFF no se descarga ni compila GoogleTest.

## 7. Ejecutable (`Executable.cmake`)

Si existe `src/main.cpp`, se crea el target `ews` enlazado con **todas** las librerías autodetectadas. Si no existe, no se crea y no se produce error.

## 8. Dependencias externas (`FetchContent.cmake`)

- Hoy: GoogleTest, con versión fijada.
- `FIND_PACKAGE_ARGS`: se usa la instalación del sistema si existe; si no, se descarga.
- Estructura para añadir un repositorio con una línea; las dependencias solo se declaran/descargan si son necesarias (GoogleTest solo con `EWS_BUILD_TESTS=ON`).
- ONNX Runtime se añadirá con el componente Clasificador.

## 9. Opciones y flags

### Opciones (prefijo `EWS_`)

| Opción | Defecto | Efecto |
|---|---|---|
| `EWS_BUILD_TESTS` | ON | Compila y registra los tests |
| `EWS_SANITIZERS` | OFF (ON en preset `Debug`) | `-fsanitize=address,undefined -fno-omit-frame-pointer` |
| `EWS_COVERAGE` | OFF (ON en preset `Debug`) | `--coverage`, `-O0`; habilita target `coverage` |
| `EWS_WARNINGS_AS_ERRORS` | OFF | Añade `-Werror` |

`EWS_SANITIZERS` y `EWS_COVERAGE` son independientes y compatibles entre sí (ASan + UBSan + gcov funcionan juntos en GCC).

### Flags (`CompilerFlags.cmake`)

- Estándar C++23, extensiones del compilador desactivadas (`-std=c++23`, no `gnu++23`).
- Warnings: `-Wall -Wextra -Wpedantic -Wshadow -Wconversion`.
- Con `EWS_WARNINGS_AS_ERRORS=OFF` los warnings no rompen la compilación; sirven de lista de limpieza (p. ej. posibles avisos en `Dummy.cpp`).
- Coverage: el informe HTML se genera con `gcovr` si está instalado; si no, el target avisa y no falla.

## 10. Presets (`CMakePresets.json`, versión 6)

Preset base oculto: generador Ninja, `binaryDir = ${sourceDir}/build/${presetName}`, `CMAKE_EXPORT_COMPILE_COMMANDS=ON`.

| Preset | Configuración | Notas |
|---|---|---|
| `Debug` | `CMAKE_BUILD_TYPE=Debug`, `EWS_SANITIZERS=ON`, `EWS_COVERAGE=ON` | Uso diario y CI. Se puede aligerar con `-DEWS_SANITIZERS=OFF` |
| `Release` | `CMAKE_BUILD_TYPE=Release` (`-O3 -DNDEBUG`) | Ejecuciones largas / datasets |
| `RelWithDebInfo` | `CMAKE_BUILD_TYPE=RelWithDebInfo` | Perfilado |

Cada configure preset tiene su build preset y test preset (`cmake --build --preset Debug`, `ctest --preset Debug`). `CMakeUserPresets.json` (personalizaciones locales) se añade a `.gitignore`.

## 11. Compatibilidad con el CI

Los directorios resultantes (`build/Debug`, ...) coinciden con los del workflow actual. Como `Debug` activa sanitizers y coverage, el CI pasa a ejecutarlos automáticamente. `gcovr` no es necesario para que el CI pase.

## 12. Riesgos y notas

- **Includes planos:** los `include/` de todos los componentes de una librería son visibles entre sí; dos componentes de la misma librería con una cabecera del mismo nombre chocarían. Solución futura, sin tocar CMake: `include/<Componente>/Cabecera.h`.
- **Glob:** un `.cpp` nuevo se detecta al compilar gracias a `CONFIGURE_DEPENDS`, pero re-ejecuta la configuración (coste pequeño).
- **Coste de Debug:** ASan hace los tests 2–3× más lentos y usa más memoria; `Release` se usa para simulaciones grandes.
- **Warnings estrictos:** `-Wconversion` y `-Wshadow` pueden avisar sobre el código actual; no rompen la compilación por defecto.
- **Test de Dummy:** los tests de un componente enlazan con la librería entera, de modo que dependen en enlazado de todos los componentes de su librería (no de forma aislada).

## 13. Criterios de éxito

1. `cmake --preset Debug && cmake --build --preset Debug && ctest --preset Debug` funciona con la estructura actual (`Network/Dummy`).
2. Crear una librería o un componente nuevo (solo carpetas y archivos de código) lo hace aparecer en la compilación sin editar ningún archivo CMake.
3. Un `deps.cmake` con una librería inexistente o un ciclo produce un error claro.
4. Los presets `Release` y `RelWithDebInfo` configuran y compilan.
5. El workflow de CI actual pasa sin modificaciones.

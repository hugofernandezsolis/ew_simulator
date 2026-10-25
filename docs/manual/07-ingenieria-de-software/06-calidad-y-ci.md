# 7.6 Calidad e integración continua

> [Manual](../README.md) › [Ingeniería de software](README.md) › Calidad e integración continua

## Las capas de control

Cada capa atrapa errores distintos, y cuanto antes en la lista, más barato es corregirlos:

| Capa | Herramienta | Atrapa |
| --- | --- | --- |
| Compilador | `-Wall -Wextra -Wpedantic -Wshadow -Wconversion` + `-Werror` en CI | Conversiones con pérdida, variables que ocultan otras, código no estándar |
| Formato | clang-format | Estilo inconsistente (y diffs llenos de espacios) |
| Análisis estático | clang-tidy | Errores probables y problemas de rendimiento que compilan bien |
| Tests | GoogleTest + CTest | Comportamiento incorrecto |
| Sanitizers | ASan + UBSan | Memoria y comportamiento indefinido durante los tests |
| Cobertura | gcov + gcovr | Código que ningún test ejecuta |
| CI | GitHub Actions | Todo lo anterior, en cada cambio y con varios compiladores |

## clang-format

`.clang-format` parte del estilo LLVM con los ajustes del proyecto: 2 espacios, 120 columnas, `public:` sin sangrar,
namespaces sin sangrar, punteros pegados al tipo (`int* p`), hasta 2 líneas en blanco seguidas y **sin reordenar
includes ni comentarios** (las secciones de R2 y los bloques de R5 tienen un orden propio).

| Target | Qué hace |
| --- | --- |
| `format` | Reescribe los ficheros de `src/` en el sitio |
| `format-check` | Solo comprueba; falla si algo cambiaría (lo que hace la CI) |

## clang-tidy

`.clang-tidy` activa un conjunto **conservador** que se ampliará poco a poco:

- `bugprone-*`: errores probables. Ejemplos que el plan del simulador tiene en cuenta: `bugprone-use-after-move`
  (usar un objeto después de moverlo), `bugprone-unchecked-optional-access` (leer un `std::optional` sin comprobarlo),
  `bugprone-throw-keyword-missing` (crear una excepción sin lanzarla).
- `performance-*`: copias innecesarias (`performance-unnecessary-value-param`), vectores que se llenan sin
  `reserve()`.
- Desactivado: `bugprone-easily-swappable-parameters` (demasiado ruidoso con constructores de muchos `double`).
- `WarningsAsErrors: "*"`: cualquier aviso hace fallar el lint.
- `HeaderFilterRegex: "/ews/src/"`: analiza las cabeceras del proyecto, no las de GoogleTest ni nlohmann.

El target `lint` analiza solo los `.cpp` (las cabeceras se revisan a través de ellos) y necesita el
`compile_commands.json` que generan los presets. Si clang-format o clang-tidy no están instalados, sus targets existen
pero **fallan con un mensaje claro**: una herramienta ausente nunca se confunde con un resultado limpio.

Cuando una regla tiene que saltarse a propósito, se hace en la línea concreta y con el motivo:
`// NOLINT(bugprone-throw-keyword-missing)` (plan, excepción E8).

## Cobertura

El target `coverage` (preset `Coverage`) borra los contadores anteriores, ejecuta los tests y genera un informe HTML
con **gcovr** en `.build/Coverage/coverage/index.html`.

- Cuenta solo el código de `src/`: excluye los tests, `main.cpp` y todo lo del directorio de build (GoogleTest).
- `--exclude-throw-branches`: no cuenta las ramas ocultas que el compilador añade a cada llamada que puede lanzar,
  porque no son decisiones del código y ningún test razonable puede tomarlas.
- Con clang usa `llvm-cov gcov`, que entiende su formato.

La cobertura dice qué **no** se ha probado; un 100 % no garantiza que los tests comprueben lo correcto.

## Integración continua (GitHub Actions)

| Workflow | Cuándo | Qué hace |
| --- | --- | --- |
| **`ci.yml`** | Push y PR a `main` (salvo cambios solo en `docs/` o `.md`) | Matriz de **3 compiladores × 3 tipos de build**: gcc-13, gcc-14, clang-18 × Debug, Release, RelWithDebInfo. Cada uno ejecuta `cmake --workflow --preset ci-<tipo>` |
| **`coverage.yml`** | Push y PR a `main` | Compila con `ci-Coverage` (gcc-13), ejecuta el target `coverage` y sube el informe como artefacto |
| **`lint.yml`** | Push y PR a `main` que toquen `src/` o la configuración de las herramientas | `format-check` y `lint` con clang-format-18 y clang-tidy-18 |
| **`release.yml`** | Al subir un tag `v*` (`git tag v1.0.0 && git push origin v1.0.0`) | Compila `ci-Release`, ejecuta los tests, genera el `.deb` con CPack (versión tomada del tag) y publica la release |

### Por qué varios compiladores

Cada compilador avisa de cosas distintas y cada biblioteca estándar implementa C++23 a un ritmo distinto. Dos casos
del plan del simulador:

- clang activa dentro de `-Wconversion` avisos que GCC no da (`-Wsign-conversion`, `-Wshorten-64-to-32`).
- El formateo de rangos de `std::format` (`std::format("{}", vector)`) existe en la libstdc++ de GCC 15 local, pero no
  en GCC 13/14 ni con clang-18: compilaría en local y rompería la CI. Por eso los contenedores se convierten a texto a
  mano.

### Detalles de los workflows

- **`concurrency` con `cancel-in-progress`**: un push nuevo a la misma rama cancela la ejecución anterior.
- **`permissions: contents: read`**: mínimo privilegio; solo el job de release pide escritura.
- **ccache**: guarda compilaciones entre ejecuciones (`CMAKE_CXX_COMPILER_LAUNCHER=ccache`).
- **`fail-fast: false`** en la matriz: si falla clang, los demás siguen y se ve el cuadro completo.
- **`timeout-minutes`**: un job colgado no consume horas.

## Empaquetado

`Packaging.cmake` instala el ejecutable en `bin/` y configura CPack. El proyecto genera un **`.deb`** con el nombre
estándar `<nombre>_<versión>_<arquitectura>.deb`, y `dpkg-shlibdeps` calcula sus dependencias (por ejemplo,
`libstdc++6`).

## Antes de cada commit

Lo que la CI comprobará, en local:

1. `cmake --workflow --preset ci-Debug` (compila con `-Werror` y sanitizers, ejecuta los tests).
2. `cmake --build --preset Release --target format-check` (o `format` para arreglarlo).
3. `cmake --build --preset Release --target lint` (tarda varios minutos; el plan lo pide al cerrar ciertas tareas).

## En este proyecto

- Configuración: `.clang-format`, `.clang-tidy`, `.cmake/Tools.cmake`, `.cmake/Coverage.cmake`,
  `.cmake/Packaging.cmake`, `.github/workflows/`.
- Los workflows ignoran los cambios que solo tocan `docs/` o ficheros `.md`: editar este manual no lanza la CI.

## Ideas clave

- Varias capas: compilador, formato, lint, tests, sanitizers, cobertura y CI.
- `format-check` y `lint` hacen en la CI lo mismo que en local.
- Matriz de compiladores: lo que compila en una máquina puede no compilar en otra.
- Un tag `v*` produce una release con su `.deb`.

---

[← 7.5 Tests](05-tests.md) · [↑ Ingeniería de software](README.md) · [↑ Manual](../README.md)

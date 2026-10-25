# 7.2 Sistema de build

> [Manual](../README.md) › [Ingeniería de software](README.md) › Sistema de build

## CMake en dos frases

**CMake** no compila: genera los ficheros de un sistema de build (aquí **Ninja**) a partir de una descripción del
proyecto. Esa descripción son *targets* (librerías, ejecutables) con sus fuentes, opciones y dependencias.

```
  cmake --preset Debug        configurar: lee CMakeLists.txt y genera .build/Debug/build.ninja
  cmake --build --preset Debug    compilar: Ninja compila lo que haya cambiado
  ctest --preset Debug        probar: ejecuta los tests registrados
```

## Mecánica frente a política

El build está partido en dos tipos de fichero:

| Tipo | Ficheros | Contiene |
| --- | --- | --- |
| **Mecánica** (genérica) | `.cmake/*.cmake` con mayúscula (`BuildComponent`, `Deps`, `Tests`…) | Funciones `proj_*` que sirven para cualquier proyecto |
| **Política** (de este proyecto) | `CMakeLists.txt`, `.cmake/dependencies.cmake`, `src/**/deps.cmake` | Nombre, versión, estándar, dependencias concretas |

El nombre real del proyecto (`ews`) solo aparece en `project(ews …)`. Todo lo demás usa `${PROJECT_NAME}` y el prefijo
genérico `proj_`/`PROJ_`, así que la carpeta `.cmake/` se puede copiar a otro proyecto cambiando una línea.

`CMakeLists.txt` se lee como un **guion**: incluye los módulos (que solo definen funciones, no hacen nada) y después
llama a las funciones en orden.

## Convención en lugar de configuración

No hay que listar ficheros ni librerías en ningún sitio. El build **descubre** la estructura de [7.1](01-estructura-del-repositorio.md):

```
  proj_build_all_libraries                       (fase 1)
   ├─ cada carpeta de src/ ─────────────▶ una librería
   │   ├─ cada subcarpeta con include/, src/ o tests/ ─▶ un componente
   │   │    (una subcarpeta sin ninguna de las tres: aviso "Carpeta ignorada")
   │   ├─ proj_build_library  ─▶ target ews_<Lib> + alias ews::<Lib>
   │   └─ proj_add_component_tests ─▶ un ejecutable de tests por componente
  proj_link_all_libraries                        (fase 2)
   ├─ proj_check_cycles  ─▶ error si A → B → A
   └─ proj_link_dependencies  ─▶ enlaza según cada deps.cmake
  proj_add_executable  ─▶ target ews si existe src/main.cpp
```

- Los `file(GLOB … CONFIGURE_DEPENDS)` hacen que un fichero o una carpeta nuevos se detecten en el siguiente
  `cmake --build`, sin reconfigurar a mano.
- Las extensiones reconocidas están en un único sitio (`proj_glob_patterns`, en `Macros.cmake`): `.cpp .cc .cxx .c++`
  como fuentes y `.h .hh .hpp .hxx .ipp .inl` como cabeceras. Así el build, los tests, el formato y el lint ven
  exactamente los mismos ficheros.
- Una librería sin fuentes se crea como `INTERFACE` (solo cabeceras).

### ¿Por qué dos fases?

Para enlazar `Simulator` con `SigInt`, el target de `SigInt` tiene que existir. Si se enlazara mientras se crean, el
orden alfabético de las carpetas decidiría si funciona. Con dos fases, primero se crean **todos** los targets y después
se enlazan en cualquier orden.

## Nombres de targets

| Nombre | Para qué |
| --- | --- |
| `ews_SigInt` (target real) | El prefijo evita choques: una carpeta podría llamarse `test`, `format` o `lint` |
| `ews::SigInt` (alias) | El nombre con el que se enlaza. Con `::`, una errata falla al configurar y no al enlazar |
| `libews_SigInt.a` | El fichero generado conserva el prefijo |
| `ews_SigInt_PulseDescriptors_tests` | Ejecutable de tests de un componente |

## Cabeceras

Las cabeceras de cada `include/` entran en un **`FILE_SET HEADERS`** público del target, con cada `include/` como
`BASE_DIR`. Eso hace dos cosas: los IDE las muestran como parte del target, y CMake añade cada `include/` como carpeta
de búsqueda para la librería **y para quien la enlace**. Los `src/` de cada componente se añaden como carpetas de
búsqueda **privadas**.

## Dependencias entre librerías: `deps.cmake`

Cada librería declara de qué depende en `src/<Lib>/deps.cmake`, con una sola llamada:

```cmake
proj_depends(LIBRARIES SigInt PRIVATE_EXTERNAL nlohmann_json::nlohmann_json)
```

| Palabra clave | Se enlaza como | Significado |
| --- | --- | --- |
| `LIBRARIES` | `PUBLIC` | Librería del proyecto; quien me use también la ve (mis cabeceras la incluyen) |
| `PRIVATE_LIBRARIES` | `PRIVATE` | Librería del proyecto que solo usan mis `.cpp` |
| `EXTERNAL` | `PUBLIC` | Target externo visible en mis cabeceras |
| `PRIVATE_EXTERNAL` | `PRIVATE` | Target externo que solo usan mis `.cpp` |

**PUBLIC frente a PRIVATE** es la pregunta "¿aparece en mis cabeceras públicas?". `Simulator` usa tipos de `SigInt`
en sus cabeceras (`sigint::EmittedPulse`…), así que es `LIBRARIES`. nlohmann/json solo aparece en
`Config/src/`, así que es `PRIVATE_EXTERNAL`: quien enlace `Simulator` no hereda esa dependencia.

Comprobaciones al configurar:

- Una librería del proyecto que no existe → error con el fichero `deps.cmake` culpable.
- Un nombre externo con `::` que no es un target (`fmt::fmtt`) → error, en lugar de un fallo críptico al enlazar.
- **Ciclos**: una búsqueda en profundidad recorre el grafo y, si encuentra `A -> B -> A`, para la configuración e
  imprime el camino completo. Es lo que obliga a que `SigInt` no dependa nunca de `Simulator`.

El ejecutable usa el mismo mecanismo con `src/deps.cmake`. Si ese fichero no existe, se enlaza con todas las librerías.

## Dependencias externas

`.cmake/dependencies.cmake` es el único fichero de `.cmake/` con política: qué dependencias externas hay, con qué URL y
versión. El mecanismo es `proj_fetch_external` (`External.cmake`), sobre `FetchContent`:

| Dependencia | Versión | Cuándo se descarga |
| --- | --- | --- |
| GoogleTest | 1.17.0 | Solo con los tests activados; primero intenta `find_package(GTest)` del sistema |
| nlohmann/json (previsto) | 3.12.0 | Siempre (la necesita la librería); **sin** `find_package`, para que todas las máquinas usen exactamente la misma versión |

## Opciones del compilador

`proj_configure_target` aplica las opciones **por target**, nunca globalmente, para no afectar al código de terceros
(GoogleTest):

- Avisos: `-Wall -Wextra -Wpedantic -Wshadow -Wconversion` (en MSVC, `/W4 /permissive-`).
- Avisos como errores solo si `PROJ_WARNINGS_AS_ERRORS=ON` (los presets `ci-*`), con la propiedad
  `COMPILE_WARNING_AS_ERROR`.
- Sanitizers y cobertura, si sus opciones están activas ([7.3](03-presets-y-configuraciones.md)).
- C++23 obligatorio y sin extensiones de compilador (`-std=c++23`, no `gnu++23`).

## Otras protecciones

- **Prohibido compilar dentro del código fuente** (`cmake -S . -B .`): ensuciaría el repositorio.
- Si no se indica tipo de build, se usa Debug.
- **Como subproyecto** (si otro proyecto lo incluye con `add_subdirectory`), no compila sus tests ni define `format`,
  `lint`, `coverage` o el empaquetado, para no chocar con los del proyecto que lo usa.

## En este proyecto

- Módulos: `.cmake/`. Cada uno empieza con un bloque de comentarios que explica qué hace y por qué; son buena lectura.
- Diseño del build: `docs/superpowers/specs/2026-10-23-cmake-build-system-design.md`.
- Al implementar el simulador se añadirán `src/Simulator/deps.cmake` y nlohmann/json en `dependencies.cmake` (plan,
  tareas 9 y 15).

## Ideas clave

- Mecánica genérica en `.cmake/`; política en `CMakeLists.txt`, `dependencies.cmake` y los `deps.cmake`.
- El build descubre librerías y componentes por carpetas.
- Dos fases: crear todos los targets y después enlazar, con detección de ciclos.
- `PUBLIC` si aparece en las cabeceras públicas; `PRIVATE` si solo en los `.cpp`.

---

[← 7.1 Estructura del repositorio](01-estructura-del-repositorio.md) · [↑ Ingeniería de software](README.md) · [Siguiente: 7.3 Presets y configuraciones →](03-presets-y-configuraciones.md)

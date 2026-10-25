# 7.1 Estructura del repositorio

> [Manual](../README.md) › [Ingeniería de software](README.md) › Estructura del repositorio

## Vista general

```
ews/
├── CMakeLists.txt          guion del build: solo llama a funciones de .cmake/
├── CMakePresets.json       configuraciones con nombre (Debug, Release, ci-Debug…)
├── .cmake/                 mecánica del build (módulos genéricos) + dependencies.cmake (política del proyecto)
├── .clang-format           estilo del código
├── .clang-tidy             análisis estático
├── .github/workflows/      CI: ci.yml, coverage.yml, lint.yml, release.yml
├── .claude/rules/          reglas para escribir clases (how_to_write_a_class.md)
├── src/
│   ├── main.cpp            ejecutable ews
│   ├── deps.cmake          de qué librerías depende el ejecutable
│   ├── SigInt/             librería
│   │   └── PulseDescriptors/       componente
│   │       ├── include/            cabeceras públicas
│   │       ├── src/                implementación (y cabeceras privadas)
│   │       └── tests/              ut_<Clase>.cpp
│   └── Dummy_Lib/          librería de ejemplo de la plantilla de build
├── scenarios/              (previsto) catálogo y misiones de ejemplo
├── docs/
│   ├── manual/             este manual
│   └── superpowers/        specs, planes y revisiones de diseño
└── .build/<preset>/        salida del build (ignorada por git)
```

## Tres niveles: librería, componente, clase

| Nivel | Qué es | Ejemplo | En CMake |
| --- | --- | --- | --- |
| **Librería** | Una carpeta directamente bajo `src/` | `src/SigInt/` | Un target `ews_SigInt` con alias `ews::SigInt` |
| **Componente** | Una subcarpeta de la librería con `include/`, `src/` o `tests/` | `src/SigInt/PulseDescriptors/` | Sus fuentes entran en la librería; sus tests son un ejecutable propio |
| **Clase** | Tres ficheros: `include/<C>.h`, `src/<C>.cpp`, `tests/ut_<C>.cpp` | `AngleOfArrival` | — |

La librería es la **unidad de enlace** (lo que otros enlazan) y el componente la **unidad de organización y de test**.
Agrupar varias clases relacionadas en un componente evita tener una librería por clase y, a la vez, mantiene los tests
separados por tema.

Cuando el simulador esté implementado habrá dos librerías:

```
src/SigInt/      Units, PulseDescriptors, Geometry, Emission, Library            (namespace sigint)
src/Simulator/   Emitter, Channel, Receiver, Engine, Config, Runner              (namespace sim)
```

## `include/` frente a `src/`

- **`include/`** es la interfaz pública: cualquiera que enlace la librería puede incluir esas cabeceras.
- **`src/`** es privado: solo lo ve la propia librería. Aquí puede haber también **cabeceras privadas**. Por ejemplo,
  `JsonReader.h` irá en `src/Simulator/Config/src/` porque incluye nlohmann/json, y así ni los tests ni el resto del
  proyecto ven esa dependencia.

Los includes del proyecto se escriben siempre con `<>` y sin ruta: `#include <AngleOfArrival.h>`. Funciona porque
CMake añade cada `include/` como carpeta de búsqueda (ver [7.2](02-sistema-de-build.md)). La contrapartida es que **dos
cabeceras no pueden llamarse igual** en toda la librería, aunque estén en componentes distintos.

## Dónde va cada cosa

| Quiero… | Lo pongo en… |
| --- | --- |
| Una clase nueva de un componente existente | `src/<Lib>/<Comp>/include/<C>.h`, `src/<C>.cpp`, `tests/ut_<C>.cpp` |
| Un componente nuevo | Una carpeta nueva en la librería con al menos `include/`, `src/` o `tests/`. CMake la descubre solo |
| Una librería nueva | Una carpeta nueva bajo `src/`, con su `deps.cmake` si depende de algo |
| Una dependencia externa | Una llamada `proj_fetch_external` en `.cmake/dependencies.cmake` y su uso en el `deps.cmake` de la librería |
| Datos de un test | `tests/data/` del componente (p. ej. la misión golden en `src/Simulator/Runner/tests/data/`) |
| Un documento de diseño | `docs/superpowers/specs/`; su plan de implementación en `docs/superpowers/plans/` |

## Convenciones de nombres

| Elemento | Convención | Ejemplo |
| --- | --- | --- |
| Clases | PascalCase | `PulseDescriptorWords` |
| Atributos | camelCase + `_`, con unidad | `azimuthDeg_`, `toaNs_` |
| Accesores | `get_`/`set_` + nombre del atributo tal cual | `get_azimuthDeg()` |
| Parámetros | prefijo `i` (entrada) u `o` (salida) | `iOther`, `oOs`, `oWriter` |
| Namespaces | minúsculas, con comentario del nombre completo encima | `// Signals Intelligence` / `namespace sigint` |
| Ficheros de test | `ut_<Clase>.cpp` | `ut_AngleOfArrival.cpp` |
| Identificadores y comentarios | inglés | — |
| Mensajes al usuario, documentación | español | `"debe ser > 0"` |

## En este proyecto

- Clase de referencia que cumple todas las reglas: `src/SigInt/PulseDescriptors/` (`AngleOfArrival`).
- `Dummy_Lib` es el ejemplo mínimo de la plantilla de build; hoy `src/deps.cmake` enlaza el ejecutable con ella.

## Ideas clave

- Librería = carpeta bajo `src/`; componente = subcarpeta con `include/`/`src/`/`tests/`; clase = 3 ficheros.
- `include/` es público, `src/` es privado.
- Añadir carpetas basta: el build las descubre.

---

[← Ingeniería de software](README.md) · [↑ Manual](../README.md) · [Siguiente: 7.2 Sistema de build →](02-sistema-de-build.md)

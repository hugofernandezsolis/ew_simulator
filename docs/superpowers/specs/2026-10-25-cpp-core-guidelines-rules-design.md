# Reglas de C++ basadas en las C++ Core Guidelines: diseño

Fecha: 2026-10-25

## 1. Objetivo

Sustituir `.claude/rules/how_to_write_a_class.md` por una guía de C++ general para todo el código del repositorio,
basada en las **C++ Core Guidelines** (en adelante, CG), y configurar `.clang-format` y `.clang-tidy` para que
comprueben automáticamente todo lo que puedan.

Las reglas existen para aportar **claridad**, **estandarización** y **optimización**. Ninguna es inmutable: se cambia
cuando el cambio mejora de verdad alguno de esos tres criterios.

### Criterio de éxito

- La guía cubre clases, funciones, errores, cabeceras, nombres, expresiones y tests. Cada regla cita su ID de las CG
  (o se marca como propia del repo) y dice cómo se comprueba.
- `clang-tidy` y `clang-format` detectan solos la mayoría de los incumplimientos. El documento solo recoge lo que una
  herramienta no puede verificar.
- `Dummy` y `AngleOfArrival` cumplen las reglas nuevas. Compilan sin avisos en Debug y Release, pasan los tests y
  `lint` y `format-check` terminan sin errores.

### Fuera de alcance

- MISRA C++:2023 (descartado: el proyecto no es un sistema crítico embebido).
- Convenciones de LLVM Coding Standards más allá de la base de `clang-format`.
- Clases nuevas del simulador: se escribirán con estas reglas, pero no forman parte de este trabajo.

## 2. Decisiones

| Decisión | Elección | Motivo |
|---|---|---|
| Alcance | Guía C++ general | Las CG cubren todo el lenguaje; las clases son solo una parte |
| Estructura | Varios archivos en `.claude/rules/cpp/` | Archivos cortos por tema |
| Nombres | Convención actual (camelCase, `get_`/`set_` + atributo, prefijos `i`/`o`/`io`, `_` final) | Coherencia con lo existente; NL.8 prima la coherencia sobre el estilo concreto |
| Accesores | Según invariante: `struct` sin accesores / `class` con accesores | C.2, C.8, C.131 |
| Organización de `class` | Orden y banners actuales | Preferencia del autor; desviación de NL.16 |
| Organización de `struct` | Sin banners | Un agregado son unos pocos atributos documentados |
| `(void)` | Se elimina | NL.25 |
| Doxygen | Bloque completo siempre (`@brief`, `@param`, `@return`) | Preferencia del autor; desviación de NL.1 |
| Guardas de inclusión | `#pragma once` | Preferencia del autor; desviación de SF.8 |
| `to_string` | Método miembro | Preferencia del autor; desviación de C.4 |
| Errores | Excepciones + `std::expected` + `assert` | E.2, E.3, F.21, I.6 |
| Inicialización de locales | `=` para valores, `{}` para objetos | Legibilidad; el estrechamiento ya lo detectan `-Wconversion` y `clang-tidy` (ES.23 relajada) |
| `clang-tidy` | Grupos amplios + exclusiones justificadas | Máxima cobertura |
| Tests en `clang-tidy` | Checks relajados desde el target `lint` de CMake | Un solo sitio de configuración (el editor puede mostrar avisos en tests que CI no da) |

## 3. Archivos de reglas

Carpeta `.claude/rules/cpp/`. Se borra `.claude/rules/how_to_write_a_class.md`.

| Archivo | Contenido | CG | `paths:` |
|---|---|---|---|
| `principles.md` | Objetivos, formato de cada regla, prioridad herramienta > documento, lista de desviaciones | P, NR, Per | `src/**/*.{h,hpp,cpp}` |
| `naming.md` | Nombres y formato | NL | ídem |
| `headers.md` | Cabecera de archivo, includes, namespace, `.h` frente a `.cpp` | SF | ídem |
| `functions.md` | Parámetros, retorno, `const`, `noexcept`, Doxygen | F, I, Con | ídem |
| `classes.md` | `struct`/`class`, accesores, funciones especiales, operadores, `to_string`, clases base, plantilla de banners | C | ídem |
| `errors.md` | Excepciones, `std::expected`, `assert`, RAII | E, R | ídem |
| `expressions.md` | Inicialización, `const`, números mágicos, casts, macros, bucles, `auto` | ES, Con | ídem |
| `tests.md` | Estructura de los tests unitarios | (propia) | `src/**/tests/**` |

Cada regla sigue el formato: **norma → ID de las CG → por qué → cómo se comprueba** (`clang-tidy: <check>`,
`clang-format` o `revisión`).

## 4. Contenido de las reglas

### 4.1 `principles.md`

- Los tres criterios (claridad, estandarización, optimización) y que una regla se cambia si mejora alguno.
- Lo que comprueba una herramienta lo comprueba la herramienta. Si una regla del documento choca con `clang-format` o
  `clang-tidy`, se corrige una de las dos; nunca se deja el conflicto.
- Medir antes de optimizar (Per.1–Per.6). Las reglas de rendimiento solo evitan costes que no aportan nada.
- **Desviaciones conscientes de las CG**, cada una con su motivo: NL.1 (Doxygen siempre), NL.16 (orden y banners de
  clase), SF.8 (`#pragma once`), C.4 (`to_string` miembro), ES.23 (`=` para valores), I.24 (parámetros adyacentes del
  mismo tipo tolerados).

### 4.2 `naming.md`

| Elemento | Convención | Ejemplo |
|---|---|---|
| Tipos (`class`, `struct`, `enum`, alias, *concepts*) | `PascalCase` | `AngleOfArrival` |
| Funciones y métodos | `snake_case`, verbo | `to_string`, `wrap_angle` |
| Accesores | `get_`/`set_` + nombre del atributo tal cual (sin `_`) | `get_azimuthDeg` |
| Atributos privados | `camelCase_`, con la unidad en el nombre | `azimuthDeg_` |
| Atributos públicos (`struct`) | `camelCase` | `dummy` |
| Parámetros | `camelCase` con prefijo `i` (entrada), `o` (salida), `io` (entrada y salida) | `iNewAzimuthDeg` |
| Variables locales y `constexpr` | `camelCase`; nunca `MAYÚSCULAS` (NL.9) | `fullTurnDeg` |
| Enumeradores (`enum class`, Enum.3) | `PascalCase` | `Band::Ku` |
| Namespaces | minúsculas | `sigint` |
| Macros | `MAYÚSCULAS` (y evitarlas, ES.31) | — |

Lo comprueba `readability-identifier-naming`. Que el prefijo `i`/`o`/`io` sea el correcto se comprueba en revisión.

Formato: lo decide `clang-format` (NL.17 K&R, NL.18 `T* p`, NL.26 `const T&`), sin reglas de formato escritas a mano.

### 4.3 `headers.md`

- Cabecera de archivo `@file`, `@author`, `@date` (de creación), `@brief`, `@copyright`, como ahora.
- `.h`: cabecera → `#pragma once` → includes. Las 4 secciones de includes con sus comentarios exactos, aunque estén
  vacías. Todos los includes con `<>` (compatible con SF.12: los headers del proyecto se resuelven por la ruta de
  include). En el `.cpp`, su propio `.h` va en `// Project includes`.
- *Include what you use* (SF.10): `misc-include-cleaner`. El `.cpp` incluye su `.h` (SF.5) y todo `.h` compila por
  sí solo (SF.11).
- Ni `using namespace` ni namespaces anónimos en un `.h` (SF.7, SF.21): `google-global-names-in-headers`.
- Namespace con el comentario del nombre completo encima y `} // namespace x` (SF.20). Clase nueva: el namespace de
  las demás clases del directorio o, si no hay, preguntar.
- En el `.h` solo declaraciones, salvo `= default`, plantillas, `constexpr` y *hidden friends*. Con LTO no hace falta
  definir en el `.h` para rendimiento.

### 4.4 `functions.md`

- Paso de parámetros (F.15–F.18), según el tipo:

  | Tipo | Parámetro |
  |---|---|
  | Barato (trivialmente copiable y ≤ 16 bytes) | por valor |
  | Con recursos que se guarda | por valor + `std::move` |
  | Grande sin recursos, o solo lectura de un tipo con recursos | `const T&` |
  | Entrada y salida | `T&`, prefijo `io` |

  Lo comprueban `modernize-pass-by-value`, `performance-unnecessary-value-param` y `performance-move-const-arg`.
- Devolver valores, no parámetros de salida (F.20). Varios resultados → `struct`; puede no haber resultado →
  `std::optional` / `std::expected` (F.21).
- Métodos `const` si no modifican el objeto (Con.2): `readability-make-member-function-const`.
- `noexcept` en movimiento, `swap` y destructores (F.6, C.66): `performance-noexcept-*`.
- Sin `(void)` (NL.25): `modernize-redundant-void-arg`.
- Bloque Doxygen completo solo en el `.h`. Textos de `@brief` fijos para las funciones estándar (`Setter`, `Getter`,
  `Default constructor`, `Equal comparison operator`, `Ostream operator`…); descripción real en las demás.

### 4.5 `classes.md`

**`struct` o `class` (C.2, C.8, C.131):**

| | `struct` (sin invariante) | `class` (con invariante) |
|---|---|---|
| Atributos | Públicos, `camelCase` | Privados, `camelCase_`, en el bloque `private:` final |
| Accesores | Ninguno | Getter siempre; setter que mantiene la invariante, salvo atributos fijos tras la construcción |
| Constructores | Ninguno (agregado; `Dummy{.dummy = true}`) | Por defecto `= default` (C.45) y con parámetros que valida o normaliza (C.41) |
| Banners | No | Sí (plantilla actual, orden actual) |

- Atributos: inicializados con `{}` (C.48, ES.20), documentados con `///<`, nunca `const` ni referencias en tipos
  copiables (C.12), nunca `protected` (C.133).
- Funciones especiales: trivialmente copiable → Regla del Cero (C.20); con recursos → las cinco `= default` en el `.h`
  (C.21); nunca solo algunas (C.21). A mano solo si se gestiona un recurso (preferir `std::unique_ptr`, R.20): soportar
  la autoasignación en copia y movimiento (C.62, C.65) y movimiento `noexcept` (C.66). Lo comprueba
  `cppcoreguidelines-special-member-functions`.
- Clase base: destructor `public virtual` o `protected` no virtual (C.35); copia y movimiento públicos suprimidos en
  las polimórficas (C.67); `override`/`final` (C.128, `modernize-use-override`).
- `explicit` en los constructores de un argumento (C.46) y en los operadores de conversión (C.164):
  `google-explicit-constructor`.
- `friend bool operator==(const C&, const C&) noexcept = default;` (C.86, C.161), sin `operator!=`.
- `std::string to_string() const;` (desviación de C.4) con el formato `[Etiqueta: valor, ...]`, y
  `friend std::ostream& operator<<` en el `.h`, que delega en `to_string`. Aplica a `struct` y `class`.
- Acceso a los atributos dentro de una `class`: por los accesores, salvo en el cuerpo de los accesores, las listas de
  inicialización, los helpers de la invariante y las funciones especiales escritas a mano.
- Anexo: plantilla de banners y orden de las secciones y de las funciones (R5 y R9 actuales).

### 4.6 `errors.md`

| Situación | Mecanismo | CG | Comprueba |
|---|---|---|---|
| La función no puede hacer su trabajo | Excepción de `<stdexcept>` o derivada | E.2, E.3, E.14 | `hicpp-exception-baseclass` |
| Fallar es un resultado normal | `std::expected<T, E>` (`E` = `enum class`) o `std::optional<T>` | F.21, I.10 | `bugprone-unused-return-value` |
| Error de programación | `assert` | I.6, I.8 | revisión |
| Lanzar y capturar | Por valor / por `const&` | E.15 | `misc-throw-by-value-catch-by-reference` |
| `try/catch` | Solo donde se puede tratar el error | E.17, E.18 | revisión |
| Destructores, movimientos, `swap` | `noexcept`, nunca fallan | E.16, C.66 | `bugprone-exception-escape` |
| Recursos | RAII; sin `new`/`delete`/`malloc` sueltos | E.6, R.11 | `cppcoreguidelines-owning-memory`, `-no-malloc` |

### 4.7 `expressions.md`

| Regla | CG | Comprueba |
|---|---|---|
| Inicializar siempre al declarar; `=` para valores, `{}` para objetos y agregados | ES.20, ES.23 (relajada) | `cppcoreguidelines-init-variables` |
| `const`/`constexpr` por defecto | Con.1, Con.4, Con.5 | `misc-const-correctness` |
| Sin números mágicos en producción: `constexpr` con nombre y unidad. Tests exentos | ES.45 | `readability-magic-numbers` |
| Sin estrechamiento implícito | ES.46 | `-Wconversion`, `cppcoreguidelines-narrowing-conversions` |
| Solo casts con nombre; nunca quitar `const` | ES.48–ES.50 | `cppcoreguidelines-pro-type-*` |
| Sin macros para constantes ni funciones | ES.31 | `cppcoreguidelines-macro-usage` |
| `for` por rangos cuando se pueda | ES.71 | `modernize-loop-convert` |
| `auto` cuando el tipo ya se ve | ES.11 | `modernize-use-auto` |

### 4.8 `tests.md`

- Archivo `tests/ut_<Tipo>.cpp`: cabecera → includes → namespace → `static_assert` → fixture → tests.
- `static_assert`: `is_nothrow_move_constructible_v` e `is_nothrow_move_assignable_v` siempre;
  `is_trivially_copyable_v` con Regla del Cero; `is_aggregate_v` en los `struct`.
- Fixture `<Tipo>Test` con el objeto como atributo, sin `new`/`delete`.
- Un test por función pública declarada; las funciones especiales implícitas no tienen test.
- `struct`: valores por defecto, `to_string`, `==` (un caso por atributo), `<<`. `class`: además, setters (un test
  por efecto) y getters (uno por getter).
- Excepciones con `EXPECT_THROW`; `std::expected` con un test del valor y uno por error.
- Comentario `// Test …` antes de cada `TEST_F`, nombre `FunctionBehavior`, `EXPECT_FLOAT_EQ`/`EXPECT_DOUBLE_EQ`,
  orden de los tests igual al de declaración.

## 5. Herramientas

### 5.1 `.clang-format`

Base LLVM actual, más:

```yaml
QualifierAlignment: Left
SortIncludes: CaseSensitive
InsertNewlineAtEOF: true
```

### 5.2 `.clang-tidy`

```yaml
Checks: >
  -*,
  bugprone-*, cppcoreguidelines-*, misc-*, modernize-*, performance-*, readability-*,
  google-explicit-constructor, google-global-names-in-headers, hicpp-exception-baseclass,
  -bugprone-easily-swappable-parameters,
  -modernize-use-trailing-return-type,
  -modernize-use-nodiscard,
  -readability-identifier-length,
  -readability-uppercase-literal-suffix,
  -readability-braces-around-statements
CheckOptions:
  readability-identifier-naming.*: (tabla de 4.2)
WarningsAsErrors: "*"
HeaderFilterRegex: "/ews/src/"
```

Cada exclusión lleva un comentario con su motivo. La lista final se cierra ejecutando `clang-tidy` sobre el código:
un aviso que choca con una regla adoptada → se excluye el check con su motivo; un aviso que señala un problema real →
se corrige el código.

### 5.3 Tests en el target `lint`

`.cmake/Tools.cmake` separa los ficheros de test (`*/tests/*`) del resto y ejecuta `clang-tidy` sobre ellos con
`--checks=` adicional que desactiva los checks incompatibles con GoogleTest (variables globales, `new` interno de las
macros, varargs…) y los de números mágicos. La lista se cierra igual que en 5.2. Limitación aceptada: `clangd` en el
editor no conoce esa relajación.

## 6. Migración

- `Dummy` (un `bool` sin invariante) pasa a `struct` agregado: sin accesores ni constructores; con `to_string`, `==`
  *hidden friend* y `<<`. Sus tests se adaptan.
- `AngleOfArrival` sigue siendo `class`: sin `(void)`, `==` como *hidden friend*, constantes `constexpr` con nombre en
  lugar de `360.0f`/`180.0f`/`90.0f`, y lo que pida `clang-tidy`.
- Memoria: se actualizan `class-rules-apply-to-all` (ya no todas las reglas se aplican a los `struct`) y la de los
  nombres de los accesores si hace falta.

## 7. Verificación

1. `cmake --build --preset Debug` y `--preset Release` sin avisos.
2. `ctest` en los dos presets.
3. `cmake --build --preset Release --target format-check` y `--target lint` sin errores.

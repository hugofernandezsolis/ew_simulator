# 7.4 Reglas para escribir clases

> [Manual](../README.md) › [Ingeniería de software](README.md) › Reglas para escribir clases

Todas las clases del proyecto siguen las reglas de `.claude/rules/how_to_write_a_class.md` (R1–R12). Esta página no
las repite al pie de la letra (el fichero es la referencia): explica **qué pide cada una y por qué**. La clase de
referencia que las cumple es `AngleOfArrival` (`src/SigInt/PulseDescriptors/`).

## Por qué tantas reglas

Una clase escrita siempre igual se lee sin esfuerzo: se sabe dónde está cada cosa antes de abrir el fichero. Las reglas
también cierran la puerta a errores típicos de C++ (atributos sin inicializar, copias que comparten estado, objetos
movidos en estado raro). El precio es más código repetitivo, que se compensa con uniformidad y tests sistemáticos.

## Forma de los ficheros (R1–R5)

| Regla | Qué pide | Por qué |
| --- | --- | --- |
| **R1** Cabecera | Bloque Doxygen con `@file`, `@author`, `@date` de creación, `@brief`, `@copyright` | Autoría y propósito visibles en la línea 1 |
| **R2** Includes | Cuatro secciones fijas (`C`, `C++`, `External`, `Project`), todas con `<>`; incluir lo que se usa | Se ve de un vistazo de qué depende el fichero |
| **R3** Namespace | Comentario con el nombre completo encima (`// Signals Intelligence`) y cierre comentado | Los namespaces cortos (`sigint`, `sim`) se entienden sin buscar |
| **R4** Comentario de clase | `@class` y `@brief`; los atributos se documentan en su línea, no aquí | Una sola fuente de documentación por atributo |
| **R5** Secciones | Orden fijo `CLASS METHODS`, `SETTERS & GETTERS`, `OPERATORS`, `CONSTRUCTORS`, `DESTRUCTORS` (+ `FRIEND FUNCTIONS`) en cada nivel de acceso, **siempre presentes** aunque estén vacías | Cada función tiene un sitio predecible |

## Documentación y atributos (R6–R7)

- **R6**: cada función lleva su bloque `@brief`/`@param`/`@return`, en el `.h` **y** repetido en el `.cpp`. Las
  funciones estándar usan textos fijos (`Setter`, `Copy constructor`…).
- **R7**: los atributos van en un **segundo bloque `private:`** al final, siempre inicializados con llaves
  (`float azimuthDeg_ {};`), con `///<` alineado y la **unidad en el nombre**. Las llaves garantizan que ningún atributo
  queda sin valor; la unidad en el nombre evita el error más común en código físico (sumar µs con ns).

## La interfaz completa (R8)

Por **cada atributo** `T x_`, cinco accesores:

| Firma | Para qué |
| --- | --- |
| `void set_x(const T&)` | Asignar copiando |
| `void set_x(T&&)` | Asignar moviendo (sin copiar un vector entero) |
| `T& set_x(void)` | **Reference setter**: modificar en el sitio (`set_values().push_back(…)`) |
| `T get_x(void)` | Obtener una copia |
| `const T& get_x(void) const` | Leer sin copiar desde un objeto `const` |

Por **cada clase**: `to_string`, copia y movimiento (constructor y asignación), `==`, `!=`, constructor por defecto, constructor con
todos los atributos, destructor y `operator<<`. Detalles: el movimiento deja el origen con los valores por defecto
(`std::exchange`), y las asignaciones comprueban la autoasignación.

**Excepción de acceso**: si un atributo tiene una **invariante** (por ejemplo, el azimut se normaliza a [0, 360)), su
reference setter es **privado**. Si fuera público, `aoa.set_azimuthDeg() = 720;` saltaría la normalización.

## Orden, texto y acceso (R9–R11)

- **R9**: el mismo orden de funciones en `.h` y `.cpp`; los accesores agrupados por tipo y, dentro, por orden de
  atributos.
- **R10**: `to_string` da `[Etiqueta: valor, …]` con `std::format`, y `operator<<` solo delega en él. Útil en los
  mensajes de los tests que fallan.
- **R11**: dentro de la clase también se accede a los atributos **por los accesores**, salvo en los propios accesores,
  en la lista de inicialización y en los helpers que mantienen una invariante. Así, si un setter normaliza, nadie se lo
  salta por accidente.

### La trampa de R11

En un método **no `const`**, `this->get_x()` elige la sobrecarga `T get_x(void)`, que devuelve una **copia**. Compila
sin avisos, pero lo que se haga sobre la copia se pierde:

| Intención | Mal (opera sobre una copia) | Bien |
| --- | --- | --- |
| Avanzar la PRI del emisor | `this->get_pri()->next()` | `this->set_pri()->next()` |
| Incrementar un contador | `++this->get_nextPulseId()` | `++this->set_nextPulseId()` |
| Leer sin copiar | `this->get_valuesNs()[i]` (copia el vector) | `std::as_const(*this).get_valuesNs()[i]` |

Regla práctica: **para modificar, reference setter; para leer en un método no `const`, `std::as_const`**. El plan del
simulador tiene tests diseñados para detectar esta trampa (un stagger que daría 0, 1, 2, 3 en lugar de 0, 1, 3, 6).

## Tests (R12)

Cada clase tiene su `tests/ut_<Clase>.cpp` con un fixture, una función bajo prueba por test y tests para todas las
funciones públicas. Se explica en [7.5](05-tests.md).

## Excepciones en el simulador

Las reglas se aplican a **todas** las clases, también a las que antes habrían sido un simple `struct`. Solo hay
excepciones donde C++ hace imposible o peligroso cumplirlas. Están en el plan del simulador, decisión 2:

| Excepción | Clases | Qué cambia y por qué |
| --- | --- | --- |
| **E1** Interfaces | `PriGenerator`, `ScanPattern`, `PulseRecordWriter`… | Sin atributos ni accesores; copia `protected` (evita *slicing*); `==` compara el tipo dinámico y delega en `isEqual` |
| **E2** Implementaciones | `FixedPri`, `CircularScan`… | `final`; el movimiento no toca la base (no tiene estado y el lint marcaría *use-after-move*) |
| **E3** Clases con estado | `StaggerPri`, `Emitter`, `Receiver`… | Constructor de configuración que fija el estado inicial; reference setters del estado privados; `std::logic_error` ante un estado imposible |
| **E4** `EventScheduler` | — | Sin copia (sus acciones capturan `this` de otro objeto) y sin `==` (`std::function` no se compara) |
| **E5** `Simulation` | — | Ni copia ni movimiento; solo getters `const` públicos |
| **E6** Atributos polimórficos | `unique_ptr<I>`, `shared_ptr<const I>` | Copia profunda con `clone()`; el getter `const` devuelve `const I*` para que el `const` proteja al objeto apuntado |
| **E7** Punteros no poseídos | `std::ostream*`, `PulseRecordWriter*` | La copia comparte el puntero; `==` compara identidad |
| **E8** `ConfigError` | — | Hereda de `std::runtime_error`; el texto de `what()` se recalcula en cada setter |
| **E9** `JsonReader` | — | Privado de `Config`: sin test propio, se prueba a través de los loaders |
| **E10** Funciones libres y enums | `Geometry`, loaders, `IntrapulseModulation` | No son clases: solo R1–R3 y R6 |

## En este proyecto

- Reglas: `.claude/rules/how_to_write_a_class.md` (incluye dos *checklists*: al crear una clase y al añadir un atributo).
- Excepciones y convenciones de `to_string` para tiempos, enums, punteros y contenedores: plan del simulador,
  decisión 2.

## Ideas clave

- Mismo esqueleto en todas las clases: se lee sin esfuerzo.
- Cinco accesores por atributo; el reference setter es privado si hay invariante.
- Dentro de la clase, siempre por los accesores, y cuidado con la trampa del getter por valor.
- Las excepciones existen solo donde C++ lo obliga, y están listadas.

---

[← 7.3 Presets y configuraciones](03-presets-y-configuraciones.md) · [↑ Ingeniería de software](README.md) · [Siguiente: 7.5 Tests →](05-tests.md)

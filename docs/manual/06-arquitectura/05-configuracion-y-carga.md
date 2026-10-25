# 6.5 Configuración y carga

> [Manual](../README.md) › [Arquitectura del simulador](README.md) › Configuración y carga

## Organización de los ficheros

```
scenarios/
├── catalog/                 ← un fichero por tipo de emisor
│   ├── SearchRadar_X.json
│   └── FireControl_Y.json
└── missions/
    └── demo_01.json         ← "catalogDir": "../catalog"
```

- El **catálogo** es una carpeta: cada fichero regular con extensión exactamente `.json` es un tipo de emisor. Se leen
  en orden alfabético y el resto de ficheros se ignora.
- La **misión** dice dónde está su catálogo (`catalogDir`, relativo al propio fichero de la misión).

## Convenciones del JSON

- **La unidad va en el nombre de la clave**: `frequencyMHz`, `valueUs`, `periodS`, `positionM`, `peakPowerDbm`. Los
  loaders convierten a SI (Hz, ns, grados) al cargar; el resto del programa nunca ve µs ni MHz.
- **Uniones etiquetadas**: cada bloque configurable tiene un campo `kind` que decide qué clase se construye y qué
  claves se admiten.

```json
"pri":  { "kind": "stagger", "valuesUs": [1000, 1200, 1100] }
"rf":   { "kind": "list", "frequenciesMHz": [9000, 9100], "pulsesPerHop": 3 }
"scan": { "kind": "circular", "periodS": 6.0, "elevationDeg": 2.0 }
```

| Bloque | `kind` admitidos |
| --- | --- |
| `pri` | `fixed`, `stagger`, `sliding`, `dwellSwitch` |
| `rf` | `fixed`, `list` |
| `pw` | `fixed` |
| `scan` | `fixed`, `circular`, `sector` |
| `antenna` | `gaussian` |

Los ejemplos completos de catálogo y misión, y la tabla con todas las claves de cada `kind`, están en la spec, §5.

## Del JSON a los objetos

```
  mision.json ──▶ readCatalogDir ──▶ loadCatalog(carpeta) ──▶ parseMission(contenido, catálogo) ──▶ Mission
                  fase 1              fase 2                    fase 3
```

Cada operación tiene dos versiones:

| Función | Recibe | Para qué |
| --- | --- | --- |
| `parseCatalog` | contenido de los ficheros (nombre, texto) | La lógica: se prueba con JSON en el propio test, sin disco |
| `loadCatalog` | ruta de la carpeta | Lee del disco y llama a `parseCatalog` |
| `parseMission` | nombre, contenido y catálogo | La lógica, sin disco |
| `loadMission` | ruta del fichero de la misión | Lee la misión, carga el catálogo y llama a `parseMission` |

Separar **leer** de **interpretar** permite probar casi toda la validación con cadenas de texto, y dejar para unos
pocos tests los errores de disco (carpeta inexistente, fichero ilegible…).

### Quién conoce JSON

Solo los ficheros de `src/Simulator/Config/src/` incluyen `<nlohmann/json.hpp>`. En CMake la dependencia es
`PRIVATE_EXTERNAL`: ni las cabeceras públicas de `Config` ni los tests la ven. Ventajas:

- El dominio (`Emitter`, `EmitterMode`…) no sabe de dónde vienen sus datos: se podría cargar desde YAML o desde una
  base de datos sin tocarlo.
- Los tests del dominio construyen objetos directamente, sin ficheros.

Dentro de `Config`, la clase privada **`JsonReader`** envuelve un nodo JSON con su ruta (`modes.search.pri`) y una
lista de errores compartida. Sus lecturas tipadas (`number`, `time`, `positiveInteger`, `position`, `id`…) no lanzan
excepciones: si algo está mal, apuntan el error y devuelven "vacío". Al terminar un objeto, `finish()` añade un error
por cada clave que nadie leyó.

## Validación

Todo se valida **al cargar, antes de simular**. Una vez arrancada, la simulación no puede fallar por culpa de la
configuración.

| Regla | Ejemplo de lo que se rechaza |
| --- | --- |
| Claves desconocidas son error | `"frecuencyMHz"` (errata): no se ignora en silencio |
| Tipos | `"durationS": "120"` (texto en lugar de número) |
| Números finitos; enteros de verdad | `pulsesPerDwell: 2.5` o `3.0` (en JSON, `3.0` es decimal) |
| Tiempos ≤ 10⁶ s y > 0 **después** de redondear a 1 ns | `valueUs: 0.0004` (son 0 ns: provocaría un bucle infinito) |
| Rangos físicos | frecuencia fuera de [30, 300 000] MHz, elevación fuera de [−90, 90], `widthDeg` fuera de (0, 360)… |
| Coherencia | PW máxima del modo ≥ PRI mínima; en `sliding`, `minUs ≥ maxUs` |
| Referencias | tipo o modo inexistentes, ids repetidos, un modo llamado `off` en el catálogo |
| Ids | solo `[A-Za-z0-9_-]+`, así nunca hay que escapar comas en el CSV |
| Parámetros de segmento | exactamente los que pide el scan del modo, ni más ni menos |
| Geometría | emisor a menos de 1 m del receptor (la FSPL es de campo lejano) |

Un calendario más largo que la misión **no** es error: se recorta.

### Conversión de tiempos

Los tiempos del JSON (µs, s) se convierten a ns enteros redondeando al más cercano (`std::llround`), en este orden:

1. Si es `≤ 0` → error.
2. Si es mayor que 10⁶ s → error. Se comprueba **en `double`, antes de convertir**, porque convertir un valor enorme a
   `int64` desbordaría.
3. Se convierte.
4. Si ha quedado en 0 ns → error ("debe ser > 0 tras redondear a 1 ns").

¿Por qué ns enteros? Porque sumar PRI una y otra vez en `double` acumula error de redondeo y el TOA derivaría. Con
enteros, mil sumas de 1000 ns son exactamente 1 000 000 ns.

## Gestión de errores

La idea es que el usuario vea **todos** sus errores de una vez, no uno por ejecución.

- Cada fase **acumula** sus errores y, al terminar, si hay alguno lanza un único `ConfigError` con la lista completa.
- Las fases van en orden; si una falla, las siguientes no se ejecutan (no tiene sentido validar la misión contra un
  catálogo roto).
- Cada error lleva el **nombre del fichero** y la **ruta dentro del JSON**:

```
demo_01.json: emitters[0].schedule[2].mode: el modo 'trak' no existe en el tipo 'SearchRadar_X'
X.json: modes.search.pri.valueUs: debe ser > 0 tras redondear a 1 ns
X.json: JSON mal formado: …
```

- Cualquier error de disco (`std::filesystem::filesystem_error`) o del parser (`nlohmann::json::exception`, la base de
  todas sus excepciones) se convierte en `ConfigError`. Ninguna excepción de librería llega sin capturar al usuario.
- `ConfigError` hereda de `std::runtime_error`: su `what()` son todos los errores unidos por saltos de línea.

Limitación conocida: una clave **repetida** en el mismo objeto no se detecta (nlohmann se queda con el último valor).

## En este proyecto

- `src/Simulator/Config/`: `ConfigError`, `CatalogLoader`, `MissionLoader` (públicos) y `JsonReader` (privado). Plan,
  tareas 15 y 16, con la tabla de mensajes exactos.
- La detección de claves desconocidas en `JsonReader` es otra de las piezas para que la escribas tú.

## Ideas clave

- Catálogo = carpeta de JSON, uno por tipo; la misión apunta a él con `catalogDir`.
- Unidad en el nombre de la clave; los loaders convierten a SI.
- `parse*` (lógica, sin disco) separado de `load*` (disco).
- Se valida todo antes de simular y se informan todos los errores, con fichero y ruta.

---

[← 6.4 Flujo de un pulso](04-flujo-de-un-pulso.md) · [↑ Arquitectura del simulador](README.md) · [Siguiente: 6.6 Ejecución y salida →](06-ejecucion-y-salida.md)

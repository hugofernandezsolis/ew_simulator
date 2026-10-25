# Simulador de emisores y receptor: diseño

Fecha: 2026-10-24. Revisada dos veces el mismo día, tras las dos rondas de revisión de
`docs/superpowers/reviews/2026-10-24-plan-review-*.md`.

## 1. Objetivo

Construir un simulador a **nivel de pulso** que, a partir de ficheros de configuración JSON, haga emitir a una serie de
emisores ya clasificados y registre en un fichero CSV los pulsos que recibe un receptor, con su instante de llegada,
sus parámetros medidos y la verdad de terreno (*ground truth*) de quién los emitió.

La verdad de terreno permitirá, más adelante, evaluar algoritmos de procesado (deinterleaver, clasificador)
comparando su salida con lo que realmente se emitió.

### Alcance de la primera versión

- Varios emisores y **un** receptor, todos en posiciones **fijas**.
- Simulación **determinista**: sin aleatoriedad.
- El AoA medido es el geométrico (**modelo de error 0**).
- Modelo de potencia completo: potencia del emisor, diagrama de antena, pérdida en espacio libre, ganancia y
  sensibilidad del receptor.

### Fuera de alcance (con la puerta abierta)

El diseño no debe impedir añadir más adelante:

- **Plataformas móviles.** Hoy la posición es un atributo constante de `Emitter` y `Receiver`. Añadir trayectorias
  supone cambiar, de forma localizada, las firmas de `Emitter`, `Receiver` y `PropagationChannel` (ver §3, decisión 1).
- **Varios receptores** (y con ellos geolocalización). La resolución de 1 ns (≈ 0,3 m) basta para TDOA. El PDW
  necesitará entonces un identificador de receptor.
- Multitrayecto, línea de vista, curvatura terrestre, coordenadas geodésicas (WGS84 / ECEF).
- **Aleatoriedad** (jitter de PRI, agilidad aleatoria de RF, ruido en la medida) con semilla en el escenario. La fuente
  aleatoria **no** pertenecerá a los generadores (ver §4, reglas del calendario).
- Modelo de error en la medida del AoA distinto de cero.
- Otros diagramas de antena (sinc², tabulado), otros scans (cónico, raster, sector unidireccional), otros formatos de
  salida.
- **Desvío del haz en el sistema de la antena** (ver §4 paso 2.4): hoy se usa la diferencia en azimut y elevación,
  válida solo cerca del horizonte.
- **Solape de pulsos y tiempo muerto del receptor** (pulsos perdidos o fusionados): hoy cada pulso se detecta de forma
  independiente, como si el receptor tuviera canales infinitos.
- **Rango dinámico del receptor** (saturación, *flags* de calidad en el PDW): hoy acepta cualquier potencia por encima
  de la sensibilidad.
- **Banda de cobertura de RF del receptor**: hoy detecta cualquier frecuencia.
- **Pérdidas del sistema** (transmisión, recepción, atmosféricas, polarización).
- Parámetro de la modulación intrapulso (ancho de banda del chirp, número de chips) y polarización.
- **Descriptor de emisor para reconocimiento** (rangos y tolerancias en lugar de valores exactos). `EmitterMode` es el
  modelo **generativo** de un modo; el futuro descriptor que use un clasificador será una clase distinta, que el loader
  podrá construir a partir del mismo JSON.
- Generación de muestras IQ.

## 2. Convenciones

### Unidades

- **Internamente, SI**: metros, segundos, hercios; ángulos en **grados** (como `AngleOfArrival`), convertidos a
  radianes solo dentro de los cálculos trigonométricos.
- **Tiempo como entero en nanosegundos** (`std::chrono::nanoseconds`, alias `sigint::Time`). Las sumas sucesivas de
  PRI son exactas; con `double` el error de redondeo se acumularía y el TOA derivaría. Resolución de 1 ns ≈ 0,3 m de
  propagación.
- Los tiempos del JSON se convierten a ns **redondeando al más cercano** (`std::llround`: los .5 se alejan de cero).
  El límite superior se comprueba **antes** de convertir (para no desbordar `int64`) y el `> 0` **después** (para que
  un valor que redondea a 0 ns sea error), ver §5.
- **Geometría y potencias en `double`**, con una excepción: la amplitud del PDW se guarda en `float`, porque el PDW es
  el final del recorrido y su resolución sobra para la medida.
- Las direcciones (AoA, dirección del haz, dirección emisor → receptor) se guardan en `AngleOfArrival` (`float`). Su
  resolución (≈ 3·10⁻⁵° cerca de 360°) es despreciable frente a cualquier ancho de haz realista y a la precisión del
  CSV. Nota de terminología: en EW "ángulo de llegada" es la dirección desde la que el receptor ve llegar la señal; aquí
  el mismo tipo se usa también para la dirección del haz, porque comparte invariantes (rango y normalización).
- **En los JSON y el CSV, la unidad va en el nombre de la clave/columna** (`frequencyMHz`, `pulseWidthUs`,
  `positionM`, `amplitudeDbm`). Los loaders convierten a SI al cargar.

### Sistema de coordenadas

- **Plano tangente local ENU**: X = Este, Y = Norte, Z = Arriba, en metros, con origen en un punto de referencia del
  escenario.
- **Azimut**: desde el **Norte**, **sentido horario**, en [0, 360) (convención de navegación).
- **Elevación**: desde el plano horizontal, positiva hacia arriba, en [-90, 90].
- Dirección de un punto A a un punto B, con Δ = B − A:
  - `az = atan2(ΔE, ΔN)` (el Este es el **primer** argumento), normalizado a [0, 360).
  - `el = atan2(ΔU, √(ΔE² + ΔN²))`.
  - En la vertical exacta (`ΔE = ΔN = 0`) el azimut vale 0 por convenio (`atan2(0, 0) = 0`, sin NaN).
- El AoA es la dirección **del receptor hacia el emisor** (Δ = emisor − receptor).

## 3. Arquitectura

### Enfoque: simulación por eventos discretos

Un **planificador** mantiene una única cola de prioridad de eventos ordenada por `(instante, número de secuencia)`.
El número de secuencia, creciente en el orden de inserción, desempata eventos simultáneos y garantiza que la misma
entrada produzca siempre la misma salida.

Tipos de evento:

- **Emit**: el emisor E emite el pulso P (ya calculado) en el instante t.
- **Arrival**: el pulso P llega al receptor en el instante t.

El reloj salta de evento en evento. Se descartaron un enfoque de flujos perezosos con fusión ordenada (supone llegadas
ordenadas por emisor, lo que deja de ser cierto con plataformas móviles) y un paso de tiempo fijo (o pierde precisión
o recorre millones de pasos vacíos).

### Diagrama

```
  ┌──────────── Configuración (JSON → objetos de dominio) ────────────┐
  │  CatalogLoader (Catalog: tipos de emisor y sus modos)              │
  │  MissionLoader (instancias, calendario, receptor, duración)        │
  └───────────────────────────────┬────────────────────────────────────┘
                                  ▼  Mission
                         ┌─────────────────┐
                         │  MissionRunner  │  Mission + ostream → CSV
                         │   Simulation    │  programa eventos y ejecuta
                         │ EventScheduler  │  cola de prioridad de eventos
                         └──┬───────────┬──┘
       "E emite P en t"     │           │       "P llega en t"
                ┌───────────▼──┐     ┌──▼─────────────────┐     ┌──────────────┐
                │   Emitter    │────▶│ PropagationChannel │────▶│   Receiver   │
                │ (instancia)  │Emit-│ retardo, FSPL,     │Inci-│ sensibilidad,│
                │  └ Segment   │ted- │ G_tx(θ), dirección │dent-│ AoA, registro│
                │    ├ Mode    │Pulse│ de llegada         │Pulse└──────┬───────┘
                │    │ ├ Pri   │     └────────────────────┘            ▼
                │    │ ├ Rf/Pw │                               PulseRecordWriter
                │    │ ├ Scan  │                               └ CsvPulseRecordWriter
                │    │ │ Spec  │
                │    │ └ Ant.  │
                │    └ Scan    │
                └──────────────┘
```

Las dependencias van en un único sentido (emisor → canal → receptor): ningún componente conoce a los que tiene detrás,
por lo que cada uno se puede testear aislado con entradas construidas a mano.

### Componentes

| Componente | Responsabilidad | Depende de |
| --- | --- | --- |
| `Time` (unidades) | Alias de tiempo y conversiones. | — |
| `Position` / geometría | Vector ENU en metros; funciones `distance_m` y `direction_from_to` (`AngleOfArrival`) entre dos puntos. | `AngleOfArrival` |
| Propagación (funciones) | `propagation_delay`, `free_space_path_loss_db`, `wrap_offset_deg`: física reutilizable también por el procesado (estimación de distancia por amplitud, TDOA, agrupación por AoA). | `Time` |
| `PriGenerator` | Interfaz: siguiente PRI. Implementaciones `Fixed`, `Stagger`, `Sliding`, `DwellSwitch`. | — |
| `RfGenerator` | Interfaz: siguiente frecuencia. Implementaciones `Fixed`, `List`. | — |
| `PwGenerator` | Interfaz: siguiente ancho de pulso. Implementación `Fixed`. | — |
| `ScanSpec` | Parte intrínseca del scan de un modo: tipo, periodo, elevación, anchura del sector. | — |
| `ScanPattern` | Interfaz: dirección del haz en un instante relativo al inicio del segmento. Implementaciones `Fixed`, `Circular`, `Sector`. | — |
| `AntennaPattern` | Interfaz: `gain_dbi(offsetAz, offsetEl)`. Implementación `GaussianAntennaPattern`. | — |
| `EmitterMode` | Prototipo del catálogo: generadores de PRI, RF y PW, `ScanSpec`, antena, potencia de pico y modulación intrapulso. | generadores |
| `EmitterType`, `Catalog` | Librería de emisores: tipos con sus modos. | `EmitterMode` |
| `Segment` | Tramo del calendario: modo (o silencio), duración y el `ScanPattern` ya orientado por la misión. | `EmitterMode`, `ScanPattern` |
| `Emitter` | Instancia: id, posición, calendario de segmentos y estado del segmento activo. Produce `EmittedPulse`. | `Segment` |
| `PropagationChannel` | Función libre `propagate`, sin estado: de `EmittedPulse` a `IncidentPulse`: instante de llegada, dirección de llegada y potencia isotrópica en el receptor. | geometría, propagación, `AntennaPattern` |
| `Receiver` | Aplica su ganancia y sensibilidad, mide el AoA y genera el registro. | `PulseRecordWriter` |
| `PulseRecordWriter` | Interfaz: escribe un registro (PDW + verdad). Implementación `CsvPulseRecordWriter` sobre `std::ostream&`. | — |
| `EventScheduler` | Cola de prioridad de eventos. No sabe nada de radares. | — |
| `Simulation` | Recibe una `Mission` ya construida, programa los eventos iniciales y ejecuta hasta vaciar la cola. | todo lo anterior |
| `MissionRunner` | `run_mission(Mission, std::ostream&)`: monta el escritor CSV y la `Simulation` y la ejecuta. | `Simulation`, escritor |
| Loaders (`Config`) | `parse_catalog`/`load_catalog`, `parse_mission`/`load_mission`: leen JSON, convierten a SI, validan. **Únicos** que conocen nlohmann/json. | todo el dominio |

### Decisiones de fondo

1. **El `EmittedPulse` es autocontenido**: lleva la posición del emisor, la dirección del haz en el instante de emisión
   y una referencia a su `AntennaPattern`. El canal no consulta el estado pasado del emisor. Esto sigue valiendo con
   varios receptores (el canal se invoca una vez por receptor con el mismo pulso) y con plataformas móviles (el pulso
   sale de esa posición y en esa dirección). Para el futuro quedan anotados tres cambios de firma localizados:
   - Con un receptor móvil, `propagate` tendrá que resolver `|R(t_a) − P_e(t_e)| = c·(t_a − t_e)` y recibir algo
     consultable en el tiempo en lugar de una `Position`.
   - La dirección del haz (2 grados de libertad) no tiene giro alrededor del eje; un haz asimétrico en una plataforma
     que alabea necesitará una orientación completa, y el AoA medido será relativo a la actitud de la plataforma.
   - Con multitrayecto, `propagate` devolverá una lista de llegadas, cada una con su dirección.
2. **El dominio no conoce JSON.** Los loaders traducen JSON a objetos; el resto se testea sin ficheros.
3. **La salida del receptor = `PulseDescriptorWords` (medida) + `GroundTruth` (verdad).** El PDW actual es un esqueleto
   y se completará con los campos que necesite el simulador, siguiendo
   `2026-10-23-pdw-attribute-grouping-design.md`. De la modulación intrapulso solo se implementa el tipo; el
   parámetro queda aplazado.
4. **El canal calcula la llegada; el receptor la mide.** El canal fija el instante, la **dirección de llegada** y la
   potencia isotrópica de la onda incidente (es quien conoce el camino de propagación). El receptor suma su propia
   ganancia y aplica su modelo de medida sobre esa dirección; no reconstruye la geometría. El canal no conoce la antena
   del receptor.
5. **Composición frente a herencia en los modos**: PRI, RF, PW y scan son ortogonales; un modo *tiene* un generador de
   cada tipo, intercambiable. Cada extensión futura es una clase nueva que implementa una interfaz existente (más su
   rama en el loader, que es quien traduce el JSON).
6. **El scan concreto se construye por segmento.** El modo guarda la parte intrínseca del scan (`ScanSpec`: tipo,
   periodo, elevación, anchura del sector) y la misión aporta su orientación (azimut inicial, centro, apuntamiento).
   El loader combina ambas partes en un `ScanPattern` que vive en el `Segment`. Así el catálogo es la descripción
   intrínseca completa del emisor, y la misión lo situacional.
7. **`Simulation` no carga ficheros.** Recibe la `Mission` construida, así se testea sin disco. La carga la hacen los
   loaders y la orquestación el ejecutable (`main`) con ayuda de `MissionRunner`.
8. **`EmittedPulse` e `IncidentPulse` mezclan señal y verdad** (ids, índices, posición del emisor, ganancia de
   transmisión). Su comentario de clase dice qué campos son de cada tipo. Los algoritmos de procesado consumen
   `PulseDescriptorWords`, nunca estos pulsos.

### Ubicación

El namespace es la librería en minúsculas (`headers.md`). Las clases que definen una señal, una parte de ella o su
tratamiento van en el namespace `sigint` (librería `src/SigInt/`); las del simulador, en `simulator` (librería
`src/Simulator/`); lo transversal sin dominio (`check_contract`), en `core` (librería `src/Core/`). `Core` no depende
de nada, `SigInt` depende de `Core` y `Simulator` de `SigInt` y `Core`. Todo el código sigue las reglas de `.claude/rules/cpp/`; la clasificación de cada tipo como `struct`
o `class` y las excepciones están en la decisión 2 del plan.

- `src/SigInt/Units/`: `Time` y sus conversiones (sin dependencias, para que no haya ciclos entre componentes).
- `src/SigInt/PulseDescriptors/` (existente): `PulseDescriptorWords`, `AngleOfArrival`, `IntrapulseModulation`.
- `src/SigInt/Geometry/`: `Position`, `distance_m`, `direction_from_to` y las funciones de propagación.
- `src/SigInt/Emission/`: generadores de PRI, RF y PW, `ScanSpec`, scans, antena, `EmitterMode`, `EmittedPulse`,
  `IncidentPulse`.
- `src/SigInt/Library/`: `EmitterType`, `Catalog`.
- `src/Simulator/` (nueva librería), con los componentes `Emitter` (`Segment`, `Emitter`), `Channel`, `Receiver`,
  `Engine`, `Config` y `Runner`.
- Dependencia externa: **nlohmann/json 3.12.0**, incorporada con `proj_fetch_external` (`.cmake/External.cmake`) y
  usada solo en `Config`.
- Ejecutable: `ews <mision.json> <salida.csv>`.

## 4. Flujo de datos de un pulso

### Paso 0 — Arranque

`main` carga la misión (que carga antes el catálogo), abre el fichero de salida y llama a `run_mission`. Al ejecutarse,
`Simulation` pide a cada emisor su primer pulso y programa un evento **Emit** con ese pulso en su instante.

### Paso 1 — Evento Emit (instante t_e)

El evento lleva el `EmittedPulse` que el emisor calculó al programarlo:

| Campo | Origen |
| --- | --- |
| emitterId, modeId, índice del segmento, índice de pulso del emisor | estado del emisor |
| t_e | instante de emisión |
| f, PW | `RfGenerator`, `PwGenerator` |
| P_tx, modulación intrapulso | parámetros del modo |
| posición del emisor | instancia |
| dirección del haz (az, el) | `ScanPattern` del segmento en t_e |
| antena | referencia al `AntennaPattern` del modo |

Al ejecutarse, entrega el pulso al canal, pide al emisor su siguiente pulso (en `t_e + PRI`, con la PRI de
`PriGenerator`) y, si lo hay, programa un nuevo **Emit** con él.

**Reglas del calendario:**

- Los segmentos se encadenan desde `startS`; el segmento k ocupa el intervalo semiabierto `[inicio_k, fin_k)`.
- El primer pulso de un segmento se emite exactamente en el instante de inicio del segmento.
- Si el siguiente instante cae fuera del segmento activo (`≥ fin_k`), el emisor pasa al siguiente segmento y su primer
  pulso sale en el inicio de ese segmento. Por eso, en un cambio de segmento el hueco entre dos pulsos puede ser menor
  que la PRI, e incluso que la PW. No se valida.
- **Cada segmento empieza con su estado a cero**: secuencia de PRI, lista de RF y scan arrancan desde el principio.
  Una antena mecánica que vuelve de un `off` reaparece en su `initialAzimuthDeg`, no donde se habría quedado girando.
  El estado que se reinicia es el **determinista** (índice de stagger, posición de sliding). Cuando haya
  aleatoriedad, la fuente aleatoria no pertenecerá al generador sino al `Emitter`, sembrada desde la semilla del
  escenario y el id del emisor; si no, cada segmento repetiría el mismo jitter.
- Los segmentos `off` no emiten.
- Un emisor no programa emisiones en instantes ≥ `durationS`.
- Al terminar el último segmento el emisor queda en silencio: el calendario **no** se repite.

**Fórmulas del scan** (t' = t_e − inicio del segmento; la fase `(t' mod T) / T` se calcula reduciendo primero en
enteros, para no perder precisión en misiones largas):

- **Fijo**: dirección = (`pointingAzimuthDeg`, `pointingElevationDeg`) del segmento.
- **Circular**: `az(t') = initialAzimuthDeg + 360 · (t' mod T) / T`, normalizado a [0, 360); elevación =
  `elevationDeg` del modo. Giro solo en sentido horario.
- **Sectorial** (bidireccional, el típico mecánico): onda triangular de periodo `periodS` entre
  `centerAzimuthDeg − widthDeg/2` y `centerAzimuthDeg + widthDeg/2`; en t' = 0 está en el borde izquierdo y avanza en
  sentido horario; recorre el sector de ida y vuelta en un periodo. Elevación = `elevationDeg` del modo. Un receptor
  que no esté en el centro del sector ve **dos** iluminaciones por periodo a intervalos desiguales.

### Paso 2 — Canal de propagación

1. Geometría emisor → receptor: Δ = receptor − emisor, d = |Δ|, dirección (az_ER, el_ER).
2. Dirección de llegada: la del receptor hacia el emisor (con camino directo, la opuesta a la anterior; se calcula con
   la misma función de geometría).
3. Retardo: `d / c`, con c = 299 792 458 m/s, **redondeado al ns más cercano**. t_a = t_e + retardo.
4. Desvío respecto al centro del haz: `Δaz = wrap(az_ER − az_haz)` en (−180, 180], `Δel = el_ER − el_haz`.
   **Aproximación válida para elevaciones pequeñas**: un grado de azimut a elevación `el` son `cos(el)` grados de arco
   reales, así que lejos del horizonte el modelo sobrestima la atenuación, y cerca del cénit el azimut deja de estar
   definido. En los escenarios de superficie de la v1 (elevaciones de centésimas de grado) el error es despreciable.
   La corrección (desvíos en el sistema del haz, sin cambiar la interfaz de `AntennaPattern`) queda fuera de alcance.
5. Ganancia del emisor (haz gaussiano con suelo de lóbulos laterales):

   ```
   G_tx = max( G_max − 12 · [ (Δaz / θ_az)² + (Δel / θ_el)² ] ,  G_max − SLL )
   ```

   θ_az y θ_el son los anchos de haz a −3 dB. El factor 12 se obtiene de exigir −3 dB a medio ancho de haz (un
   gaussiano lineal es una parábola en dB). El suelo `G_max − SLL` representa el **nivel medio** de los lóbulos
   laterales y traseros, igual en todas las direcciones; no es el nivel del primer lóbulo lateral. Por conservación de
   la energía (la ganancia media de una antena sobre la esfera no supera 0 dBi), en antenas directivas el suelo debe
   quedar por debajo de 0 dBi, típicamente entre −5 y −15 dBi: `SLL ≈ G_max + 5…15`.
6. Pérdida en espacio libre: `FSPL = 20·log10(d) + 20·log10(f) − 147,55` (d en m, f en Hz). La constante exacta es
   `20·log10(4π/c) = −147,5522`; se usa la redondeada a propósito (los tests dependen de ella). La fórmula es de campo
   lejano: por eso la validación exige d ≥ 1 m y f ≥ 30 MHz (§5), con lo que la FSPL es siempre positiva.
7. Potencia isotrópica en el receptor: `P_iso = P_tx + G_tx − FSPL`.
8. Construye `IncidentPulse` (el `EmittedPulse`, t_a, dirección de llegada, d, G_tx, P_iso) y programa **Arrival** en
   t_a.

### Paso 3 — Evento Arrival (instante t_a)

1. `P_rx = P_iso + G_rx`: potencia de pico del pulso a la salida de la antena del receptor, sin pérdidas de receptor.
   Es la **amplitud** del PDW.
2. Si `P_rx < sensitivityDbm`, el pulso se descarta (la condición de detección es `P_rx ≥ sensitivityDbm`). Los pulsos
   descartados no se escriben.
3. AoA medido: el modelo de error aplicado a la dirección de llegada del `IncidentPulse` (hoy, identidad). La verdad
   (`truth_azimuthDeg`, `truth_elevationDeg`) es esa misma dirección de llegada.
4. Construye el PDW y el `GroundTruth` y los entrega al `PulseRecordWriter`.

### Paso 4 — Final

Cuando ya no se programan emisiones, el planificador sigue procesando eventos hasta **vaciar la cola**: los pulsos
emitidos antes de `durationS` que estén en vuelo se entregan igualmente (con `toaNs` ≥ `durationS`).

### Ejemplo numérico

Emisor en (15000, 20000, 30), receptor en (0, 0, 10), f = 3 GHz, P_tx = 90 dBm, G_max = 30 dBi, SLL = 38 dB (suelo
−8 dBi):

- d ≈ 25 000 m, retardo ≈ 83 391 ns, FSPL ≈ 130 dB.
- AoA visto por el receptor: az ≈ 36,87°, el ≈ 0,05°. El emisor ilumina al receptor apuntando a az ≈ 216,87°.
- P_iso ≈ −10 dBm en el lóbulo principal y ≈ −48 dBm en lóbulos laterales: con sensibilidad −70 dBm se reciben todos
  los pulsos (la detección por lóbulos laterales a decenas de km es lo normal en ESM). Para observar ráfagas limpias
  hay que elegir distancia, sensibilidad y SLL con intención.

## 5. Configuración

### Organización

```
scenarios/
├── catalog/                     ← un fichero por tipo de emisor
│   ├── SearchRadar_X.json
│   └── FireControl_Y.json
└── missions/
    └── demo_01.json             ← referencia el catálogo
```

### Catálogo (tipo de emisor)

```json
{
  "type": "SearchRadar_X",
  "modes": {
    "search": {
      "peakPowerDbm": 90,
      "intrapulseModulation": "None",
      "pri":     { "kind": "stagger", "valuesUs": [1000, 1200, 1100] },
      "rf":      { "kind": "fixed",   "frequencyMHz": 3000 },
      "pw":      { "kind": "fixed",   "widthUs": 1.0 },
      "scan":    { "kind": "circular", "periodS": 6.0, "elevationDeg": 2.0 },
      "antenna": { "kind": "gaussian", "peakGainDbi": 30,
                   "beamwidthAzDeg": 1.5, "beamwidthElDeg": 20, "sidelobeLevelDb": 38 }
    },
    "track": {
      "peakPowerDbm": 90,
      "intrapulseModulation": "None",
      "pri":     { "kind": "fixed", "valueUs": 250 },
      "rf":      { "kind": "fixed", "frequencyMHz": 3100 },
      "pw":      { "kind": "fixed", "widthUs": 0.5 },
      "scan":    { "kind": "fixed" },
      "antenna": { "kind": "gaussian", "peakGainDbi": 44,
                   "beamwidthAzDeg": 1.0, "beamwidthElDeg": 1.0, "sidelobeLevelDb": 50 }
    }
  }
}
```

Los datos de antena son físicamente coherentes:

- **Ganancia frente a ancho de haz**: la directividad de un haz único es aproximadamente
  `G ≈ 10·log10(K / (θ_az · θ_el))` (θ en grados, K ≈ 41 253 ideal, ≈ 25 000–30 000 con eficiencia real).
- **Suelo de lóbulos laterales** `G_max − SLL` por debajo de 0 dBi (§4 paso 2.5).

El loader no lo comprueba (se admiten antenas artificiales para pruebas).

Cada bloque tiene un campo `kind` (unión etiquetada) que decide la clase construida y las claves admitidas:

| Bloque | `kind` | Claves |
| --- | --- | --- |
| `pri` | `fixed` | `valueUs` |
| | `stagger` | `valuesUs` (lista, se repite cíclicamente) |
| | `sliding` | `minUs`, `maxUs`, `stepUs` (diente de sierra creciente: de min a max y vuelve a min; si el paso no divide el rango, no se supera max) |
| | `dwellSwitch` | `valuesUs` (lista), `pulsesPerDwell` (entero, los mismos pulsos para cada valor antes de pasar al siguiente, cíclico) |
| `rf` | `fixed` | `frequencyMHz` |
| | `list` | `frequenciesMHz` (lista, orden cíclico), `pulsesPerHop` (entero) |
| `pw` | `fixed` | `widthUs` |
| `scan` | `fixed` | — (la dirección la da la misión) |
| | `circular` | `periodS`, `elevationDeg` |
| | `sector` | `widthDeg`, `periodS`, `elevationDeg` |
| `antenna` | `gaussian` | `peakGainDbi`, `beamwidthAzDeg`, `beamwidthElDeg`, `sidelobeLevelDb` |

PRI y RF son generadores independientes. Para que el cambio de RF vaya sincronizado con el de PRI (como en un radar
que cambia ambos por CPI) basta con poner `pulsesPerHop` = `pulsesPerDwell`.

`intrapulseModulation` es un dato descriptivo que se copia al pulso; no tiene efecto físico en esta versión. Valores
admitidos (exactos, con mayúsculas): `None`, `LFM`, `NLFM`, `BPSK`, `Barker`, `FSK`.

**Regla de reparto**: el catálogo define *cómo* es el radar (periodos, anchos, potencias, tipo de scan); la misión
define lo que depende de la situación (dónde está, hacia dónde apunta, dónde empieza el barrido, centro del sector).

### Misión

```json
{
  "catalogDir": "../catalog",
  "durationS": 120,
  "receiver": { "id": "RX1", "positionM": [0, 0, 10], "gainDbi": 0, "sensitivityDbm": -70 },
  "emitters": [
    { "id": "E1", "type": "SearchRadar_X", "positionM": [15000, 20000, 30], "startS": 5,
      "schedule": [
        { "mode": "search", "durationS": 40, "initialAzimuthDeg": 0 },
        { "mode": "off",    "durationS": 10 },
        { "mode": "track",  "durationS": 30, "pointingAzimuthDeg": 216.87, "pointingElevationDeg": 0 }
      ] }
  ]
}
```

- `catalogDir` es relativo al fichero de la misión. El catálogo son los ficheros regulares de esa carpeta con
  extensión exactamente `.json`, leídos en orden alfabético; el resto se ignora.
- Los segmentos de `schedule` se encadenan a partir de `startS`.
- `"off"` es un nombre de modo reservado que representa silencio.
- Parámetros de segmento según el `scan` del modo:
  - `circular` → `initialAzimuthDeg`;
  - `sector` → `centerAzimuthDeg`;
  - `fixed` → `pointingAzimuthDeg`, `pointingElevationDeg`;
  - `off` → ninguno.
- `emitters` puede estar vacía (el CSV solo tendrá la cabecera); `schedule` no.

### Validación

Todo se valida **al cargar, antes de simular**. Una vez arrancada, la simulación no puede fallar por la configuración
(salvo por agotar recursos, ver al final de esta sección).

1. **Claves desconocidas son error** (una errata en una clave con unidad no debe ignorarse en silencio). Limitación
   conocida: una clave **repetida** en el mismo objeto no se detecta (nlohmann se queda con el último valor).
2. **Tipos y rangos** (notación de intervalos: `[` incluye el extremo, `(` lo excluye):
   - Todo número debe ser finito. Un literal que no cabe en un `double` (`1e400`) lo rechaza ya el parser de JSON.
   - `pulsesPerDwell` y `pulsesPerHop`: **enteros** del JSON en [1, 2³² − 1]. Un `2.5` es error, no se trunca; un
     `3.0` también es error, porque en JSON es un número decimal.
   - **Tiempos** (PRI, PW, `minUs`, `maxUs`, `stepUs`, periodos, duraciones de segmento, `durationS`): ≤ 10⁶ s
     (comprobado antes de convertir) y > 0 **después de redondear a 1 ns**. `startS`: en [0, 10⁶] s. Así un
     `valueUs: 0.0004` (0 ns) es error y ninguna suma de tiempos desborda `int64`.
   - Frecuencias en [30, 300 000] MHz (radar y ESM; con d ≥ 1 m garantiza campo lejano y FSPL positiva).
   - Potencias y ganancias (`peakPowerDbm`, `peakGainDbi`, `gainDbi`, `sensitivityDbm`) en [−300, 300];
     `sidelobeLevelDb` en [0, 300].
   - Elevaciones (`elevationDeg`, `pointingElevationDeg`) en [−90, 90]: `AngleOfArrival` plegaría un 95° en un haz
     apuntando hacia atrás. Azimuts (`initialAzimuthDeg`, `centerAzimuthDeg`, `pointingAzimuthDeg`) en [−360, 360]:
     se normalizan, pero un valor enorme perdería precisión al pasar a `float`.
   - `widthDeg` en (0, 360). Anchos de haz en (0, 180].
   - `positionM`: lista de exactamente 3 números, cada uno en [−10⁸, 10⁸] m.
   - Listas (`valuesUs`, `frequenciesMHz`, `schedule`) no vacías.
   - En `sliding`, `minUs` < `maxUs` (comparados en ns).
3. **Coherencia física**: la PW máxima del modo debe ser menor que su PRI mínima, comparadas en ns.
4. **Referencias e identificadores**: el tipo existe en el catálogo; el modo existe en el tipo; ids de emisor únicos;
   nombres de tipo únicos en el catálogo; ningún tipo define un modo llamado `off`. Los ids (tipo, modo, emisor,
   receptor) solo admiten `[A-Za-z0-9_-]+`, lo que evita tener que escapar texto en el CSV.
5. **Parámetros de segmento**: presentes exactamente los que exige el `scan` del modo (ni faltan ni sobran).
6. **Geometría**: cada emisor a **d ≥ 1 m** del receptor (la FSPL es de campo lejano).
7. Un calendario que se extienda más allá de `durationS` **no** es error: se recorta. Los segmentos que empiezan en
   `durationS` o después se validan, pero no se construyen, y su duración no se acumula.

**Recursos.** Una configuración válida puede ser inviable: una PRI de 2 ns durante 10⁶ s son 5·10¹⁴ pulsos. La v1 no lo
estima ni lo rechaza; si se agota la memoria, `main` sale con el código 4.

**Gestión de errores:**

- La validación **acumula todos los errores** de cada fase y, al terminar la fase, si hay alguno lanza un
  `ConfigError` con la lista completa. Las fases van en orden: leer `catalogDir` de la misión → cargar el catálogo →
  cargar la misión contra él. Si una fase falla, las siguientes no se ejecutan.
- Cada error indica el **nombre base** del fichero y la ruta dentro del JSON (sin punto inicial en la raíz; índices
  entre corchetes), por ejemplo:
  `demo_01.json: emitters[0].schedule[2].mode: el modo 'trak' no existe en el tipo 'SearchRadar_X'`.
- Los errores del sistema de ficheros (misión inexistente, `catalogDir` inexistente o que no es una carpeta, catálogo
  sin ningún `.json`, fichero ilegible) también son `ConfigError`, nunca una excepción sin capturar. Igual con
  cualquier excepción del parser de JSON.
- `main` carga y valida **antes** de abrir el fichero de salida (un error de configuración no deja un CSV vacío).
  Códigos de salida: 0 éxito; 1 `ConfigError` (imprime cada error en `stderr`, uno por línea); 2 uso incorrecto;
  3 no se puede abrir el fichero de salida o falla la escritura; 4 cualquier otra excepción (red de seguridad).

## 6. Salida

Fichero CSV, una fila por pulso **detectado**, en orden de llegada. Primera línea de cabecera, separador decimal `.`,
precisión fija para que la salida sea reproducible byte a byte. Al formatear, un azimut que redondee a 360 se escribe
como 0, y un `-0` (p. ej. `-0.0000`) se escribe sin signo.

| Bloque | Columna | Contenido |
| --- | --- | --- |
| Medida (PDW) | `pulseId` | secuencial desde 0, asignado por el receptor |
| | `toaNs` | instante de llegada |
| | `frequencyMHz` | frecuencia |
| | `pulseWidthUs` | ancho de pulso |
| | `amplitudeDbm` | P_rx (§4 paso 3) |
| | `azimuthDeg`, `elevationDeg` | AoA medido |
| | `intrapulseModulation` | texto (`None`, …) |
| Verdad | `truth_emitterId`, `truth_modeId` | emisor y modo |
| | `truth_segmentIndex` | índice del segmento del calendario (distingue dos segmentos del mismo modo) |
| | `truth_emitterPulseIndex` | índice del pulso en su emisor (los huecos delatan los pulsos no detectados) |
| | `truth_emissionNs` | t_e |
| | `truth_distanceM` | d |
| | `truth_azimuthDeg`, `truth_elevationDeg` | dirección de llegada verdadera |
| | `truth_txGainDbi` | G_tx(θ) hacia el receptor (distingue lóbulo principal de lateral) |
| | `truth_eirpDbm` | P_tx + G_tx(θ) hacia el receptor |

Las columnas `truth_` solo sirven para evaluar; ningún algoritmo de procesado debe usarlas como entrada. La frecuencia
y el ancho de pulso verdaderos coinciden hoy con los medidos; cuando haya ruido de medida se añadirán sus columnas
`truth_` (y cambiará el formato).

`CsvPulseRecordWriter` escribe sobre un `std::ostream&`: en producción un `std::ofstream`, en tests un
`std::ostringstream`.

## 7. Tests

### Unitarios (GoogleTest, un test por función)

| Componente | Casos clave |
| --- | --- |
| Geometría | triángulo 3-4-5 → 36,87°; los cuatro puntos cardinales; ida y vuelta difieren en 180°; vertical sin NaN |
| Propagación | 299,792458 m → 1000 ns; FSPL contra valor calculado a mano; wrap de Δaz |
| PRI | `fixed`; `stagger` y vuelta al inicio; `sliding` al alcanzar el máximo; `dwellSwitch` en la frontera de bloque |
| RF / PW | `fixed`; `list` en la frontera de salto y vuelta al inicio |
| Scan | circular en t = 0, T/4, T; sector en los bordes y cambio de sentido; fijo; cruce de 0°/360° |
| Antena | pico en desvío 0; −3 dB exactos a medio ancho de haz en az y en el; suelo de lóbulos laterales |
| Canal | instante y dirección de llegada; P_iso; ganancia con wrap de Δaz |
| Receptor | P_rx por debajo, igual y por encima de la sensibilidad |
| Planificador | orden por instante; desempate por número de secuencia |
| Emisor | primer pulso al inicio del segmento; segmento `off`; cambio de modo con estado a cero; corte en `durationS`; dos emisores del mismo modo no comparten estado |
| Simulación | todos los pulsos, en orden de llegada, numerados; pulsos en vuelo al final |
| Loaders | JSON válido; un test por cada regla de validación (con sus extremos); varios errores acumulados; ruta del error en el mensaje; errores del sistema de ficheros |
| Escritor CSV | cabecera; formato de una fila; azimut que redondea a 360; cero negativo |

Comparaciones: los tiempos con `EXPECT_EQ` (enteros exactos). En los tests de accesores, copia y movimiento,
`EXPECT_FLOAT_EQ` / `EXPECT_DOUBLE_EQ` (`.claude/rules/cpp/tests.md`). En los cálculos físicos (ángulos,
ganancias, potencias), `EXPECT_NEAR` con tolerancia explícita.

### Integración (golden file)

Una misión pequeña en `src/Simulator/Runner/tests/data/` (dos emisores, 0,1 s con periodos de scan comprimidos a
propósito para que la salida sea corta) se ejecuta completa y su CSV se compara con un fichero de referencia
versionado. Si un cambio intencionado altera la salida, se regenera la referencia y el diff de git muestra qué ha
cambiado. Es posible porque la simulación es determinista.

La referencia es válida para la toolchain de la CI (x86-64, glibc, sin `-march`). `atan2`, `log10` y `std::format` no
garantizan el último bit en todas las plataformas: si la comparación falla por un dígito en la última cifra, revisarlo
antes de regenerar la referencia a ciegas.

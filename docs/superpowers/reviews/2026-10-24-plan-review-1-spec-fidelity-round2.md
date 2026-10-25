# Revisión 1, segunda ronda: fidelidad entre spec y plan

Fecha: 2026-10-24
Spec: `docs/superpowers/specs/2026-10-24-simulator-design.md` (486 líneas)
Plan: `docs/superpowers/plans/2026-10-24-simulator.md` (1050 líneas)
Contexto: `2026-10-24-plan-review-1-spec-fidelity.md` (ronda 1), `.claude/rules/how_to_write_a_class.md`,
`src/SigInt/PulseDescriptors/`, `.cmake/` (Components, BuildComponent, Deps, Tests), `2026-10-23-pdw-attribute-grouping-design.md`.

Las referencias `spec:N` y `plan:N` son números de línea de cada documento; `R:N`, de `how_to_write_a_class.md`.

## Resumen y veredicto

**Veredicto: apto, con un cambio necesario antes de ejecutar (R2-F1) y tres recomendables (R2-F2 a R2-F4).**

La reescritura resuelve los 17 hallazgos y las 3 dudas de la ronda 1. Solo la duda D2 queda resuelta a medias: se
acepta de hecho, pero no se declara. Spec y plan coinciden ahora en la arquitectura, el reparto en librerías y
namespaces, las fórmulas, las 18 columnas del CSV, las reglas de validación y los códigos de salida. Las referencias
cruzadas entre tareas y los comandos `ctest` son correctos, salvo una referencia del Review Focus 7. El reparto
`sigint`/`sim` es viable: ningún tipo de `sigint` usa uno de `sim`, y el sistema de CMake (una librería por carpeta de
`src/`, detección de ciclos y `PRIVATE_EXTERNAL`) lo admite sin cambios.

Los problemas nuevos vienen casi todos de la **decisión 2** (aplicar R1–R12 a todas las clases):

- Las clases con estado (generadores, `Emitter`, `Receiver`, `EventScheduler`, `Simulation`) no pueden usar el
  "constructor con todos los atributos" como constructor de trabajo, y el plan las construye con otros constructores no
  declarados como excepción (R2-F1).
- La regla R11 (acceder a todo mediante accesores), junto con `T get_x(void)`, que devuelve **una copia**, convierte
  cada mutación interna en una trampa silenciosa (R2-F2).

Aparte, el flujo de `Simulation` no dice dónde se guarda el pulso entre `next()` y el evento Emit (R2-F3), y los
rangos abiertos y cerrados de la validación no se pueden expresar con `numberInRange` (R2-F4).

**Hallazgos nuevos: 0 críticos, 1 alto, 3 medios y 10 bajos.**

## Tabla de trazabilidad

| Spec | Requisito | Tarea / paso del plan | Estado |
| --- | --- | --- | --- |
| §1 (spec:16) | Varios emisores, un receptor, posiciones fijas | T8, T11, T13 (`Mission`) | OK |
| §1 (spec:17-18) | Determinista; AoA con error 0 | T11 (`measureAoa` identidad, plan:616-617), T12 (desempate) | OK |
| §1 (spec:19-20) | Modelo de potencia completo | T6, T9, T11 | OK |
| §1 (spec:26-27) | Móviles: cambio de firma localizado y anotado | Decisión 8 (plan:97-98) | OK |
| §1 (spec:30-31) | Fuente aleatoria fuera de los generadores (futuro) | T8 (clonado por segmento, sin RNG) | OK |
| §2 (spec:48-53) | SI, grados, `nanoseconds`, `llround`, rango tras redondear | Global Constraints (plan:134-140), T1 (plan:225-228) | OK |
| §2 (spec:54-56) | Geometría y potencias en `double`; direcciones en `AngleOfArrival` | Global Constraints (plan:134-135, 142-143) | OK (PDW `float`, ver D2) |
| §2 (spec:57-58) | Unidad en el nombre de la clave o columna | T10, T14, T15 | OK |
| §2 (spec:62-70) | ENU, `atan2(ΔE, ΔN)`, elevación, vertical sin NaN, AoA receptor → emisor | T1 (plan:233-239), T11 (plan:616) | OK |
| §3 (spec:76-87) | Eventos discretos con `(instante, secuencia)`; Emit y Arrival | T12, T13 | OK, con hueco en Emit (R2-F3) |
| §3 tabla (spec:122) | `Position`, `distanceM`, `directionFromTo` | T1 (plan:215-219) | OK |
| §3 tabla (spec:123-125) | Generadores PRI (4), RF (2), PW (1) | T3, T4 | OK |
| §3 tabla (spec:126-127) | `ScanPattern` (3), `AntennaPattern::gainDbi` + gaussiano | T5, T6 | OK |
| §3 tabla (spec:128) | `EmitterMode` sin scan: PRI, RF, PW, antena, P_tx, modulación | T7 (plan:448) | OK |
| §3 tabla (spec:129-130) | `Segment` (modo, duración, `ScanPattern` orientado), `Emitter` | T8 (plan:476-477) | OK |
| §3 tabla (spec:131-133) | Canal, receptor, `PulseRecordWriter` sobre `std::ostream&` | T9, T10, T11 | OK |
| §3 tabla (spec:134-136) | `EventScheduler`, `Simulation` con `Mission` ya hecha, `MissionRunner` | T12, T13, T16 | OK |
| §3 tabla (spec:137) | Loaders, únicos con nlohmann | T14, T15; grep en T14 paso 4 | OK (R2-F14) |
| §3 Dec. 1 (spec:141-149) | `EmittedPulse` autocontenido | T7 (plan:449) | OK |
| §3 Dec. 2 (spec:150) | Dominio sin JSON | Global Constraints (plan:157), T14 | OK |
| §3 Dec. 3 (spec:151-154) | PDW + `GroundTruth`; solo el tipo de modulación | T2, T10, decisión 7 | OK |
| §3 Dec. 4 (spec:155-156) | El canal da P_iso; el receptor suma G_rx | T9, T11 (plan:614) | OK |
| §3 Dec. 5 (spec:157-159) | Composición; extensión = clase nueva + rama del loader | T3-T6, T14 | OK |
| §3 Dec. 6 (spec:160-163) | `ScanSpec` en `Config`; el `Segment` tiene el `ScanPattern` | Decisión 3 (plan:83-85), T14, T15 | OK |
| §3 Dec. 7 (spec:164-165) | `Simulation` no carga ficheros | Decisión 6 (plan:93-94), T13, T16 | OK |
| §3 Ubicación (spec:169-178) | `sigint`/`sim`; SigInt sin dependencias; Simulator → SigInt | Decisión 1 (plan:24-42), T8 (`deps.cmake`) | OK (R2-F13) |
| §3 Ubicación (spec:180-181) | R1–R12 en todas las clases; excepciones en el plan | Decisión 2 (plan:44-81) | **Contradicción** (R2-F1, R2-F5, R2-F6) |
| §3 Ubicación (spec:182-184) | nlohmann 3.12.0 con `proj_fetch_external`; `ews <mision> <csv>` | T14 (plan:729-746), T16 | OK |
| §4 Paso 0 (spec:190-191) | `main` carga, abre y llama a `runMission`; un Emit por emisor | T16 (plan:950-951), T13 (plan:695) | OK |
| §4 Paso 1 (spec:195-207) | Campos del `EmittedPulse`; siguiente Emit en `t_e + PRI` | T7, T8 (plan:487-488), T13 | **Ambiguo** (R2-F3) |
| §4 Calendario (spec:211-223) | Semiabiertos, primer pulso al inicio, estado a cero, `off`, `< durationS`, sin repetir | T8 (plan:484-494, 500-516) | OK |
| §4 Scan (spec:225-233) | Fijo, circular, sectorial bidireccional | T5 (plan:392-405) | OK |
| §4 Paso 2 (spec:237-257) | Geometría, retardo redondeado, wrap, gaussiano, FSPL −147.55, P_iso | T9, T6, Global Constraints | OK |
| §4 Paso 3 (spec:261-266) | `P_rx`, detección `≥`, AoA, PDW + verdad | T11 | OK |
| §4 Paso 4 (spec:270-271) | Vaciar la cola; pulsos en vuelo | T13 `RunDeliversPulsesInFlightAfterEnd` | OK |
| §5 Organización (spec:288-294) | `scenarios/catalog`, `scenarios/missions/demo_01.json` | T16 (plan:940) | OK (`FireControl_Y` es ilustrativo) |
| §5 Catálogo (spec:298-350) | Claves y `kind`; modulación con 6 valores exactos | T14, T2 | OK |
| §5 Misión (spec:357-382) | `catalogDir` relativo; `.json` en orden alfabético; parámetros por scan; `emitters` vacía válida | T14 (plan:766-767), T15 | OK |
| §5 Val. 1 (spec:388-389) | Claves desconocidas; repetidas no detectadas | `finish()` (plan:772), tests T14/T15 | OK |
| §5 Val. 2 (spec:391-402) | Finitos, enteros, tiempos tras redondear ≤ 10⁶ s, rangos, `positionM`, listas, min < max | `JsonReader` (plan:774-779), tests T14/T15 | OK, con huecos (R2-F4, R2-F8) |
| §5 Val. 3 (spec:403) | PW máx < PRI mín, en ns | T14 (plan:843-846) | OK |
| §5 Val. 4 (spec:404-406) | Referencias, unicidad, `off`, formato de ids | T14, T15 | OK |
| §5 Val. 5-7 (spec:407-410) | Parámetros de segmento exactos; d ≥ 1 m; recorte | T15 (plan:882-891, 909-920) | OK |
| §5 Errores (spec:414-424) | Acumulación por fase, nombre base, ruta, errores de disco, orden de `main`, códigos 0-4 | T14 (plan:784-813), T15 (plan:888-890), T16 (plan:950-954) | OK |
| §6 (spec:428-453) | 18 columnas, formato fijo, 360 → 0, sin `-0` | T10 (plan:578-596) | OK |
| §7 Unitarios (spec:457-471) | Casos clave por componente; un test por regla de validación | T1-T15 | OK salvo R2-F8 y R2-F9 |
| §7 Comparaciones (spec:473-475) | `EXPECT_EQ`, `*_EQ` (R12), `EXPECT_NEAR` | Global Constraints (plan:149-151) | OK |
| §7 Integración (spec:479-486) | Golden: dos emisores, 0.1 s, en `Runner/tests/data/` | T16 (plan:956-1050) | OK (recuentos 18 + 58 + 55 comprobados) |

## Estado de los hallazgos de la ronda 1

| Id | Estado | Dónde se resuelve |
| --- | --- | --- |
| F1 (redondeo frente a `> 0`) | Resuelto | spec:52-53, 393-395, 403; plan:139-140, 774-775; tests plan:827-830, 845-846 |
| F2 (puerta abierta a móviles) | Resuelto (decisión consciente) | Decisión 8 (plan:97-98); spec:26-27, 144-149 |
| F3 (`ScanKind` en el dominio) | Resuelto | Decisión 3 (plan:83-85); spec:160-163; `ScanSpec` en `Config` (plan:753, 758) |
| F4 (`Simulation` sin carga + `Runner`) | Resuelto | Decisión 6; spec:164-165, 177-178, 190 |
| F5 (`positionM` de 3 números) | Resuelto | plan:778, 915-916; spec:400 |
| F6 (modulación cerrada, parámetro aplazado) | Resuelto | Decisión 7; spec:153-154, 349-350; plan:273-274 |
| F7 (receptor por encima) | Resuelto | plan:626 |
| F8 (dos funciones de geometría) | Resuelto (spec adaptada) | spec:122; plan:217 |
| F9 (golden poco especificada) | Resuelto | plan:956-1041 (JSON completos); spec:479-481 |
| F10 (formato del error) | Resuelto | plan:784-788; spec:417-419 |
| F11 (acumulación por fase, misión inexistente) | Resuelto | plan:888-890, 924; spec:414-421 |
| F12 (orden de `main`, códigos) | Resuelto | plan:950-954; spec:422-424 |
| F13 (texto del Review Focus 2) | Resuelto | plan:178-180 |
| F14 (R12, ficheros de `Catalog`, `JsonReader`) | Resuelto | Decisión 2 (plan:66-70); plan:725-727, 816-817 |
| F15 (`EXPECT_NEAR` frente a R12) | Resuelto | plan:149-151; spec:473-475 |
| F16 (cobertura de ids) | Resuelto | plan:847-848, 914; spec:405-406 |
| F17 (listas vacías en la misión) | Resuelto | Decisión 11; spec:382; plan:918-919 |
| D1 (precisión `float` intermedia) | Resuelto | spec:54-56 documenta la resolución y la acepta |
| D2 (`amplitudeDbm_` `float`) | **Parcial** | Se acepta de hecho (plan:142-143, 268, 614-615), pero spec:54 sigue diciendo "potencias en `double`" sin la excepción del PDW. Basta con media frase en spec §2. |
| D3 (claves repetidas) | Resuelto (limitación documentada) | spec:388-389; decisión 11 |

## Hallazgos nuevos

### R2-F1 — Alta — El "constructor con todos los atributos" choca con las clases con estado, y los constructores que usa el plan no son excepciones declaradas

- **Ubicación:** decisión 2 (plan:44-47); T3 (plan:317-335); T4 (plan:359-365); T8 (plan:477, 496-499); T10
  (plan:571, 575-576); T11 (plan:609-612); T12 (plan:644-646); T13 (plan:690-693); R8 (R:213-214).
- **Descripción:** la decisión 2 exige en todas las clases el "constructor por defecto y con todos los atributos". Pero
  en las clases con estado, los atributos de estado (`index_`, `currentNs_`, `pulsesInDwell_`, `pulsesInHop_`,
  `segmentIndex_`, `nextEmissionNs_`, `pulseIndex_`, `pri_`/`rf_`/`pw_` activos, `nextPulseId_`, `nextSequence_`,
  `currentTimeNs_`) forman parte de ese constructor, y el plan:
  1. construye los objetos con constructores que **no son** el de todos los atributos ni figuran como excepción:
     `StaggerPri{1000, 1200, 1100}`, `SlidingPri{100, 130, 10}` (3 argumentos para 4 atributos),
     `DwellSwitchPri{{1000, 2000}, 3}`, `ListRf{{1e9, 2e9, 3e9}, 2}`,
     `Receiver(id, position, gainDbi, sensitivityDbm, PulseRecordWriter& oWriter)` (5 parámetros para 6 atributos, y
     referencia donde el atributo es puntero), `CsvPulseRecordWriter(std::ostream& oStream)` (que además escribe la
     cabecera) y `Simulation(Mission, PulseRecordWriter&)` (2 parámetros para 4 atributos);
  2. no dice qué **valores iniciales** de estado tiene que pasar el loader (T15) a `Emitter`, ni los tests a cada
     generador, si se usa el constructor de R8. Por ejemplo: ¿`SlidingPri::currentNs_` empieza en `minNs_` (el
     siguiente valor que se devolverá) o en 0? ¿`Emitter::nextEmissionNs_` empieza en `startNs_`? ¿Un `pri_` nulo
     significa "segmento aún no iniciado"? Con un valor inicial equivocado, `SlidingPri` arranca en 0 ns, y el
     `assert` de T8 (plan:493-494) salta o el emisor no clona al entrar en el primer segmento.

  La excepción de `Simulation` (plan:54-55) solo cubre copia, movimiento y `==`, no el constructor. R9 (R:238) prevé
  un único constructor "con parámetros".
- **Evidencia:** plan:46-47 "constructor por defecto y con todos los atributos"; plan:324 `SlidingPri | Time minNs_,
  Time maxNs_, Time stepNs_, Time currentNs_` frente a plan:333 `SlidingPri{100, 130, 10}`; plan:609-611 "atributos
  … `PulseRecordWriter* writer_` (no poseído), `std::uint64_t nextPulseId_`. Constructor con parámetros
  `Receiver(id, position, gainDbi, sensitivityDbm, PulseRecordWriter& oWriter)`".
- **Cambio sugerido:** añadir a la decisión 2 una excepción "**clases con estado**": además del constructor de R8 (que
  se mantiene para copia, tests R12 y `==`), tienen un constructor de configuración que recibe solo los atributos de
  configuración y deja el estado inicial. Enumerar esas clases y, en la tabla de atributos de cada una, su estado
  inicial (`index_ = 0`, `currentNs_ = minNs_`, `nextEmissionNs_ = startNs_`, `segmentIndex_ = 0`, generadores
  activos nulos hasta entrar en el segmento, `nextPulseId_ = 0`…). Indicar también que `CsvPulseRecordWriter` escribe
  la cabecera **solo** en el constructor de configuración (el de R8 no).

### R2-F2 — Media — Trampa de R8 + R11: `T get_x(void)` devuelve una copia y cualquier mutación interna a través del getter se pierde en silencio

- **Ubicación:** decisión 2 (plan:58-60, "`set_x(const T&)` y `T get_x(void)` clonan"); R8 (R:199); R11 (R:255-256);
  T8 (plan:487-488); T11 (plan:618); T13 (plan:695-701); T12.
- **Descripción:** R11 obliga a acceder a los atributos mediante accesores también dentro de la propia clase. En un
  método no `const`, `this->get_x()` elige la sobrecarga no `const`, que devuelve **por valor**. Algunos ejemplos:
  - En `Emitter::next`, `this->get_pri()->next()` avanza un **clon** (por la decisión 2, el getter clona): la PRI no
    avanza nunca y `StaggerPri` siempre devuelve su primer valor.
  - En `Simulation`, `this->get_mission().get_emitters()[i].next()` avanza la copia de una copia y
    `this->get_scheduler().schedule(...)` programa en una cola temporal: los eventos se pierden.
  - `this->get_nextPulseId()++` en `Receiver` no numera.

  Todo compila sin avisos. Los tests lo detectan (`NextResetsStateOnModeChange`, `RunDeliversEveryPulse`), pero el
  diagnóstico no es obvio para quien aprende. Además, copiar en cada pulso un `Mission` con todos sus emisores es muy
  caro. El plan ya documenta otras trampas parecidas (la del lookup en plan:277-279 y la de la división entera en
  plan:394-397), pero esta no.
- **Evidencia:** plan:487 "`f = rf->nextHz()`, `pw = pw->next()`, … siguiente `t += pri->next()`"; R:199 "`T get_x(void);` Getter".
- **Cambio sugerido:** añadir a Global Constraints una "Trampa de accesores": para mutar un atributo desde dentro de la
  clase se usa el reference setter (`this->set_pri()->next()`,
  `this->set_mission().set_emitters()[i].next()`, `++this->set_nextPulseId()`), y para leer en un método no `const`
  sin copiar, `std::as_const(*this).get_x()`. Mencionarlo en T8, T11, T12 y T13.

### R2-F3 — Media — `Simulation`: el pulso devuelto por `next()` no tiene dónde guardarse hasta su evento Emit

- **Ubicación:** T13 (plan:690, 695-701); T8 (plan:479).
- **Descripción:** según el plan, `run()` "llama a `next()` de cada emisor y programa su Emit en su instante", y la
  acción Emit hace `channel_.propagate` y luego `next()` del mismo emisor. `next()` ya devuelve el `EmittedPulse`
  construido, pero la lambda de Emit captura solo `[this, index]` y `Simulation` no tiene ningún atributo de pulsos
  pendientes. Si la acción Emit vuelve a llamar a `next()` para obtener el pulso, recibe el **siguiente**, y el primero
  de cada emisor se pierde. Hay dos implementaciones razonables y dan resultados distintos: capturar el pulso en la
  lambda, o llamar a `next()` dentro de Emit tras consultar `get_nextEmissionNs()`.
- **Evidencia:** plan:695-697 "`run()` … llama a `next()` de cada emisor y programa su **Emit** en su instante. Emit:
  `channel_.propagate` → … → `next()` del mismo emisor y programar su Emit"; plan:699 "las lambdas capturan
  `[this, index]` (Emit)".
- **Cambio sugerido:** fijar la captura de Emit como `[this, index, pulse = std::move(pulse)]` (igual que la de
  Arrival) y describir el ciclo así: Emit(p) → `propagate(p)` → programar Arrival → `q = next()` → si existe,
  programar Emit(q) en `q.emissionTimeNs`.

### R2-F4 — Media — `numberInRange(clave, a, b)` no distingue intervalos abiertos y cerrados, y faltan los tests de los extremos

- **Ubicación:** spec:397-399; plan:777 (`numberInRange(clave, a, b)`), plan:797 (mensaje), plan:840-842, plan:917.
- **Descripción:** la spec usa tres tipos de intervalo: `widthDeg` en (0, 360), anchos de haz en (0, 180] y
  elevaciones en [−90, 90]. Una única lectura `numberInRange(a, b)` con el mensaje `debe estar entre <a> y <b>` no dice
  qué extremos se incluyen, y los tests solo prueban valores muy alejados (400, 200, 95, 200). Un implementador que
  use un intervalo cerrado aceptaría `beamwidthAzDeg: 0`, y `GaussianAntennaPattern::gainDbi` dividiría por cero
  (Δaz/0 → `inf` o `NaN` en la ganancia y en el CSV). Eso contradice spec:386 ("la simulación no puede fallar por la
  configuración"). Con `widthDeg: 0` el sector queda degenerado.
- **Evidencia:** spec:399 "`widthDeg` en (0, 360). Anchos de haz en (0, 180]"; plan:777 "`numberInRange(clave, a, b)`".
- **Cambio sugerido:** indicar en la firma qué extremos se incluyen (p. ej. `numberInRange(clave, a, b, Bounds::OpenClosed)`,
  o lecturas separadas), con el mensaje correspondiente (`debe estar en (0, 180]`). Añadir tests de frontera:
  `beamwidthAzDeg: 0` y `widthDeg: 360` rechazados; `beamwidthAzDeg: 180` y `elevationDeg: 90` aceptados.

### R2-F5 — Baja — `EventScheduler::Event` es un `struct` que no figura entre las excepciones

- **Ubicación:** decisión 2 (plan:44-47, "incluidos los antiguos mensajes internos … pasan de `struct` a clases
  completas"); T12 (plan:645-646).
- **Descripción:** `Event` es un `struct` con miembros públicos sin `_` y sin R8. Tiene sentido, pero contradice el
  "se aplica a todas las clases", y la lista de excepciones (plan:48-70) no lo menciona. Además, como `events_` es
  atributo, R8 genera accesores públicos que devuelven `std::vector<Event>` de un tipo privado.
- **Cambio sugerido:** añadir "tipos anidados privados de detalle de implementación (`EventScheduler::Event`)" a las
  excepciones, y decidir si los accesores de `events_` son públicos o privados.

### R2-F6 — Baja — `ConfigError::message_` tiene setters públicos que rompen su invariante

- **Ubicación:** decisión 2 (plan:64-65); T14 (plan:752).
- **Descripción:** la excepción solo hace privado el reference setter de `errors_`. Pero `message_` es una caché
  derivada de `errors_`. Con R8 tiene `set_message(const std::string&)` y `set_message(std::string&&)` públicos, y el
  constructor de todos los atributos recibe `(errors, message)`. Las dos cosas permiten que `what()` no coincida con
  `get_errors()`.
- **Cambio sugerido:** declarar que los cinco accesores de `message_` son privados, o que no tiene setters, y que el
  constructor de R8 ignora el mensaje recibido o lo recalcula. También vale no hacer de `message_` un atributo R8 y
  calcularlo en el constructor.

### R2-F7 — Baja — `to_string` sin formato fijado para punteros, contenedores, `Time` y enums

- **Ubicación:** R10 (R:245-248); plan:216, 271 (solo se fija para `Position` y el PDW); atributos de plan:448-449, 477,
  571, 611, 644, 755-756.
- **Descripción:** R12 exige un test de `to_string` con la cadena exacta, pero el plan no dice cómo se formatean:
  - punteros nulos (`Segment::mode_`/`scan_` en `off`, generadores activos de `Emitter`);
  - punteros no poseídos (`writer_`, `stream_`), cuya dirección cambia en cada ejecución;
  - contenedores de tipos sin `std::formatter` (`std::vector<Segment>`, `std::map<…, EmitterType>`);
  - `Time`, que con `std::format("{}")` sale como `1000ns`;
  - `ScanKind`, que no tiene `to_string`.

  Cada implementador elegirá una cosa distinta.
- **Cambio sugerido:** añadir a la decisión 2 una convención: `Time` como número de ns (como en el PDW); un puntero se
  muestra con el `to_string` del objeto apuntado o `null`; un puntero no poseído, solo como `set` o `null`; listas
  `[a, b]` con el `to_string` de cada elemento; y `to_string(ScanKind)`.

### R2-F8 — Baja — Faltan tests de algunas reglas de validación

- **Ubicación:** spec:470 ("un test por cada regla de validación"); spec:396, 400; T14 (plan:815-854), T15
  (plan:900-926).
- **Descripción:** no hay test para:
  - "Frecuencias > 0" (`frequencyMHz: 0`, o un 0 en `frequenciesMHz`);
  - el límite `|x| ≤ 10⁸ m` de `positionM`, cuyo mensaje tampoco está en la lista de mensajes fijos (plan:790-810);
  - "el resto se ignora" de spec:373-374 (un `.txt` o un subdirectorio en el catálogo).
- **Cambio sugerido:** añadir `ParseCatalogRejectsNonPositiveFrequency`, `ParseMissionRejectsPositionOutOfRange` (con
  su mensaje) y `LoadCatalogIgnoresNonJsonFiles`.

### R2-F9 — Baja — `clone()` sin test en los scans y la antena; `==` entre tipos distintos solo se prueba en la PRI

- **Ubicación:** R12 (R:296, "Todas las funciones públicas tienen al menos un test"); T5 (plan:399-405), T6
  (plan:424-431), T4 (plan:366).
- **Descripción:** `CloneKeepsState` existe para los generadores (T3, T4), pero `FixedScan`, `CircularScan`,
  `SectorScan` y `GaussianAntennaPattern` declaran `clone()` y no tienen test de `clone()`. El test de comparación
  polimórfica entre tipos distintos solo existe para `PriGenerator`, aunque `RfGenerator` (`FixedRf` frente a `ListRf`)
  y `ScanPattern` (tres implementaciones) también lo admiten.
- **Cambio sugerido:** añadir `CloneReturnsEqualCopy` en T5 y T6, y `EqualityOperatorIsFalseForDifferentDerivedTypes`
  en `ut_FixedRf.cpp` y `ut_FixedScan.cpp`.

### R2-F10 — Baja — El Review Focus 7 remite a las Tareas 3 y 8, pero el test de `EmitterMode` está en la Tarea 7

- **Ubicación:** plan:192-193 frente a plan:456-458.
- **Evidencia:** plan:192 "copiar un `Emitter` o un `EmitterMode` no comparte estado mutable … Tests en Tareas 3 y 8";
  el test `EqualityOperatorComparesPointedGenerators` de `EmitterMode` está en la Tarea 7 (plan:457).
- **Cambio sugerido:** "Tests en Tareas 3, 7 y 8".

### R2-F11 — Baja — Tests con el resultado esperado sin fijar

- **Ubicación:** plan:826, 831-833, 838-839.
- **Descripción:**
  - `ParseCatalogRejectsNegativeInteger` espera "`debe ser un entero` o `debe ser >= 1` (… fijarlo al implementar)".
  - `ParseCatalogRejectsNonFiniteNumber` admite dos comportamientos.
  - `ParseCatalogRejectsNonPositiveValues` (`valueUs: 0`) no dice si el mensaje es `debe ser > 0` o
    `debe ser > 0 tras redondear a 1 ns`. Como `time()` valida después de convertir (plan:774-775), los dos son
    defendibles.

  Un test cuyo resultado se decide al implementarlo no sirve como especificación.
- **Cambio sugerido:** fijar los tres. Por ejemplo: `-1` → `debe ser >= 1` (es un entero); `valueUs: 0` → `debe ser > 0`
  (el valor ya era ≤ 0 antes de redondear) y `debe ser > 0 tras redondear a 1 ns` solo cuando el valor original era
  positivo.

### R2-F12 — Baja — Nombres inconsistentes entre clases

- **Ubicación:** plan:448-449 (`modulation_` en `EmitterMode` y `EmittedPulse`) frente a plan:268
  (`intrapulseModulation_` en el PDW), spec:304 (clave JSON `intrapulseModulation`) y spec:440 (columna
  `intrapulseModulation`); plan:353-354 (`RfGenerator::nextHz` frente a `next` en PRI y PW).
- **Descripción:** el mismo dato tiene dos nombres, y por tanto dos juegos de accesores (`get_modulation` y
  `get_intrapulseModulation`). No incumple ninguna regla, pero sí la convención de usar el mismo nombre en JSON,
  atributo y CSV que se siguió con `amplitudeDbm` (decisión 10).
- **Cambio sugerido:** usar `intrapulseModulation_` en las tres clases. `nextHz` puede quedarse (la unidad en el
  nombre es útil), pero conviene decirlo.

### R2-F13 — Baja — Ciclo entre componentes de `SigInt`: `Geometry` ↔ `PulseDescriptors`

- **Ubicación:** plan:208 (`Geometry` consume `AngleOfArrival`) y plan:275 (`PulseDescriptors` depende de `Geometry`
  por `Time`); spec:174-175.
- **Descripción:** CMake no lo ve (un solo target por librería, `.cmake/BuildComponent.cmake`), así que compila. Pero es
  justo el tipo de ciclo que spec:174-175 quiere evitar entre librerías, e impediría separar esos componentes en el
  futuro.
- **Cambio sugerido:** anotarlo como aceptado en la decisión 1, o mover `Units.h` (`Time`) a un componente sin
  dependencias.

### R2-F14 — Baja — La comprobación de aislamiento de nlohmann solo mira las cabeceras

- **Ubicación:** Global Constraints (plan:157); T14 paso 4 (plan:857-858).
- **Descripción:** `PRIVATE_EXTERNAL` se aplica a todo el target `Simulator`, así que un `.cpp` de `Engine` o de
  `Runner` podría incluir `<nlohmann/json.hpp>` y compilar. El `grep … --include=*.h` no lo detectaría.
- **Cambio sugerido:** `grep -rln nlohmann src --include=*.h --include=*.cpp | grep -v '^src/Simulator/Config/src/'`
  (sin `--include` también saldría `src/Simulator/deps.cmake`).

## Viabilidad del reparto de librerías

- **Ningún tipo de `sigint` usa uno de `sim`.** Los atributos de las clases de `sigint` son: generadores (`Time`,
  `std::vector`, enteros), scans (`AngleOfArrival`, `Time`, `double`), `GaussianAntennaPattern` (`double`),
  `EmitterMode` (interfaces de `sigint`, `IntrapulseModulation`), `EmittedPulse` (`Position`, `AngleOfArrival`,
  `AntennaPattern`, `Time`, `std::string`), `IncidentPulse` (`EmittedPulse`) y el PDW (`Time`, `AngleOfArrival`,
  `IntrapulseModulation`). Todos son de `sigint` o de la biblioteca estándar. `segmentIndex_` es un `std::size_t`
  opaco y no arrastra `Segment`.
- **`sim` → `sigint` en un solo sentido:** `Segment`/`Emitter` → `EmitterMode`, `ScanPattern` y generadores; canal →
  `EmittedPulse`, `IncidentPulse`, `Position`, `AntennaPattern`; receptor → PDW, geometría; `Config` →
  `IntrapulseModulation`, generadores y scans.
- **CMake:** cada carpeta de `src/` es una librería (`.cmake/Components.cmake`). `SigInt` no tiene `deps.cmake` (no
  depende de nada). `src/Simulator/deps.cmake` declara `LIBRARIES SigInt` (público, así el ejecutable y los tests de
  `Simulator` ven `sigint`) y `PRIVATE_EXTERNAL nlohmann_json::nlohmann_json`. `dependencies.cmake` se incluye antes
  de construir las librerías (`CMakeLists.txt`), así que el target de nlohmann existe cuando `proj_load_dependencies`
  lo comprueba. `proj_check_cycles` no encontraría ningún ciclo. Las carpetas `src/` de cada componente son include
  `PRIVATE` del target, por lo que los tests no ven `JsonReader.h`, lo que es coherente con la excepción de la
  decisión 2.
- **Ejecutable:** `src/deps.cmake` pasa de `Dummy_Lib` a `Simulator` (plan:941) y recibe `SigInt` de forma transitiva.
- **Nombres en ctest:** `<Librería>.<Componente>.<Suite>.<Caso>` (`.cmake/Tests.cmake`). Los filtros de cada tarea
  coinciden con la carpeta que crea: T1 `SigInt\.Geometry`, T2 `SigInt\.PulseDescriptors`, T3-T7 `SigInt\.Emission`,
  T8 `Simulator\.Emitter`, T9 `Simulator\.Channel`, T10-T11 `Simulator\.Receiver`, T12-T13 `Simulator\.Engine`,
  T14-T15 `Simulator\.Config` y T16 todos.

## Verificado sin problemas

- **Decisiones 1-11** (plan:22-106) coinciden con la spec, y cada una remite a la sección de spec correcta (§3
  decisiones 6 y 7, §4 paso 2.3, §5, §6, §1).
- **Referencias cruzadas de tareas:** tabla de reparto (T1, T3, T5, T6, T8, T12, T14), Review Focus 1-6 (Tareas 5, 9,
  8, 1/14, 14/15, 8), "Tarea 14" en T3, "Tarea 5" en T15, lint al cerrar las Tareas 8, 12, 14 y 16 (presente en los
  pasos 4 de T8, T12 y T14 y en el paso 6 de T16). La única errata está en el Review Focus 7 (R2-F10).
- **Nombres de atributos usados en los tests y en el texto:** `emissionTimeNs`, `arrivalTimeNs`, `isotropicPowerDbm`,
  `txGainDbi`, `peakPowerDbm`, `segmentIndex`, `emitterPulseIndex`, `trueAoa`, `amplitudeDbm`, `currentTimeNs` y
  `durationNs` coinciden con las tablas de atributos de T7, T8, T10, T11, T12 y T13.
- **CSV:** las 18 columnas, en el orden y con los nombres de spec §6. La fila de `WriteFormatsRow` es correcta con los
  formatos indicados: `36.87f` → `36.8700`; `359.99997f` → `360.0000` → `0.0000`.
- **Calendarios de T8** recalculados: `NextSkipsOffSegment` (5, 6, 7, 9.5, 10.5),
  `NextResetsStateOnModeChange` (5, 6 | 7.5, 8.5, 10.5), frontera en 7 ms, `NextStopsAtEnd` (5, 6, 7),
  `NextDoesNotShareState…` (0, 1, 3, 6) y el scan relativo (90° a 6 ms).
- **Golden (T16):** B1 da 58 + 55 = 113 pulsos (2 + 0.7k < 42 → k ≤ 57; 62 + 0.7k < 100 → k ≤ 54). A1 da dos ráfagas
  de 9 pulsos: el umbral −60 dBm permite un desvío de ±37.2°, es decir ±5.17 ms alrededor de 25 y 75 ms, con la
  secuencia de stagger 20, 21, 22.5 … 30 ms. P_iso de pico −41.53 dBm.
- **T13:** retardos y recuentos de `RunDeliversEveryPulse`, `RunOrdersByArrivalTime` y
  `RunDeliversPulsesInFlightAfterEnd`. La antena con SLL 0 da 0 dBi en todas las direcciones, y P_iso ≈ −82 dBm queda
  por encima de −200.
- **Reglas de validación 1-7 y gestión de errores:** cada regla tiene test, salvo lo indicado en R2-F8. El mensaje de
  ejemplo de la spec se reproduce literalmente (plan:906-907). El orden de las fases, los errores de disco y los
  códigos 0-4 coinciden.
- **Excepciones de la decisión 2:** son coherentes para las interfaces (copia `protected` contra el *slicing*, `==` no
  virtual con `typeid` + `isEqual`), `Simulation`, `EventScheduler` (sin `==`), los atributos polimórficos, los
  punteros no poseídos, `JsonReader` y los módulos de funciones libres. `PropagationChannel` sin atributos cumple R8 sin
  excepción.
- **Spec §3 Ubicación:** el párrafo de R1–R12 (spec:180-181) rompe visualmente la lista de viñetas siguiente
  (spec:182-184). Es solo de formato y no lo cuento como hallazgo.

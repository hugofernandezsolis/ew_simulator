# Revisión adversarial del plan del simulador, segunda ronda (abogado del diablo)

Fecha: 2026-10-24
Documentos revisados: `specs/2026-10-24-simulator-design.md`, `plans/2026-10-24-simulator.md` (versiones reescritas
tras la primera ronda), `.claude/rules/how_to_write_a_class.md`, `src/SigInt/PulseDescriptors/` y mi informe anterior
`reviews/2026-10-24-plan-review-3-adversarial.md` (A1–A15).

Pruebas de apoyo: un fichero suelto de C++23 compilado con `g++ -std=c++23 -fsanitize=undefined` en el scratchpad
(`review3-round2/t1.cpp`) que reproduce el patrón de accesores R8 con `unique_ptr` + `clone()`, la comparación por
`typeid` + `isEqual`, `std::llround` fuera de rango y la conversión `double → float` de valores enormes. Los
resultados citados abajo salen de esa ejecución.

## Resumen y veredicto

La reescritura cierra bien casi todo lo de la primera ronda: la validación sobre el `Time` ya redondeado elimina el
bucle de PRI 0 ns, `shared_ptr<const …>` impide avanzar el prototipo, los enteros, las posiciones, los errores de disco
y el CSV quedan cubiertos. **Lo que abre huecos nuevos es aplicar R8 completo a las clases con estado y polimorfismo.**
El problema más serio no es una invariante concreta, sino un patrón: R11 obliga a acceder a los atributos a través de
los accesores, y en un método no `const` `this->get_x()` elige la sobrecarga `T get_x(void)`, que **devuelve una
copia** (y, por la decisión 2, un **clon** en los `unique_ptr`). Quien escriba `this->get_pri()->next()` en
`Emitter::next`, `this->get_mission().get_emitters()[i].next()` en `Simulation` o
`mission.get_emitters()[0].next()` en un test avanza una copia temporal: la secuencia no avanza nunca y, en el caso
del emisor dentro de la simulación, **el programa se cuelga** en el instante del primer pulso. Ni el plan ni la regla
lo advierten, y varias de las piezas afectadas son 👤.

Además, los accesores públicos de estado y el constructor por defecto permiten construir objetos que fallan al usarse
(índice fuera de rango, `% 0`, punteros nulos), el `Emit` del plan no dice dónde viaja el pulso, y la validación sigue
convirtiendo a `int64` **antes** de comprobar el límite superior.

**Veredicto: apto para ejecutar tras corregir R2-A1** (una regla explícita en Global Constraints y algún test que lo
detecte) **y, preferiblemente, R2-A3, R2-A4 y R2-A7**, que son aclaraciones de pocas líneas en las Tareas 3, 5, 8 y
13. El resto son endurecimientos y notas.

| Gravedad | Nº | Hallazgos |
| --- | --- | --- |
| Crítica | 0 | — |
| Alta | 1 | R2-A1 |
| Media | 7 | R2-A2, R2-A3, R2-A4, R2-A5, R2-A6, R2-A7, R2-A8 |
| Baja | 7 | R2-A9 – R2-A15 |

## Estado de los hallazgos de la primera ronda

| Id | Estado | Comentario |
| --- | --- | --- |
| A1 | Resuelto | `time()` comprueba > 0 ns tras redondear; tests `…RoundsToZero`, `…PwEqualToPriAfterRounding`. Restos: el `assert` desaparece en Release (R2-A14) y los objetos por defecto vuelven a tener PRI 0 / periodo 0 (R2-A4). |
| A2 | Parcial | `isfinite` y límites de 10⁶ s / 10⁸ m, bien. Pero se convierte a ns **antes** de comprobar ≤ 10⁶ s (R2-A5) y la suma de inicios solo está acotada si el loader deja de sumar al pasar `durationS` (R2-A12). |
| A3 | Resuelto | `shared_ptr<const PriGenerator>` en `EmitterMode`: `get_pri()->next()` no compila. Hueco nuevo, distinto, en los `unique_ptr` del `Emitter` (R2-A2). |
| A4 | Resuelto | `positiveInteger` con `is_number_integer()`. Restos: falta un test con `4294967296` (rango de `uint32_t`), y `3.0` o `1e2` (que nlohmann lee como `double`) se rechazan como "no entero": conviene decirlo en la spec. |
| A5 | Resuelto | Documentado como aproximación (spec §4 paso 2.3). No se añadió el test a el = 60° que fijaría el comportamiento; opcional. |
| A6 | Resuelto | Lectura `position` (3 números finitos, ≤ 10⁸) y validación por elemento de las listas con ruta. |
| A7 | Parcial | Copia/movimiento `= delete`, eventos en `run()`, captura de índice: bien. Pero el `Emit` capturando solo `[this, index]` pierde el pulso (R2-A7) y los accesores R8 de `Simulation` y `EventScheduler` reabren la puerta (R2-A8). |
| A8 | Resuelto | Errores de disco → `ConfigError`, solo ficheros regulares, `.json` exacto documentado. Resto conocido: `"catalogDir": "."` carga la propia misión como tipo (error confuso, pero error). |
| A9 | Resuelto | Reglas de 360 y −0 tras formatear. Resto: el test solo cubre `azimuthDeg`; la misma regla debe aplicarse a `truth_azimuthDeg` (añadir un `EXPECT` en `WriteWrapsAzimuthRoundedTo360`). |
| A10 | Resuelto | Elevaciones [−90, 90], `widthDeg` (0, 360), anchos (0, 180]. Los azimuts quedan libres: ver R2-A6. |
| A11 | Resuelto | Documentado en spec §1 y §4. |
| A12 | Resuelto | Limitación documentada (spec §5 regla 1). |
| A13 | Parcial | d ≥ 1 m. Con frecuencias bajas sigue habiendo campo cercano: `frequencyMHz: 0.000001` (1 Hz) a 1 m da FSPL ≈ −147,6 dB y `P_rx > P_tx`. Aceptable si se documenta; ver también R2-A6. |
| A14 | Resuelto | Tests `NextReturnsNulloptWhenAllSegmentsOff`, `…StartAfterEnd`, `schedule` vacía error, `emitters` vacía válida. |
| A15 | Resuelto | Nota en spec §7 y Tarea 16. |

## Hallazgos nuevos

### R2-A1 — `this->get_x()` en un método no `const` trabaja sobre una copia o un clon: cuelgues y estado que no avanza (Alta)

- **Escenario.** R11 exige leer los atributos a través de los accesores también dentro de la clase. R8 da dos
  getters: `T get_x(void)` y `const T& get_x(void) const`. En un método no `const` (`Emitter::next`,
  `Simulation::run`, `EventScheduler::runAll`, `Receiver::receive`, `StaggerPri::next`), la llamada
  `this->get_x()` elige la sobrecarga **no const**, que devuelve **por valor**; y para los `unique_ptr`, la
  decisión 2 dice que ese getter **clona**. Casos concretos que el plan deja abiertos:
  1. `Emitter::next` (👤): `this->get_pri()->next()` avanza un clon temporal. Con `StaggerPri{1,2,3 ms}` devuelve 1,
     1, 1… Reproducido en `t1.cpp`: `via non-const getter: 1 1 1`.
  2. `Simulation` (acción `Emit`): `this->get_mission().get_emitters()[index].next()` copia la `Mission` entera,
     avanza el emisor de la copia y lo tira. Cada `Emit` vuelve a obtener el **primer** pulso y programa el
     siguiente `Emit` en ese mismo instante (permitido: `iAt == now()` no lanza) → **bucle infinito en t₀** con la
     cola creciendo (un `Arrival` por vuelta) hasta agotar la memoria.
  3. `Simulation`: `this->get_receiver().receive(…)` recibe en una copia; como la copia comparte el puntero al
     escritor, las filas se escriben, pero `nextPulseId_` no avanza: **todas las filas con `pulseId` 0**. Ningún test
     de la Tarea 13 comprueba `pulseId`, y la verificación manual del golden (Tarea 16, paso 5) tampoco lo menciona,
     así que el golden se generaría con el error dentro.
  4. `EventScheduler::runAll` (👤): `while (!this->get_events().empty()) { auto ev = this->get_events(); … }` nunca
     vacía el heap real → **bucle infinito**; y aunque se haga bien, cada `get_events()` no const copia todos los
     `std::function` pendientes (coste O(n) por evento).
  5. Test de la Tarea 15 `ParseMissionChainsSegmentsFromStart`: "avanzar `E1` hasta el primer pulso `track`", escrito
     de forma natural como `while (mission.get_emitters()[0].next()->get_modeId() != "track")` sobre una `Mission`
     no const, **no termina nunca** (cada iteración avanza una copia nueva). Reproducido con un `Mission` de juguete:
     `mission.get_emitters()[0]: 1 1`.
- **Comportamiento previsto.** Según el caso, secuencia congelada (los tests de stagger lo detectan), cuelgue del
  test o de `ews` (ctest sin `TIMEOUT` lo deja colgado hasta el límite del job de CI), o una salida errónea que ningún
  test mira (`pulseId`).
- **Esperado.** Que el plan diga cómo se muta un atributo dentro de la clase sin violar R11, y que un error así lo
  detecte un test rápido y no un timeout.
- **Cambio sugerido.**
  - Global Constraints, una regla explícita: "Para **leer** un atributo dentro de la clase en un método no `const`,
    `std::as_const(*this).get_x()` o el getter `const`; para **mutarlo** (incluido llamar a un método no `const` del
    objeto apuntado), el reference setter `this->set_x()` (p. ej. `this->set_pri()->next()`,
    `this->set_mission().set_emitters()[index].next()`). El getter no const devuelve una copia y, en los `unique_ptr`,
    un clon." Repetirlo junto a las piezas 👤 de las Tareas 3, 8 y 12.
  - Tarea 13: en `RunDeliversEveryPulse`, comprobar también `pulseId` 0, 1, 2, 3; añadir un emisor con `StaggerPri`
    en algún test de `Simulation` (con `FixedPri` un estado congelado pasa inadvertido).
  - Tarea 15: escribir el bucle del test sobre `mission.set_emitters()[0]` (o sobre una referencia local) y acotarlo
    (`for` con un máximo de iteraciones y `ASSERT`).
  - Tarea 16 / CMake: dar a los tests un `TIMEOUT` (p. ej. 60 s) para que un cuelgue sea un fallo y no un job
    bloqueado.

### R2-A2 — El getter `const` de un `unique_ptr` deja mutar el generador a través de un `const Emitter&` (Media)

- **Escenario.** `const std::unique_ptr<sigint::PriGenerator>& Emitter::get_pri(void) const` (firma obligada por
  R8). La `const` cae sobre el `unique_ptr`, no sobre el `PriGenerator`: `operator->` de un `const unique_ptr<T>`
  devuelve `T*`. Así, `void f(const Emitter& e) { e.get_pri()->next(); }` **compila y avanza el estado real** del
  emisor. Reproducido: tras `ce.get_pri()->next()` el siguiente valor del original pasa de 1 a 2.
- **Comportamiento previsto.** La semántica queda invertida según la constancia: sobre un `Emitter` no const,
  `get_pri()->next()` no tiene efecto (clon, R2-A1); sobre un `const Emitter&`, sí lo tiene. Es el mismo agujero
  que A3 cerraba en `EmitterMode`, ahora en el estado activo.
- **Esperado.** Que `const` signifique "no cambia el estado observable".
- **Cambio sugerido.** Tarea 8 (excepción documentada en la decisión 2): el getter `const` de los atributos
  polimórficos con estado devuelve `const sigint::PriGenerator*` (o `const PriGenerator&` con precondición de no
  nulo) en lugar de `const std::unique_ptr<PriGenerator>&`. Alternativa sin cambiar la firma:
  `std::experimental::propagate_const<std::unique_ptr<…>>` (libstdc++ la trae, pero no es estándar). Test
  `ConstGetPriDoesNotAllowAdvancing` como `static_assert` sobre `decltype(std::as_const(e).get_pri()->next())`
  (o, sin `static_assert`, un comentario en el `.h`).

### R2-A3 — El estado inicial del `Emitter` no está definido y el constructor con todos los atributos lo expone (Media)

- **Escenario.** R8 obliga a un constructor con **todos** los atributos, incluidos los de estado
  (`segmentIndex_`, `nextEmissionNs_`, `pulseIndex_`, `pri_`, `rf_`, `pw_`). El loader (Tarea 15) y los tests de la
  Tarea 8 tienen que pasar esos valores para un emisor "sin empezar", pero el plan no dice cuáles son ni cómo
  distingue `next()` "aún no he entrado en el segmento k" de "estoy dentro":
  - Si `next()` clona los generadores **solo al cambiar de segmento** y el loader construye con `pri_` nulo y
    segmento 0 con modo → **desreferencia de nulo** en el primer `next()`.
  - Si el loader clona el segmento 0 de antemano, pero el segmento 0 es `off` → hay generadores "activos" en un
    segmento en silencio; si el segmento 0 tiene modo y la implementación vuelve a clonar al entrar, sin daño.
  - `next()` necesita el inicio del segmento (para `t − inicio_k` y el fin), que no se guarda: hay que recalcularlo
    sumando duraciones, y `set_nextEmissionNs` (público) puede dejarlo **antes** del inicio → `t' < 0` →
    `SectorScan` hace `t % T` con dividendo negativo (resultado negativo en C++) y apunta fuera del sector.
  - `set_segmentIndex(schedule_.size() + 1)` (público): si el fin se detecta con `==` en lugar de `>=`, `next()`
    indexa fuera de rango (UB). El `Emitter` por defecto (fixture R12) tiene `schedule_` vacía: `next()` debe
    devolver `nullopt` **antes** de indexar.
- **Esperado.** Un contrato de estado escrito.
- **Cambio sugerido.** Tarea 8: fijar en el comentario de la clase las invariantes y el estado inicial, p. ej.
  "`segmentIndex_ >= schedule_.size()` ⇒ terminado; `pri_ == nullptr` ⇒ hay que entrar en el segmento
  `segmentIndex_` (clonar si tiene modo, saltar si es `off`) con `nextEmissionNs_` = su inicio; estado inicial
  `{0, startNs_, 0, nullptr, nullptr, nullptr}`". Mejor aún, añadir un constructor de conveniencia
  `Emitter(id, position, startNs, schedule, endNs)` que fije ese estado (el loader y los tests lo usan) y dejar el
  de R8 para copia/pruebas. Tests `NextOnDefaultEmitterReturnsNullopt`,
  `NextWithSegmentIndexPastEndReturnsNullopt`.

### R2-A4 — Objetos por defecto, movidos o con setters de estado sueltos que fallan al usarse (Media)

- **Escenario.** El plan acepta (decisión 2, "consecuencias") que los objetos por defecto "no se deben usar sin
  configurar" y que "constructores y setters no validan" (Tarea 3). Pero hay invariantes reales que los setters
  públicos rompen, y algunos usos no son exóticos:
  - `StaggerPri` / `DwellSwitchPri` / `ListRf` por defecto (o tras `set_valuesNs({})`, o movidos): `next()` con
    vector vacío → `valuesNs_[index_]` fuera de rango o `index % 0` → **SIGFPE**. `set_index(5)` con 3 valores →
    lectura fuera de rango si el índice solo se reduce al incrementar.
  - `DwellSwitchPri`/`ListRf` con `set_pulsesInDwell(10)` y `pulsesPerDwell_ = 3`: si el cambio de bloque se
    comprueba con `==`, el contador sube hasta dar la vuelta a `uint32_t` (≈ 4·10⁹ pulsos con el mismo valor).
  - `SectorScan` por defecto o `set_periodNs(0)`: `t % 0ns` → división entera por cero (UB, SIGFPE).
    `CircularScan` con T = 0: `0/0` = NaN en t = 0 → azimut NaN → ganancia NaN → pulso descartado en silencio. El
    `assert(pri > 0)` del `Emitter` no cubre los scans.
  - `Emitter` por defecto: si el getter no const o el constructor de copia hacen `pri_->clone()` sin comprobar nulo,
    **el propio test R12 del getter** (que usa el objeto por defecto del fixture) da *segfault*. El plan dice que
    "dos nulos son iguales" en `==`, pero no que copia, getter y setter (`set_pri(const unique_ptr&)` con un nulo)
    deban tolerar nulos.
  - `Receiver` por defecto o tras `set_writer(nullptr)`, y `CsvPulseRecordWriter` por defecto (stream nulo): la
    primera detección/escritura desreferencia nulo. Variante: `Simulation sim(mission, writer); auto w2 =
    std::move(writer);` → el `Receiver` sigue apuntando a `writer`, ya movido (stream nulo) → *segfault* al primer
    pulso detectado.
- **Esperado.** O que esas operaciones sean seguras por construcción, o un fallo diagnosticable.
- **Cambio sugerido.**
  - Tareas 3 y 4: en `next()`, leer con `values[index % size]` y comparar contadores con `>=`; `assert(!empty())`.
    Alternativamente, tratar `index_`/`pulsesInDwell_` como atributos con invariante (reference setter privado y
    setters que reducen módulo el tamaño), que es justo para lo que existe la excepción de R8.
  - Tarea 5: `assert(periodNs_ > 0ns)` en `pointingAt` de los dos scans.
  - Tarea 8: copia, getter no const y setter por copia de `pri_/rf_/pw_` con `x ? x->clone() : nullptr`; un test
    R12 explícito con el emisor por defecto lo cubre.
  - Tareas 10 y 11: `assert(stream_ != nullptr)` / `assert(writer_ != nullptr)` en `write`/`receive`, y una frase en
    `runMission`: el escritor no se mueve ni se destruye mientras viva la `Simulation`.

### R2-A5 — Se convierte a `int64` antes de comprobar el límite superior (Media)

- **Escenario.** `time(clave, unidad)` "convierte a `Time` y **después** comprueba > 0 ns y ≤ 10⁶ s". Con
  `"durationS": 1e10` o `"valueUs": 1e13` (finitos, pasan `isfinite`), el valor en ns (10¹⁹) no cabe en `int64`.
- **Comportamiento previsto.** `std::llround` fuera de rango devuelve un valor no especificado: en x86 en ejecución
  `LLONG_MIN`; con plegado de constantes de GCC, `-8446744073709551616` (medido en `t1.cpp`); en AArch64 satura a
  `LLONG_MAX`. El mensaje resultante es `debe ser > 0 tras redondear a 1 ns` en x86 y `debe ser <= 1000000 s` en
  ARM: incorrecto y dependiente de la plataforma. Además contradice la precondición que el propio plan documenta en
  `secondsToTime` ("el loader la garantiza"). Si alguien implementa la conversión con
  `duration_cast<nanoseconds>(duration<double, …>)` en vez de `llround`, el desbordamiento `double → int64` es **UB**
  (y UBSan de GCC no lo vigila: `float-cast-overflow` no forma parte de `-fsanitize=undefined` en GCC).
- **Esperado.** `durationS: debe ser <= 1000000 s` en todas las plataformas.
- **Cambio sugerido.** Tarea 14, `time()`: (1) `isfinite`, (2) comprobar `valor·escala ≤ 10⁶ s` **en `double`**,
  (3) convertir con `llround`, (4) comprobar `> 0 ns`. Test `ParseMissionRejectsDurationBeyondInt64`
  (`durationS: 1e10` → `debe ser <= 1000000 s`).

### R2-A6 — Números finitos pero absurdos: azimuts libres, dB y frecuencias sin techo (Media)

- **Escenario.**
  - Azimuts "libres porque se normalizan" (`initialAzimuthDeg`, `centerAzimuthDeg`, `pointingAzimuthDeg`): con
    `1e39`, `static_cast<float>` da `inf` (formalmente UB: fuera del rango de `float`), `AngleOfArrival` lo pliega con
    `fmod(inf, 360)` = **NaN** → Δaz NaN → `max(NaN, suelo)` devuelve NaN si el NaN es el primer argumento →
    `P_rx` NaN → `P_rx ≥ S` es falso → **todos los pulsos descartados en silencio**. Con `1e10` no hay NaN, pero el
    `float` tiene una resolución de 1024° a esa magnitud: el scan salta en lugar de girar (medido:
    `float(1e10 + 90) mod 360` = 280 frente a 10 exacto).
  - `peakPowerDbm`, `peakGainDbi`, `gainDbi`, `sensitivityDbm` y el techo de `sidelobeLevelDb` no tienen rango:
    `peakPowerDbm: 1e300` → `amplitudeDbm` = `static_cast<float>(1e300)` → `inf` en el CSV (UB formal);
    `1e308 + 1e308` = `inf`, e `inf − inf` = NaN → descarte silencioso.
  - `frequencyMHz: 1e305` es finito, pero ×10⁶ al pasar a Hz da `inf` → FSPL `inf` → descarte silencioso.
- **Comportamiento previsto.** No hay *crash*, pero sí `inf`/`nan` en el CSV o pulsos perdidos sin aviso, en contra de
  "una vez arrancada, la simulación no puede fallar por la configuración".
- **Esperado.** Error de configuración con ruta.
- **Cambio sugerido.** Spec §5 regla 2 y Tarea 14/15: azimuts en [−360, 360] (o normalizarlos en `double` en el loader
  antes de guardarlos); potencias y ganancias en un rango generoso (p. ej. [−300, 300] dB); frecuencias en
  (0, 10¹² Hz] tras convertir. Tests `ParseMissionRejectsAzimuthOutOfRange`, `ParseCatalogRejectsFrequencyTooHigh`.

### R2-A7 — El evento `Emit` captura `[this, index]` pero no el pulso (Media)

- **Escenario.** Tarea 13: "`run()` llama a `next()` de cada emisor y programa su Emit en su instante" y "las lambdas
  capturan `[this, index]` (Emit)". El `EmittedPulse` que devolvió `next()` no viaja con el evento.
- **Comportamiento previsto.** Quien implemente tiene tres salidas y dos son malas:
  1. Llamar otra vez a `next()` dentro del `Emit` → se procesa el pulso **siguiente** y se programa el posterior:
     **se pierde uno de cada dos pulsos** (o el `Emit` se ejecuta en un instante anterior al `t_e` del pulso que
     propaga).
  2. Usar `get_nextEmissionNs()` como "peek" → antes del primer `next()` no es fiable (si el segmento 0 es `off`, el
     primer pulso no está en `startNs`).
  3. Capturar el pulso por valor, que es lo correcto pero contradice el texto del plan.
- **Esperado.** Un único diseño escrito.
- **Cambio sugerido.** Tarea 13: el `Emit` captura `[this, index, pulse = std::move(*pulse)]`; al ejecutarse propaga
  ese pulso, programa el `Arrival`, llama a `next()` y, si hay pulso, programa el siguiente `Emit` con él. Los tests
  `RunDeliversEveryPulse` (4 registros, TOA 0–3 ms) ya detectarían la opción 1.

### R2-A8 — Los accesores R8 de `Simulation` y `EventScheduler` reabren A7 (Media)

- **Escenario.** `Simulation` no se copia ni se mueve, pero R8 le da cinco accesores por atributo:
  - `EventScheduler get_scheduler(void)` (no const) devuelve una **copia** con todos los `std::function` pendientes,
    que capturan `this` de la `Simulation`. Ejecutar esa copia (`auto s = sim.get_scheduler(); …; s.runAll();`)
    después de destruir la simulación es **uso tras liberación**; antes, mezcla dos colas (las acciones programan en
    la cola original).
  - `sim.set_mission(otra)` o `sim.set_mission().set_emitters().clear()` (por ejemplo desde un escritor de pruebas
    durante `run()`) → las lambdas `[this, index]` indexan fuera de rango.
  - `set_receiver(...)` desincroniza `receiver_` y `mission_.receiver_` (el receptor existe dos veces).
  - `EventScheduler::set_events(v)` con un `v` que no es un heap → `std::pop_heap` con su precondición violada (UB;
    en la práctica, orden equivocado). `set_nextSequence(0)` a mitad de ejecución → números de secuencia repetidos:
    el desempate deja de seguir el orden de inserción (sigue siendo reproducible, pero ya no es el documentado).
    `set_currentTimeNs(t_futuro)` → el siguiente `schedule` legítimo lanza `logic_error`.
- **Esperado.** Que A7 ("imposible de usar mal") siga siendo cierto.
- **Cambio sugerido.** Ampliar las excepciones de la decisión 2:
  - `EventScheduler`: copia `= delete` (copiar acciones que capturan `this` de otro objeto nunca tiene sentido);
    `events_`, `nextSequence_` y `currentTimeNs_` son atributos con invariante (heap, monotonía): setters privados,
    solo getters `const` públicos.
  - `Simulation`: solo getters `const`; sin setters públicos (su estado lo gobierna `run()`).

### R2-A9 — `Simulation`: el plan sugiere leer `iMission` después de moverla (Baja)

- **Escenario.** Atributos en orden `mission_, channel_, receiver_, scheduler_`; "construye `receiver_` desde
  `iMission.get_receiver()`". Con `mission_(std::move(iMission))` en la lista de inicialización, `iMission` ya está
  movida cuando se construye `receiver_` → `ReceiverSpec` por defecto (posición en el origen, sensibilidad 0 dBm).
- **Comportamiento previsto.** Casi todo se descarta. Lo detectarían `RunDeliversEveryPulse` y
  `clang-tidy bugprone-use-after-move`, pero el texto del plan empuja hacia el error.
- **Cambio sugerido.** Tarea 13: "`receiver_` se construye a partir de `mission_` (ya inicializado, se declara antes),
  nunca de `iMission`".

### R2-A10 — `ConfigError`: la caché de `what()` tiene setters públicos propios (Baja)

- **Escenario.** `message_` es un atributo, así que R8 le da `set_message(const std::string&)` y
  `set_message(std::string&&)` **públicos**; la decisión 2 solo hace privado el reference setter de `errors_`.
  `e.set_message("x")` deja `what()` diciendo "x" con `errors_` intactos, y `==` compara dos estados que deberían ser
  uno. Además, el constructor de copia copia un `vector<string>` y puede lanzar `bad_alloc`; si el objeto excepción
  se copia durante el lanzamiento (`throw e;` con un lvalue, `std::make_exception_ptr`), eso es `std::terminate`.
- **Comportamiento previsto.** Copia y movimiento, implementados con R8, sí conservan la caché coherente (los dos
  atributos viajan juntos; el movido queda con ambos vacíos y `what()` devuelve `""`, válido). El problema son los
  setters de `message_`.
- **Cambio sugerido.** No guardar el texto como atributo R8: pasar el texto unido al constructor de
  `std::runtime_error` (su copia es `noexcept`, usa una cadena con recuento de referencias) y, en los setters de
  `errors_`, reasignar la base (`std::runtime_error::operator=(std::runtime_error(join(errors_)))`); sin sobrescribir
  `what()`. Si se mantiene `message_`, que sus cuatro setters sean privados (es estado derivado).

### R2-A11 — Implementaciones polimórficas sin `final`: clon con *slicing* en una subclase futura (Baja)

- **Escenario.** Herencia de varios niveles: `class JitteredStaggerPri : public StaggerPri` que olvida sobrescribir
  `clone()` e `isEqual()`. Reproducido: `clone()` devuelve un `StaggerPri` (*slicing*: el `Emitter` pierde el jitter
  al entrar en cada segmento) y dos `Jittered` con semillas distintas comparan **iguales** (`typeid` coincide y se usa
  el `isEqual` del padre).
- **Comportamiento previsto.** Nada falla hoy; el hueco aparece con la primera extensión (spec §1 la anuncia).
- **Cambio sugerido.** Tareas 3–6: declarar `final` todas las clases concretas (`FixedPri`, `StaggerPri`, …,
  `GaussianAntennaPattern`, `CsvPulseRecordWriter`). Una extensión hereda de la interfaz, no de una concreta.
- **Comprobado que no es problema:** la comparación mixta `derivado == base&` compila y resuelve al `operator==` de la
  base como candidato invertido de C++20 (devuelve el resultado correcto); `derivado1 == derivado2` de tipos
  distintos no compila, que es lo deseable.

### R2-A12 — La suma de inicios de segmento puede desbordar si el loader suma todo antes de recortar (Baja)

- **Escenario.** 9 224 segmentos de `durationS: 1e6` (cada uno válido). La suma pasa de 9,22·10⁹ s = máximo de `int64`
  en ns.
- **Comportamiento previsto.** El plan afirma "así la suma de inicios nunca pasa de 2·10⁶ s", lo cual solo es cierto
  si el loader **deja de acumular** al alcanzar `durationS`. Si suma todos los segmentos para decidir cuáles recortar,
  hay desbordamiento con signo (UB).
- **Cambio sugerido.** Tarea 15: escribir "se deja de sumar en cuanto el inicio alcanza `durationS`; los segmentos
  siguientes solo se validan". Test opcional con 10 000 segmentos.

### R2-A13 — Configuraciones válidas que agotan tiempo o memoria (Baja)

- **Escenario.** PRI 2 ns y PW 1 ns (cumplen PW < PRI), `durationS: 1e6` → 5·10¹⁴ pulsos por emisor: días de
  ejecución y un CSV de petabytes. Con el emisor a 10⁸ m (retardo 0,33 s) hay ≈ 1,7·10⁸ `Arrival` en vuelo, cada uno
  con un `IncidentPulse` (dos `std::string`, un `shared_ptr`…; unos cientos de bytes) → decenas de GB → `bad_alloc`
  (código 4) o el OOM killer.
- **Comportamiento previsto.** Contradice "una vez arrancada, la simulación no puede fallar por la configuración".
- **Cambio sugerido.** Documentarlo en la spec §5, o rechazar al cargar una estimación de pulsos
  (Σ duración/PRI mínima) por encima de un límite (p. ej. 10⁹), o fijar una PRI mínima realista (p. ej. ≥ 100 ns).

### R2-A14 — La red de seguridad de A1 es un `assert`: desaparece en Release (Baja)

- **Escenario.** El ejecutable para uso real se compilará con el preset `Release` (`NDEBUG`). Si una regresión del
  loader deja pasar una PRI de 0 ns, el `assert(pri > Time::zero())` no existe y vuelve el bucle infinito de A1.
- **Cambio sugerido.** Tarea 8: comprobación siempre activa que lance `std::logic_error` (sale con código 4 y mensaje)
  en lugar de `assert`. Igual para los nulos y el periodo 0 de R2-A4 si se quiere red también en Release.

### R2-A15 — Un error al escribir el CSV no se detecta (Baja)

- **Escenario.** Disco lleno o error de E/S durante `runMission`.
- **Comportamiento previsto.** `std::ofstream` pone `badbit` y deja de escribir; `main` sale con 0 y un CSV truncado.
- **Cambio sugerido.** Tarea 16: tras `runMission`, `out.close()` (o `flush`) y si `!out`, mensaje y código 3 (o uno
  nuevo). Spec §5, códigos de salida: mencionarlo.

## Descartados (ataques probados que el diseño resiste)

- **Comparación polimórfica con nulos.** `operator==` de la interfaz recibe referencias; el nulo se trata en el
  dueño ("dos nulos son iguales", decisión 2). Con esa regla no hay `typeid(*nullptr)` ni llamada sobre nulo.
- **Ocultación del `operator==` de la base por el R8 de la derivada.** `FixedPri::operator==(const FixedPri&)` oculta
  el de la base dentro de `FixedPri`, pero en C++20 `fixed == baseRef` encuentra el de la base como candidato
  invertido y da el resultado correcto (probado con g++ 23); entre dos concretas distintas no compila.
- **Copia de un `Emitter` a medio avanzar.** Clona los generadores con su estado, copia índices e instante y comparte
  los prototipos inmutables (`shared_ptr<const>`): la copia continúa la misma secuencia y no toca la del original.
  Coherente (siempre que los nulos se clonen como nulos, R2-A4).
- **Copia de `Mission` y `Segment`.** Los `shared_ptr<const EmitterMode>` y `<const ScanPattern>` compartidos son
  inmutables (A3): compartirlos al copiar es seguro.
- **Mover la `Mission` dentro de `Simulation`.** El `vector<Emitter>` movido conserva su bloque; las lambdas capturan
  índice, no punteros; `Simulation` no se mueve. `Receiver` guarda puntero al escritor, que en `runMission` se declara
  antes que la `Simulation` y por tanto vive más.
- **`ConfigError` copiado o movido.** Con R8 los dos atributos viajan juntos; el movido queda con `what()` = `""`,
  puntero válido. Capturar por valor como `std::exception` haría *slicing*, pero `main` captura por referencia.
- **Movimiento de `AngleOfArrival`.** Los setters normalizan otra vez, pero sobre valores ya normalizados no cambian
  nada (incluido el plegado de elevación).
- **`SlidingPri` con `set_currentNs` por encima del máximo.** Devuelve un valor fuera de rango una vez y vuelve a
  `min`; no cuelga. Con `stepNs_` 0 la PRI es constante, no infinita.
- **Segmento de duración 0 o negativa vía setter.** Si `next()` comprueba `t ≥ fin` antes de emitir (lo que exige el
  intervalo semiabierto), se salta sin bucle.
- **Determinismo.** `std::map` ordenado, lista de ficheros ordenada por nombre, objetos de nlohmann con claves
  ordenadas, desempate por secuencia: la misma entrada da la misma salida y los mismos errores en el mismo orden.
- **Límites de tiempo.** Con ≤ 10⁶ s por valor y recorte a `durationS`, ningún instante pasa de ≈ 2·10⁶ s (lejos de
  9,2·10⁹ s), salvo el caso de R2-A12.
- **Geometría en los límites.** Posiciones ≤ 10⁸ m: retardo < 1,2 s, FSPL finita; d ≥ 1 m evita `log10(0)`. Anchos de
  haz diminutos → `−inf` → suelo, sin NaN.
- **Ids en el CSV.** `[A-Za-z0-9_-]+` impide comas, comillas y saltos de línea.
- **Prototipos.** `mode.get_pri()->next()` no compila con `shared_ptr<const PriGenerator>` (A3 cerrado).

# 6.7 Decisiones y puntos de extensión

> [Manual](../README.md) › [Arquitectura del simulador](README.md) › Decisiones y puntos de extensión

Una arquitectura se entiende mejor por sus **decisiones** (qué se eligió, frente a qué y por qué) que por su lista de
clases. Esta página las reúne y después explica qué habría que tocar para cada ampliación prevista.

## Decisiones de fondo

| # | Decisión | Alternativa descartada | Por qué |
| --- | --- | --- | --- |
| 1 | Simulación por **eventos discretos** | Paso fijo; flujos perezosos con fusión | Exacta al ns, sin pasos vacíos, y sigue valiendo con plataformas móviles ([6.2](02-simulacion-por-eventos-discretos.md)) |
| 2 | **Tiempo en ns enteros** (`std::chrono::nanoseconds`) | `double` en segundos | Las sumas de PRI son exactas; 1 ns ≈ 0,3 m basta incluso para TDOA |
| 3 | **El pulso es autocontenido** | El canal consulta el estado pasado del emisor | Vale para varios receptores y emisores móviles sin rehacer nada ([6.4](04-flujo-de-un-pulso.md)) |
| 4 | **El canal calcula la llegada; el receptor la mide** | El receptor reconstruye la geometría | Cada uno hace lo que le corresponde físicamente; con multitrayecto el canal dará varias llegadas |
| 5 | **Composición** de generadores | Una clase por combinación de PRI/RF/PW/scan | Las dimensiones son ortogonales; ampliar es añadir una clase ([6.3](03-modelo-de-dominio.md)) |
| 6 | **Scan = `ScanSpec` del modo + orientación de la misión** | Todo el scan en el catálogo, o todo en la misión | El catálogo describe el radar completo y la misión solo lo situacional |
| 7 | **El dominio no conoce JSON**; `Simulation` no carga ficheros | Clases que se cargan a sí mismas | Todo se prueba sin disco; cambiar de formato no toca el dominio ([6.5](05-configuracion-y-carga.md)) |
| 8 | **Salida = PDW + `GroundTruth`** separados | Un único registro mezclado | Deja claro qué puede usar un algoritmo (solo el PDW) y qué es para evaluarlo |
| 9 | **Determinismo** (orden total de eventos, sin aleatoriedad, formato fijo) | — | Permite el test golden y comparar versiones de un algoritmo de forma justa |
| 10 | **`sigint` frente a `sim`** | Todo en una librería | El procesado futuro reutiliza la física y la librería de emisores sin depender del simulador ([6.1](01-vision-general.md)) |

## Puntos de extensión

Para cada ampliación anotada en la spec (§1), qué cambia y qué no:

| Ampliación | Qué se toca | Qué no cambia |
| --- | --- | --- |
| **Nuevo tipo de PRI, RF, PW o scan** (jitter, cónico, raster…) | Una clase que implementa la interfaz + su rama `kind` en el loader | Emisor, canal, receptor, simulación |
| **Otro diagrama de antena** (sinc², tabulado) | Una implementación de `AntennaPattern` + loader | Canal (llama a `gainDbi` igual) |
| **Aleatoriedad** (jitter, agilidad aleatoria, ruido) | Semilla en el escenario; la fuente aleatoria vive en el **`Emitter`**, sembrada con la semilla y el id del emisor | Los generadores siguen sin estado aleatorio propio: si lo tuvieran, cada segmento repetiría el mismo jitter al reiniciarse |
| **Error en la medida del AoA** | `Receiver::measureAoa` (hoy devuelve su entrada) | Canal, PDW |
| **Plataformas móviles** | Firmas de `Emitter`, `Receiver` y `PropagationChannel`: la posición pasa a ser consultable en el tiempo; con receptor móvil, `propagate` resuelve `‖R(t_a) − P_e(t_e)‖ = c·(t_a − t_e)` | El pulso autocontenido y la cola de eventos |
| **Varios receptores** | La simulación llama al canal una vez por receptor; el PDW necesita un id de receptor | `EmittedPulse` |
| **Multitrayecto** | `propagate` devuelve una lista de llegadas, cada una con su dirección | Receptor (recibe llegadas como hoy) |
| **Desvío del haz en el sistema de la antena** | Cálculo del desvío en el canal | La interfaz de `AntennaPattern` |
| **Solape de pulsos, tiempo muerto, saturación** | El receptor pasa a tener estado entre pulsos; *flags* en el PDW | Canal, emisores |
| **Banda de RF del receptor, pérdidas del sistema** | Receptor (filtro por frecuencia) y canal o receptor (pérdidas) | Emisores |
| **Otro formato de salida** | Una implementación de `PulseRecordWriter` | Receptor, simulación |
| **Descriptor para reconocimiento** | Una clase nueva en `sigint` (rangos y tolerancias) que el loader construye desde el mismo JSON | `EmitterMode` (sigue siendo el modelo generativo) |

Fíjate en el patrón: casi todas las ampliaciones tocan **una** pieza, porque cada pieza tiene una sola
responsabilidad y las dependencias van en un solo sentido. Las que tocan varias firmas (plataformas móviles) están
identificadas y anotadas de antemano.

## Límites conocidos de la v1

Cosas que el diseño acepta a sabiendas, documentadas para que nadie se sorprenda:

- El desvío del haz se calcula como diferencia de azimut y elevación: solo es preciso cerca del horizonte.
- Una configuración válida puede ser inviable en recursos (PRI de 2 ns durante 10⁶ s). No se estima; si se agota la
  memoria, `main` sale con el código 4.
- Una clave JSON repetida en el mismo objeto no se detecta.
- En un cambio de segmento, el hueco entre dos pulsos puede ser menor que la PRI o incluso que la PW. No se valida.

## En este proyecto

- Decisiones de fondo: spec §3. Decisiones de implementación (1–11) y excepciones a las reglas de clase (E1–E10):
  plan, sección "Decisiones".
- Las dos rondas de revisión que dieron forma a estas decisiones: `docs/superpowers/reviews/`.

## Ideas clave

- Cada decisión resuelve un problema concreto frente a una alternativa explícita.
- Ampliar suele ser añadir una clase que implementa una interfaz existente.
- Los cambios de firma previsibles (plataformas móviles, multitrayecto) ya están anotados.

---

[← 6.6 Ejecución y salida](06-ejecucion-y-salida.md) · [↑ Arquitectura del simulador](README.md) · [Siguiente: 7. Ingeniería de software →](../07-ingenieria-de-software/README.md)

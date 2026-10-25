# 6. Arquitectura del simulador

> [Manual](../README.md) › Arquitectura del simulador

Los bloques anteriores explican la física y el análisis. Este bloque explica **cómo está construido el simulador**:
qué piezas tiene, cómo se reparten el trabajo, por qué se eligió cada estructura y por dónde se puede ampliar.

> **Estado.** El simulador está **diseñado** (spec y plan revisados), pero todavía no implementado: hoy solo existe
> `src/SigInt/PulseDescriptors/`. Estas páginas describen el diseño; cuando el código exista, la referencia será el
> código.

| Página | Qué aprenderás |
| --- | --- |
| [6.1 Visión general](01-vision-general.md) | Entradas y salidas, las dos librerías (`sigint` y `sim`), componentes y dependencias |
| [6.2 Simulación por eventos discretos](02-simulacion-por-eventos-discretos.md) | Por qué eventos y no un paso de tiempo fijo; cola de prioridad, desempate y determinismo |
| [6.3 Modelo de dominio](03-modelo-de-dominio.md) | Catálogo frente a misión, prototipo frente a instancia, composición de generadores |
| [6.4 Flujo de un pulso](04-flujo-de-un-pulso.md) | Del emisor al CSV paso a paso, con un ejemplo numérico completo |
| [6.5 Configuración y carga](05-configuracion-y-carga.md) | Ficheros JSON, loaders, validación y gestión de errores |
| [6.6 Ejecución y salida](06-ejecucion-y-salida.md) | El ejecutable `ews`, códigos de salida, formato del CSV y test golden |
| [6.7 Decisiones y puntos de extensión](07-decisiones-y-extensiones.md) | Las decisiones de fondo y qué hay que tocar para cada ampliación futura |

---

[← 5.5 Evaluación con verdad de terreno](../05-analisis-de-senal/05-evaluacion-con-verdad-de-terreno.md) · [↑ Manual](../README.md) · [Siguiente: 6.1 Visión general →](01-vision-general.md)

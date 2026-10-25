# 5. Análisis de señal

> [Manual](../README.md) › Análisis de señal

Un receptor ESM entrega un flujo de PDW: pulsos de todos los radares mezclados, uno detrás de otro. Este bloque
explica qué contiene un PDW y cómo se pasa de ese flujo a "hay un radar de vigilancia de tipo X al Noreste, girando
cada 6 segundos". Es el trabajo futuro que el simulador del proyecto permitirá desarrollar y evaluar.

| Página | Qué aprenderás |
| --- | --- |
| [5.1 El PDW](01-pdw.md) | Campos de un PDW, parámetros intrínsecos y extrínsecos |
| [5.2 Deinterleaving](02-deinterleaving.md) | Separar los pulsos por emisor: agrupación por parámetros, histogramas de diferencias de TOA |
| [5.3 Identificación de emisores](03-identificacion-de-emisores.md) | Librería de emisores, descriptor de emisor, comparación |
| [5.4 Análisis de scan](04-analisis-de-scan.md) | Tipo y periodo de barrido a partir de la amplitud |
| [5.5 Evaluación con verdad de terreno](05-evaluacion-con-verdad-de-terreno.md) | Cómo medir si un algoritmo acierta, usando las columnas `truth_` |

---

[← 4.3 Medida del ángulo de llegada](../04-guerra-electronica/03-medida-del-aoa.md) · [↑ Manual](../README.md) · [Siguiente: 5.1 El PDW →](01-pdw.md)

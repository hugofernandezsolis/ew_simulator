# Manual del proyecto EWS

Este manual reúne la teoría y el diseño de todo lo que aparece en el proyecto: ondas y radares, emisores y
receptores, propagación, guerra electrónica, análisis de señal, la arquitectura del simulador y la ingeniería de
software. Está pensado para leerse en orden: cada bloque se apoya en los anteriores. También sirve como consulta,
porque cada página termina con un apartado **En este proyecto** que dice dónde aparece ese concepto en el código, en
la configuración del build o en la spec del simulador.

## Estructura

| Bloque | Contenido | Estado |
| --- | --- | --- |
| [1. Fundamentos](01-fundamentos/README.md) | Ondas electromagnéticas, decibelios, coordenadas y ángulos | ✅ |
| [2. Radar](02-radar/README.md) | Principio del radar, forma de onda pulsada, PRI, RF y modulación intrapulso, antenas, barrido | ✅ |
| [3. Propagación](03-propagacion/README.md) | Espacio libre, retardo, horizonte radar, balance de enlace | ✅ |
| [4. Guerra electrónica](04-guerra-electronica/README.md) | Qué es la EW, receptores ESM, medida del ángulo de llegada | ✅ |
| [5. Análisis de señal](05-analisis-de-senal/README.md) | PDW, deinterleaving, identificación de emisores, análisis de scan, evaluación con verdad de terreno | ✅ |
| [6. Arquitectura del simulador](06-arquitectura/README.md) | Visión general, eventos discretos, modelo de dominio, flujo de un pulso, configuración, ejecución y salida, decisiones y extensiones | ✅ |
| [7. Ingeniería de software](07-ingenieria-de-software/README.md) | Estructura del repositorio, build con CMake, presets, reglas de clases, tests, calidad y CI | ✅ |

## Cómo leer las páginas

- Las fórmulas van en bloques de código con la notación que se usa en el código (`f`, `d`, `θ`…), y cada una se
  acompaña de un ejemplo numérico.
- Los números de ejemplo son órdenes de magnitud de la literatura general de radar y EW, **no** datos de ningún
  sistema real concreto.
- Las unidades siguen la convención del proyecto: SI internamente, y la unidad en el nombre cuando hay ambigüedad
  (`frequencyMHz`, `pulseWidthUs`).

## Documentos relacionados

- Spec del simulador: [`docs/superpowers/specs/2026-10-24-simulator-design.md`](../superpowers/specs/2026-10-24-simulator-design.md)
- Agrupación de atributos del PDW: [`docs/superpowers/specs/2026-10-23-pdw-attribute-grouping-design.md`](../superpowers/specs/2026-10-23-pdw-attribute-grouping-design.md)
- Plan de implementación del simulador: [`docs/superpowers/plans/2026-10-24-simulator.md`](../superpowers/plans/2026-10-24-simulator.md)

## Bibliografía general

Libros clásicos donde ampliar cualquiera de los temas:

- M. I. Skolnik, *Introduction to Radar Systems*. Referencia general de radar.
- R. G. Wiley, *ELINT: The Interception and Analysis of Radar Signals*. Análisis de señales radar interceptadas.
- D. Adamy, *EW 101: A First Course in Electronic Warfare*. Introducción muy didáctica a la guerra electrónica.
- D. C. Schleher, *Electronic Warfare in the Information Age*. Visión de conjunto de EW.

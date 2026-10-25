# 5.5 Evaluación con verdad de terreno

> [Manual](../README.md) › [Análisis de señal](README.md) › Evaluación con verdad de terreno

## Por qué simular

Con datos reales nunca se sabe con certeza qué emisor produjo cada pulso, así que es difícil medir si un
deinterleaver o un clasificador acierta. Un simulador resuelve el problema: como **genera** los pulsos, sabe la
respuesta correcta. Esa respuesta es la **verdad de terreno** (*ground truth*).

## Qué verdad guarda el proyecto

Cada fila del CSV tiene dos bloques (spec §6):

- **Medida (PDW)**: lo que vería un receptor real. Es la **única** entrada que pueden usar los algoritmos.
- **Verdad** (columnas `truth_`): la respuesta correcta. Solo sirve para **evaluar**.

| Columna | Para qué sirve al evaluar |
| --- | --- |
| `truth_emitterId` | ¿El deinterleaver agrupó bien este pulso? |
| `truth_modeId` | ¿El clasificador reconoció el modo correcto? |
| `truth_segmentIndex` | Distinguir dos tramos del mismo modo separados por un silencio u otro modo |
| `truth_emitterPulseIndex` | Los huecos en este índice delatan los pulsos que se emitieron pero no se detectaron |
| `truth_emissionNs` | Instante de emisión: permite calcular la PRI verdadera |
| `truth_distanceM` | Distancia real: evaluar la estimación de distancia por amplitud |
| `truth_azimuthDeg`, `truth_elevationDeg` | Dirección de llegada verdadera: evaluar el modelo de error del AoA |
| `truth_txGainDbi` | Ganancia del emisor hacia el receptor: ¿lóbulo principal o lateral? |
| `truth_eirpDbm` | EIRP hacia el receptor |

> Si un algoritmo lee una columna `truth_`, la evaluación no vale nada: estaría copiando la respuesta.

## Cómo medir un deinterleaver

El deinterleaver asigna a cada pulso una etiqueta de grupo (A, B, C…), y la verdad dice su emisor (E1, E2…). Se
construye una **matriz de confusión** grupo × emisor:

```
             E1     E2     E3
  Grupo A   120      0      2
  Grupo B     0     85      0
  Grupo C     0     40      0     ← E2 partido en dos grupos
```

Métricas habituales:

- **Pureza** de un grupo: fracción de sus pulsos que vienen del emisor mayoritario (A: 120/122 ≈ 98 %).
- **Completitud** de un emisor: fracción de sus pulsos que caen en su grupo principal (E2: 85/125 = 68 %).
- **Grupos partidos**: un emisor repartido en varios grupos (E2 en B y C). Es típico con agilidad de frecuencia o
  cambios de modo.
- **Grupos mezclados**: un grupo con pulsos de varios emisores.

## Cómo medir un clasificador

Para cada grupo, comparar el tipo y el modo identificados con `truth_emitterId`/`truth_modeId` (a través del tipo del
emisor en la misión): tasa de aciertos, de identificaciones ambiguas y de "desconocidos".

## Escenarios de prueba

Lo potente del simulador es poder **diseñar** escenarios que aíslen una dificultad cada vez:

- Dos emisores en la misma dirección con PRI distintas (prueba el análisis de TOA, no el AoA).
- Dos emisores a la misma frecuencia en direcciones distintas (prueba la agrupación por AoA).
- Un stagger y su suma de marco.
- Cambios de modo con un segmento `off` en medio.
- Ráfagas limpias frente a recepción continua por lóbulos laterales (cambiando la sensibilidad).

Y como la simulación es determinista, el mismo escenario da siempre el mismo CSV: las comparaciones entre versiones de
un algoritmo son justas.

## Golden file: otra cosa distinta

El proyecto tiene también un **test golden** (spec §7). No evalúa algoritmos de análisis, sino el **propio
simulador**: ejecuta una misión pequeña y compara su CSV byte a byte con una referencia guardada en git. Si un cambio
del código altera la salida, el test falla y el diff muestra qué ha cambiado.

## En este proyecto

- `sim::GroundTruth` (`Simulator/Receiver`) guarda la verdad de cada pulso, y `CsvPulseRecordWriter` la escribe junto
  al PDW.
- Hoy medida y verdad coinciden en AoA, frecuencia y ancho de pulso (modelo de error 0). Cuando haya ruido de medida,
  se añadirán `truth_frequencyMHz` y `truth_pulseWidthUs`.

## Ideas clave

- La verdad de terreno permite medir objetivamente si un algoritmo acierta.
- Los algoritmos solo pueden leer el PDW; las columnas `truth_` son para evaluar.
- Deinterleaver: matriz de confusión, pureza y completitud.
- El golden file prueba el simulador, no los algoritmos de análisis.

---

[← 5.4 Análisis de scan](04-analisis-de-scan.md) · [↑ Análisis de señal](README.md) · [Siguiente: 6. Arquitectura del simulador →](../06-arquitectura/README.md)

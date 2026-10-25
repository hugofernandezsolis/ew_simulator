# 6.6 Ejecución y salida

> [Manual](../README.md) › [Arquitectura del simulador](README.md) › Ejecución y salida

## El ejecutable `ews`

```
ews <mision.json> <salida.csv>
```

`main` hace cinco cosas, **en este orden**:

1. Comprueba los argumentos.
2. Carga la misión (`loadMission`), que carga también el catálogo y lo valida todo.
3. Abre el fichero de salida.
4. Ejecuta la misión (`runMission`).
5. Cierra el fichero y comprueba que la escritura no falló (disco lleno, error de E/S).

El orden de los pasos 2 y 3 es intencionado: si la configuración tiene errores, **no se crea el CSV**. Así nunca queda
un fichero vacío o a medias que alguien pueda confundir con un resultado.

### Códigos de salida

| Código | Significado | Qué imprime |
| --- | --- | --- |
| 0 | Éxito | — |
| 1 | `ConfigError` | Cada error en `stderr`, uno por línea, con fichero y ruta |
| 2 | Uso incorrecto | `uso: ews <mision.json> <salida.csv>` |
| 3 | No se puede abrir o escribir el fichero de salida | Mensaje |
| 4 | Cualquier otra excepción (red de seguridad; p. ej. memoria agotada) | `what()` |

Códigos distintos para causas distintas permiten que un script sepa qué ha pasado sin leer el texto.

## `runMission`

```
  runMission(Mission, std::ostream&)
     ├─ crea CsvPulseRecordWriter sobre el ostream    (escribe la cabecera)
     ├─ crea Simulation(mission, writer)
     └─ simulation.run()
```

Recibe un `std::ostream&` y no una ruta. En producción es un `std::ofstream`; en el test golden, un
`std::ostringstream`. El mismo código sirve para los dos sin tocar el disco en los tests.

### Quién posee qué

El escritor guarda un **puntero no poseído** al flujo, y el receptor otro al escritor. "No poseído" significa que no
lo destruyen ellos: quien los crea (`main`, `runMission`) debe declararlos **antes** que la simulación, para que vivan
más que ella. Si se usaran con el puntero nulo (objeto construido por defecto), lanzan `std::logic_error`.

## El CSV

Una fila por pulso **detectado**, en orden de llegada. 18 columnas en dos bloques:

| Bloque | Columnas |
| --- | --- |
| Medida (PDW) | `pulseId`, `toaNs`, `frequencyMHz`, `pulseWidthUs`, `amplitudeDbm`, `azimuthDeg`, `elevationDeg`, `intrapulseModulation` |
| Verdad | `truth_emitterId`, `truth_modeId`, `truth_segmentIndex`, `truth_emitterPulseIndex`, `truth_emissionNs`, `truth_distanceM`, `truth_azimuthDeg`, `truth_elevationDeg`, `truth_txGainDbi`, `truth_eirpDbm` |

Para qué sirve cada columna de verdad: [5.5](../05-analisis-de-senal/05-evaluacion-con-verdad-de-terreno.md).

### Formato reproducible

Para que dos ejecuciones den el mismo fichero **byte a byte**:

| Regla | Detalle |
| --- | --- |
| Precisión fija por columna | frecuencia `{:.6f}`, PW `{:.3f}`, potencias y ganancias `{:.2f}`, ángulos `{:.4f}`, distancia `{:.3f}`; enteros sin decimales |
| Separador decimal `.` siempre | `std::format` sin el especificador `L` (no depende del idioma del sistema) |
| Azimut que redondea a 360 | se escribe `0.0000` (el rango es [0, 360)) |
| Cero negativo | `-0.0000` o `-0.00` se escriben sin signo |
| Fin de línea | `\n` |

Ejemplo de fila: ver [6.4](04-flujo-de-un-pulso.md#paso-5--la-fila-del-csv).

### Otros formatos

`CsvPulseRecordWriter` implementa la interfaz `PulseRecordWriter`, que tiene un solo método:
`write(pdw, groundTruth)`. Un formato nuevo (binario, base de datos, red) es otra implementación de esa interfaz; el
receptor no cambia.

## El test golden

Un test de integración ejecuta una misión pequeña completa y compara su CSV, **byte a byte**, con un fichero de
referencia guardado en git (`src/Simulator/Runner/tests/data/expected/golden.csv`).

| | `A1` (`TestRadar_A`) | `B1` (`TestRadar_B`) |
| --- | --- | --- |
| Modo | `search`: stagger [1000, 1500] µs, 3000 MHz, scan circular de 0,05 s | `track`: PRI 700 µs, RF por lista [9000, 9100] MHz cada 3 pulsos, LFM, haz fijo |
| Posición | (0, 30 000, 30), d ≈ 30 km | (20 000, 0, 50), d ≈ 20 km |
| Calendario | un segmento de 0,1 s | `track` 40 ms, `off` 20 ms, `track` 40 ms, desde 2 ms |
| Qué se ve | Dos **ráfagas** de 9 pulsos, cuando el haz pasa por el receptor (25 ms y 75 ms) | Pulsos continuos a −47,56 / −47,65 dBm, con un hueco durante el `off` |

Receptor en (0, 0, 10) con sensibilidad −60 dBm; misión de 0,1 s; resultado esperado: **131 filas** (18 de A1, 113 de
B1). Los periodos están comprimidos a propósito para que el fichero sea corto.

Para qué sirve:

- Si un cambio del código altera la salida, el test falla y el `git diff` del CSV muestra exactamente qué cambió.
- Si el cambio era intencionado, se regenera la referencia y se revisa el diff antes de aceptarlo.
- Antes de aceptar la primera referencia, sus valores se comprueban a mano con las fórmulas de la spec.

La referencia vale para la toolchain de la CI: `atan2`, `log10` o `std::format` pueden diferir en el último bit entre
plataformas. Si falla por una última cifra, hay que investigarlo antes de regenerar a ciegas.

## En este proyecto

- `runMission` en `src/Simulator/Runner/`, `main` en `src/main.cpp`. Plan, tarea 17, con todos los datos de la misión
  golden y los valores esperados.
- Escenario de ejemplo para probar a mano: `scenarios/missions/demo_01.json`.

## Ideas clave

- Primero se valida y después se abre la salida: un error de configuración no deja CSV.
- Un código de salida distinto por cada tipo de fallo.
- `runMission` escribe en un `ostream`: el mismo código para fichero y para test.
- Formato fijo y reproducible ⇒ test golden byte a byte.

---

[← 6.5 Configuración y carga](05-configuracion-y-carga.md) · [↑ Arquitectura del simulador](README.md) · [Siguiente: 6.7 Decisiones y puntos de extensión →](07-decisiones-y-extensiones.md)

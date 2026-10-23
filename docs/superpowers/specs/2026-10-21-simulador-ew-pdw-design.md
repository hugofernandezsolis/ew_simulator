# Simulador EW a nivel PDW: diseño

Fecha: 2026-10-21

## 1. Objetivo

Construir un simulador de guerra electrónica en **C++** que genere pulsos de radar tal y como los mediría un receptor ESM (nivel PDW), para entrenar y evaluar un modelo que **clasifique el tipo de emisor**.

El proyecto es de aprendizaje: la persona que lo desarrolla escribe el código y parte de cero en radar/EW, con buen nivel de Python, NumPy y ML.

### Alcance de la versión 1

- Un único emisor estático por ejecución.
- Dos clases: **PRI fija** y **PRI con jitter**.
- Ciclo completo: simular → generar dataset → entrenar en Python → exportar a ONNX → ejecutar el modelo dentro del simulador en C++.

### Fuera de alcance (versiones posteriores)

- Varios emisores entremezclados y deinterleaving.
- Geometría, movimiento y propagación.
- Simulación a nivel IQ (modulación intra-pulso).
- Falsos pulsos (ruido que parece un pulso).
- Aprendizaje por refuerzo y EW activa.

### Criterio de éxito

Se completa el ciclo de extremo a extremo y el modelo iguala o supera la línea base trivial (ver sección 8), con una curva de precisión que baja de forma razonable al aumentar la dificultad (poco jitter, mucho ruido).

## 2. Decisiones de diseño

| Decisión | Elección | Motivo |
|---|---|---|
| Nivel de señal | PDW | Lo que entrega un ESM real tras el procesado inicial. Ligero y suficiente para identificar emisores por su comportamiento temporal. IQ podrá añadirse después. |
| Lenguaje del simulador | C++ | Preferencia del autor y rendimiento. |
| Integración del modelo | Todo en C++ (ONNX Runtime) | Preferencia del autor. El entrenamiento sigue en Python. |
| Avance del tiempo | Pasos de reloj fijos, `dt` configurable (por defecto 0,1 µs) | Intuitivo. A esta escala el coste es asumible. Si crece el número de emisores, se puede migrar a eventos discretos. |

### Consecuencias del paso fijo

- El TOA queda cuantizado a múltiplos de `dt`. Esto imita la resolución finita del reloj de un receptor real.
- El coste crece con `duración / dt`, no con el número de pulsos.
- El jitter de PRI debe ser claramente mayor que `dt` para ser visible.
- El orden de operaciones dentro de cada paso se fija: avanzar emisores, pasar lo emitido al receptor, registrar los PDW.

## 3. Componentes

- **Escenario (config):** `dt`, duración, semilla aleatoria, emisor y sus parámetros, parámetros del receptor.
- **Emisor:** en cada paso responde si emite. Si emite, genera un pulso real. Comportamientos: PRI fija y PRI con jitter.
- **Receptor (ESM):** convierte pulsos reales en PDW imperfectos (ruido de medida, pulsos perdidos).
- **Simulador:** bucle de pasos que orquesta emisor, receptor y acumulación de PDW.
- **Extractor de características:** convierte una ventana de PDW en la entrada del modelo. Se implementa una sola vez y lo usan ambos modos.
- **Escritor de dataset:** guarda ventanas de características con su etiqueta.
- **Clasificador:** envoltorio de ONNX Runtime que carga el modelo y clasifica ventanas.

### Modos de ejecución (mismo núcleo)

1. `generar`: escenario → simulador → dataset en disco.
2. `evaluar`: escenario → simulador → clasificador → predicción comparada con la etiqueta real.

## 4. Formato de datos

### PDW

| Campo | Representación | Notas |
|---|---|---|
| TOA | entero de 64 bits, en ticks de `dt` | Evita pérdida de precisión con decimales |
| RF | `float32`, MHz | |
| PW | `float32`, µs | |
| Amplitud | `float32`, dB | |
| AOA | `float32`, grados | Casi constante con un emisor estático, se incluye para no rediseñar |

### Ventana y etiqueta

- La unidad de aprendizaje es una **ventana de `N` PDW consecutivos** (por ejemplo 64 o 128) con una única etiqueta de clase.
- Cada ejecución del simulador usa un solo tipo de radar y produce muchas ventanas.

### Características para el modelo

- **ΔTOA** (diferencia de TOA entre pulsos consecutivos, en µs), RF, PW, amplitud y AOA.
- **No se usa el TOA absoluto**: no informa del tipo de radar y fomenta la memorización. El primer pulso de cada ventana solo sirve para calcular el primer ΔTOA.
- Normalización con media y desviación guardadas junto al modelo exportado.

### Un único punto de verdad

El cálculo de características existe una sola vez en C++. `generar` escribe el dataset con las características ya calculadas y `evaluar` usa el mismo código, lo que elimina la discrepancia entre entrenamiento e inferencia.

### Formato en disco

`.npy`, que es fácil de escribir desde C++ y se carga con `np.load` en Python:
- Características: `[ventanas, N, F]`.
- Etiquetas: `[ventanas]`.
- Metadatos: `dt`, semilla y constantes de normalización.

## 5. Emisores

Ambos emisores guardan el instante del siguiente pulso. Cuando el reloj lo alcanza, emiten y calculan el siguiente.

- **PRI fija:** siguiente pulso a `PRI` después del anterior, redondeado al tick más próximo.
- **PRI con jitter:** intervalo `PRI × (1 + ε)`, con `ε` aleatorio (gaussiano) de desviación `j%`. Cada intervalo es independiente.

RF, PW, amplitud y AOA son constantes durante la ejecución.

### Aleatorización entre ejecuciones

Cada ejecución sortea PRI nominal, RF, PW, amplitud, AOA y, en la clase jitter, el porcentaje `j`.

**Regla de oro:** los rangos de los parámetros que no definen la clase (PRI nominal, RF, PW…) deben ser **idénticos para las dos clases**. Si no, el modelo clasificaría por el valor de la PRI y no por su regularidad.

## 6. Receptor

Convierte el pulso real en un PDW imperfecto:

- **Error de medida:** ruido gaussiano en TOA (decenas de ns, luego cuantizado al tick), RF, PW, amplitud y AOA.
- **Pulsos perdidos:** con probabilidad `p_miss` (por ejemplo 0 a 10 %) el pulso no se detecta, y algunos ΔTOA pasan a ser múltiplos de la PRI.

### Dificultad ajustable

El jitter varía desde casi nulo (0,5 %) hasta alto (10 %). Con poco jitter y mucho ruido de TOA, las clases se parecen y se obtiene una curva de precisión frente a dificultad.

## 7. Clasificador y errores

### Clasificador

- El modelo `.onnx` se carga una vez al arrancar.
- Cada ventana se normaliza con las constantes guardadas, se convierte en un tensor `[1, N, F]` de `float32` y el modelo devuelve una puntuación por clase. La predicción es la clase con la puntuación más alta.
- Al cargar se comprueba que el modelo espera el mismo `N` y `F` que produce el simulador.

### Manejo de errores

Se falla pronto y con mensaje claro, sin parches silenciosos:

- **Configuración inválida:** `dt ≤ 0`, PW mayor que la PRI, o PRI de pocos ticks (el pulso no se resolvería). Se rechaza al leer el escenario.
- **Fallos de E/S:** no se puede escribir el dataset o leer el modelo. Se informa del fichero y el motivo.
- **Desajuste modelo-datos:** `N` o `F` no coinciden.

## 8. Pruebas

1. **Emisor PRI fija:** sin receptor ruidoso, todos los ΔTOA son exactamente la PRI en ticks.
2. **Emisor con jitter:** la media de intervalos se acerca a la PRI y su desviación al `j%` configurado (tolerancia estadística).
3. **Receptor:** sin ruido ni pérdidas, los PDW coinciden con los pulsos reales. Con ruido, la desviación medida se parece a la configurada. Con `p_miss`, la fracción de pulsos perdidos se acerca a ese valor.
4. **Cuantización:** todo TOA es múltiplo entero de `dt`.
5. **Reproducibilidad:** misma semilla, mismo dataset, byte a byte.
6. **Formato:** Python carga el `.npy` con las formas esperadas.
7. **Paridad ONNX:** para una misma ventana, las salidas de PyTorch y de ONNX Runtime en C++ coinciden dentro de una tolerancia pequeña.
8. **Línea base trivial:** un clasificador sencillo basado en la desviación de los ΔTOA marca un suelo de precisión. El modelo debe igualarlo o superarlo.

Las tolerancias de las pruebas estadísticas (2 y 3) se eligen para que no fallen por azar con ciertas semillas.

## 9. Riesgos conocidos

- **Fuga de información entre clases** por rangos de parámetros distintos (mitigado con la regla de oro de la sección 5).
- **Discrepancia entrenamiento/inferencia** (mitigada con el extractor de características único).
- **Coste de `dt` pequeño** si aumenta el número de emisores (migrar a eventos discretos).
- **Complejidad de la construcción en C++** (CMake y dependencias: ONNX Runtime). Se abordará paso a paso en el plan.

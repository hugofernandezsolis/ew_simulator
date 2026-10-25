# Agrupación de atributos del PDW: diseño

Fecha: 2026-10-23

## 1. Objetivo

Separar los atributos de `sigint::PulseDescriptorWords` (`src/SigInt/Pulse/include/PulseDescriptorWords.h`) en grupos con
significado propio y decidir cuáles merecen convertirse en una clase independiente. Este documento recoge el criterio
seguido, la agrupación propuesta y el diseño de la primera clase extraída: `AngleOfArrival`.

## 2. Criterio: ¿el grupo tiene vida propia?

Un conjunto de atributos merece una clase cuando cumple al menos una de estas condiciones:

1. **Tiene invariantes**: reglas que relacionan sus campos o limitan sus valores (p. ej. azimut en [0, 360)).
2. **Tiene operaciones propias**: cálculos que solo usan esos campos.
3. **Se reutiliza en otro contexto**: aparece igual en otra entidad del sistema.
4. **Cambia por la misma razón**: si se modifica uno de los campos, probablemente haya que tocar los demás.

Si un grupo no cumple ninguna, convertirlo en clase solo añade indirección (`pdw.x().y()`) sin aportar nada.

### Eje conceptual del dominio (ELINT)

- **Parámetros intrínsecos del emisor**: describen lo que el radar transmite y no dependen de la posición del receptor.
  Son los que identifican al emisor y formarán parte del futuro *emitter descriptor*.
- **Parámetros extrínsecos o de la medida**: dependen de la geometría, la propagación o el propio receptor.

## 3. Agrupación propuesta

| Grupo                       | Atributos                                                               | Justificación                                                                                                                                                     |
| --------------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Forma de onda (`Waveform`)  | `frequency_`, `pulseWidth_`, `intrapulseModulation_`, `modulationParameter_` | Intrínsecos al emisor; se reutilizarán en `EmitterDescriptor` (criterio 3) y el deinterleaver compara pulsos con ellos (criterio 2).                          |
| Modulación intrapulso       | `intrapulseModulation_`, `modulationParameter_`                         | Invariante fuerte: el significado de `modulationParameter_` depende del tipo (ancho de banda en LFM, nº de chips en Barker, nada en `None`).                       |
| Ángulo de llegada (`AngleOfArrival`) | `aoaAzimuth_`, `aoaElevation_`                                 | Invariantes de rango (criterio 1), operaciones propias como la diferencia angular (criterio 2) y reutilizable en tracks o localización (criterio 3).               |
| Calidad de recepción        | `amplitude_`, `snr_`, `flags_`                                          | Describe la calidad de la medida, no al emisor. Grupo débil: `amplitude_` también sirve para el análisis de scan de antena.                                       |
| Metadatos del registro      | `pulseId_`, `toa_`, `channelId_`                                        | Identidad del PDW: quién lo captó, cuándo y en qué orden.                                                                                                         |

### Decisiones tomadas

- **`polarization_` queda suelta en el PDW.** No forma parte de `Waveform`, que se limita a lo temporal/espectral.
- **`toa_` queda en el PDW**, sin agrupar: sus diferencias entre pulsos son la base de la PRI.
- **Metadatos y calidad no se convierten en clases**: no tienen invariantes ni operaciones que lo justifiquen.

### Orden de extracción

1. `AngleOfArrival`: pequeña, con reglas de rango claras; sirve para practicar el patrón.
2. Modulación intrapulso (tipo + parámetro): la invariante más fuerte.
3. `Waveform`: cuando exista `EmitterDescriptor` y se confirme la reutilización.

## 4. Diseño de `AngleOfArrival`

### Decisiones

- **La elevación se mide siempre**: `float` normal, sin `std::optional` ni valores centinela.
- **Valores fuera de rango se normalizan**, no se rechazan ni lanzan excepción.
- **La elevación se pliega sobre el polo** (no se recorta). Normalizar significa conservar la misma dirección física y
  cambiar solo su representación; recortar cambiaría el dato.

### Invariantes

- Azimut en **[0, 360)** grados.
- Elevación en **[-90, 90]** grados.

### Normalización

Plegar la elevación modifica el azimut, por lo que **el orden es obligatorio**:

1. Plegar la elevación:
   - Si `el > 90`: `el = 180 - el` y `az += 180`.
   - Si `el < -90`: `el = -180 - el` y `az += 180`.
   - Una elevación muy grande (p. ej. 300°) no se resuelve con un solo pliegue: hay que reducirla antes a un rango
     acotado.
2. Normalizar el azimut a [0, 360).

Trampas conocidas al normalizar con `float`:

- `std::fmod(-10.0f, 360.0f)` devuelve **-10**, no 350: el resultado conserva el signo del dividendo y hay que
  corregir los negativos.
- `-0.0000001f + 360.0f` se redondea **exactamente a 360.0f**, que queda fuera de [0, 360): hace falta una comprobación
  final.

### Interfaz

- Constructor `(azimut, elevación)` que normaliza; constructor por defecto que deja (0°, 0°).
- Getters `const` para azimut y elevación.
- Setters que **reciben el valor nuevo y normalizan**.
- `operator==` y `operator!=`.
- La lógica de normalización en **un único método privado**, usado por el constructor y los setters.

**No** se ofrecen setters que devuelvan una referencia no constante (como `bool& set_dummy(void)` en la plantilla de
clase): permitirían escribir el atributo sin pasar por la normalización y romperían la invariante.

### Ubicación

En el componente `Pulse`, siguiendo su estructura:

- `src/SigInt/Pulse/include/AngleOfArrival.h`
- `src/SigInt/Pulse/src/AngleOfArrival.cpp`
- `src/SigInt/Pulse/tests/ut_AngleOfArrival.cpp`

### Integración en el PDW

`aoaAzimuth_` y `aoaElevation_` se sustituyen por un único `AngleOfArrival aoa_{}`. El tamaño (8 bytes) y el
alineamiento (4) se mantienen, así que el orden de atributos por tamaño sigue siendo válido.

## 5. Casos de prueba

| Entrada (az, el)   | Esperado (az, el) | Qué comprueba                        |
| ------------------ | ----------------- | ------------------------------------ |
| (370, 0)           | (10, 0)           | Vuelta por arriba                    |
| (-10, 0)           | (350, 0)          | Negativos (trampa de `fmod`)         |
| (360, 0)           | (0, 0)            | El límite superior queda excluido    |
| (-0.0000001, 0)    | (0, 0), no 360    | Redondeo                             |
| (10, 100)          | (190, 80)         | Pliegue por el polo norte            |
| (0, -100)          | (180, -80)        | Pliegue por el polo sur              |
| (10, 90)           | (10, 90)          | El polo es válido y no se pliega     |

## 6. Preguntas abiertas

- `operator==`: ¿comparación exacta o con tolerancia? ¿Qué debe dar `AngleOfArrival(0, 0) == AngleOfArrival(360, 0)`?
- ¿Cómo reducir una elevación arbitrariamente grande (p. ej. 300°) antes de plegarla?
- Más adelante: representar la modulación intrapulso con `std::variant` (un tipo por modulación) en lugar de enum +
  `float`.

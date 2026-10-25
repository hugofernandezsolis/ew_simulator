# 2.3 Modulación de la PRI

> [Manual](../README.md) › [Radar](README.md) › Modulación de la PRI

Muchos radares no repiten siempre la misma PRI: la varían siguiendo un patrón. El patrón de la PRI es uno de los
rasgos más característicos de un radar y la principal pista para separar los pulsos de cada emisor.

## Los tipos

### PRI fija (constante)

```
| PRI | PRI | PRI | PRI |
 1000  1000  1000  1000 µs
```

La más simple. Fácil de reconocer: las diferencias de TOA entre pulsos consecutivos son siempre iguales.

### Jitter

La PRI varía **aleatoriamente** alrededor de un valor medio (por ejemplo ±5 %). Dificulta que un adversario prediga
el siguiente pulso, lo que complica ciertas técnicas de perturbación. Para el análisis aparece como una nube de
diferencias de TOA en lugar de un valor exacto.

### Stagger (escalonado)

La PRI recorre **cíclicamente una lista corta** de valores:

```
1000, 1200, 1100, 1000, 1200, 1100, …   µs
```

- **Número de posiciones** del stagger: cuántos valores tiene la lista (aquí, 3).
- **Periodo del marco**: la suma de la lista (aquí, 3300 µs). Al cabo de un marco el patrón se repite.

Motivo clásico: en los radares con MTI (que eliminan los ecos fijos del suelo) una PRI fija produce **velocidades
ciegas**, blancos que se mueven justo a la velocidad que los hace parecer fijos. Variar la PRI desplaza esas
velocidades ciegas.

### Sliding (deslizante)

La PRI **crece (o decrece) en pasos** entre un mínimo y un máximo y vuelve a empezar, formando un diente de sierra:

```
100, 110, 120, 130, 100, 110, …   µs
```

Se usa en algunos modos de búsqueda para variar el alcance no ambiguo de forma continua. También existen el perfil
decreciente y el triangular (sube y baja).

### Dwell & switch (permanencia y cambio)

El radar mantiene una PRI durante un **bloque de pulsos** (un *dwell*, o CPI) y luego cambia a otra:

```
1000 ×3, 2000 ×3, 1000 ×3, …   µs
```

Es típico de los radares de PRF media: cada PRF da distancias y velocidades ambiguas, y combinando las medidas de
varias PRF se resuelve la ambigüedad.

## Cómo se ven en el análisis

| Tipo | Huella en las diferencias de TOA |
| --- | --- |
| Fija | Un único valor que se repite |
| Jitter | Valores dispersos alrededor de una media |
| Stagger | Varios valores que se repiten en el mismo orden; la suma del marco aparece como diferencia de orden superior |
| Sliding | Valores que crecen regularmente y vuelven al principio |
| Dwell & switch | Bloques de valores constantes que cambian |

Ver [5.2 Deinterleaving](../05-analisis-de-senal/02-deinterleaving.md) para cómo se usan estas huellas.

## En este proyecto

| Tipo | Clase (`SigInt/Emission`) | JSON (`pri.kind`) | Claves |
| --- | --- | --- | --- |
| Fija | `FixedPri` | `fixed` | `valueUs` |
| Stagger | `StaggerPri` | `stagger` | `valuesUs` |
| Sliding | `SlidingPri` | `sliding` | `minUs`, `maxUs`, `stepUs` (solo creciente; si el paso no divide el rango, no se supera el máximo) |
| Dwell & switch | `DwellSwitchPri` | `dwellSwitch` | `valuesUs`, `pulsesPerDwell` (los mismos pulsos para cada valor) |
| Jitter | — | — | Fuera de alcance (la v1 es determinista) |

Detalles del diseño:

- Todas implementan la interfaz `PriGenerator`, con `next()` (devuelve la siguiente PRI y avanza el estado) y
  `clone()` (copia con el mismo estado).
- **Cada segmento del calendario empieza con el estado a cero**: al entrar en un segmento, el emisor clona el
  generador del prototipo del modo, así que un stagger vuelve a empezar por su primer valor.
- Cuando llegue el jitter, la fuente aleatoria **no** irá dentro del generador: si fuera así, al clonarlo cada
  segmento repetiría exactamente el mismo jitter, una periodicidad artificial que un analizador podría detectar.

## Ideas clave

- Fija, jitter, stagger, sliding y dwell & switch son los patrones básicos.
- El patrón de PRI es una de las huellas más útiles para separar e identificar emisores.
- En el proyecto, cada tipo es una clase que implementa `PriGenerator`.

---

[← 2.2 Forma de onda pulsada](02-forma-de-onda-pulsada.md) · [↑ Radar](README.md) · [Siguiente: 2.4 Frecuencia y modulación intrapulso →](04-rf-y-modulacion-intrapulso.md)

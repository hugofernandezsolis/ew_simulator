# 2.4 Frecuencia y modulación intrapulso

> [Manual](../README.md) › [Radar](README.md) › Frecuencia y modulación intrapulso

## La frecuencia portadora (RF)

Cada pulso es un trozo de onda a una frecuencia concreta, la **frecuencia portadora** o RF. Igual que con la PRI, un
radar puede mantenerla fija o variarla.

| Tipo | Comportamiento | Para qué |
| --- | --- | --- |
| **Fija** | Siempre la misma frecuencia | Lo más sencillo y común |
| **Saltos por lista** | Recorre una lista de frecuencias en orden | Evitar interferencias, dificultar la perturbación |
| **Agilidad aleatoria** | Cambia de frecuencia al azar, pulso a pulso o por bloques | Protección electrónica: el perturbador no sabe dónde estará el siguiente pulso |
| **Diversidad** | Emite varias frecuencias a la vez o muy seguidas | Mejorar la detección |

Cuando un radar cambia a la vez la PRI y la RF por bloques, ambos cambios suelen ir sincronizados (un bloque = un
CPI, *coherent processing interval*).

## Modulación intrapulso (MOP)

Hasta aquí, cada pulso era un trozo de onda a frecuencia constante. Muchos radares **modulan el interior del pulso**
(MOP, *Modulation On Pulse*). Lo hacen para resolver un conflicto de la [forma de onda pulsada](02-forma-de-onda-pulsada.md):

- Para **alcance**, el pulso tiene que ser largo (más energía).
- Para **resolución**, el pulso tiene que ser corto.

### Compresión de pulsos

La solución es emitir un pulso **largo pero modulado** y, al recibir el eco, pasarlo por un filtro adaptado que lo
"comprime" en un pulso corto. La resolución pasa a depender del ancho de banda `B` de la modulación, no de la
duración del pulso:

```
ΔR = c / (2·B)
Relación de compresión = B · PW
```

Ejemplo: pulso de 10 µs con 10 MHz de ancho de banda → resolución de 15 m (la de un pulso simple de 0,1 µs) y
relación de compresión 100 (20 dB).

### Tipos de modulación

| Tipo | Nombre | Cómo funciona |
| --- | --- | --- |
| **None** | Sin modulación | Frecuencia y fase constantes durante el pulso |
| **LFM** | *Linear Frequency Modulation*, "chirp" | La frecuencia sube (o baja) linealmente a lo largo del pulso |
| **NLFM** | FM no lineal | La frecuencia varía de forma no lineal, para reducir los lóbulos laterales tras la compresión |
| **BPSK** | *Binary Phase Shift Keying* | El pulso se divide en "chips" y la fase salta entre 0° y 180° según un código |
| **Barker** | Código de Barker | Un BPSK con unos códigos concretos de lóbulos laterales mínimos (el de 13 chips deja los lóbulos a −22,3 dB) |
| **FSK** | *Frequency Shift Keying* | El pulso se divide en tramos de frecuencias distintas |

### Por qué interesa en guerra electrónica

La MOP es un rasgo **intrínseco** del radar: no depende de dónde esté ni de hacia dónde apunte. Saber que un pulso es
LFM con 10 MHz de barrido ayuda mucho a identificar el emisor. Para que sea realmente útil hace falta conocer también
su **parámetro** (ancho de banda del chirp, número de chips…), no solo su tipo.

## En este proyecto

- **RF**: generadores `FixedRf` (`rf.kind = fixed`, clave `frequencyMHz`) y `ListRf` (`rf.kind = list`, claves
  `frequenciesMHz` y `pulsesPerHop`: cada frecuencia se repite ese número de pulsos antes de pasar a la siguiente).
- Para sincronizar el salto de RF con el cambio de PRI de un dwell & switch basta con poner
  `pulsesPerHop` = `pulsesPerDwell`.
- La agilidad aleatoria está fuera de alcance (la v1 es determinista).
- **MOP**: enum `IntrapulseModulation` (`SigInt/PulseDescriptors`) con seis valores (`None`, `LFM`, `NLFM`, `BPSK`,
  `Barker`, `FSK`). Es un dato **descriptivo**: se copia del modo al pulso y del pulso al PDW, sin efecto físico. El
  parámetro de la modulación está aplazado (spec §3, decisión 3).

## Ideas clave

- La RF puede ser fija, por lista o ágil.
- La MOP permite pulsos largos (alcance) con buena resolución (compresión).
- La MOP es un rasgo intrínseco muy útil para identificar emisores.

---

[← 2.3 Modulación de la PRI](03-modulacion-de-pri.md) · [↑ Radar](README.md) · [Siguiente: 2.5 Antenas →](05-antenas.md)

# 6.4 Flujo de un pulso

> [Manual](../README.md) › [Arquitectura del simulador](README.md) › Flujo de un pulso

Esta página sigue a **un** pulso desde que el emisor lo calcula hasta que aparece como fila del CSV.

## La tubería

```
  Emitter ──EmittedPulse──▶ PropagationChannel ──IncidentPulse──▶ Receiver ──PDW + GroundTruth──▶ PulseRecordWriter
  "lo que sale"             "lo que llega"                        "lo que se mide"                 "lo que se escribe"
```

Cada flecha es un objeto que **lleva todo lo necesario** para el paso siguiente. Nadie tiene que ir a preguntar al
paso anterior.

| Objeto | Señal | Verdad o contabilidad |
| --- | --- | --- |
| `EmittedPulse` | t_e, f, PW, potencia de pico, modulación, dirección del haz | id de emisor y modo, índice de segmento, índice de pulso, posición del emisor, antena |
| `IncidentPulse` | el `EmittedPulse`, t_a, dirección de llegada, potencia isotrópica | distancia, G_tx hacia el receptor |
| `PulseDescriptorWords` | `pulseId`, TOA, f, PW, amplitud, AoA, modulación | — |
| `GroundTruth` | — | emisor, modo, segmento, índice, t_e, distancia, dirección verdadera, G_tx, EIRP |

`EmittedPulse` e `IncidentPulse` mezclan señal y verdad: son objetos internos del simulador. Los algoritmos de
procesado solo deben consumir el PDW.

## Ejemplo de referencia

El de la spec, §4. Todos los números de esta página salen de él:

| Dato | Valor |
| --- | --- |
| Emisor `E1`, modo `search` | posición (15000, 20000, 30) m, f = 3 GHz, P_tx = 90 dBm, PW = 1 µs |
| Antena del emisor | G_max = 30 dBi, SLL = 38 dB (suelo de lóbulos: −8 dBi) |
| Receptor | posición (0, 0, 10) m, G_rx = 0 dBi, sensibilidad −70 dBm |

## Paso 0 — Arranque

`main` carga la misión (y con ella el catálogo), abre el CSV y llama a `runMission`. Al empezar `run()`, la simulación
pide a cada emisor su **primer** pulso y programa un evento Emit para cada uno.

## Paso 1 — El emisor calcula el pulso

`Emitter::next()` devuelve el siguiente pulso (o nada si ha terminado). Para rellenarlo:

| Campo | De dónde sale |
| --- | --- |
| t_e | estado del emisor (`nextEmissionNs_`) |
| f, PW | `rf_->next…()`, `pw_->next()` (las instancias del emisor, no los prototipos) |
| P_tx, modulación | el `EmitterMode` del segmento |
| dirección del haz | `ScanPattern` del segmento evaluado en `t_e − inicio del segmento` |
| posición, antena | el emisor y su modo |

Después calcula el instante del siguiente pulso: `t_e + pri_->next()`.

### Reglas del calendario

El calendario de un emisor es una lista de **segmentos** encadenados desde `startS`.

- El segmento k ocupa el intervalo **semiabierto** `[inicio_k, fin_k)`: un pulso que cae justo en `fin_k` ya es del
  segmento siguiente.
- El primer pulso de un segmento sale **exactamente** en su inicio.
- Si el siguiente instante cae en `≥ fin_k`, se pasa al segmento siguiente. Por eso, en un cambio de segmento el hueco
  entre pulsos puede ser menor que la PRI.
- **Cada segmento empieza con el estado a cero** (se clonan los generadores del prototipo, ver
  [6.3](03-modelo-de-dominio.md)).
- Los segmentos `off` no emiten. Al acabar el último segmento, el emisor calla: el calendario no se repite.
- Nunca se emite en `t ≥ durationS`.

Ejemplo (test `NextSkipsOffSegment` del plan): inicio 5 ms, PRI fija de 1 ms, calendario
[modo 2,5 ms, `off` 2 ms, modo 2 ms]:

```
  segmento 0 (modo) [5; 7,5)    ●───●───●            pulsos en 5, 6, 7       (8 ≥ 7,5 → cambio)
  segmento 1 (off)  [7,5; 9,5)            · · ·      ninguno
  segmento 2 (modo) [9,5; 11,5)                ●───● pulsos en 9,5 y 10,5    (11,5 ≥ fin → terminado)
```

## Paso 2 — El evento Emit

Al ejecutarse el Emit en t_e, la simulación:

1. Pasa el pulso al canal: `propagate(pulse, posición del receptor)` → `IncidentPulse`.
2. Programa un **Arrival** con ese `IncidentPulse` en su t_a.
3. Pide al emisor su siguiente pulso y, si existe, programa otro **Emit**.

## Paso 3 — El canal de propagación

`PropagationChannel::propagate` es una función pura: misma entrada, misma salida, sin estado.

| # | Cálculo | Fórmula | Ejemplo |
| --- | --- | --- | --- |
| 1 | Geometría emisor → receptor | Δ = receptor − emisor, d = \|Δ\| | d = 25 000,008 m; az_ER ≈ 216,87° |
| 2 | Dirección de llegada | receptor → emisor | az ≈ 36,87°, el ≈ 0,046° |
| 3 | Retardo | `d / c`, redondeado al ns | 83 391 ns ⇒ t_a = t_e + 83 391 ns |
| 4 | Desvío respecto al haz | `Δaz = wrap(az_ER − az_haz)`, `Δel = el_ER − el_haz` | haz apuntando al receptor: Δ ≈ 0 |
| 5 | Ganancia del emisor | `max(G − 12·[(Δaz/θ_az)² + (Δel/θ_el)²], G − SLL)` | 30 dBi (lóbulo principal) o −8 dBi (suelo) |
| 6 | Pérdida en espacio libre | `20·log10(d) + 20·log10(f) − 147,55` | 129,95 dB |
| 7 | Potencia isotrópica | `P_iso = P_tx + G_tx − FSPL` | −9,95 dBm (principal) / −47,95 dBm (suelo) |

La teoría de cada fila: geometría en [1.3](../01-fundamentos/03-coordenadas-y-angulos.md), ganancia en
[2.5](../02-radar/05-antenas.md), FSPL en [3.1](../03-propagacion/01-espacio-libre.md) y balance completo en
[3.3](../03-propagacion/03-balance-de-enlace.md).

El canal **calcula la llegada**, pero no sabe nada del receptor salvo su posición: ni su antena ni su sensibilidad.

## Paso 4 — El evento Arrival y el receptor

Al llegar t_a, el receptor (`Receiver::receive`):

1. Suma su ganancia: `P_rx = P_iso + G_rx` = −9,95 dBm. Es la **amplitud** del PDW.
2. Compara con la sensibilidad: se detecta si `P_rx ≥ −70 dBm`. Si no, el pulso se descarta y **no** consume
   `pulseId`.
3. Mide el AoA aplicando su modelo de error a la dirección de llegada. Hoy el modelo es la identidad: AoA medido =
   dirección verdadera.
4. Construye el PDW y el `GroundTruth`, se los da al escritor y avanza `pulseId`.

En el ejemplo se detecta tanto en el lóbulo principal (−9,95 dBm) como en el suelo de lóbulos laterales
(−47,95 dBm): con −70 dBm de sensibilidad este receptor oye **todos** los pulsos. Para ver ráfagas limpias habría que
subir la sensibilidad por encima de −48 dBm ([3.3](../03-propagacion/03-balance-de-enlace.md)).

## Paso 5 — La fila del CSV

Si el pulso del ejemplo fuera el octavo detectado (`pulseId` 7), el cuarto que emite `E1` (índice 3) y se hubiera
emitido en t_e = 0, la fila sería:

```
pulseId,toaNs,frequencyMHz,pulseWidthUs,amplitudeDbm,azimuthDeg,elevationDeg,intrapulseModulation,truth_emitterId,truth_modeId,truth_segmentIndex,truth_emitterPulseIndex,truth_emissionNs,truth_distanceM,truth_azimuthDeg,truth_elevationDeg,truth_txGainDbi,truth_eirpDbm
7,83391,3000.000000,1.000,-9.95,36.8700,0.0500,None,E1,search,0,3,0,25000.008,36.8700,0.0500,30.00,120.00
```

Es la fila del test `WriteFormatsRow` del plan (tarea 11). Ese test redondea la elevación a 0,05° para que la fila sea
más fácil de leer; el valor geométrico exacto es 0,046°.

## Por qué el pulso es autocontenido

El `EmittedPulse` lleva la posición del emisor y la dirección del haz **en el instante de emisión**. El canal no tiene
que preguntar al emisor "¿dónde estabas y hacia dónde mirabas hace 83 µs?". Esto mantiene el diseño válido cuando
lleguen las ampliaciones:

- **Varios receptores**: el canal se llama una vez por receptor con el mismo pulso.
- **Emisores móviles**: el pulso salió de esa posición y en esa dirección, aunque el emisor ya se haya movido.

## En este proyecto

- Flujo completo: spec §4. Clases: `Emitter` (tarea 9), `PropagationChannel` (10), `GroundTruth` y escritor (11),
  `Receiver` (12), `Simulation` (14).
- La acción Emit captura `[this, index, pulse]` y la Arrival `[this, incident]`, por valor (ver
  [6.2](02-simulacion-por-eventos-discretos.md)).

## Ideas clave

- Emisor → canal → receptor → escritor, cada uno con un objeto autocontenido.
- El canal calcula la llegada (instante, dirección, potencia isotrópica); el receptor la mide.
- Calendario con intervalos semiabiertos y estado a cero en cada segmento.
- Solo los pulsos detectados consumen `pulseId`; los huecos en `truth_emitterPulseIndex` delatan los perdidos.

---

[← 6.3 Modelo de dominio](03-modelo-de-dominio.md) · [↑ Arquitectura del simulador](README.md) · [Siguiente: 6.5 Configuración y carga →](05-configuracion-y-carga.md)

# 5.2 Deinterleaving

> [Manual](../README.md) › [Análisis de señal](README.md) › Deinterleaving

## El problema

El receptor entrega los PDW en orden de llegada, con los pulsos de todos los radares **entrelazados**:

```
tiempo →   A   B   A   C   B   A   A   C   B   A …
```

Antes de poder identificar nada hay que **desentrelazar** (*deinterleave*, también *pulse sorting*): agrupar los
pulsos que pertenecen al mismo emisor. Es el paso más difícil de la cadena ESM, y el que más sufre con los entornos
densos y las técnicas de protección electrónica.

## Paso 1: agrupar por parámetros (pre-clasificación)

Primero se separan los pulsos por los parámetros que **no cambian** (o cambian poco) de un pulso a otro del mismo
emisor:

- **AoA**: el más fiable, porque un emisor no puede cambiar de dirección en milisegundos
  ([4.3](../04-guerra-electronica/03-medida-del-aoa.md)).
- **Frecuencia**, si no es ágil.
- **Ancho de pulso**, si es fijo.
- **Modulación intrapulso**.

Se forman grupos (*clusters*) de pulsos parecidos, con ventanas del tamaño del error de medida: si el AoA tiene ±2°
de error, se agrupan los pulsos dentro de unos pocos grados. Al comparar ángulos hay que usar la diferencia envuelta
(359° y 1° están a 2°).

Con suerte cada grupo es un solo emisor. A menudo no: dos radares en direcciones parecidas y con frecuencias cercanas
caen en el mismo grupo, y un radar con agilidad de frecuencia se reparte en varios.

## Paso 2: analizar los tiempos de llegada

Dentro de cada grupo se buscan **periodicidades en los TOA**: la firma de una PRI.

### Histograma de diferencias de TOA

La idea básica: calcular las diferencias entre los TOA de los pulsos y hacer un histograma. Si en el grupo hay un
emisor con PRI fija de 1 ms, la diferencia de 1 ms aparece muchísimas veces y forma un pico.

```
nº de veces
   │        █
   │        █
   │        █               █
   │   ▁    █    ▁          █
   └────────────────────────────── diferencia de TOA
          1 ms            2 ms
```

Las diferencias entre pulsos no consecutivos dan picos en los **múltiplos** de la PRI (2 ms, 3 ms…), y hay que
distinguirlos de PRI reales.

Dos algoritmos clásicos de la literatura sobre esta idea:

- **CDIF** (*Cumulative Difference histogram*, Mardia, 1989): acumula histogramas de diferencias de primer orden
  (pulsos consecutivos), luego de segundo orden (saltando uno), etc., y compara los picos con un umbral para evitar
  confundir múltiplos con PRI reales.
- **SDIF** (*Sequential Difference histogram*, Milojević y Popović, 1992): variante que no acumula los niveles y usa
  un umbral ajustado, más rápida.

Una vez encontrada una PRI candidata, se hace una **búsqueda de secuencia**: se extraen del flujo los pulsos que caen
en `t₀, t₀ + PRI, t₀ + 2·PRI…` (con una tolerancia), se retiran y se repite con los que quedan.

### Cómo se ven los distintos patrones

| Patrón | En el histograma |
| --- | --- |
| PRI fija | Un pico y sus múltiplos |
| Stagger | Un pico por cada valor de la lista, y uno fuerte en la **suma del marco** (el periodo del patrón) |
| Jitter | Un pico ancho y bajo, difícil de distinguir del fondo |
| Sliding | Una banda de valores entre el mínimo y el máximo |
| Dwell & switch | Picos en cada valor, cada uno solo durante su bloque |

## Lo que lo complica

- **Pulsos perdidos**: por los lóbulos de la antena (el barrido deja silencios), por baja sensibilidad o por solape
  con otros pulsos. Rompen las secuencias y añaden diferencias "dobles".
- **Pulsos espurios**: reflexiones, ruido.
- **Agilidad y jitter**: diseñados precisamente para dificultar este paso.
- **Densidad**: con decenas de emisores, la mezcla es enorme y crecen los solapes.
- **Cambios de modo**: el emisor cambia de PRI a mitad de la observación.

## En este proyecto

- El deinterleaver **no** está implementado: es el trabajo futuro para el que se construye el simulador.
- El simulador genera exactamente el problema: un CSV con los pulsos de varios emisores entrelazados en orden de
  llegada (spec §6).
- La columna `truth_emitterId` dice a qué emisor pertenece cada pulso. Es la respuesta correcta con la que se evalúa
  el deinterleaver ([5.5](05-evaluacion-con-verdad-de-terreno.md)), y **nunca** debe usarse como entrada.
- La función `sigint::wrapOffsetDeg` (diferencia de ángulos envuelta) ya existe para agrupar por AoA.
- El simulador ya produce silencios de barrido, cambios de modo y segmentos `off`. Los solapes, el jitter y la
  agilidad aleatoria llegarán con las extensiones de "fuera de alcance".

## Ideas clave

- Deinterleaving = agrupar los pulsos entrelazados por emisor.
- Primero por parámetros estables (AoA ante todo), luego por periodicidades en los TOA.
- Histogramas de diferencias de TOA (CDIF, SDIF) y búsqueda de secuencias.

---

[← 5.1 El PDW](01-pdw.md) · [↑ Análisis de señal](README.md) · [Siguiente: 5.3 Identificación de emisores →](03-identificacion-de-emisores.md)

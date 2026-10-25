# 4.1 Qué es la guerra electrónica

> [Manual](../README.md) › [Guerra electrónica](README.md) › Qué es la guerra electrónica

## Definición

La **guerra electrónica** (EW, *Electronic Warfare*) es el uso del espectro electromagnético para saber qué hace el
adversario, impedirle usarlo y proteger el uso propio. Se divide en tres ramas:

| Rama | Antes se llamaba | Qué hace | Ejemplos |
| --- | --- | --- | --- |
| **ES** — *Electronic Support* (apoyo) | ESM | **Escuchar**: interceptar, identificar y localizar emisiones | Receptores ESM, receptores de alerta radar |
| **EA** — *Electronic Attack* (ataque) | ECM | **Perturbar**: degradar o engañar los sensores del adversario | Perturbadores (*jammers*), señuelos, chaff |
| **EP** — *Electronic Protection* (protección) | ECCM | **Protegerse** del ataque electrónico | Agilidad de frecuencia, jitter de PRI, lóbulos laterales bajos |

Este proyecto pertenece a la primera rama: simula lo que **oye** un receptor de apoyo electrónico.

## Inteligencia de señales (SIGINT)

Parte de la escucha no es táctica (reaccionar ahora) sino de **inteligencia** (estudiar con calma). Ahí entra
**SIGINT** (*Signals Intelligence*), que se divide en:

- **COMINT** (*Communications Intelligence*): comunicaciones (voz, datos).
- **ELINT** (*Electronic Intelligence*): emisiones que no son comunicaciones, sobre todo **radares**.
- **FISINT**: telemetría de sistemas extranjeros (misiles, satélites…).

## ESM frente a ELINT

Las dos escuchan radares, pero con objetivos distintos:

| | ESM | ELINT |
| --- | --- | --- |
| Pregunta | ¿Qué radar es y dónde está, **ahora**? | ¿Cómo es este radar **en detalle**? |
| Tiempo | Real, segundos | Diferido, horas o días |
| Salida | Alertas, situación táctica | Parámetros precisos para las librerías de emisores |
| Ejemplo | Un barco detecta un radar de control de tiro apuntándole | Un analista caracteriza un radar nuevo |

Lo que produce ELINT (los parámetros de cada tipo de radar) alimenta la **librería de emisores** que usa el ESM para
identificar lo que oye. El catálogo del proyecto juega ese papel.

Un caso particular de ESM es el **RWR** (*Radar Warning Receiver*): receptor de alerta radar de aviones y barcos,
pensado para avisar rápido de amenazas concretas.

## La cadena de procesado de un ESM

```
  antenas → receptor → codificador → deinterleaving → identificación → situación
              │            │             │                │                │
            detecta     un PDW       separa los         compara con     orden de batalla
            pulsos     por pulso    pulsos por emisor   la librería     electrónico (EOB)
```

1. **Interceptar**: el receptor detecta cada pulso que supera su sensibilidad ([4.2](02-receptores-esm.md)).
2. **Medir**: para cada pulso mide sus parámetros y los empaqueta en un **PDW**
   ([5.1](../05-analisis-de-senal/01-pdw.md)).
3. **Separar** (*deinterleaving*): los pulsos de todos los radares llegan mezclados; hay que agruparlos por emisor
   ([5.2](../05-analisis-de-senal/02-deinterleaving.md)).
4. **Identificar**: con los parámetros de cada grupo (RF, PRI, PW, scan…) se busca qué tipo de radar es en la
   librería ([5.3](../05-analisis-de-senal/03-identificacion-de-emisores.md)).
5. **Situar**: con el ángulo de llegada (y, con varios receptores, la geolocalización) se construye el **orden de
   batalla electrónico** (EOB): qué emisores hay, dónde y en qué modo.

## En este proyecto

- El **simulador** produce lo que saldría del paso 2: un CSV de PDW, con la **verdad de terreno** de qué emisor generó
  cada pulso.
- Los pasos 3 a 5 (deinterleaver, clasificador) son el trabajo futuro que esa verdad de terreno permitirá evaluar
  ([5.5](../05-analisis-de-senal/05-evaluacion-con-verdad-de-terreno.md)).
- La librería de emisores (`sigint::Catalog`) ya existe como descripción **generativa** de los radares. Para
  reconocerlos hará falta un descriptor con rangos y tolerancias (spec §1, fuera de alcance).
- Las técnicas de protección electrónica que aparecen en el manual (jitter, agilidad) son justo las que complican el
  paso 3.

## Ideas clave

- EW = ES (escuchar) + EA (perturbar) + EP (protegerse).
- SIGINT = COMINT + ELINT (+ FISINT).
- ESM es táctico y en tiempo real; ELINT es de análisis detallado.
- Cadena ESM: interceptar → medir (PDW) → separar → identificar → situar.

---

[← Guerra electrónica](README.md) · [↑ Manual](../README.md) · [Siguiente: 4.2 Receptores ESM →](02-receptores-esm.md)

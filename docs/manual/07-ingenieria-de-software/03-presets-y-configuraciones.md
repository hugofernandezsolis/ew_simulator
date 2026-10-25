# 7.3 Presets y configuraciones

> [Manual](../README.md) › [Ingeniería de software](README.md) › Presets y configuraciones

## Qué es un preset

Un **preset** de CMake es una configuración con nombre guardada en `CMakePresets.json`. En lugar de recordar

```
cmake -S . -B .build/Debug -G Ninja -DCMAKE_BUILD_TYPE=Debug -DPROJ_ENABLE_SANITIZERS=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

se escribe `cmake --preset Debug`. La ventaja principal: **el desarrollador, el IDE y la CI usan exactamente la misma
configuración**.

## Tipos de build

| Tipo | Optimización | Información de depuración | `assert` | Para qué |
| --- | --- | --- | --- | --- |
| Debug | ninguna (`-O0`) | sí | activos | Desarrollar y depurar |
| Release | máxima (`-O3`) | no | desactivados (`NDEBUG`) | Lo que se entrega |
| RelWithDebInfo | alta (`-O2`) | sí | desactivados | Perfilar o depurar un fallo que solo aparece optimizado |

Por eso el plan del simulador usa `std::logic_error` y no `assert` para los estados imposibles: un `assert` desaparece
en Release y el error volvería a ser silencioso.

## Los presets del proyecto

Todos heredan de `base`: generador **Ninja**, carpeta `.build/<preset>` y `compile_commands.json` (que necesitan
clang-tidy y los IDE).

| Preset | Tipo | Añade | Uso |
| --- | --- | --- | --- |
| `Debug` | Debug | Sanitizers (ASan + UBSan) | El día a día |
| `Coverage` | Debug | Instrumentación de cobertura (`--coverage -O0`) | Informe de cobertura |
| `Release` | Release | — | Ejecutable final, lint |
| `RelWithDebInfo` | RelWithDebInfo | — | Perfilado |
| `ci-Debug`, `ci-Coverage`, `ci-Release`, `ci-RelWithDebInfo` | los mismos | **Avisos como errores** (`-Werror`) | La CI, y en local antes de subir |

Los presets `ci-*` combinan dos padres (`"inherits": ["Debug", "ci"]`): el tipo de build y la política de la CI. Por
eso el plan del simulador pide compilar con `ci-Debug`: es lo más exigente (sanitizers y `-Werror` a la vez).

### ¿Por qué sanitizers y cobertura van separados?

UBSan añade comprobaciones (por ejemplo, que todo `bool` leído valga 0 o 1) que gcov cuenta como ramas que ningún test
puede tomar. Mezclados, el porcentaje de cobertura de ramas bajaría por ruido.

## Sanitizers

Los **sanitizers** instrumentan el programa para detectar errores en tiempo de ejecución que el compilador no ve:

| Sanitizer | Detecta | Ejemplo en este proyecto |
| --- | --- | --- |
| **AddressSanitizer** (ASan) | Accesos fuera de rango, uso después de liberar, referencias colgantes, fugas | Ejecutar la acción de un evento mientras el vector de eventos se realoca ([6.2](../06-arquitectura/02-simulacion-por-eventos-discretos.md)) |
| **UndefinedBehaviorSanitizer** (UBSan) | Comportamiento indefinido: desbordamiento de enteros con signo, desplazamientos inválidos, `bool` corruptos | Convertir un tiempo enorme a `int64` sin comprobar antes el límite |

Con ellos el programa va unas 2–3 veces más lento: por eso están en Debug y no en Release. Se activan con
`-fsanitize=address,undefined -fno-omit-frame-pointer`, tanto al compilar como al enlazar.

## Presets de test, paquete y workflow

| Clase | Qué hace |
| --- | --- |
| `testPresets` | Uno por configuración; muestran la salida de los tests que fallan y activan el color de GoogleTest |
| `packagePresets` | `Release` y `ci-Release`: dejan el paquete en `dist/` |
| `workflowPresets` | `ci-Debug`, `ci-Release`, `ci-RelWithDebInfo`: configurar + compilar + probar en un solo comando |

## Comandos del día a día

| Tarea | Comando |
| --- | --- |
| Configurar y compilar | `cmake --preset Debug && cmake --build --preset Debug` |
| Todos los tests | `ctest --preset Debug` |
| Tests de un componente | `ctest --preset Debug -R '^SigInt\.PulseDescriptors\.'` |
| Igual que la CI, en un paso | `cmake --workflow --preset ci-Debug` |
| Con un límite de tiempo por test | `ctest --preset ci-Debug --timeout 60` |
| Formatear el código | `cmake --build --preset Release --target format` |
| Comprobar formato y lint como la CI | `--target format-check` y `--target lint` ([7.6](06-calidad-y-ci.md)) |
| Informe de cobertura | `cmake --preset Coverage && cmake --build --preset Coverage --target coverage` → `.build/Coverage/coverage/index.html` |
| Empaquetar | `cpack --preset Release` |
| Probar con otro compilador | `CXX=clang++-18 cmake --preset ci-Debug -B .build/ci-Debug-clang` |

El `--timeout` merece un comentario: un error que deje un bucle infinito (por ejemplo, una PRI que no avanza) haría que
el test se colgara. Con un límite de tiempo, el test **falla**, que es lo que tiene que pasar.

Los ajustes personales (otro compilador, otra carpeta) van en `CMakeUserPresets.json`, que git ignora.

## En este proyecto

- `CMakePresets.json` (versión 6, CMake ≥ 3.25).
- Opciones del proyecto definidas en `CMakeLists.txt`: `PROJ_ENABLE_SANITIZERS`, `PROJ_ENABLE_COVERAGE`,
  `PROJ_WARNINGS_AS_ERRORS` (todas `OFF` por defecto; los presets las activan) y `PROJ_ENABLE_TESTS`.
- Comandos del simulador: plan, sección "Comandos".

## Ideas clave

- Un preset es una configuración con nombre: misma configuración en local, en el IDE y en la CI.
- `Debug` lleva sanitizers; `ci-*` añade `-Werror`.
- Sanitizers y cobertura no se mezclan.
- `ctest --timeout` convierte un cuelgue en un fallo.

---

[← 7.2 Sistema de build](02-sistema-de-build.md) · [↑ Ingeniería de software](README.md) · [Siguiente: 7.4 Reglas para escribir clases →](04-reglas-de-clases.md)

# 7. Ingeniería de software

> [Manual](../README.md) › Ingeniería de software

Este bloque explica **cómo se construye, se prueba y se mantiene** el proyecto: la estructura de carpetas, el sistema
de build con CMake, las reglas para escribir clases, los tests y la integración continua. A diferencia del bloque 6,
casi todo lo que se describe aquí **ya existe** en el repositorio (`CMakeLists.txt`, `.cmake/`, `CMakePresets.json`,
`.github/workflows/`, `.claude/rules/`).

| Página | Qué aprenderás |
| --- | --- |
| [7.1 Estructura del repositorio](01-estructura-del-repositorio.md) | Librerías, componentes y la convención `include/`, `src/`, `tests/` |
| [7.2 Sistema de build](02-sistema-de-build.md) | Cómo CMake descubre librerías y componentes, dependencias, cabeceras, dependencias externas |
| [7.3 Presets y configuraciones](03-presets-y-configuraciones.md) | Debug, Release, Coverage, `ci-*`; sanitizers; comandos del día a día |
| [7.4 Reglas para escribir clases](04-reglas-de-clases.md) | R1–R12: qué piden y por qué; excepciones del simulador |
| [7.5 Tests](05-tests.md) | GoogleTest, un ejecutable por componente, nombres en ctest, cómo se escribe un test |
| [7.6 Calidad e integración continua](06-calidad-y-ci.md) | clang-format, clang-tidy, cobertura y los cuatro workflows de GitHub Actions |

---

[← 6.7 Decisiones y puntos de extensión](../06-arquitectura/07-decisiones-y-extensiones.md) · [↑ Manual](../README.md) · [Siguiente: 7.1 Estructura del repositorio →](01-estructura-del-repositorio.md)

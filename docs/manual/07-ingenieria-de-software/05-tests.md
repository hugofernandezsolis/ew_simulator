# 7.5 Tests

> [Manual](../README.md) › [Ingeniería de software](README.md) › Tests

## Herramientas

- **GoogleTest 1.17**: framework de tests de C++. Aporta `TEST_F`, los fixtures, las aserciones (`EXPECT_EQ`,
  `EXPECT_NEAR`…) y el `main()` de los ejecutables de test (`GTest::gtest_main`).
- **CTest**: el ejecutor de tests de CMake. Lanza los ejecutables, recoge los resultados y permite filtrar.

## Cómo se organizan

```
  src/SigInt/PulseDescriptors/tests/ut_AngleOfArrival.cpp ┐
  src/SigInt/PulseDescriptors/tests/ut_PulseDescriptorWords.cpp ┴─▶ ews_SigInt_PulseDescriptors_tests
                                                                       enlazado con ews::SigInt + GTest::gtest_main
```

- **Un ejecutable por componente**, con todos sus `ut_*.cpp`. Por eso los helpers de un test van en un
  `namespace {}` anónimo: dos `ut_*.cpp` del mismo componente con un helper del mismo nombre violarían la regla de una
  sola definición (ODR) al enlazarse juntos.
- Cada caso se registra en CTest con el nombre `<Librería>.<Componente>.<Fixture>.<Test>`:

```
SigInt.PulseDescriptors.AngleOfArrivalTest.AzimuthSetterByConstReferenceWrapsIntoRange
```

  Ese nombre permite filtrar por librería, componente o clase: `ctest --preset Debug -R '^SigInt\.PulseDescriptors\.'`.
- La lista de tests se obtiene **al lanzar ctest** (`DISCOVERY_MODE PRE_TEST`), no al compilar: compilar nunca
  ejecuta binarios de test, lo que va más rápido con sanitizers y permite compilación cruzada.

## Anatomía de un test

Cada clase tiene un **fixture**, una clase que prepara el objeto antes de cada test y lo destruye después:

```cpp
// Ilustración del esquema de R12 (no es código del repositorio)
class AngleOfArrivalTest : public ::testing::Test {
protected:
  AngleOfArrival* angleofarrival;
  void SetUp(void) override {angleofarrival = new AngleOfArrival();}
  void TearDown(void) override {delete angleofarrival;}
  ...
};

// Test azimuth setter wraps values into [0, 360)
TEST_F(AngleOfArrivalTest, AzimuthSetterByConstReferenceWrapsIntoRange) {
  ...
}
```

Las reglas de R12 ([7.4](04-reglas-de-clases.md)):

| Regla | Motivo |
| --- | --- |
| **Una función bajo prueba por test** (los getters que solo observan no cuentan) | Cuando un test falla, su nombre dice qué función está mal |
| Nombre en PascalCase: función + comportamiento | `CopyAssignmentToSelfKeepsValue` se entiende sin leer el cuerpo |
| Un comentario `// Test …` encima de cada test | Explica la intención en una línea |
| Todas las funciones públicas tienen test, incluidos los accesores, `==`, `!=`, `to_string` y `<<` | Nada público queda sin probar |
| Constructores, copia y movimiento comprueban **todos** los atributos | Un atributo nuevo olvidado en la copia se detecta |
| Copia: modificar el original no cambia la copia. Movimiento: el origen queda por defecto | Prueba que no comparten estado |
| Autoasignación con un alias (`C& alias = *obj; *obj = alias;`) | Evita los avisos `-Wself-assign` / `-Wself-move` y prueba el `if (this != &iOther)` |
| Orden de los tests = orden de las funciones en el `.h` | Fácil de comparar con la cabecera |

Ejemplo real: `ut_AngleOfArrival.cpp` tiene 30 tests. Solo el setter de azimut por referencia constante tiene tres,
uno por efecto: guarda el valor, normaliza a [0, 360) y no toca la elevación.

## Comparar números

| Qué se compara | Aserción | Por qué |
| --- | --- | --- |
| Tiempos (`std::chrono::nanoseconds`) | `EXPECT_EQ` | Son enteros: deben coincidir exactamente |
| Valor guardado y leído (accesores, copia) | `EXPECT_FLOAT_EQ` / `EXPECT_DOUBLE_EQ` | Margen de 4 ULP: tolera el último bit |
| Resultados de cálculos físicos | `EXPECT_NEAR(valor, esperado, tolerancia)` | La tolerancia explícita dice cuánta precisión se exige (ángulos 1e-4°, potencias 1e-9 dB) |

Nunca `EXPECT_EQ` con `double` calculados: `0.1 + 0.2 != 0.3`.

## Tipos de test del proyecto

| Tipo | Qué prueba | Ejemplo |
| --- | --- | --- |
| **Unitario de clase** (R12) | La interfaz completa de una clase | `ut_AngleOfArrival.cpp` |
| **Unitario de comportamiento** | Una regla del dominio, con valores calculados a mano | Stagger que vuelve al inicio; −3 dB exactos a medio ancho de haz |
| **De regresión de una trampa** | Un error concreto que el diseño quiere evitar | `NextAdvancesStaggerPri` (trampa del getter por valor) |
| **De validación** | Cada regla del loader, con sus extremos | `elevationDeg: 90` válido, `95` error |
| **Golden** (integración) | El sistema completo, byte a byte | Misión golden del simulador ([6.6](../06-arquitectura/06-ejecucion-y-salida.md#el-test-golden)) |

Los dobles de prueba (por ejemplo, un `RecordingWriter` que guarda las llamadas en lugar de escribir un CSV) permiten
probar el receptor o la simulación sin ficheros.

## TDD en el plan

Cada tarea del plan del simulador sigue el ciclo de **desarrollo guiado por tests**:

1. Escribir los tests, que fallan (ni siquiera compilan, porque la clase no existe).
2. Compilar y ver el fallo esperado.
3. Implementar lo mínimo para que pasen.
4. Ejecutar los tests del componente y verlos pasar (con `--timeout 60`).
5. Commit.

Escribir el test antes obliga a decidir qué tiene que hacer la función antes de pensar cómo.

## En este proyecto

- Integración con CMake: `.cmake/Tests.cmake` (`proj_add_component_tests`).
- GoogleTest se declara en `.cmake/dependencies.cmake` y solo se descarga si los tests están activos
  (`-DBUILD_TESTING=OFF` los desactiva todos).
- Convenciones adicionales del simulador (mover siempre desde el objeto del fixture, `std::optional` comprobado con
  `if (!p.has_value()) { FAIL(); }`, `reserve()` antes de llenar un vector): plan, decisión 2, "Tests".

## Ideas clave

- Un ejecutable por componente; nombres `<Lib>.<Comp>.<Fixture>.<Test>` en ctest.
- Una función bajo prueba por test; todas las funciones públicas probadas.
- Tiempos con `EXPECT_EQ`, cálculos con `EXPECT_NEAR` y tolerancia explícita.
- Test primero, después el código.

---

[← 7.4 Reglas para escribir clases](04-reglas-de-clases.md) · [↑ Ingeniería de software](README.md) · [Siguiente: 7.6 Calidad e integración continua →](06-calidad-y-ci.md)

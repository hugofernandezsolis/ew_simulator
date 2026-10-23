include_guard(GLOBAL)

########################################################################################################################
#########                                            COVERAGE FLAGS                                            #########
########################################################################################################################
### proj_enable_coverage(<target>) adds gcov instrumentation when PROJ_ENABLE_COVERAGE=ON. -O0 keeps the optimizer from
### merging lines, so the report matches the source. It comes after the build type flags, so it wins over -O2/-O3.
### --coverage only exists in GCC and Clang (GNU command line): with MSVC or clang-cl nothing is added and a warning is
### printed once per configuration.
########################################################################################################################

function(proj_enable_coverage target)
  if(NOT PROJ_ENABLE_COVERAGE)
    return()
  endif()

  if(MSVC OR NOT CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
    get_property(warned GLOBAL PROPERTY _PROJ_COVERAGE_WARNED)
    if(NOT warned)
      set_property(GLOBAL PROPERTY _PROJ_COVERAGE_WARNED TRUE)
      proj_warn("Cobertura no soportada con ${CMAKE_CXX_COMPILER_ID} (solo GCC/Clang): no se aplica")
    endif()
    return()
  endif()

  target_compile_options(${target} PRIVATE --coverage -O0)
  target_link_options(${target} PRIVATE --coverage)
endfunction()


########################################################################################################################
#########                                           COVERAGE TARGET                                            #########
########################################################################################################################
### proj_add_coverage_target() defines the custom target `coverage`, only when PROJ_ENABLE_COVERAGE=ON. It has to be
### called after the libraries and their tests exist: it depends on every test executable (global property
### PROJ_TEST_TARGETS, filled by Tests.cmake), so it builds them first. Then it deletes the old .gcda files (gcov adds
### counters to them on each run, so without this the report would mix runs), runs ctest and writes an HTML report to
### <build>/coverage/index.html. The deletion is a small script generated here and run with cmake -P, so it works on
### every platform (gcovr --delete only deletes the files after reading them, it does not clean stale ones first).
### The report only counts the code under src/: tests, src/main.cpp (no unit test runs it, and it would only show up if
### the executable happened to be built) and the build directory (GoogleTest, generated files) are left out. With Clang
### the .gcda files are read with "llvm-cov gcov" instead of GCC's gcov. Without gcovr, the target only prints a notice
### and succeeds, so it never breaks a build.
########################################################################################################################

function(proj_add_coverage_target)
  if(NOT PROJ_ENABLE_COVERAGE)
    return()
  endif()

  find_program(PROJ_GCOVR gcovr)
  if(NOT PROJ_GCOVR)
    add_custom_target(coverage
      COMMAND ${CMAKE_COMMAND} -E echo "AVISO: gcovr no está instalado; no se genera informe de cobertura."
      VERBATIM)
    proj_warn("gcovr no encontrado: el target 'coverage' no generará informe")
    return()
  endif()

  # Clang writes .gcda files that GCC's gcov cannot read: use llvm-cov (versioned name first, e.g. llvm-cov-18).
  set(gcov_args "")
  if(CMAKE_CXX_COMPILER_ID MATCHES "^(Clang|AppleClang)$")
    string(REGEX MATCH "^[0-9]+" clang_major "${CMAKE_CXX_COMPILER_VERSION}")
    find_program(PROJ_LLVM_COV NAMES llvm-cov-${clang_major} llvm-cov)
    if(PROJ_LLVM_COV)
      set(gcov_args --gcov-executable "${PROJ_LLVM_COV} gcov")
    else()
      proj_warn("llvm-cov no encontrado: gcovr usará gcov, que no entiende la cobertura de Clang")
    endif()
  endif()

  # Script that deletes every .gcda file under the build directory, so each report starts from zero.
  set(clean_script "${PROJECT_BINARY_DIR}/coverage_clean.cmake")
  file(CONFIGURE OUTPUT "${clean_script}" CONTENT [=[
file(GLOB_RECURSE gcda_files "@PROJECT_BINARY_DIR@/*.gcda")
if(gcda_files)
  file(REMOVE ${gcda_files})
endif()
]=] @ONLY)

  add_custom_target(coverage
    COMMAND ${CMAKE_COMMAND} -P "${clean_script}"
    COMMAND ${CMAKE_CTEST_COMMAND} --test-dir "${PROJECT_BINARY_DIR}" --output-on-failure
    COMMAND ${CMAKE_COMMAND} -E make_directory "${PROJECT_BINARY_DIR}/coverage"
    COMMAND ${PROJ_GCOVR} --root "${PROJECT_SOURCE_DIR}"
            --filter "${PROJECT_SOURCE_DIR}/src/"
            --exclude ".*/tests/.*"
            --exclude "${PROJECT_SOURCE_DIR}/src/main\\.cpp"
            --exclude "${PROJECT_BINARY_DIR}/"
            ${gcov_args}
            --print-summary
            --html-details "${PROJECT_BINARY_DIR}/coverage/index.html"
            "${PROJECT_BINARY_DIR}"
    COMMENT "Ejecutando los tests y generando informe de cobertura con gcovr"
    VERBATIM)

  get_property(test_targets GLOBAL PROPERTY PROJ_TEST_TARGETS)
  if(test_targets)
    add_dependencies(coverage ${test_targets})
  endif()
endfunction()

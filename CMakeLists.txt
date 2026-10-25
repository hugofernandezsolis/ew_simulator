########################################################################################################################
#########                                            CMAKE SETTINGS                                            #########
########################################################################################################################
### Minimum CMake version required. 3.25 is the floor because CMake presets (version 6) need it.
########################################################################################################################

cmake_minimum_required(VERSION 3.25)


########################################################################################################################
#########                                           PROJECT SETTINGS                                           #########
########################################################################################################################
### Project name and languages. This is the only place where the real project name is written: the build files in
### .cmake/ read it as ${PROJECT_NAME}. Everything they define (functions, variables, options) uses the generic prefix
### proj_ / PROJ_, so the folder can be copied to another project by changing only the name here. Only C++ is used, so
### no C compiler checks are done. VERSION is the project version: CPack uses it for the package name unless the release
### workflow passes another one (-DCPACK_PACKAGE_VERSION=<tag>).
########################################################################################################################

project(ews VERSION 0.1.0 LANGUAGES CXX)


########################################################################################################################
#########                                            PROJECT SETUP                                             #########
########################################################################################################################
### Checks that must run before anything else is configured: refuse an in-source build (cmake -S . -B .) and, when no
### preset or -DCMAKE_BUILD_TYPE is given, default the build type to Debug. Macros.cmake is included here, before the
### other modules, because these checks report with proj_fatal/proj_status.
########################################################################################################################

include("${CMAKE_CURRENT_LIST_DIR}/.cmake/Macros.cmake")          # proj_status/warn/fatal, proj_glob_patterns
include("${CMAKE_CURRENT_LIST_DIR}/.cmake/ProjectSetup.cmake")    # proj_forbid_in_source_build...

proj_forbid_in_source_build()
proj_set_default_build_type()


########################################################################################################################
#########                                            TEST SETTINGS                                             #########
########################################################################################################################
### As the main project, include(CTest) enables testing and writes DartConfiguration.tcl to the build tree. ctest needs
### that file in dashboard mode (ctest -T test), which IDEs such as VS Code CMake Tools use to read the results. It also
### defines BUILD_TESTING, the standard switch that packagers (Debian, vcpkg, Conan...) set to OFF to skip the tests.
### The CDash targets it would add (Experimental, Nightly, Continuous...) are not used, so they are skipped by marking
### them as already added. As a subproject CTest is not included: it would set itself up in the consumer's build tree.
###
### PROJ_ENABLE_TESTS builds our tests. It defaults to PROJECT_IS_TOP_LEVEL: ON when this is the main project, OFF when
### it is consumed with add_subdirectory() or FetchContent, so a consumer does not build (nor download GoogleTest for)
### our tests unless it asks for them. It is forced OFF while BUILD_TESTING is OFF (or undefined, in a consumer without
### CTest), so -DBUILD_TESTING=OFF turns every test off. enable_testing() has to be called in this directory before
### any test is registered. As the main project it is always called, so ctest also runs (with 0 tests) when the tests
### are off. As a subproject it is only called when the consumer turned our tests on (the consumer still needs its own
### enable_testing() to run them from its ctest).
########################################################################################################################

if(PROJECT_IS_TOP_LEVEL)
  set_property(GLOBAL PROPERTY CTEST_TARGETS_ADDED 1)  # Skip the CDash dashboard targets
  include(CTest)
endif()

include(CMakeDependentOption)
cmake_dependent_option(PROJ_ENABLE_TESTS "Compilar los tests" ${PROJECT_IS_TOP_LEVEL} "BUILD_TESTING" OFF)

if(PROJECT_IS_TOP_LEVEL OR PROJ_ENABLE_TESTS)
  enable_testing()
endif()


########################################################################################################################
#########                                            BUILD OPTIONS                                             #########
########################################################################################################################
### Switches that change what is built. The presets set them (Debug enables sanitizers, Coverage enables coverage,
### Release and RelWithDebInfo enable LTO) and they can be overridden from the command line, for example:
### cmake --preset Debug -DPROJ_ENABLE_SANITIZERS=OFF
### Sanitizers and coverage live in separate presets: UBSan adds checks (e.g. that every bool read is 0 or 1) that gcov
### counts as branches no test can take, so mixing them lowers the branch coverage with noise.
### They all default to OFF. The switch for the tests, PROJ_ENABLE_TESTS, is defined in TEST SETTINGS.
########################################################################################################################

option(PROJ_ENABLE_SANITIZERS  "Activar sanitizers (ASan/UBSan)"      OFF)
option(PROJ_ENABLE_COVERAGE    "Activar cobertura de código"          OFF)
option(PROJ_ENABLE_LTO         "Activar optimización en enlace (LTO)" OFF)
option(PROJ_WARNINGS_AS_ERRORS "Tratar warnings como errores"         OFF)


########################################################################################################################
#########                                             C++ SETTINGS                                             #########
########################################################################################################################
### C++23 standard, required. Compiler extensions are disabled so the code is standard C++ (-std=c++23 instead of
### -std=gnu++23). The warning flags are not set here: they are applied per target in CompilerFlags.cmake.
########################################################################################################################

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


########################################################################################################################
#########                                           PROJECT MODULES                                            #########
########################################################################################################################
### All the build logic lives in .cmake/. Each module is included by its full path instead of adding .cmake/ to
### CMAKE_MODULE_PATH: that variable is global and FetchContent dependencies would inherit it, so they could load our
### modules (Coverage, Sanitizers...) instead of their own. Including a module does no work: it only defines functions.
### The sections below call them in order, so this file reads as the script of the build. Macros.cmake and
### ProjectSetup.cmake are already included in PROJECT SETUP.
########################################################################################################################

include("${CMAKE_CURRENT_LIST_DIR}/.cmake/CompilerFlags.cmake")   # proj_configure_target
include("${CMAKE_CURRENT_LIST_DIR}/.cmake/Sanitizers.cmake")      # proj_enable_sanitizers
include("${CMAKE_CURRENT_LIST_DIR}/.cmake/Coverage.cmake")        # proj_enable_coverage, proj_add_coverage_target
include("${CMAKE_CURRENT_LIST_DIR}/.cmake/Lto.cmake")             # proj_enable_lto
include("${CMAKE_CURRENT_LIST_DIR}/.cmake/External.cmake")        # proj_fetch_external, proj_setup_googletest
include("${CMAKE_CURRENT_LIST_DIR}/.cmake/BuildComponent.cmake")  # proj_build_library
include("${CMAKE_CURRENT_LIST_DIR}/.cmake/Tests.cmake")           # proj_add_component_tests
include("${CMAKE_CURRENT_LIST_DIR}/.cmake/Deps.cmake")            # proj_depends, proj_link_dependencies...
include("${CMAKE_CURRENT_LIST_DIR}/.cmake/Components.cmake")      # proj_build_all_libraries, proj_link_all_libraries
include("${CMAKE_CURRENT_LIST_DIR}/.cmake/Executable.cmake")      # proj_add_executable
include("${CMAKE_CURRENT_LIST_DIR}/.cmake/Packaging.cmake")       # proj_setup_packaging
include("${CMAKE_CURRENT_LIST_DIR}/.cmake/Tools.cmake")           # proj_add_tools_targets


########################################################################################################################
#########                                        EXTERNAL DEPENDENCIES                                         #########
########################################################################################################################
### The project's external dependencies (URLs and versions) are declared in .cmake/dependencies.cmake. It is the only
### file in .cmake/ that holds project policy instead of mechanism (lowercase name, unlike the modules), so it is the
### one to review when copying the folder to another project. They have to be available before the test executables
### are created. The file is optional: a project without external dependencies does not need it.
########################################################################################################################

if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/.cmake/dependencies.cmake")
  include("${CMAKE_CURRENT_LIST_DIR}/.cmake/dependencies.cmake")
endif()


########################################################################################################################
#########                                              LIBRARIES                                               #########
########################################################################################################################
### Phase 1: discovers the libraries under src/ and builds them (and their tests). PROJ_LIBRARIES gets the list of
### library names. Phase 2: once every library target exists, checks for cycles and links the dependencies declared in
### each src/<library>/deps.cmake.
########################################################################################################################

proj_build_all_libraries(PROJ_LIBRARIES)
proj_link_all_libraries("${PROJ_LIBRARIES}")


########################################################################################################################
#########                                              EXECUTABLE                                              #########
########################################################################################################################
### Target ${PROJECT_NAME}, only created if src/main.cpp exists. It is linked with what src/deps.cmake declares or, if
### that file does not exist, with every library.
########################################################################################################################

proj_add_executable("${PROJ_LIBRARIES}")


########################################################################################################################
#########                                           COVERAGE REPORT                                            #########
########################################################################################################################
### Target `coverage` (gcovr HTML report), only when PROJ_ENABLE_COVERAGE=ON and this is the main project: as a
### subproject it would clash with a consumer's own `coverage` target. It goes after the libraries and the executable
### because the target depends on every test executable, which must already exist.
########################################################################################################################

if(PROJECT_IS_TOP_LEVEL)
  proj_add_coverage_target()
endif()


########################################################################################################################
#########                                              PACKAGING                                               #########
########################################################################################################################
### Install rule for the executable and CPack configuration (used by the release workflow). The packaging policy is
### passed here: a .deb named after the project (the maintainer is mandatory for the DEB generator, SHLIBDEPS makes
### dpkg compute the dependencies, e.g. libstdc++6, and DEB-DEFAULT gives the usual <name>_<version>_<arch>.deb file
### name). Only for the main project: as a subproject, include(CPack) would overwrite the consumer's package
### configuration (CPackConfig.cmake lives in the top-level build directory).
########################################################################################################################

if(PROJECT_IS_TOP_LEVEL)
  set(CPACK_DEBIAN_PACKAGE_MAINTAINER "hfersol99 <hfersol99@gmail.com>")
  set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
  set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
  proj_setup_packaging(GENERATOR DEB NAME ${PROJECT_NAME})
endif()


########################################################################################################################
#########                                          DEVELOPMENT TOOLS                                           #########
########################################################################################################################
### Targets format, format-check and lint (clang-format and clang-tidy). Only for the main project: they are developer
### tools for this repository and, as a subproject, their names would clash with the consumer's own targets.
########################################################################################################################

if(PROJECT_IS_TOP_LEVEL)
  proj_add_tools_targets()
endif()

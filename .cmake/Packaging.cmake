include_guard(GLOBAL)

########################################################################################################################
#########                                              PACKAGING                                               #########
########################################################################################################################
### proj_setup_packaging([GENERATOR <gen>...] [NAME <name>])
###
### Install rule and CPack configuration. The executable (if src/main.cpp exists) is installed in CMAKE_INSTALL_BINDIR
### (GNUInstallDirs, bin/ by default). Which packages to build is project policy, so it is passed by the caller:
### GENERATOR is the list of CPack generators (default TGZ) and NAME the package name (default ${PROJECT_NAME}). With
### the defaults `cpack` builds a .tar.gz named <name>-<version>-<system>. The version defaults to ${PROJECT_VERSION}.
### It is set explicitly because CPack would otherwise take CMAKE_PROJECT_VERSION, which the last project() call
### (GoogleTest's) leaves in the cache. A value given from outside is kept: the release workflow passes it from the git
### tag when configuring (cmake --preset ... -DCPACK_PACKAGE_VERSION=<version>), so it is already defined as a cache
### variable. For the same reason CPACK_PACKAGE_VERSION_MAJOR/MINOR/PATCH are derived from the final
### CPACK_PACKAGE_VERSION (unless they are defined too).
###
### It is a macro, not a function, on purpose: include(CPack) reads the CPACK_* variables of the scope it runs in and
### leaves its own ones there, so it runs in the caller's scope (the top-level CMakeLists.txt) exactly as before. Being
### a macro, its parsed arguments (_PROJ_PKG_*) are left in that scope too; the prefix keeps them from clashing.
########################################################################################################################

macro(proj_setup_packaging)
  cmake_parse_arguments(_PROJ_PKG "" "NAME" "GENERATOR" ${ARGN})
  if(_PROJ_PKG_UNPARSED_ARGUMENTS)
    proj_fatal("proj_setup_packaging: argumentos no reconocidos: ${_PROJ_PKG_UNPARSED_ARGUMENTS}")
  endif()
  if(NOT _PROJ_PKG_GENERATOR)
    set(_PROJ_PKG_GENERATOR TGZ)
  endif()
  if(NOT _PROJ_PKG_NAME)
    set(_PROJ_PKG_NAME ${PROJECT_NAME})
  endif()

  include(GNUInstallDirs)
  if(TARGET ${PROJECT_NAME})
    install(TARGETS ${PROJECT_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
  endif()

  set(CPACK_GENERATOR ${_PROJ_PKG_GENERATOR})
  set(CPACK_PACKAGE_NAME ${_PROJ_PKG_NAME})
  if(NOT DEFINED CPACK_PACKAGE_VERSION)
    set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
  endif()
  # Keep the components coherent with CPACK_PACKAGE_VERSION (CPack would take them from CMAKE_PROJECT_VERSION_*)
  string(REGEX MATCH "^([0-9]+)(\\.([0-9]+))?(\\.([0-9]+))?" _PROJ_PKG_VERSION_MATCH "${CPACK_PACKAGE_VERSION}")
  if(NOT DEFINED CPACK_PACKAGE_VERSION_MAJOR AND NOT "${CMAKE_MATCH_1}" STREQUAL "")
    set(CPACK_PACKAGE_VERSION_MAJOR ${CMAKE_MATCH_1})
  endif()
  if(NOT DEFINED CPACK_PACKAGE_VERSION_MINOR AND NOT "${CMAKE_MATCH_3}" STREQUAL "")
    set(CPACK_PACKAGE_VERSION_MINOR ${CMAKE_MATCH_3})
  endif()
  if(NOT DEFINED CPACK_PACKAGE_VERSION_PATCH AND NOT "${CMAKE_MATCH_5}" STREQUAL "")
    set(CPACK_PACKAGE_VERSION_PATCH ${CMAKE_MATCH_5})
  endif()
  include(CPack)
endmacro()

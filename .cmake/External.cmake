include_guard(GLOBAL)

########################################################################################################################
#########                                      EXTERNAL DEPENDENCY HELPER                                      #########
########################################################################################################################
### proj_fetch_external(<name> URL <url> [FIND_PACKAGE <package>])
###
### Declares and makes available an external dependency. If FIND_PACKAGE is given, find_package(<package>) is tried
### first and the URL is only downloaded when the system does not provide it. Adding a dependency is one call, written
### in the project's .cmake/dependencies.cmake (this module only provides the mechanism, never the URLs or versions).
########################################################################################################################

include(FetchContent)

function(proj_fetch_external name)
  cmake_parse_arguments(PARSE_ARGV 1 ARG "" "URL;FIND_PACKAGE" "")
  if(NOT ARG_URL)
    proj_fatal("proj_fetch_external(${name}): falta URL")
  endif()

  set(find_args)
  if(ARG_FIND_PACKAGE)
    set(find_args FIND_PACKAGE_ARGS NAMES ${ARG_FIND_PACKAGE})
  endif()

  proj_status("Dependencia externa: ${name}")
  FetchContent_Declare(${name} URL "${ARG_URL}" DOWNLOAD_EXTRACT_TIMESTAMP TRUE ${find_args})
  FetchContent_MakeAvailable(${name})
endfunction()


########################################################################################################################
#########                                              GOOGLETEST                                              #########
########################################################################################################################
### proj_setup_googletest(URL <url>)
###
### Makes GoogleTest available, from the system (find_package(GTest)) or downloaded from <url>. Which version to use is
### project policy, so the URL is passed by the caller (see .cmake/dependencies.cmake). It is only needed
### for the tests, so nothing is downloaded when PROJ_ENABLE_TESTS=OFF. INSTALL_GTEST is turned off so `install` and
### `cpack` do not ship GoogleTest with the project.
########################################################################################################################

function(proj_setup_googletest)
  if(NOT PROJ_ENABLE_TESTS)
    return()
  endif()
  cmake_parse_arguments(PARSE_ARGV 0 ARG "" "URL" "")
  if(NOT ARG_URL)
    proj_fatal("proj_setup_googletest: falta URL")
  endif()

  set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
  proj_fetch_external(googletest URL "${ARG_URL}" FIND_PACKAGE GTest)
endfunction()

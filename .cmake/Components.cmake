include_guard(GLOBAL)

########################################################################################################################
#########                                          LIBRARY DISCOVERY                                           #########
########################################################################################################################
### proj_discover_libraries(<out_var>)
###
### Every folder directly under src/ is a library. Returns their names, sorted, in <out_var>. Hidden folders (.idea,
### .git...) are skipped. CONFIGURE_DEPENDS makes a plain `cmake --build` notice new folders and reconfigure by itself.
########################################################################################################################

function(proj_discover_libraries out_var)
  file(GLOB entries LIST_DIRECTORIES true RELATIVE "${PROJECT_SOURCE_DIR}/src" CONFIGURE_DEPENDS
    "${PROJECT_SOURCE_DIR}/src/*")
  list(SORT entries)
  set(libraries "")
  foreach(entry IN LISTS entries)
    if(entry MATCHES "^\\.")
      continue()  # hidden folders
    endif()
    if(IS_DIRECTORY "${PROJECT_SOURCE_DIR}/src/${entry}")
      list(APPEND libraries ${entry})
    endif()
  endforeach()
  set(${out_var} "${libraries}" PARENT_SCOPE)
endfunction()


########################################################################################################################
#########                                         COMPONENT DISCOVERY                                          #########
########################################################################################################################
### proj_discover_components(<library> <out_var>)
###
### A component is a subfolder of a library that has include/, src/ or tests/. Any other subfolder is ignored with a
### warning, in case it is a misnamed component. Returns the components, sorted, in <out_var>.
########################################################################################################################

function(proj_discover_components library out_var)
  set(lib_root "${PROJECT_SOURCE_DIR}/src/${library}")
  file(GLOB entries LIST_DIRECTORIES true RELATIVE "${lib_root}" CONFIGURE_DEPENDS "${lib_root}/*")
  list(SORT entries)
  set(components "")
  foreach(entry IN LISTS entries)
    if(entry MATCHES "^\\.")
      continue()  # hidden folders
    endif()
    set(path "${lib_root}/${entry}")
    if(NOT IS_DIRECTORY "${path}")
      continue()
    endif()
    if(IS_DIRECTORY "${path}/include" OR IS_DIRECTORY "${path}/src" OR IS_DIRECTORY "${path}/tests")
      list(APPEND components ${entry})
    else()
      proj_warn("Carpeta ignorada (sin include/, src/ ni tests/): ${path}")
    endif()
  endforeach()
  set(${out_var} "${components}" PARENT_SCOPE)
endfunction()


########################################################################################################################
#########                                         LIBRARY CONSTRUCTION                                         #########
########################################################################################################################
### proj_build_all_libraries(<out_var>)
###
### Phase 1 of the build. For every library: discovers its components, checks that there is at least one, creates the
### library target and, if tests are enabled, the test executable of each component. Returns the library names in
### <out_var>. Dependencies between libraries are NOT linked here: they need every library target to exist first (see
### proj_link_all_libraries).
########################################################################################################################

function(proj_build_all_libraries out_var)
  proj_discover_libraries(libraries)
  foreach(library IN LISTS libraries)
    proj_discover_components(${library} components)
    if(NOT components)
      proj_fatal("La librería no tiene ningún componente válido: ${PROJECT_SOURCE_DIR}/src/${library}")
    endif()
    proj_status("Librería ${library}: ${components}")
    proj_build_library(${library} COMPONENTS ${components})
    if(PROJ_ENABLE_TESTS)
      foreach(component IN LISTS components)
        proj_add_component_tests(${library} ${component})
      endforeach()
    endif()
  endforeach()
  set(${out_var} "${libraries}" PARENT_SCOPE)
endfunction()


########################################################################################################################
#########                                         LIBRARY DEPENDENCIES                                         #########
########################################################################################################################
### proj_link_all_libraries(<libraries>)
###
### Phase 2 of the build. It must run after proj_build_all_libraries: all the library targets exist by then, so they can
### be linked in any order. First the dependency graph is checked for cycles, then the dependencies declared in each
### src/<library>/deps.cmake are linked.
########################################################################################################################

function(proj_link_all_libraries libraries)
  proj_check_cycles("${libraries}")
  foreach(library IN LISTS libraries)
    proj_link_dependencies(${library})
  endforeach()
endfunction()

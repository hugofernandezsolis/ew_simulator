include_guard(GLOBAL)

########################################################################################################################
#########                                        DEPENDENCY DECLARATION                                        #########
########################################################################################################################
### Each library can have a src/<library>/deps.cmake file that declares what it depends on, with one call (the
### executable can have src/deps.cmake too, see Executable.cmake):
###
###   proj_depends([LIBRARIES <lib>...] [PRIVATE_LIBRARIES <lib>...]
###                [EXTERNAL <target>...] [PRIVATE_EXTERNAL <target>...])
###
### LIBRARIES and EXTERNAL are linked as PUBLIC (whoever uses this library also sees them); PRIVATE_LIBRARIES and
### PRIVATE_EXTERNAL as PRIVATE. In INTERFACE (headers only) libraries everything is linked as INTERFACE. For example:
###
###   find_package(Threads REQUIRED)
###   proj_depends(LIBRARIES Core EXTERNAL fmt::fmt PRIVATE_EXTERNAL Threads::Threads)
###
### External names that contain "::" must be existing targets (imported or ALIAS); a typo such as fmt::fmtt stops the
### configuration here instead of failing later at link time as -lfmt::fmtt. Plain names (pthread, m...) are still
### allowed and passed to the linker as system libraries. LINK_LIBRARIES_ONLY_TARGETS is not used for this: it would
### reject those plain names too.
###
### The declarations are stored in global properties, one set per library (<lib> is the key the file was loaded with):
###   PROJ_DEP_<lib>          project libraries (LIBRARIES + PRIVATE_LIBRARIES)
###   PROJ_DEP_PUBLIC_<lib>   LIBRARIES
###   PROJ_DEP_PRIVATE_<lib>  PRIVATE_LIBRARIES
###   PROJ_DEP_EXTERNAL_<lib> EXTERNAL
###   PROJ_DEP_PRIVATE_EXTERNAL_<lib> PRIVATE_EXTERNAL
########################################################################################################################

# Called from a deps.cmake; PROJ_CURRENT_LIBRARY says whose file it is (its key) and PROJ_CURRENT_DEPS_FILE where it is.
function(proj_depends)
  if(NOT PROJ_CURRENT_LIBRARY)
    proj_fatal("proj_depends solo puede llamarse desde un deps.cmake (de una librería o del ejecutable)")
  endif()
  cmake_parse_arguments(ARG "" "" "LIBRARIES;PRIVATE_LIBRARIES;EXTERNAL;PRIVATE_EXTERNAL" ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    proj_fatal("${PROJ_CURRENT_DEPS_FILE}: argumentos no reconocidos en proj_depends: ${ARG_UNPARSED_ARGUMENTS}")
  endif()
  set(lib ${PROJ_CURRENT_LIBRARY})
  set_property(GLOBAL APPEND PROPERTY PROJ_DEP_PUBLIC_${lib} ${ARG_LIBRARIES})
  set_property(GLOBAL APPEND PROPERTY PROJ_DEP_PRIVATE_${lib} ${ARG_PRIVATE_LIBRARIES})
  set_property(GLOBAL APPEND PROPERTY PROJ_DEP_EXTERNAL_${lib} ${ARG_EXTERNAL})
  set_property(GLOBAL APPEND PROPERTY PROJ_DEP_PRIVATE_EXTERNAL_${lib} ${ARG_PRIVATE_EXTERNAL})
  set_property(GLOBAL APPEND PROPERTY PROJ_DEP_${lib} ${ARG_LIBRARIES} ${ARG_PRIVATE_LIBRARIES})
endfunction()


########################################################################################################################
#########                                          DEPENDENCY LOADING                                          #########
########################################################################################################################
### proj_load_dependencies(<key> [FILE <deps_file>] [OWNER <text>])
###
### Includes <deps_file> (only once, however many times it is asked for), which registers its declarations under <key>.
### By default <key> is a library and <deps_file> is src/<key>/deps.cmake; FILE and OWNER (the "who" of the error
### messages, "La librería '<key>'" by default) let the executable reuse this with its own key and src/deps.cmake.
### Then it checks that every project library it names exists, and that every external name with "::" is a target (a
### generator expression, $<...>, is not checked: it is only resolved at generation time). The file is also registered
### as a configure dependency, so editing it triggers a reconfigure.
########################################################################################################################

function(proj_load_dependencies library)
  cmake_parse_arguments(ARG "" "FILE;OWNER" "" ${ARGN})
  get_property(loaded GLOBAL PROPERTY PROJ_DEPS_LOADED_${library})
  if(loaded)
    return()
  endif()
  set_property(GLOBAL PROPERTY PROJ_DEPS_LOADED_${library} TRUE)

  set(deps_file "${PROJECT_SOURCE_DIR}/src/${library}/deps.cmake")
  if(ARG_FILE)
    set(deps_file "${ARG_FILE}")
  endif()
  set(owner "La librería '${library}'")
  if(ARG_OWNER)
    set(owner "${ARG_OWNER}")
  endif()
  if(NOT EXISTS "${deps_file}")
    return()
  endif()
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${deps_file}")
  file(RELATIVE_PATH origin "${PROJECT_SOURCE_DIR}" "${deps_file}")

  set(PROJ_CURRENT_LIBRARY ${library})
  set(PROJ_CURRENT_DEPS_FILE "${origin}")
  include("${deps_file}")

  get_property(edges GLOBAL PROPERTY PROJ_DEP_${library})
  foreach(dep IN LISTS edges)
    if(NOT TARGET ${PROJECT_NAME}::${dep})
      proj_fatal("${owner} depende de '${dep}', que no existe (${origin})")
    endif()
  endforeach()

  get_property(external GLOBAL PROPERTY PROJ_DEP_EXTERNAL_${library})
  get_property(private_external GLOBAL PROPERTY PROJ_DEP_PRIVATE_EXTERNAL_${library})
  foreach(dep IN LISTS external private_external)
    if(dep MATCHES "::" AND NOT dep MATCHES "^\\$<" AND NOT TARGET ${dep})
      set(hint "¿falta find_package/proj_fetch_external o hay una errata?")
      proj_fatal("${owner} depende de '${dep}', que no es un target; ${hint} (${origin})")
    endif()
  endforeach()
endfunction()


########################################################################################################################
#########                                           CYCLE DETECTION                                            #########
########################################################################################################################
### proj_check_cycles(<libs>)
###
### Stops the configuration if the libraries depend on each other in a circle (A -> B -> A), printing the whole path. It
### is a depth-first search: proj_cycle_visit walks the graph keeping the current path in <stack>, and a node that is
### reached again while still on the path closes a cycle. Nodes already fully explored are remembered, so a library that
### several others depend on (a diamond) is not reported as a cycle.
########################################################################################################################

# Depth-first search; <stack> is the current path.
function(proj_cycle_visit node stack)
  get_property(done GLOBAL PROPERTY PROJ_CYCLE_DONE)
  if(node IN_LIST done)
    return()
  endif()
  if(node IN_LIST stack)
    list(FIND stack ${node} start)
    list(SUBLIST stack ${start} -1 cycle)
    list(APPEND cycle ${node})
    list(JOIN cycle " -> " path)
    proj_fatal("Dependencia cíclica entre librerías: ${path}")
  endif()
  list(APPEND stack ${node})
  get_property(edges GLOBAL PROPERTY PROJ_DEP_${node})
  foreach(dep IN LISTS edges)
    proj_cycle_visit(${dep} "${stack}")
  endforeach()
  set_property(GLOBAL APPEND PROPERTY PROJ_CYCLE_DONE ${node})
endfunction()

# Checks that the dependency graph of <libs> has no cycles.
function(proj_check_cycles libs)
  foreach(library IN LISTS libs)
    proj_load_dependencies(${library})
  endforeach()
  set_property(GLOBAL PROPERTY PROJ_CYCLE_DONE "")
  foreach(library IN LISTS libs)
    proj_cycle_visit(${library} "")
  endforeach()
endfunction()


########################################################################################################################
#########                                          DEPENDENCY LINKING                                          #########
########################################################################################################################
### proj_link_dependencies(<library>)
###
### Links <library> with what its deps.cmake declared, using the <project>::<lib> aliases for project libraries
### (<project> is ${PROJECT_NAME}). It must run after every library target has been created. <library> itself is
### addressed by its real target name, <project>_<library>: target_link_libraries does not accept an ALIAS as the
### target being linked.
########################################################################################################################

function(proj_link_dependencies library)
  proj_load_dependencies(${library})
  get_property(public_libs GLOBAL PROPERTY PROJ_DEP_PUBLIC_${library})
  get_property(private_libs GLOBAL PROPERTY PROJ_DEP_PRIVATE_${library})
  get_property(external GLOBAL PROPERTY PROJ_DEP_EXTERNAL_${library})
  get_property(private_external GLOBAL PROPERTY PROJ_DEP_PRIVATE_EXTERNAL_${library})

  set(target ${PROJECT_NAME}_${library})
  get_target_property(type ${target} TYPE)
  if(type STREQUAL "INTERFACE_LIBRARY")
    set(public_scope INTERFACE)
    set(private_scope INTERFACE)
  else()
    set(public_scope PUBLIC)
    set(private_scope PRIVATE)
  endif()

  foreach(dep IN LISTS public_libs)
    target_link_libraries(${target} ${public_scope} ${PROJECT_NAME}::${dep})
  endforeach()
  foreach(dep IN LISTS private_libs)
    target_link_libraries(${target} ${private_scope} ${PROJECT_NAME}::${dep})
  endforeach()
  foreach(dep IN LISTS external)
    target_link_libraries(${target} ${public_scope} ${dep})
  endforeach()
  foreach(dep IN LISTS private_external)
    target_link_libraries(${target} ${private_scope} ${dep})
  endforeach()
endfunction()

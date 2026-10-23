include_guard(GLOBAL)

########################################################################################################################
#########                                        IN-SOURCE BUILD GUARD                                         #########
########################################################################################################################
### proj_forbid_in_source_build()
###
### Stops the configuration when the build directory is the source directory (cmake -S . -B .): the generated files
### (CMakeCache.txt, CMakeFiles/, build.ninja...) would be mixed with the sources. It must be called right after
### project(), before anything else is generated. CMake has already written CMakeCache.txt and CMakeFiles/ by then, so
### the message asks to delete them; otherwise the next run would reuse that cache.
########################################################################################################################

function(proj_forbid_in_source_build)
  if(PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
    proj_fatal("No se permite compilar dentro del árbol de fuentes (${PROJECT_SOURCE_DIR}). Borra CMakeCache.txt y \
CMakeFiles/ de ese directorio y usa un directorio de build aparte, por ejemplo: cmake --preset Debug")
  endif()
endfunction()


########################################################################################################################
#########                                          DEFAULT BUILD TYPE                                          #########
########################################################################################################################
### proj_set_default_build_type()
###
### When the project is configured without presets (plain cmake -S . -B <dir>) CMAKE_BUILD_TYPE is empty, which means
### no optimization and no debug info. In that case it is set to Debug: this is a development repository and Debug is
### also what the default preset uses, so a build without presets behaves like `cmake --preset Debug`. FORCE is only
### used when the value is empty, so a value given with -D or by a preset is never overwritten. Multi-config generators
### (Visual Studio, Ninja Multi-Config, Xcode) ignore CMAKE_BUILD_TYPE, so they are left alone. Only for the main
### project: as a subproject the build type belongs to the consumer.
########################################################################################################################

function(proj_set_default_build_type)
  get_property(is_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
  if(NOT PROJECT_IS_TOP_LEVEL OR is_multi_config OR CMAKE_BUILD_TYPE)
    return()
  endif()
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "Tipo de build" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)
  proj_status("CMAKE_BUILD_TYPE no indicado: se usa Debug")
endfunction()

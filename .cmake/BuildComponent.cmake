include_guard(GLOBAL)

########################################################################################################################
#########                                           LIBRARY BUILDER                                            #########
########################################################################################################################
### proj_build_library(<name> COMPONENTS <c1> <c2> ...)
###
### Creates the target of one library out of all its components. It is the same for every library. Sources are the
### translation units under src/<name>/<component>/src/ (recursive; the extensions come from proj_glob_patterns in
### Macros.cmake). Without sources the library is INTERFACE (headers only).
###
### Target names: <name> is the folder name, but the real target is <project>_<name> (<project> is ${PROJECT_NAME}), so
### a folder can be called like a reserved target (test, install, all...) or an existing one (format, lint, gtest, the
### executable) without a clash. The alias <project>::<name> is also created: it is the name everything else uses to
### link the library, and a typo in it fails at configure time. OUTPUT_NAME is not changed, so the file keeps the
### prefix (libews_Dummy_Lib.a): it is still readable and cannot collide with another project's library file.
###
### Headers: the headers of every component's include/ (recursive) go into one FILE_SET HEADERS of the target, PUBLIC
### (INTERFACE for an INTERFACE library), with each include/ as one of its BASE_DIRS. That does two things: IDEs list
### the headers as part of the target, and CMake adds every BASE_DIR as an include folder of the target and of whoever
### links it, so no target_include_directories is needed for include/. A single file set with several BASE_DIRS is used
### instead of one named set per component: the result is the same and there is only one set to handle (and to install,
### if that is ever needed). Each component's src/ is still added as a PRIVATE include folder (internal only).
### An INTERFACE library gets no Ninja target (it cannot be built by name): an INTERFACE file set does not count as
### sources of its own. That is fine, as there is nothing to compile; the CMake target and its alias exist as usual.
########################################################################################################################

function(proj_build_library name)
  cmake_parse_arguments(ARG "" "" "COMPONENTS" ${ARGN})

  set(lib_root "${PROJECT_SOURCE_DIR}/src/${name}")
  set(target ${PROJECT_NAME}_${name})

  # 1. Collect the sources of every component. CONFIGURE_DEPENDS makes a new source file get picked up by a plain
  #    `cmake --build`.
  set(sources "")
  foreach(component IN LISTS ARG_COMPONENTS)
    proj_glob_patterns(patterns SOURCES "${lib_root}/${component}/src")
    file(GLOB_RECURSE component_sources CONFIGURE_DEPENDS ${patterns})
    list(APPEND sources ${component_sources})
  endforeach()

  # 2. Create the target: a normal library, or INTERFACE if there is no code
  if(sources)
    add_library(${target} ${sources})
    set(public_scope PUBLIC)
  else()
    add_library(${target} INTERFACE)
    set(public_scope INTERFACE)
  endif()
  add_library(${PROJECT_NAME}::${name} ALIAS ${target})

  # 3. Headers (one FILE_SET whose BASE_DIRS are the include/ folders) and private src/ folders of every component
  set(header_dirs "")
  set(headers "")
  foreach(component IN LISTS ARG_COMPONENTS)
    set(include_dir "${lib_root}/${component}/include")
    set(src_dir "${lib_root}/${component}/src")
    if(IS_DIRECTORY "${include_dir}")
      list(APPEND header_dirs "${include_dir}")
      proj_glob_patterns(patterns HEADERS "${include_dir}")
      file(GLOB_RECURSE component_headers CONFIGURE_DEPENDS ${patterns})
      list(APPEND headers ${component_headers})
    endif()
    if(sources AND IS_DIRECTORY "${src_dir}")
      target_include_directories(${target} PRIVATE "${src_dir}")
    endif()
  endforeach()
  if(header_dirs)
    target_sources(${target} ${public_scope} FILE_SET HEADERS BASE_DIRS ${header_dirs} FILES ${headers})
  endif()

  # 4. Compiler flags (an INTERFACE library has nothing to compile)
  if(sources)
    proj_configure_target(${target})
  endif()
endfunction()

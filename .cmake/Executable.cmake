include_guard(GLOBAL)

########################################################################################################################
#########                                              EXECUTABLE                                              #########
########################################################################################################################
### proj_add_executable(<libraries>)
###
### The project executable (target ${PROJECT_NAME}) only exists if src/main.cpp does. Its dependencies are declared in
### src/deps.cmake with the same proj_depends() as the libraries (see Deps.cmake); being an executable, everything is
### linked PRIVATE, so LIBRARIES/PRIVATE_LIBRARIES and EXTERNAL/PRIVATE_EXTERNAL mean the same here. The names are
### checked as for a library: project libraries must exist and external names with "::" must be targets.
### If src/deps.cmake does not exist, the executable is linked with every library in <libraries> (the list returned by
### proj_build_all_libraries), so projects without that file keep working. src/deps.cmake is a file, not a folder, so
### the library discovery never takes it for a library. The declarations are stored under the key ".executable": it
### starts with "." and hidden folders are never libraries, so it cannot clash with a library name.
### The GLOBs with CONFIGURE_DEPENDS make creating or deleting main.cpp or deps.cmake trigger a reconfigure on the next
### build.
########################################################################################################################

function(proj_add_executable libraries)
  file(GLOB main_cpp CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/src/main.cpp")
  if(NOT main_cpp)
    return()
  endif()
  add_executable(${PROJECT_NAME} "${main_cpp}")

  file(GLOB deps_file CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/src/deps.cmake")
  if(deps_file)
    set(key ".executable")
    proj_load_dependencies(${key} FILE "${deps_file}" OWNER "El ejecutable '${PROJECT_NAME}'")
    get_property(project_libs GLOBAL PROPERTY PROJ_DEP_${key})
    get_property(external GLOBAL PROPERTY PROJ_DEP_EXTERNAL_${key})
    get_property(private_external GLOBAL PROPERTY PROJ_DEP_PRIVATE_EXTERNAL_${key})
  else()
    set(project_libs ${libraries})
    set(external "")
    set(private_external "")
  endif()

  foreach(library IN LISTS project_libs)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${PROJECT_NAME}::${library})
  endforeach()
  foreach(dep IN LISTS external private_external)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${dep})
  endforeach()
  proj_configure_target(${PROJECT_NAME})
endfunction()

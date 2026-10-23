include_guard(GLOBAL)

########################################################################################################################
#########                                          DEVELOPMENT TOOLS                                           #########
########################################################################################################################
### proj_add_tools_targets() defines custom targets that wrap clang-format and clang-tidy, so the commands live in one
### place and the CI runs the same ones as a developer:
###
###   format        rewrites the sources in place
###   format-check  only checks them (fails if something would change)
###   lint          runs clang-tidy on the translation units only, not on the headers (needs compile_commands.json,
###                 which the presets generate)
###
### They act on every C++ file under src/ (the extensions come from proj_glob_patterns in Macros.cmake). If a tool is
### not installed, its targets are still defined but fail with a clear message, so a missing tool is never mistaken for
### a clean result. lint passes -p ${CMAKE_BINARY_DIR} (not PROJECT_BINARY_DIR) on purpose: CMake always writes
### compile_commands.json to the top-level build directory, also when this project is used as a subproject.
########################################################################################################################

# proj_add_missing_tool_target(<target> <tool>) defines <target> so that it prints a message and fails.
function(proj_add_missing_tool_target target tool)
  add_custom_target(${target}
    COMMAND ${CMAKE_COMMAND} -E echo "ERROR: ${tool} no está instalado; el target '${target}' no puede ejecutarse."
    COMMAND ${CMAKE_COMMAND} -E false
    VERBATIM)
endfunction()

function(proj_add_tools_targets)
  proj_glob_patterns(format_patterns ALL "${PROJECT_SOURCE_DIR}/src")
  proj_glob_patterns(lint_patterns SOURCES "${PROJECT_SOURCE_DIR}/src")
  file(GLOB_RECURSE format_files CONFIGURE_DEPENDS ${format_patterns})
  file(GLOB_RECURSE lint_files CONFIGURE_DEPENDS ${lint_patterns})

  find_program(PROJ_CLANG_FORMAT clang-format)
  find_program(PROJ_CLANG_TIDY clang-tidy)

  if(PROJ_CLANG_FORMAT)
    add_custom_target(format
      COMMAND ${PROJ_CLANG_FORMAT} -i ${format_files}
      COMMENT "Formateando los fuentes con clang-format"
      VERBATIM)
    add_custom_target(format-check
      COMMAND ${PROJ_CLANG_FORMAT} --dry-run --Werror ${format_files}
      COMMENT "Comprobando el formato con clang-format"
      VERBATIM)
  else()
    proj_add_missing_tool_target(format clang-format)
    proj_add_missing_tool_target(format-check clang-format)
  endif()

  if(PROJ_CLANG_TIDY)
    add_custom_target(lint
      COMMAND ${PROJ_CLANG_TIDY} -p "${CMAKE_BINARY_DIR}" --quiet ${lint_files}
      COMMENT "Analizando los fuentes con clang-tidy"
      VERBATIM)
  else()
    proj_add_missing_tool_target(lint clang-tidy)
  endif()
endfunction()

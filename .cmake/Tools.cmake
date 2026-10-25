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
###                 which the presets generate). It runs twice: on the production sources with the checks of
###                 .clang-tidy, and on the test sources (paths containing /tests/) with an extra --checks= that
###                 disables the checks GoogleTest is incompatible with (see PROJ_LINT_TEST_CHECKS). Accepted
###                 limitation: clangd in the editor does not know about this relaxation.
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
  set(lint_test_files ${lint_files})
  list(FILTER lint_test_files INCLUDE REGEX "/tests/")
  list(FILTER lint_files EXCLUDE REGEX "/tests/")

  # Checks disabled only for the test sources (the --checks= value is added on top of .clang-tidy). Each one is tagged
  # as in .clang-tidy (see principles.md): [a] does not contradict the CG; [b] deviation, listed in principles.md.
  set(PROJ_LINT_TEST_CHECKS
    # [b ES.45] Test data and expected values are literal numbers by nature.
    -readability-magic-numbers
    -cppcoreguidelines-avoid-magic-numbers
    # [a] TEST_F/TEST_P macros generate global objects.
    -cppcoreguidelines-avoid-non-const-global-variables
    # [a] The GoogleTest macros use new internally.
    -cppcoreguidelines-owning-memory
    # [a] The GoogleTest macros use variadic functions internally.
    -cppcoreguidelines-pro-type-vararg
    # [a] Fixtures and macro-generated classes do not follow the rule of five.
    -cppcoreguidelines-special-member-functions
    # [a] The macro-generated test classes cannot be placed in anonymous namespaces.
    -misc-use-anonymous-namespace
    -misc-use-internal-linkage
    # [a] The assertion macros expand into branches that inflate the cognitive complexity.
    -readability-function-cognitive-complexity)
  list(JOIN PROJ_LINT_TEST_CHECKS "," lint_test_checks_arg)

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
    set(lint_commands)
    if(lint_files)
      list(APPEND lint_commands COMMAND ${PROJ_CLANG_TIDY} -p "${CMAKE_BINARY_DIR}" --quiet ${lint_files})
    endif()
    if(lint_test_files)
      list(APPEND lint_commands
        COMMAND ${PROJ_CLANG_TIDY} -p "${CMAKE_BINARY_DIR}" --quiet "--checks=${lint_test_checks_arg}" ${lint_test_files})
    endif()
    add_custom_target(lint
      ${lint_commands}
      COMMENT "Analizando los fuentes con clang-tidy"
      VERBATIM)
  else()
    proj_add_missing_tool_target(lint clang-tidy)
  endif()
endfunction()

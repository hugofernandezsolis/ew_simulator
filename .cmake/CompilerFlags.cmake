include_guard(GLOBAL)

########################################################################################################################
#########                                             TARGET FLAGS                                             #########
########################################################################################################################
### proj_configure_target(<target>) applies the project's compile options to one target. They are always applied per
### target and never globally, so third-party code such as GoogleTest is not affected. It is called for every library,
### every test executable and for the project executable.
### The warning flags depend on the command-line style of the compiler. MSVC is true for cl and for clang-cl (Clang with
### the MSVC front end), which both take /W4 /permissive-; every other compiler gets the GCC/Clang flags. A plain if()
### is used instead of generator expressions because the choice is known at configure time and reads more clearly.
### Warnings as errors use the COMPILE_WARNING_AS_ERROR property (CMake 3.24+): CMake picks the right flag (-Werror or
### /WX) and it can be turned off from the command line with cmake --compile-no-warning-as-error.
########################################################################################################################

function(proj_configure_target target)
  # Warnings
  if(MSVC)
    target_compile_options(${target} PRIVATE /W4 /permissive-)
  else()
    target_compile_options(${target} PRIVATE
      -Wall -Wextra -Wpedantic -Wshadow -Wconversion)
  endif()

  # Warnings as errors, only when requested
  if(PROJ_WARNINGS_AS_ERRORS)
    set_target_properties(${target} PROPERTIES COMPILE_WARNING_AS_ERROR ON)
  endif()

  # Sanitizers and coverage (they do nothing unless their option is ON)
  proj_enable_sanitizers(${target})
  proj_enable_coverage(${target})
endfunction()

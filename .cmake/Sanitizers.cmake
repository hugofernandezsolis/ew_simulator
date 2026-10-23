include_guard(GLOBAL)

########################################################################################################################
#########                                              SANITIZERS                                              #########
########################################################################################################################
### proj_enable_sanitizers(<target>) adds AddressSanitizer and UndefinedBehaviorSanitizer when
### PROJ_ENABLE_SANITIZERS=ON. The flags go in both the compile and the link options. Link options of a static library
### are not propagated to the executables that use it, so each executable gets them through its own
### proj_configure_target call.
### MSVC (cl and clang-cl) only has AddressSanitizer: it gets /fsanitize=address, at compile time only (the MSVC
### toolchain links the runtime by itself). Compilers that are neither MSVC nor GCC/Clang get no sanitizers. In both
### cases a warning is printed once per configuration, not once per target.
########################################################################################################################

function(proj_enable_sanitizers target)
  if(NOT PROJ_ENABLE_SANITIZERS)
    return()
  endif()

  if(MSVC)
    target_compile_options(${target} PRIVATE /fsanitize=address)
    _proj_sanitizers_warn_once("MSVC solo soporta AddressSanitizer: UBSan no está disponible")
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
    set(_flags -fsanitize=address,undefined -fno-omit-frame-pointer)
    target_compile_options(${target} PRIVATE ${_flags})
    target_link_options(${target} PRIVATE ${_flags})
  else()
    _proj_sanitizers_warn_once("Sanitizers no soportados con ${CMAKE_CXX_COMPILER_ID}: no se aplican")
  endif()
endfunction()

# Prints msg only the first time it is called, so the warning is not repeated for every target.
function(_proj_sanitizers_warn_once msg)
  get_property(warned GLOBAL PROPERTY _PROJ_SANITIZERS_WARNED)
  if(NOT warned)
    set_property(GLOBAL PROPERTY _PROJ_SANITIZERS_WARNED TRUE)
    proj_warn("${msg}")
  endif()
endfunction()

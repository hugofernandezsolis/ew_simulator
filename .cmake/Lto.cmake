include_guard(GLOBAL)

########################################################################################################################
#########                                        LINK-TIME OPTIMIZATION                                        #########
########################################################################################################################
### proj_enable_lto(<target>) turns on link-time optimization (LTO, CMake's INTERPROCEDURAL_OPTIMIZATION) when
### PROJ_ENABLE_LTO=ON. Without LTO each .cpp is optimized on its own, so a call to a function defined in another .cpp
### (for example a getter declared in a .h and defined in its .cpp) can never be inlined. With LTO the compiler
### optimizes the whole program at link time and can inline those calls.
### The Release and RelWithDebInfo presets turn it on. Debug does not: LTO slows down the link and makes the debugger
### less precise.
### Support is checked once with check_ipo_supported() and the result is cached in a global property, so the check does
### not run once per target. If the compiler or linker does not support it, a warning is printed once and the build
### continues without LTO.
########################################################################################################################

function(proj_enable_lto target)
  if(NOT PROJ_ENABLE_LTO)
    return()
  endif()

  get_property(checked GLOBAL PROPERTY _PROJ_LTO_CHECKED)
  if(NOT checked)
    include(CheckIPOSupported)
    check_ipo_supported(RESULT supported OUTPUT output LANGUAGES CXX)
    set_property(GLOBAL PROPERTY _PROJ_LTO_CHECKED TRUE)
    set_property(GLOBAL PROPERTY _PROJ_LTO_SUPPORTED ${supported})
    if(NOT supported)
      proj_warn("LTO no soportado por el compilador o el enlazador: se compila sin LTO (${output})")
    endif()
  endif()

  get_property(supported GLOBAL PROPERTY _PROJ_LTO_SUPPORTED)
  if(supported)
    set_target_properties(${target} PROPERTIES INTERPROCEDURAL_OPTIMIZATION ON)
  endif()
endfunction()

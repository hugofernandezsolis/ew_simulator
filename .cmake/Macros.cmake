include_guard(GLOBAL)

########################################################################################################################
#########                                          MESSAGE UTILITIES                                           #########
########################################################################################################################
### Wrappers around message() that prefix every line with the project name, [${PROJECT_NAME}], so the project's own
### output is easy to tell from CMake's. proj_fatal stops the configuration with an error.
########################################################################################################################

function(proj_status msg)
  message(STATUS "[${PROJECT_NAME}] ${msg}")
endfunction()

function(proj_warn msg)
  message(WARNING "[${PROJECT_NAME}] ${msg}")
endfunction()

function(proj_fatal msg)
  message(FATAL_ERROR "[${PROJECT_NAME}] ${msg}")
endfunction()


########################################################################################################################
#########                                        SOURCE FILE EXTENSIONS                                        #########
########################################################################################################################
### proj_glob_patterns(<out_var> <SOURCES|HEADERS|ALL> <dir>...)
###
### The single place that says which file extensions are C++ code. It returns in <out_var> the glob patterns
### <dir>/*.<ext> for every <dir> and every extension of the requested kind, ready for file(GLOB) or file(GLOB_RECURSE):
###
###   SOURCES  translation units: .cpp .cc .cxx .c++
###   HEADERS  headers and inline/template implementation files: .h .hh .hpp .hxx .ipp .inl
###   ALL      both lists
###
### BuildComponent (library sources and headers), Tests (test sources) and Tools (format and lint) use it, so a file
### is either seen by all of them or by none, instead of being silently ignored by some.
########################################################################################################################

function(proj_glob_patterns out_var kind)
  set(source_exts cpp cc cxx c++)
  set(header_exts h hh hpp hxx ipp inl)
  if(kind STREQUAL "SOURCES")
    set(exts ${source_exts})
  elseif(kind STREQUAL "HEADERS")
    set(exts ${header_exts})
  elseif(kind STREQUAL "ALL")
    set(exts ${source_exts} ${header_exts})
  else()
    proj_fatal("proj_glob_patterns: tipo '${kind}' no válido (SOURCES, HEADERS o ALL)")
  endif()

  set(patterns "")
  foreach(dir IN LISTS ARGN)
    foreach(ext IN LISTS exts)
      list(APPEND patterns "${dir}/*.${ext}")
    endforeach()
  endforeach()
  set(${out_var} ${patterns} PARENT_SCOPE)
endfunction()

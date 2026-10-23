########################################################################################################################
#########                                        EXTERNAL DEPENDENCIES                                         #########
########################################################################################################################
### Project policy: the external dependencies of this project, with their URLs and versions. The top-level
### CMakeLists.txt includes this file; the mechanism (proj_fetch_external, proj_setup_googletest) lives in
### External.cmake, which stays generic. Unlike the other files in .cmake/, this one is specific to the project: review
### it when copying the folder to another project.
###
### To add a dependency, add one proj_fetch_external call, for example:
###
###   proj_fetch_external(fmt
###     URL "https://github.com/fmtlib/fmt/archive/refs/tags/11.1.4.tar.gz"
###     FIND_PACKAGE fmt)
###
### and then link its target from a library's deps.cmake: proj_depends(EXTERNAL fmt::fmt), or
### proj_depends(PRIVATE_EXTERNAL fmt::fmt) if it is only used in the library's .cpp files. A target name that does not
### exist (fmt::fmtt) stops the configuration.
########################################################################################################################

# GoogleTest, only needed (and only downloaded) when PROJ_ENABLE_TESTS=ON.
if(PROJ_ENABLE_TESTS)
  proj_setup_googletest(URL "https://github.com/google/googletest/archive/refs/tags/v1.17.0.tar.gz")
endif()

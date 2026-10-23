include_guard(GLOBAL)

########################################################################################################################
#########                                           COMPONENT TESTS                                            #########
########################################################################################################################
### proj_add_component_tests(<library> <component>)
###
### If src/<library>/<component>/tests/ has no source files (extensions from proj_glob_patterns), it does nothing.
### Otherwise it creates the executable <project>_<library>_<component>_tests (<project> is ${PROJECT_NAME}, see
### BuildComponent.cmake), links it with the alias <project>::<library> and GTest::gtest_main (which provides main()),
### and registers every test case in CTest as "<library>.<component>.<suite>.<case>" (logical names, without the
### prefix). The target name is also appended to the
### global property PROJ_TEST_TARGETS, so other modules (the `coverage` target) can depend on every test executable.
###
### Discovery uses DISCOVERY_MODE PRE_TEST: the test list is obtained by running the executable with --gtest_list_tests
### when ctest starts, not as a POST_BUILD step. Building therefore never executes test binaries (faster with
### ASan/coverage instrumentation, and required for cross-compilation, where the host cannot run them). `ctest -N`
### still needs the executables to be built, since listing the tests runs them.
########################################################################################################################

include(GoogleTest)

function(proj_add_component_tests library component)
  proj_glob_patterns(patterns SOURCES "${PROJECT_SOURCE_DIR}/src/${library}/${component}/tests")
  file(GLOB test_sources CONFIGURE_DEPENDS ${patterns})
  if(NOT test_sources)
    return()
  endif()

  set(target ${PROJECT_NAME}_${library}_${component}_tests)
  add_executable(${target} ${test_sources})
  target_link_libraries(${target} PRIVATE ${PROJECT_NAME}::${library} GTest::gtest_main)
  proj_configure_target(${target})
  gtest_discover_tests(${target} TEST_PREFIX "${library}.${component}." DISCOVERY_MODE PRE_TEST)
  set_property(GLOBAL APPEND PROPERTY PROJ_TEST_TARGETS ${target})
endfunction()

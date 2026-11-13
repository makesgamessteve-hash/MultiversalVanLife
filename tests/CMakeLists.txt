# Multiversal Van Life - unit tests, automated game tests and coverage.
set(MVL_TEST_TMP ${CMAKE_CURRENT_BINARY_DIR}/tmp)
file(MAKE_DIRECTORY ${MVL_TEST_TMP})

file(GLOB MVL_UNIT_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/unit/*.c)
add_executable(mvl_unit_tests ${MVL_UNIT_SOURCES})
target_link_libraries(mvl_unit_tests PRIVATE mvl_core)
target_include_directories(mvl_unit_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/unit)
target_compile_definitions(mvl_unit_tests PRIVATE MVL_TEST_TMP="${MVL_TEST_TMP}")
add_test(NAME unit COMMAND mvl_unit_tests)

# Automated game tests: the real Lua game driven by scripted input through
# the headless runner. Each test gets a fresh save folder.
file(GLOB MVL_GAME_TESTS ${CMAKE_CURRENT_SOURCE_DIR}/game/test_*.lua)
foreach(test_file ${MVL_GAME_TESTS})
  get_filename_component(test_name ${test_file} NAME_WE)
  set(save_dir ${MVL_TEST_TMP}/save_${test_name})
  set(extra "")
  if(test_name STREQUAL "test_mods")
    set(extra --mods ${CMAKE_CURRENT_SOURCE_DIR}/game/mods)
  endif()
  add_test(NAME game.${test_name}
    COMMAND ${CMAKE_COMMAND}
      -DRUNNER=$<TARGET_FILE:mvl_headless>
      -DDATA=${CMAKE_SOURCE_DIR}/game
      -DSAVE=${save_dir}
      -DTEST=${test_file}
      "-DEXTRA=${extra}"
      -P ${CMAKE_CURRENT_SOURCE_DIR}/run_game_test.cmake)
endforeach()

# Coverage report for the engine core (requires MVL_COVERAGE=ON and gcovr).
find_program(GCOVR gcovr)
if(MVL_COVERAGE AND GCOVR)
  add_custom_target(coverage
    COMMAND ${GCOVR} --root ${CMAKE_SOURCE_DIR} --filter ${CMAKE_SOURCE_DIR}/engine/src/core/
            --print-summary --fail-under-line 95
            --html-details ${CMAKE_BINARY_DIR}/coverage/index.html
            --xml ${CMAKE_BINARY_DIR}/coverage/coverage.xml
            ${CMAKE_BINARY_DIR}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Measuring engine core coverage (minimum 95% lines)")
  file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/coverage)
endif()

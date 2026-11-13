# Multiversal Van Life - unit tests, automated game tests and coverage.
set(MVL_TEST_TMP ${CMAKE_CURRENT_BINARY_DIR}/tmp)
find_package(Python3 COMPONENTS Interpreter)
file(MAKE_DIRECTORY ${MVL_TEST_TMP})

file(GLOB MVL_UNIT_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/unit/*.c)
add_executable(mvl_unit_tests ${MVL_UNIT_SOURCES})
target_link_libraries(mvl_unit_tests PRIVATE mvl_core)
target_include_directories(mvl_unit_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/unit)
target_compile_definitions(mvl_unit_tests PRIVATE MVL_TEST_TMP="${MVL_TEST_TMP}"
                                                  MVL_TEST_DATA="${CMAKE_CURRENT_SOURCE_DIR}/unit/data")
add_test(NAME unit COMMAND mvl_unit_tests)

# Automated game tests: the real Lua game driven by scripted input through
# the headless runner. Each test gets a fresh save folder, seeded from
# game/saves/<test name> when that folder exists.
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
      -DSEED=${CMAKE_CURRENT_SOURCE_DIR}/game/saves/${test_name}
      -DTEST=${test_file}
      "-DEXTRA=${extra}"
      -P ${CMAKE_CURRENT_SOURCE_DIR}/run_game_test.cmake)
endforeach()

# The world bible exporter (mvl_headless --bible ADDRESS --out FILE).
add_test(NAME tools.bible
  COMMAND ${CMAKE_COMMAND}
    -DRUNNER=$<TARGET_FILE:mvl_headless>
    -DDATA=${CMAKE_SOURCE_DIR}/game
    -DSAVE=${MVL_TEST_TMP}/save_bible
    -DOUT=${MVL_TEST_TMP}/bible.md
    -P ${CMAKE_CURRENT_SOURCE_DIR}/run_bible_test.cmake)

# Documented Lua examples (docs/*.md blocks marked <!-- example -->) must run.
if(Python3_FOUND)
  add_test(NAME docs.examples
    COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/doc_examples.py
      $<TARGET_FILE:mvl_headless> ${CMAKE_SOURCE_DIR}/game ${MVL_TEST_TMP}/docs
      ${CMAKE_SOURCE_DIR}/docs/MODDING.md ${CMAKE_SOURCE_DIR}/docs/WORLDGEN.md)
endif()

# Optional: run the same game tests through the real SDL3/OpenGL game
# (needs a display, e.g. `xvfb-run ctest -L gl` on Linux CI with Mesa).
option(MVL_GL_TESTS "Also run game tests with the real OpenGL renderer" OFF)
if(MVL_GL_TESTS AND TARGET multiversal_van_life)
  foreach(test_file ${MVL_GAME_TESTS})
    get_filename_component(test_name ${test_file} NAME_WE)
    set(extra "--mute")
    if(test_name STREQUAL "test_mods")
      set(extra --mute --mods ${CMAKE_CURRENT_SOURCE_DIR}/game/mods)
    endif()
    add_test(NAME gl.${test_name}
      COMMAND ${CMAKE_COMMAND}
        -DRUNNER=$<TARGET_FILE:multiversal_van_life>
        -DDATA=${CMAKE_SOURCE_DIR}/game
        -DSAVE=${MVL_TEST_TMP}/glsave_${test_name}
        -DSEED=${CMAKE_CURRENT_SOURCE_DIR}/game/saves/${test_name}
        -DTEST=${test_file}
        "-DEXTRA=${extra}"
        -P ${CMAKE_CURRENT_SOURCE_DIR}/run_game_test.cmake)
    set_tests_properties(gl.${test_name} PROPERTIES LABELS gl)
  endforeach()
  # OpenGL-only tests with screenshot checks (tests/gl)
  file(GLOB MVL_GL_TESTS ${CMAKE_CURRENT_SOURCE_DIR}/gl/test_*.lua)
  foreach(test_file ${MVL_GL_TESTS})
    get_filename_component(test_name ${test_file} NAME_WE)
    get_filename_component(test_dir ${test_file} DIRECTORY)
    add_test(NAME gl.${test_name}
      COMMAND ${CMAKE_COMMAND}
        -DRUNNER=$<TARGET_FILE:multiversal_van_life>
        -DDATA=${CMAKE_SOURCE_DIR}/game
        -DWORK=${MVL_TEST_TMP}/gl_${test_name}
        -DTEST=${test_file}
        -DCHECKS=${test_dir}/${test_name}.json
        -DPYTHON=${Python3_EXECUTABLE}
        -P ${CMAKE_CURRENT_SOURCE_DIR}/gl/run_gl_test.cmake)
    set_tests_properties(gl.${test_name} PROPERTIES LABELS gl)
  endforeach()
  add_test(NAME gl.screenshot
    COMMAND $<TARGET_FILE:multiversal_van_life> --mute --data ${CMAKE_SOURCE_DIR}/game
            --save ${MVL_TEST_TMP}/glsave_shot --frames 90 --screenshot ${CMAKE_BINARY_DIR}/screenshot.tga)
  set_tests_properties(gl.screenshot PROPERTIES LABELS gl)
endif()

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

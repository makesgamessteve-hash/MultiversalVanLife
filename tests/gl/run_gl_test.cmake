# Runs one OpenGL test script in the real game and checks its screenshots.
file(REMOVE_RECURSE ${WORK})
file(MAKE_DIRECTORY ${WORK}/save)
execute_process(
  COMMAND ${RUNNER} --mute --data ${DATA} --save ${WORK}/save --shots ${WORK} --test ${TEST}
  RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "GL test ${TEST} failed (exit code ${rc})")
endif()
if(EXISTS ${CHECKS})
  execute_process(COMMAND ${PYTHON} ${CMAKE_CURRENT_LIST_DIR}/check_shot.py ${WORK} ${CHECKS} RESULT_VARIABLE rc)
  if(NOT rc EQUAL 0)
    message(FATAL_ERROR "screenshot checks failed for ${TEST}")
  endif()
endif()

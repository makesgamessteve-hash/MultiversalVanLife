# Runs one automated game test with a fresh save folder.
file(REMOVE_RECURSE ${SAVE})
file(MAKE_DIRECTORY ${SAVE})
set(extra_args ${EXTRA})
execute_process(
  COMMAND ${RUNNER} --data ${DATA} --save ${SAVE} --test ${TEST} ${extra_args}
  RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "game test ${TEST} failed (exit code ${rc})")
endif()

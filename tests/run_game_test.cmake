# Runs one automated game test with a fresh save folder. If SEED names a
# folder (tests/game/saves/<test name>), the save folder starts as a copy.
file(REMOVE_RECURSE ${SAVE})
file(MAKE_DIRECTORY ${SAVE})
if(SEED AND IS_DIRECTORY ${SEED})
  file(COPY ${SEED}/ DESTINATION ${SAVE})
endif()
set(extra_args ${EXTRA})
execute_process(
  COMMAND ${RUNNER} --data ${DATA} --save ${SAVE} --test ${TEST} ${extra_args}
  RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "game test ${TEST} failed (exit code ${rc})")
endif()

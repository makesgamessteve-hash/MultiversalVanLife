# Runs the headless runner as a tool (variety statistics, budgets) with
# ARGS (a ;-list). With EXPECT naming a text, the run must fail and print
# it (the tool catches a deliberately biased or slowed generator);
# otherwise it must succeed.
file(REMOVE_RECURSE ${SAVE})
file(MAKE_DIRECTORY ${SAVE})
execute_process(
  COMMAND ${RUNNER} --data ${DATA} --save ${SAVE} ${ARGS}
  RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE err)
message("${out}")
if(EXPECT)
  if(rc EQUAL 0)
    message(FATAL_ERROR "the tool should have failed (expected '${EXPECT}')")
  endif()
  string(FIND "${out}${err}" "${EXPECT}" at)
  if(at EQUAL -1)
    message(FATAL_ERROR "the tool failed without naming '${EXPECT}':\n${err}")
  endif()
elseif(NOT rc EQUAL 0)
  message(FATAL_ERROR "the tool failed (exit code ${rc}):\n${err}")
endif()

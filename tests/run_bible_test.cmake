# Runs the world bible exporter on a cosmos address and checks the result.
file(REMOVE ${OUT})
execute_process(
  COMMAND ${RUNNER} --data ${DATA} --save ${SAVE} --bible u1.g2.c3 --seed 77 --out ${OUT}
  RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "bible export failed (exit code ${rc})")
endif()
file(READ ${OUT} text)
foreach(want "# World bible: Cluster u1.g2.c3" "Root seed 77" "## Multiverse" "## Universe u1" "## Galaxy u1.g2"
             "## Cluster u1.g2.c3")
  string(FIND "${text}" "${want}" at)
  if(at EQUAL -1)
    message(FATAL_ERROR "bible lacks '${want}':\n${text}")
  endif()
endforeach()

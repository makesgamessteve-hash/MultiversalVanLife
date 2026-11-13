# Runs the world bible exporter on a reference star system and checks it.
file(REMOVE ${OUT})
execute_process(
  COMMAND ${RUNNER} --data ${DATA} --save ${SAVE} --bible u1.g2.c3.s1 --seed 77 --out ${OUT}
  RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "bible export failed (exit code ${rc})")
endif()
file(READ ${OUT} text)
foreach(want "# World bible: System u1.g2.c3.s1" "Root seed 77" "## Multiverse" "## Universe u1" "## Galaxy u1.g2"
             "## Cluster u1.g2.c3" "## System u1.g2.c3.s1" "billion years old" "kiloparsecs across" "cluster of"
             "frost line at" "Planets: " "### Places inside" "u1/laws/1")
  string(FIND "${text}" "${want}" at)
  if(at EQUAL -1)
    message(FATAL_ERROR "bible lacks '${want}':\n${text}")
  endif()
endforeach()

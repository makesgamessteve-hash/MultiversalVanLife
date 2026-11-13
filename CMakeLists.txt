cmake_minimum_required(VERSION 3.20)
project(MultiversalVanLife VERSION 0.1.0 LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(MVL_BUILD_GAME     "Build the SDL3/OpenGL game executable" ON)
option(MVL_BUILD_TESTS    "Build unit and game tests" ON)
option(MVL_COVERAGE       "Instrument the engine core for coverage (gcc/clang)" OFF)
option(MVL_FETCH_SDL      "Download and build SDL3 if it is not installed" ON)

if(EMSCRIPTEN)
  set(MVL_BUILD_TESTS OFF CACHE BOOL "" FORCE)
endif()

if(MSVC)
  add_compile_options(/W3 /D_CRT_SECURE_NO_WARNINGS)
else()
  add_compile_options(-Wall -Wextra -Wno-unused-parameter)
  if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
    add_compile_options(-Wno-format-truncation)
  endif()
endif()

# --------------------------------------------------------------------------
# Lua 5.4 (vendored, MIT)
# --------------------------------------------------------------------------
file(GLOB LUA_SOURCES ${CMAKE_SOURCE_DIR}/third_party/lua/*.c)
add_library(mvl_lua STATIC ${LUA_SOURCES})
target_include_directories(mvl_lua PUBLIC ${CMAKE_SOURCE_DIR}/third_party/lua)
if(NOT MSVC)
  target_compile_options(mvl_lua PRIVATE -w)
endif()
if(UNIX AND NOT APPLE AND NOT EMSCRIPTEN)
  target_compile_definitions(mvl_lua PRIVATE LUA_USE_LINUX)
elseif(APPLE)
  target_compile_definitions(mvl_lua PRIVATE LUA_USE_MACOSX)
endif()
if(UNIX)
  target_link_libraries(mvl_lua PUBLIC m)
endif()

# dr_mp3 (vendored, public domain / MIT-0): MP3 decoding for music
add_library(mvl_drmp3 STATIC ${CMAKE_SOURCE_DIR}/third_party/dr_libs/dr_mp3.c)
target_include_directories(mvl_drmp3 PUBLIC ${CMAKE_SOURCE_DIR}/third_party/dr_libs)
if(NOT MSVC)
  target_compile_options(mvl_drmp3 PRIVATE -w)
endif()

# --------------------------------------------------------------------------
# Engine core: platform independent, no SDL / OpenGL. Fully unit tested.
# --------------------------------------------------------------------------
file(GLOB MVL_CORE_SOURCES CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/engine/src/core/*.c)
add_library(mvl_core STATIC ${MVL_CORE_SOURCES})
target_include_directories(mvl_core PUBLIC ${CMAKE_SOURCE_DIR}/engine/src)
target_link_libraries(mvl_core PUBLIC mvl_lua mvl_drmp3)
# Procedural generation must be bit-identical on every platform: forbid
# fused multiply-add contraction and other value-changing float rewrites.
if(MSVC)
  target_compile_options(mvl_core PRIVATE /fp:precise)
else()
  target_compile_options(mvl_core PRIVATE -ffp-contract=off -fno-fast-math)
endif()
if(MVL_COVERAGE AND NOT MSVC)
  target_compile_options(mvl_core PRIVATE --coverage -O0 -g)
  target_link_options(mvl_core PUBLIC --coverage)
endif()

# Copies the moddable data folder next to a target's binary.
# Runs on every build so script and asset edits are always picked up.
function(mvl_copy_data target)
  add_custom_target(${target}_data ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            ${CMAKE_SOURCE_DIR}/game $<TARGET_FILE_DIR:${target}>/game
    COMMENT "Copying game data next to ${target}")
  add_dependencies(${target} ${target}_data)
endfunction()

# Headless runner: no window/GPU/audio device. Runs automated game tests.
if(NOT EMSCRIPTEN)
  add_executable(mvl_headless ${CMAKE_SOURCE_DIR}/engine/src/headless_main.c)
  target_link_libraries(mvl_headless PRIVATE mvl_core)
endif()

# --------------------------------------------------------------------------
# Game executable (SDL3 + OpenGL / WebGL2)
# --------------------------------------------------------------------------
if(MVL_BUILD_GAME)
  find_package(SDL3 CONFIG QUIET)
  if(NOT SDL3_FOUND)
    if(NOT MVL_FETCH_SDL)
      message(FATAL_ERROR "SDL3 not found. Set CMAKE_PREFIX_PATH or enable MVL_FETCH_SDL.")
    endif()
    include(FetchContent)
    set(SDL_SHARED OFF CACHE BOOL "" FORCE)
    set(SDL_STATIC ON CACHE BOOL "" FORCE)
    set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
    set(SDL_TESTS OFF CACHE BOOL "" FORCE)
    set(SDL_EXAMPLES OFF CACHE BOOL "" FORCE)
    FetchContent_Declare(SDL3
      GIT_REPOSITORY https://github.com/libsdl-org/SDL.git
      GIT_TAG release-3.2.24
      GIT_SHALLOW TRUE)
    FetchContent_MakeAvailable(SDL3)
  endif()

  file(GLOB MVL_PLATFORM_SOURCES ${CMAKE_SOURCE_DIR}/engine/src/platform/*.c)
  add_executable(multiversal_van_life ${MVL_PLATFORM_SOURCES})
  target_link_libraries(multiversal_van_life PRIVATE mvl_core SDL3::SDL3)

  if(EMSCRIPTEN)
    set_target_properties(multiversal_van_life PROPERTIES SUFFIX ".html")
    target_link_options(multiversal_van_life PRIVATE
      -sMAX_WEBGL_VERSION=2 -sMIN_WEBGL_VERSION=2 -sFULL_ES3=1
      -sALLOW_MEMORY_GROWTH=1 -sSTACK_SIZE=1048576
      -sEXPORTED_FUNCTIONS=_main,_mvl_xr_frame,_mvl_xr_session_ended,_mvl_web_set_touch,_mvl_web_save_synced
      -sEXPORTED_RUNTIME_METHODS=ccall,cwrap,FS,HEAPF32
      -lidbfs.js
      --js-library ${CMAKE_SOURCE_DIR}/web/library_webxr.js
      --pre-js ${CMAKE_SOURCE_DIR}/web/pre.js
      --shell-file ${CMAKE_SOURCE_DIR}/web/shell.html
      --preload-file ${CMAKE_SOURCE_DIR}/game@/game)
    # repackage the preloaded data whenever anything in game/ changes
    file(GLOB_RECURSE MVL_GAME_FILES CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/game/*)
    set_property(TARGET multiversal_van_life APPEND PROPERTY LINK_DEPENDS ${MVL_GAME_FILES})
    set_property(TARGET multiversal_van_life APPEND PROPERTY LINK_DEPENDS
      ${CMAKE_SOURCE_DIR}/web/shell.html ${CMAKE_SOURCE_DIR}/web/library_webxr.js ${CMAKE_SOURCE_DIR}/web/pre.js)
  else()
    if(WIN32)
      set_target_properties(multiversal_van_life PROPERTIES WIN32_EXECUTABLE OFF)
    endif()
    if(APPLE)
      target_link_libraries(multiversal_van_life PRIVATE "-framework OpenGL")
    endif()
    mvl_copy_data(multiversal_van_life)
  endif()
endif()

# --------------------------------------------------------------------------
# Tests
# --------------------------------------------------------------------------
if(MVL_BUILD_TESTS)
  enable_testing()
  add_subdirectory(tests)
endif()

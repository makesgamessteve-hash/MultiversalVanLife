/* Multiversal Van Life - internals shared by the Lua binding files. MIT License. */
#ifndef MVL_SCRIPT_INTERNAL_H
#define MVL_SCRIPT_INTERNAL_H

#include "core/engine.h"
#include "lauxlib.h"
#include "lua.h"

mvl_engine *mvl_script_engine(lua_State *L);
/* Adds the procedural generation functions to the table at the top of the stack. */
void mvl_script_open_procedural(lua_State *L);
/* Adds the planet kernels (planet grid, tectonics, climate, rivers, territories). */
void mvl_script_open_planet(lua_State *L);

#endif

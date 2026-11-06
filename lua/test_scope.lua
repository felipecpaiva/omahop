-- Plain Lua self-check:  lua lua/test_scope.lua
local dir = arg[0]:match("^(.*)/") or "."
local S = dofile(dir .. "/scope.lua")
local F = 'o.workspace_mode({ workspace = "1", mode = "floating" })\n'
local D = 'o.workspace_mode({ workspace = "2", mode = "dwindle" })\n'
local DEF_F = 'o.workspace_mode({ default = "floating" })\n'
local DEF_D = 'o.workspace_mode({ default = "dwindle" })\n'

assert(S.workspace_floating(F, nil, false) == true, "own file says floating")
assert(S.workspace_floating(D, DEF_F, true) == false, "own file wins over the default and over a stale tag")
assert(S.workspace_floating(nil, DEF_F, false) == true, "no own file: the saved default")
assert(S.workspace_floating(nil, DEF_D, true) == false, "default dwindle: tiling")
assert(S.workspace_floating(nil, nil, true) == true, "nothing saved, tagged window: floating")
assert(S.workspace_floating(nil, nil, false) == false, "nothing saved, no tag: tiling")
assert(S.workspace_floating("garbage", nil, false) == false, "unreadable file is not floating")
assert(S.active("floating", true) and not S.active("floating", false), "scope floating needs a floating workspace")
assert(S.active("all", false) and S.active("all", true), "scope all is always active")
print("scope ok")

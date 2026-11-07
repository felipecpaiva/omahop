-- Plain Lua self-check:  lua lua/test_action_keys.lua
local dir = arg[0]:match("^(.*)/") or "."
local A = dofile(dir .. "/action_keys.lua")
local known = { close = true, minimize = true }

local m, p = A.parse("q=close, M = Minimize", known)
assert(m.q == "close" and m.m == "minimize" and #p == 0, "keys and names lower case, spaces ignored")
assert(next((A.parse("", known))) == nil and next((A.parse(nil, known))) == nil, "empty is off")

m, p = A.parse("q=close, x=nope, ab=close, delete=close, =close, noequals, 5=minimize", known)
assert(m.q == "close" and m["5"] == "minimize" and m.x == nil and m.ab == nil, "bad items are skipped, good ones kept")
assert(#p == 5, "each bad item is reported, got " .. #p)

-- conflicts with hints: numbers claim 1-9, apps claim the mapped letters; hints off claims nothing
local u, c = A.drop_conflicts({ q = "close", ["3"] = "close", ["0"] = "minimize" }, "numbers", {})
assert(u.q and u["0"] and u["3"] == nil and #c == 1, "a digit 1-9 clashes with number hints, 0 does not")
u, c = A.drop_conflicts({ q = "close", c = "minimize" }, "apps", { c = "chrome" })
assert(u.q and u.c == nil and #c == 1 and c[1]:find("hint"), "a mapped app letter clashes")
u, c = A.drop_conflicts({ q = "close", ["3"] = "close" }, "off", { q = "x" })
assert(u.q and u["3"] and #c == 0, "hints off: no clash")

u, c = A.resolve("q=close, c=minimize, z=bogus", known, "apps", { c = "chrome" })
assert(u.q == "close" and u.c == nil and #c == 2, "resolve reports parse problems and clashes together")
print("action_keys ok")

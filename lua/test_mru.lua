-- Plain Lua self-check:  lua lua/test_mru.lua
local dir = arg[0]:match("^(.*)/") or "."
local M = dofile(dir .. "/mru.lua")

local function addrs(list) local t = {} for i, w in ipairs(list) do t[i] = w.address end return table.concat(t, ",") end
local function win(a, min) return { address = a, minimized = min or false } end

-- touch and forget
local o = M.touch(M.touch(M.touch({}, "a"), "b"), "c")
assert(table.concat(o, ",") == "c,b,a", "touch puts the newest first")
assert(table.concat(M.touch(o, "a"), ",") == "a,c,b", "touch moves an old one to the front, no duplicate")
assert(table.concat(M.forget(o, "b"), ",") == "c,a", "forget drops it")
assert(table.concat(o, ",") == "c,b,a", "inputs are not mutated")

-- sort: known first by order, unknown keep given order after them, minimized last
local ws = { win("x"), win("a"), win("m", true), win("b"), win("y") }
assert(addrs(M.sort({ "b", "a" }, ws)) == "b,a,x,y,m", "known by order, unknown after in given order, minimized last")
-- L12: after a shell restart the order is empty; a minimized window must still not lead
assert(addrs(M.sort({}, { win("m", true), win("p"), win("q") })) == "p,q,m", "minimized last with empty history")
assert(addrs(M.sort({ "m", "a" }, { win("a"), win("m", true) })) == "a,m", "minimized last even when most recent")
assert(addrs(M.sort({ "a" }, {})) == "", "empty windows")

-- first_pick: tap flips between two; backward starts at the last
local l = { win("a"), win("b"), win("c") }
assert(M.first_pick(l, "a", 1) == 2, "focused leads: pick the previous one")
assert(M.first_pick(l, "b", 1) == 1, "focus is not the most recent (changed by mouse): the most recent other window")
assert(M.first_pick(l, nil, 1) == 1, "nothing focused: first")
assert(M.first_pick(l, "a", -1) == 3, "backward: the last")
assert(M.first_pick(l, "c", -1) == 2, "backward when the focused one is last: the one before")
assert(M.first_pick({ win("a") }, "a", 1) == 1, "one window: itself")
assert(M.first_pick({}, nil, 1) == 0, "no windows: 0")

print("mru ok")

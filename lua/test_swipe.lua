-- Plain Lua self-check:  lua lua/test_swipe.lua
local dir = arg[0]:match("^(.*)/") or "."
local W = dofile(dir .. "/swipe.lua")

-- nothing happens before start, or after finish
local s = W.new(100)
assert(not s:is_active() and s:update(0, 500) == 0, "an update before start is ignored")

-- small moves add up; the first whole row opens, later rows do not
s:start(0)
local r, first = s:update(10, 40)
assert(r == 0 and not first, "40 px is no row yet")
r, first = s:update(20, 70)
assert(r == 1 and first, "110 px in total: one row to the right, the first one")
assert(math.type(r) == "integer", "rows are integers")
r, first = s:update(30, 95)
assert(r == 1 and not first, "the 10 px left over plus 95: the second row, not a first")
r = s:update(40, -230)
assert(r == -2, "back 230 px from 5 px over: two rows to the left, got " .. tostring(r))
r = s:update(50, 350)
assert(r == 3, "a fast flick crosses several rows in one update, got " .. tostring(r))

-- leftward first: the first row is negative
local l = W.new(80)
l:start(0)
r, first = l:update(1, -90)
assert(r == -1 and first, "a left swipe opens with a step back")

-- bad deltas never move anything and never break the sum
local b = W.new(100)
b:start(0)
for _, bad in ipairs({ "x", 0 / 0, math.huge, -math.huge }) do
  assert(b:update(1, bad) == 0, "a delta that is not a finite number is ignored: " .. tostring(bad))
end
assert(b:update(1, nil) == 0, "a missing delta is ignored")
assert(b:update(2, 100) == 1, "the sum is intact after bad deltas")

-- finish reports whether the list was opened, and ends the swipe
local f = W.new(100)
f:start(0); f:update(1, 20)
assert(f:finish() == false and not f:is_active(), "a swipe that never crossed a row did not open the list")
f:start(0); f:update(1, 120)
assert(f:finish() == true and not f:is_active(), "a swipe that crossed a row opened the list")
assert(f:finish() == false, "a second finish is a no-op")

-- idle: fingers down with no event for W.idle_ms expires; any event moves the deadline
local i = W.new(100)
i:start(1000)
assert(not i:expired(1000 + W.idle_ms - 1), "not yet expired")
i:update(1000 + W.idle_ms - 1, 1)
assert(not i:expired(1000 + W.idle_ms + 5), "an update moves the deadline")
assert(i:expired(1000 + 2 * W.idle_ms), "expired after a quiet stretch")
i:stop()
assert(not i:expired(1e9) and not i:is_active(), "a stopped swipe never expires")

print("swipe ok")

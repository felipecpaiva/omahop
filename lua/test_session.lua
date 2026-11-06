-- Plain Lua self-check:  lua lua/test_session.lua
local dir = arg[0]:match("^(.*)/") or "."
local S = dofile(dir .. "/session.lua")
local C = dofile(dir .. "/config.lua")
local cfg = C.merge(nil) -- reveal 100, repeat delay 250, repeat 40

local function types(acts) local t = {} for i, a in ipairs(acts) do t[i] = a.type .. (a.index and (":" .. a.index) or "") end return table.concat(t, ",") end
local function ticks(s, from, to, keys)  -- tick every 25 ms; returns "time=actions" for each tick that did something
  local all = {}
  for t = from, to, 25 do
    local a = types(s:tick(t, keys)); if a ~= "" then all[#all + 1] = t .. "=" .. a end
  end
  return table.concat(all, " ")
end
local HELD, TABDOWN, GONE = { alt = true, tab = false }, { alt = true, tab = true }, { alt = false, tab = false }

-- quick tap: Alt gone before the reveal delay commits the first pick and never reveals
local s = S.new(cfg)
assert(types(s:open(0, 3, 2)) == "select:2", "open selects the first pick")
assert(ticks(s, 25, 25, HELD) == "", "held: nothing")
assert(ticks(s, 50, 75, GONE) == "75=commit:2", "Alt gone on two ticks in a row commits; one tick is not enough")
assert(not s:is_open(), "closed after commit")

-- hold: reveal at the delay, Tab steps, release commits the selection
s = S.new(cfg); s:open(0, 3, 2)
assert(ticks(s, 25, 100, HELD) == "100=reveal", "reveal exactly at the delay")
assert(types(s:step(120, 1)) == "select:3", "Tab moves on")
assert(types(s:step(140, 1)) == "select:1", "wraps forward")
assert(types(s:step(160, -1)) == "select:3", "Shift+Tab wraps backward")
assert(ticks(s, 175, 200, GONE) == "200=commit:3", "release commits what was picked")

-- hold Tab: waits the repeat delay, then repeats at the interval, in the pressed direction
s = S.new(cfg); s:open(0, 5, 2); s:step(0, 1)
local rep = ticks(s, 25, 400, TABDOWN)
local n = select(2, rep:gsub("select", ""))
assert(rep:find("100=reveal") and n == 4, "four repeats between 250 and 400 ms, got: " .. rep)
assert(not rep:find("^25="), "no repeat before the delay")
s = S.new(cfg); s:open(0, 5, 2); s:step(0, -1)
assert(types(s:tick(250, TABDOWN)) == "reveal,select:5", "Shift+Tab repeats backward (2 -> 1 by the press, then 5 by the repeat)")
-- a fresh press resets the repeat delay
s = S.new(cfg); s:open(0, 5, 3); s:step(0, 1); s:tick(250, TABDOWN); s:step(300, 1)
assert(types(s:tick(400, TABDOWN)) == "" and types(s:tick(550, TABDOWN)) == "select:" .. s:selected(), "after a new press the delay applies again: nothing at +100, a repeat at +250")

-- escape cancels, return commits, arrows move
s = S.new(cfg); s:open(0, 3, 2)
assert(types(s:key(10, "down")) == "select:3" and types(s:key(10, "up")) == "select:2", "arrows")
assert(types(s:key(10, "escape")) == "cancel" and not s:is_open(), "escape cancels")
assert(types(s:tick(30, GONE)) == "", "nothing after the session closed")
s:open(0, 3, 2); assert(types(s:key(10, "return")) == "commit:2", "return commits")
assert(types(s:key(10, "x")) == "", "unknown key on a closed session")

-- Alt unknown (nil) counts as held; a single glitch does not end the session (stuck-drag lesson)
s = S.new(cfg); s:open(0, 3, 2)
assert(ticks(s, 25, 500, { alt = nil, tab = nil }) == "100=reveal", "nil Alt never commits")
assert(types(s:tick(525, GONE)) == "" and types(s:tick(550, HELD)) == "" and s:is_open(), "one gone tick then held again: still open")
assert(types(s:tick(575, GONE)) == "" and types(s:tick(600, GONE)) == "commit:2", "two in a row ends it")

-- failsafe
s = S.new(cfg); s:open(0, 3, 2)
assert(types(s:tick(S.max_ms + 1, HELD)) == "cancel" and not s:is_open(), "a session never outlives max_ms")

-- no windows: nothing opens; a closed session can open again
s = S.new(cfg)
assert(types(s:open(0, 0, 0)) == "" and not s:is_open(), "no windows, no session")
s:open(0, 2, 2); s:key(1, "escape")
assert(types(s:open(5, 2, 1)) == "select:1" and s:is_open(), "reopens after finishing")
assert(types(s:open(6, 2, 1)) == "", "open while open is ignored")

-- zero reveal delay reveals on the first tick
local c0 = C.merge({ top = { reveal_delay_ms = 0 } })
s = S.new(c0); s:open(0, 3, 2)
assert(types(s:tick(25, HELD)) == "reveal", "reveal delay 0")

print("session ok")

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
local HELD, TABDOWN, GONE = { mod = true, tab = false }, { mod = true, tab = true }, { mod = false, tab = false }

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
assert(ticks(s, 25, 500, { mod = nil, tab = nil }) == "100=reveal", "nil Alt never commits")
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

-- resize (search changed the list): new size and selection; an empty list never moves or breaks
s = S.new(cfg); s:open(0, 5, 3)
s:resize(2, 1)
assert(s:selected() == 1 and types(s:step(10, 1)) == "select:2" and types(s:step(20, 1)) == "select:1", "wraps inside the new size")
s:resize(0, 0)
assert(types(s:step(30, 1)) == "select:0" and types(s:key(30, "down")) == "select:0", "empty list: selection stays 0, no error")
assert(types(s:key(40, "return")) == "commit:0", "committing an empty list reports index 0 (the glue activates nothing)")
s = S.new(cfg); s:resize(3, 1); assert(not s:is_open(), "resize on a closed session does nothing")

-- linger (search_linger_seconds): Alt up with a search typed keeps the list open until a key, a pick or the deadline
local cl = C.merge({ top = { search_linger_seconds = 3 } })
-- empty query: Alt up commits as today, linger on or off
s = S.new(cl); s:open(0, 3, 2)
assert(ticks(s, 25, 50, GONE) == "50=commit:2", "linger on, nothing typed: Alt up commits")
-- a query and linger 0: commits as today
s = S.new(cfg); s:open(0, 3, 2); s:mark_query(true)
assert(ticks(s, 25, 50, GONE) == "50=commit:2", "linger off, a query typed: Alt up commits")
-- a query and linger 3 s: lingers (revealed at once if the delay had not passed), never commits on Alt
s = S.new(cl); s:open(0, 3, 2); s:mark_query(true)
assert(ticks(s, 25, 50, GONE) == "50=reveal,linger" and s:is_lingering() and s:is_revealed(), "linger: reveal and linger at the second Alt-up tick")
local rev0 = s:linger_rev()
assert(ticks(s, 75, 3025, GONE) == "", "nothing until the deadline (Alt up and Tab do nothing)")
assert(ticks(s, 75, 3025, TABDOWN) == "", "Tab held while lingering does not repeat (bare Tab now reaches the overlay)")
-- touch restarts the deadline and bumps the revision the overlay animates from
s:touch(3000)
assert(s:linger_rev() == rev0 + 1, "touch bumps the revision")
assert(types(s:tick(5999, GONE)) == "" and s:is_open(), "deadline moved to 6000")
-- timeout cancels, never commits
assert(types(s:tick(6000, GONE)) == "cancel" and not s:is_open() and not s:is_lingering(), "timeout cancels")
-- a key restarts the deadline too; Return commits while lingering
s = S.new(cl); s:open(0, 3, 2); s:mark_query(true); ticks(s, 25, 50, GONE)
assert(types(s:key(2000, "down")) == "select:3" and types(s:tick(4999, GONE)) == "", "an arrow moves and restarts the deadline")
assert(types(s:key(4000, "return")) == "commit:3" and not s:is_open(), "Return picks while lingering")
-- Escape clears, then cancels
s = S.new(cl); s:open(0, 3, 2); s:mark_query(true); ticks(s, 25, 50, GONE)
assert(types(s:key(100, "escape")) == "clear" and s:is_open() and s:is_lingering(), "first Escape clears the search, the list stays")
assert(types(s:key(200, "escape")) == "cancel" and not s:is_open(), "second Escape cancels")
-- cancel (a click outside the list) ends at once, search or not
s = S.new(cl); s:open(0, 3, 2); s:mark_query(true); ticks(s, 25, 50, GONE)
assert(types(s:key(100, "cancel")) == "cancel" and not s:is_open(), "cancel ends the session")
-- Escape while Alt is held with a search: clears too (the old glue rule, now here)
s = S.new(cfg); s:open(0, 3, 2); s:mark_query(true)
assert(types(s:key(10, "escape")) == "clear" and types(s:key(20, "escape")) == "cancel", "Alt held: clear then cancel")
-- the failsafe still ends a non-lingering session, and a lingering one is bound by its deadline only
s = S.new(cl); s:open(0, 3, 2); s:mark_query(true)
assert(types(s:tick(S.max_ms + 1, HELD)) == "cancel", "failsafe for a held session with linger on")
s = S.new(cl); s:open(0, 3, 2); s:mark_query(true); s:tick(S.max_ms - 50, GONE); s:tick(S.max_ms - 25, GONE)
assert(s:is_lingering() and types(s:tick(S.max_ms + 100, GONE)) == "" and types(s:tick(S.max_ms - 25 + 3000, GONE)) == "cancel", "lingering past max_ms: the deadline decides")
-- a reopened session starts not lingering
s:open(0, 3, 2); assert(not s:is_lingering(), "a new session is not lingering")
-- touch on a session that is not lingering does nothing
s = S.new(cl); s:open(0, 3, 2); local r = s:linger_rev(); s:touch(10); assert(s:linger_rev() == r, "touch outside lingering does nothing")

-- sequence numbers from the overlay: only newer integers pass
assert(S.newer(0, 1) == 1 and S.newer(4, "5") == 5 and S.newer(nil, 3) == 3, "newer seq accepted")
assert(S.newer(5, 5) == nil and S.newer(5, 4) == nil, "same or older seq rejected")
assert(S.newer(0, "x") == nil and S.newer(0, 2.5) == nil and S.newer(0, nil) == nil and S.newer(0, "1;os.exit()") == nil, "non integers rejected")

print("session ok")

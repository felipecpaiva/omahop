-- Plain Lua self-check with a fake Hyprland:  lua lua/test_glue.lua   (Lua 5.5, like Hyprland)
-- Needs its own XDG dirs, so it re-runs itself once with temporary ones.
if not os.getenv("OMAHOP_TEST_DIR") then
  local dir = os.tmpname(); os.remove(dir)
  os.execute(("mkdir -p '%s/run' '%s/state/omarchy/workspace-layouts' '%s/cfg/omahop'"):format(dir, dir, dir))
  local lay = io.open(dir .. "/state/omarchy/workspace-layouts/1.lua", "w"); lay:write('o.workspace_mode({ workspace = "1", mode = "floating" })\n'); lay:close()
  local cmd = ("OMAHOP_TEST_DIR='%s' XDG_RUNTIME_DIR='%s/run' XDG_STATE_HOME='%s/state' XDG_CONFIG_HOME='%s/cfg' lua '%s'"):format(dir, dir, dir, dir, arg[0])
  local ok = os.execute(cmd)
  os.execute("rm -rf '" .. dir .. "'")
  os.exit(ok and 0 or 1)
end

local here = arg[0]:match("^(.*)/") or "."
local TESTDIR = os.getenv("OMAHOP_TEST_DIR")

-- ---- a fake hl ----
local binds, dispatched, timers, key_state, handlers = {}, {}, {}, {}, {}
local windows, active = {}, nil
local clock = 1000
local function win(addr, class, ws, extra)
  local w = { address = addr, class = class, title = "title " .. addr, mapped = true, hidden = false, workspace = { id = ws, name = tostring(ws) },
    monitor = { name = "eDP-1" }, tags = {}, focus_history_id = 99 }
  for k, v in pairs(extra or {}) do w[k] = v end
  windows[#windows + 1] = w
  return w
end
local function dsp(name) return function(args) return { name = name, args = args } end end
hl = {
  dsp = { focus = dsp("focus"), send_key_state = dsp("send_key_state"),
    window = { move = dsp("move"), alter_zorder = dsp("alter_zorder"), cycle_next = dsp("cycle_next"), bring_to_top = dsp("bring_to_top") } },
  get_windows = function() return windows end,
  get_active_window = function() return active end,
  get_active_workspace = function() return active and active.workspace or { id = 1, name = "1" } end,
  get_active_monitor = function() return { name = "eDP-1" } end,
  get_workspace = function(id) return { id = tonumber(id), monitor = { name = "eDP-1" } } end,
  get_window = function(sel) for _, w in ipairs(windows) do if "address:" .. w.address == sel then return w end end end,
  dispatch = function(d) dispatched[#dispatched + 1] = d end,
  bind = function(chord, fn) binds[chord] = fn end,
  unbind = function(chord) binds[chord] = nil end,
  on = function(ev, fn) handlers[ev] = fn end,
  timer = function(fn, opts) timers[#timers + 1] = fn end,
  is_key_down = function(k) return key_state[k] end,
}
local function names() local t = {} for i, d in ipairs(dispatched) do t[i] = d.name end return table.concat(t, ",") end
local function run_timers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end
local function advance(ms, n) for _ = 1, n or 1 do clock = clock + ms; run_timers() end end
local function reset() dispatched = {} end  -- timers are kept: a session schedules its own tick
local function read_state() local f = io.open(TESTDIR .. "/run/omahop/state"); local t = f and f:read("a") or ""; if f then f:close() end return t end

-- fixture: floating workspace 1 holds a, b, c (a focused); tiling workspace 2 holds t
local a = win("0xa", "app-a", 1, { focus_history_id = 0, tags = { "omarchy-floating-workspace" } })
win("0xb", "app-b", 1, { focus_history_id = 1, tags = { "omarchy-floating-workspace" } })
win("0xc", "app-c", 1, { focus_history_id = 2, tags = { "omarchy-floating-workspace" } })
local t = win("0xt", "app-t", 2, { focus_history_id = 3 })
active = a

-- load with the default config
local M = dofile(here .. "/omahop.lua")
M.now = function() return clock end
assert(binds["ALT + TAB"] and binds["ALT + SHIFT + TAB"], "setup binds both chords")
local before = 0; for _ in pairs(binds) do before = before + 1 end
dofile(here .. "/omahop.lua")  -- idempotent: loading again must not add binds
M = _G.omahop; M.now = function() return clock end
local after = 0; for _ in pairs(binds) do after = after + 1 end
assert(before == after, "loading twice leaves the same binds")

-- Tab is physically down whenever a bind fires for a real press
key_state = { Alt_L = true, Alt_R = false, Tab = true }
-- in scope (floating workspace): Alt+Tab opens a session on the previous window and injects the key
binds["ALT + TAB"]()
assert(M.session:is_open() and M.session:selected() == 2, "session open on the previous window (b)")
assert(names() == "send_key_state,send_key_state", "the F24 key is injected (down and up) so the app does not see a bare Alt tap, got " .. names())
assert(binds["ALT + ESCAPE"] and binds["ALT + LEFT"], "session keys bound while open")
assert(read_state():find("open=1") and read_state():find("0xb"), "state file written with the entries")
assert(not read_state():find("0xt"), "tiling window not listed by default")

-- quick tap: Alt released -> after two ticks the previous window is raised
reset(); key_state = { Alt_L = false, Alt_R = false, Tab = false }
advance(25, 2)
assert(not M.session:is_open(), "session closed after Alt release")
assert(names() == "focus,alter_zorder", "focus then raise, got " .. names())
assert(dispatched[1].args.window.address == "0xb", "the previous window was picked")
assert(binds["ALT + ESCAPE"] == nil and binds["ALT + LEFT"] == nil, "session keys unbound after the session")
assert(read_state():find("open=0"), "state says closed")

-- hold: second Tab moves on, Escape cancels without activating
key_state = { Alt_L = true, Alt_R = false, Tab = true }; reset()
active = a; binds["ALT + TAB"](); binds["ALT + TAB"]()
assert(M.session:selected() == 3, "two Tabs: third entry")
reset(); binds["ALT + ESCAPE"]()
assert(not M.session:is_open() and names() == "", "escape cancels and activates nothing")

-- Shift+Tab starts on the last window
binds["ALT + SHIFT + TAB"]()
assert(M.session:selected() == 3, "Shift+Tab starts at the end")
reset(); key_state.Alt_L = false; key_state.Tab = false; advance(25, 2)
assert(dispatched[1].args.window.address == "0xc", "last window picked")

-- minimized window comes back to the active workspace first
local m = win("0xm", "app-m", -99, { focus_history_id = 9, workspace = { id = -99, name = "special:minimized" }, tags = { "omarchy-minimized-from-1" } })
key_state.Alt_L = true; key_state.Tab = true; reset(); active = a
binds["ALT + SHIFT + TAB"]()
assert(M.session:selected() == 4 and M.entries[4].address == "0xm" and M.entries[4].minimized, "minimized window is listed last")
reset(); key_state.Alt_L = false; advance(25, 2)
assert(names() == "move,focus,alter_zorder" and dispatched[1].args.workspace == "1", "minimized: move to workspace 1, then focus and raise")

-- out of scope (tiling workspace 2): stock behaviour, no session
key_state.Alt_L = true; key_state.Tab = true; reset(); active = t
binds["ALT + TAB"]()
assert(not M.session:is_open() and names() == "cycle_next,bring_to_top", "tiling workspace: stock Alt+Tab, got " .. names())
reset(); binds["ALT + SHIFT + TAB"]()
assert(names() == "cycle_next,alter_zorder", "stock Shift+Alt+Tab, got " .. names())

-- a single window: nothing to switch to
windows = { a }; active = a; reset(); binds["ALT + TAB"]()
assert(not M.session:is_open() and names() == "send_key_state,send_key_state", "one window: no session")

-- live config: an edit to the file applies to the next Alt+Tab, with no reload
local cfgpath = TESTDIR .. "/cfg/omahop/config.toml"
local cf = io.open(cfgpath, "w"); cf:write('[windows]\nworkspaces = "all"\n'); cf:close()
windows = { a, t }; active = a; key_state.Alt_L = true; key_state.Tab = true; reset()
M.session:key(clock, "escape"); advance(25, 2)
binds["ALT + TAB"]()
assert(#M.entries == 2, "file edit applied without a reload: tiling window listed from a floating workspace, got " .. #M.entries)
M.session:key(clock, "escape"); M.apply({})
cf = io.open(cfgpath, "w"); cf:write('[windows]\nworkspaces = "current"\n'); cf:close()
reset(); binds["ALT + TAB"]()
assert(M.cfg.windows.workspaces == "current" and not M.session:is_open(), "second edit applied (one window left in view: nothing to switch to)")

-- takeover off: no binds at all
for k in pairs(binds) do binds[k] = nil end
_G.omahop_takeover = false
dofile(here .. "/omahop.lua")
assert(next(binds) == nil, "takeover = false leaves Alt+Tab alone")
_G.omahop_takeover = nil

-- scope all: omahop is active on a tiling workspace too
local f = io.open(TESTDIR .. "/cfg/omahop/config.toml", "w"); f:write('scope = "all"\n[windows]\nworkspaces = "all"\n'); f:close()
windows = { a, t }; active = t; key_state.Alt_L = true; key_state.Tab = true
dofile(here .. "/omahop.lua"); M = _G.omahop; M.now = function() return clock end
reset(); binds["ALT + TAB"]()
assert(M.session:is_open() and #M.entries == 2, "scope all on a tiling workspace opens the switcher")

print("glue ok")

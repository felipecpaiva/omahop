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
local binds, dispatched, timers, key_state, handlers, execd, ever_bound, timer_opts = {}, {}, {}, {}, {}, {}, {}, {}
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
    window = { move = dsp("move"), alter_zorder = dsp("alter_zorder"), cycle_next = dsp("cycle_next"), bring_to_top = dsp("bring_to_top"), close = dsp("close") } },
  get_windows = function() return windows end,
  get_active_window = function() return active end,
  get_active_workspace = function() return active and active.workspace or { id = 1, name = "1" } end,
  get_active_monitor = function() return { name = "eDP-1" } end,
  get_workspace = function(id) return { id = tonumber(id), monitor = { name = "eDP-1" } } end,
  get_window = function(sel) for _, w in ipairs(windows) do if "address:" .. w.address == sel then return w end end end,
  dispatch = function(d) dispatched[#dispatched + 1] = d end,
  bind = function(chord, fn) binds[chord] = fn; ever_bound[chord] = true end,
  unbind = function(chord) binds[chord] = nil end,
  on = function(ev, fn) handlers[ev] = fn end,
  timer = function(fn, opts) timers[#timers + 1] = fn; timer_opts[#timer_opts + 1] = opts end,
  exec_cmd = function(cmd) execd[#execd + 1] = cmd end,
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

-- search: letters typed while Alt is held filter the list; chords with a bind of the user's own are left alone (snapshot of `hyprctl binds`)
do
  local snap = io.open(TESTDIR .. "/run/omahop/binds.txt", "w")
  snap:write("bind\n\tmodmask: 8\n\tsubmap: \n\tkey: X\n\tkeycode: 0\n\n")  -- the user's own ALT + X
  snap:close()
  M.used = nil
  local userbind = function() end
  binds["ALT + X"] = userbind
  key_state.Alt_L = true; key_state.Tab = true; reset(); active = a; windows = { a, windows[2] or a }
  windows = {}
  local wa = win("0xa2", "app-a", 1, { focus_history_id = 0, tags = { "omarchy-floating-workspace" } })
  local wb = win("0xb2", "app-b", 1, { focus_history_id = 1, tags = { "omarchy-floating-workspace" } })
  local wc = win("0xc2", "app-c", 1, { focus_history_id = 2, tags = { "omarchy-floating-workspace" } })
  active = wa
  M.session:key(clock, "cancel"); advance(25, 2)
  binds["ALT + TAB"]()
  assert(#M.entries == 3 and M.session:selected() == 2, "session with three windows")
  assert(binds["ALT + A"] and binds["ALT + SPACE"] and binds["ALT + BACKSPACE"] and binds["ALT + 5"], "typing chords bound during the session")
  assert(binds["ALT + X"] == userbind, "the user's own bind on ALT + X is not replaced")
  binds["ALT + B"]()
  assert(M.query == "b" and #M.entries == 1 and M.entries[1].class == "app-b" and M.session:selected() == 1, "typing b keeps only app-b and selects it")
  assert(read_state():find("query=b") and read_state():find("0xb2") and not read_state():find("0xa2"), "state file carries the query and the filtered list")
  binds["ALT + BACKSPACE"]()
  assert(M.query == "" and #M.entries == 3 and M.session:selected() == 1, "backspace brings the list back, first entry selected")
  binds["ALT + C"]()
  binds["ALT + ESCAPE"]()
  assert(M.query == "" and M.session:is_open() and #M.entries == 3, "first Escape clears the query and keeps the session")
  -- fuzzy: "ac" is the initials of app-c's words, not a substring of anything; search_fuzzy = false drops it
  binds["ALT + A"](); binds["ALT + C"]()
  assert(#M.entries >= 1 and M.entries[1].class == "app-c", "search_fuzzy default: ac finds app-c by initials")
  M.cfg.search_fuzzy = false; M.refilter()
  assert(#M.entries == 0, "search_fuzzy = false: no fuzzy match")
  M.cfg.search_fuzzy = true; binds["ALT + ESCAPE"]()
  binds["ALT + Z"]()
  assert(#M.entries == 0 and M.session:selected() == 0 and M.session:is_open(), "no match: empty list, session stays open")
  reset(); key_state.Alt_L = false; advance(25, 2)
  assert(names() == "" and not M.session:is_open(), "releasing Alt with nothing matched activates nothing")
  assert(binds["ALT + A"] == nil and binds["ALT + X"] == userbind, "typing chords unbound at the end, the user's bind still there")
  -- picking from the filtered list
  key_state.Alt_L = true; reset(); active = wa
  binds["ALT + TAB"](); binds["ALT + C"]()
  reset(); key_state.Alt_L = false; advance(25, 2)
  assert(dispatched[1] and dispatched[1].args.window.address == "0xc2", "the filtered match is the window that comes forward")
  binds["ALT + X"] = nil
  -- search off in the settings: no typing chords
  local cfgf = io.open(TESTDIR .. "/cfg/omahop/config.toml", "w"); cfgf:write("search = false\n"); cfgf:close()
  key_state.Alt_L = true; active = wa; reset(); binds["ALT + TAB"]()
  assert(M.session:is_open() and binds["ALT + A"] == nil and binds["ALT + ESCAPE"] ~= nil, "search = false: navigation keys only")
  M.session:key(clock, "cancel"); M.apply({}); key_state.Alt_L = false; advance(25, 2)
  cfgf = io.open(TESTDIR .. "/cfg/omahop/config.toml", "w"); cfgf:write("[windows]\nworkspaces = \"all\"\n"); cfgf:close()
end

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
M.session:key(clock, "cancel"); advance(25, 2)
binds["ALT + TAB"]()
assert(#M.entries == 2, "file edit applied without a reload: tiling window listed from a floating workspace, got " .. #M.entries)
M.session:key(clock, "cancel"); M.apply({})
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

-- pointer entry points and quick actions (the overlay calls these through hyprctl eval; arguments are validated)
do
  windows = {}
  local wa = win("0xa3", "app-a", 1, { focus_history_id = 0, tags = { "omarchy-floating-workspace" } })
  local wb = win("0xb3", "app-b", 1, { focus_history_id = 1, tags = { "omarchy-floating-workspace" } })
  local wc = win("0xc3", "app-c", 1, { focus_history_id = 2, tags = { "omarchy-floating-workspace" } })
  active = wa; key_state.Alt_L = true; key_state.Tab = true
  local cfgf = io.open(TESTDIR .. "/cfg/omahop/config.toml", "w"); cfgf:write('[windows]\nworkspaces = "current"\n'); cfgf:close()
  M.session:key(clock, "cancel"); M.apply({}); reset()
  binds["ALT + TAB"]()
  assert(M.session:is_open() and #M.entries == 3, "session for the pointer tests")
  assert(binds["ALT + DELETE"], "ALT + DELETE bound during the session")
  assert(read_state():find("actions=1"), "state tells the overlay to show the hover buttons")
  -- a click on row 3 picks it
  reset(); M.pick(3)
  assert(not M.session:is_open() and dispatched[1] and dispatched[1].args.window.address == "0xc3", "pick(3) brings window c forward and ends the session")
  -- bad input is ignored
  binds["ALT + TAB"]()
  reset(); M.pick(0); M.pick(9); M.pick("x"); M.pick(nil); M.pick(2.5)
  assert(M.session:is_open() and names() == "", "out of range, non numeric and fractional picks do nothing")
  -- close and minimize validate the address
  reset(); execd = {}
  M.close_window("0xb3"); M.close_window("0xb3; echo injected"); M.close_window(42); M.close_window("address:0xb3")
  assert(names() == "close" and dispatched[1].args.window.address == "0xb3", "only a plain hex address closes a window")
  M.minimize_window("0xb3"); M.minimize_window("0xb3 && echo injected"); M.minimize_window("$(id)")
  assert(#execd == 1 and execd[1] == "omarchy-hyprland-window-minimize 0xb3", "only a plain hex address reaches the minimize script, got " .. #execd .. " calls")
  -- the peek strip's click: focus and raise, restore a minimized window first, bad addresses ignored
  reset(); M.focus_window("0xb3", false)
  assert(names() == "focus,alter_zorder" and dispatched[1].args.window.address == "0xb3", "focus_window focuses and raises")
  reset(); M.focus_window("0xb3; echo injected", false); M.focus_window(7, true)
  assert(names() == "", "focus_window ignores anything but a hex address")
  -- Delete closes the picked window; the row stays until the window is gone
  reset()
  binds["ALT + DELETE"]()
  assert(names() == "close" and #M.entries == 3, "Delete asks for a close, the list is unchanged until the window closes")
  -- the window closes: it leaves the list, the selection stays in range
  windows = { wa, wc }
  M.on_window_closed("0xb3")
  assert(#M.entries == 2 and M.session:selected() >= 1 and M.session:selected() <= 2, "closed window leaves the list, selection in range")
  assert(not read_state():find("0xb3"), "and the state file")
  M.on_window_closed("0xa3"); M.on_window_closed("0xc3")
  assert(not M.session:is_open(), "the last window closing ends the session")
  cfgf = io.open(TESTDIR .. "/cfg/omahop/config.toml", "w"); cfgf:write('[windows]\nworkspaces = "all"\n'); cfgf:close()
end


-- v0.4 rules: ignore by title, apps listed first, pass-through for fullscreen and for named apps
do
  local function setcfg(text) local f = io.open(TESTDIR .. "/cfg/omahop/config.toml", "w"); f:write(text); f:close() end
  windows = {}
  local wa = win("0xa4", "app-a", 1, { focus_history_id = 0, title = "Main", tags = { "omarchy-floating-workspace" } })
  local wb = win("0xb4", "app-b", 1, { focus_history_id = 1, title = "Picture in picture", tags = { "omarchy-floating-workspace" } })
  local wc = win("0xc4", "app-c", 1, { focus_history_id = 2, title = "Other", tags = { "omarchy-floating-workspace" } })
  local wd = win("0xd4", "app-d", 1, { focus_history_id = 3, title = "Last", tags = { "omarchy-floating-workspace" } })
  key_state.Alt_L = true; key_state.Tab = true
  local function open_session()
    if M.session:is_open() then M.session:key(clock, "cancel"); M.apply({}) end
    active = wa; reset(); binds["ALT + TAB"]()
  end
  local function classes() local t = {} for i, e in ipairs(M.entries) do t[i] = e.class end return table.concat(t, ",") end
  -- ignore by title
  setcfg('[windows]\nworkspaces = "current"\nignore_titles = "picture in picture"\n')
  open_session()
  assert(classes() == "app-a,app-c,app-d", "ignore_titles drops the matching window, got " .. classes())
  -- apps first
  setcfg('[windows]\nworkspaces = "current"\nfirst = "app-d, app-c"\n')
  open_session()
  assert(classes() == "app-c,app-d,app-a,app-b", "listed apps come first in recently used order, got " .. classes())
  -- pass-through: a fullscreen focused window with the setting on runs stock Alt+Tab, nothing opens
  setcfg('passthrough_fullscreen = true\n[windows]\nworkspaces = "current"\n')
  M.session:key(clock, "cancel"); M.apply({})
  wa.fullscreen = 2; active = wa; reset(); binds["ALT + TAB"]()
  assert(not M.session:is_open() and names() == "cycle_next,bring_to_top", "fullscreen focused window: stock Alt+Tab, got " .. names())
  wa.fullscreen = 1; reset(); binds["ALT + TAB"]()
  assert(M.session:is_open(), "a maximized window (state 1) does not make omahop step aside")
  M.session:key(clock, "cancel"); M.apply({})
  wa.fullscreen = 0
  -- pass-through by app class, any state
  setcfg('passthrough = "app-a, other"\n[windows]\nworkspaces = "current"\n')
  active = wa; reset(); binds["ALT + TAB"]()
  assert(not M.session:is_open() and names() == "cycle_next,bring_to_top", "a listed app keeps stock Alt+Tab")
  active = wb; reset(); binds["ALT + TAB"]()
  assert(M.session:is_open(), "other apps still use omahop")
  M.session:key(clock, "cancel"); M.apply({})
  setcfg('[windows]\nworkspaces = "all"\n')
end

-- v0.4 same-app shortcut (the second profile)
do
  local function setcfg(text) local f = io.open(TESTDIR .. "/cfg/omahop/config.toml", "w"); f:write(text); f:close() end
  local function snapshot(extra) local f = io.open(TESTDIR .. "/run/omahop/binds.txt", "w"); f:write("bind\n\tmodmask: 8\n\tkey: TAB\n\n" .. (extra or "")); f:close(); M.used = nil end
  windows = {}
  local x1 = win("0xe1", "app-x", 1, { focus_history_id = 0, title = "x one", tags = { "omarchy-floating-workspace" } })
  local x2 = win("0xe2", "app-x", 1, { focus_history_id = 1, title = "x two", tags = { "omarchy-floating-workspace" } })
  local y1 = win("0xe3", "app-y", 1, { focus_history_id = 2, title = "y", tags = { "omarchy-floating-workspace" } })
  local t1 = win("0xe4", "app-x", 2, { focus_history_id = 3, title = "x on tiling" })
  key_state.Alt_L = true; key_state.Tab = true
  setcfg('[windows]\nworkspaces = "current"\n')
  if M.session:is_open() then M.session:key(clock, "cancel"); M.apply({}) end
  binds["ALT + TAB"]()  -- loads the config through the normal path
  M.session:key(clock, "cancel"); M.apply({})
  -- bound when free, with the Shift variant
  for _, c in ipairs({ "ALT + GRAVE", "ALT + SHIFT + GRAVE" }) do binds[c] = nil end
  snapshot(); M.bind_same_app()
  assert(binds["ALT + GRAVE"] and binds["ALT + SHIFT + GRAVE"], "the same-app chord and its Shift variant are bound when free")
  -- lists only the focused app's windows, first pick is the app's previous window
  active = x1; reset(); binds["ALT + GRAVE"]()
  assert(M.session:is_open() and #M.entries == 2 and M.entries[1].class == "app-x" and M.entries[2].class == "app-x", "only the app's windows, got " .. #M.entries)
  assert(M.session:selected() == 2, "first pick is the app's previous window")
  reset(); key_state.Alt_L = false; advance(25, 2)
  assert(dispatched[1] and dispatched[1].args.window.address == "0xe2", "release goes to the app's other window")
  -- an app with a single window: nothing to switch to
  key_state.Alt_L = true; active = y1; reset(); binds["ALT + GRAVE"]()
  assert(not M.session:is_open(), "one window of the app: no session")
  -- a chord the user already uses is left alone
  for _, c in ipairs({ "ALT + GRAVE", "ALT + SHIFT + GRAVE" }) do binds[c] = nil end
  snapshot("bind\n\tmodmask: 8\n\tkey: GRAVE\n\n"); M.bind_same_app()
  assert(binds["ALT + GRAVE"] == nil, "a chord already in use is not taken")
  -- not an ALT chord, or empty: ignored
  setcfg('same_app_key = "SUPER + X"\n[windows]\nworkspaces = "current"\n'); M.cfg = nil; M.config_text = nil; M.reload_config(); snapshot(); M.bind_same_app()
  assert(binds["SUPER + X"] == nil and binds["ALT + GRAVE"] == nil, "only ALT chords are accepted")
  setcfg('same_app_key = ""\n[windows]\nworkspaces = "current"\n'); M.config_text = nil; M.reload_config(); snapshot(); M.bind_same_app()
  assert(binds["ALT + GRAVE"] == nil, "empty turns it off")
  -- where omahop is not active the key goes back to the app
  setcfg('[windows]\nworkspaces = "current"\n'); M.config_text = nil; M.reload_config(); snapshot(); M.bind_same_app()
  assert(binds["ALT + GRAVE"], "bound again")
  active = t1; reset(); binds["ALT + GRAVE"]()
  assert(not M.session:is_open() and names() == "send_key_state,send_key_state", "out of scope: the key is handed back, got " .. names())
  assert(dispatched[1].args.key == "grave" and dispatched[1].args.mods == "ALT", "as Alt + grave")
  setcfg('[windows]\nworkspaces = "all"\n'); M.config_text = nil
end

-- v0.4 hints: number keys and app letters jump while the query is empty; anything else still types
do
  local function setcfg(text) local f = io.open(TESTDIR .. "/cfg/omahop/config.toml", "w"); f:write(text); f:close() end
  local function snapshot() local f = io.open(TESTDIR .. "/run/omahop/binds.txt", "w"); f:write("bind\n\tmodmask: 8\n\tkey: TAB\n\n"); f:close(); M.used = nil end
  windows = {}
  local wa = win("0xf1", "app-a", 1, { focus_history_id = 0, tags = { "omarchy-floating-workspace" } })
  local wb = win("0xf2", "app-b", 1, { focus_history_id = 1, tags = { "omarchy-floating-workspace" } })
  local wc = win("0xf3", "app-c", 1, { focus_history_id = 2, tags = { "omarchy-floating-workspace" } })
  key_state.Alt_L = true; key_state.Tab = true
  local function open_session()
    if M.session:is_open() then M.session:key(clock, "cancel"); M.apply({}) end
    snapshot(); active = wa; reset(); binds["ALT + TAB"]()
  end
  -- numbers
  setcfg('hints = "numbers"\n[windows]\nworkspaces = "current"\n')
  open_session()
  assert(read_state():find("w\t0xf1\tapp%-a\t0\t1\t") and read_state():find("w\t0xf3\tapp%-c\t0\t3\t"), "the state carries a number hint per row")
  reset(); binds["ALT + 3"]()
  assert(not M.session:is_open() and dispatched[1] and dispatched[1].args.window.address == "0xf3", "Alt + 3 picks the third row")
  open_session()
  reset(); binds["ALT + 9"]()
  assert(M.session:is_open() and M.query == "9", "a number with no such row types into the search")
  -- once typing has started, digits type
  open_session()
  binds["ALT + B"]()
  assert(M.query == "b", "a letter that is not a hint types")
  reset(); binds["ALT + 2"]()
  assert(M.query == "b2" and M.session:is_open(), "with a query, a digit types and does not jump")
  assert(not read_state():find("\t1\t"), "no hint labels while a query exists")
  -- app letters
  setcfg('hints = "apps"\nhint_keys = "c=app-c, x=app-none"\n[windows]\nworkspaces = "current"\n')
  open_session()
  assert(read_state():find("w\t0xf3\tapp%-c\t0\tc\t"), "the mapped app's row carries its letter")
  reset(); binds["ALT + C"]()
  assert(not M.session:is_open() and dispatched[1].args.window.address == "0xf3", "the letter jumps to that app's window")
  open_session(); binds["ALT + X"]()
  assert(M.session:is_open() and M.query == "x", "a mapped app with no window types instead")
  -- hints off: digits always type
  setcfg('[windows]\nworkspaces = "current"\n')
  open_session(); binds["ALT + 3"]()
  assert(M.query == "3" and M.session:is_open(), "hints off: a digit types")
  M.session:key(clock, "cancel"); M.apply({})
  setcfg('[windows]\nworkspaces = "all"\n')
end

-- v1.3 action keys (action_keys): a mapped key acts on the selected row while the query is empty; otherwise it types
do
  local function setcfg(text) local f = io.open(TESTDIR .. "/cfg/omahop/config.toml", "w"); f:write(text); f:close() end
  local function snapshot() local f = io.open(TESTDIR .. "/run/omahop/binds.txt", "w"); f:write("bind\n\tmodmask: 8\n\tkey: TAB\n\n"); f:close(); M.used = nil end
  windows = {}
  local wa = win("0xd1", "app-a", 1, { focus_history_id = 0, tags = { "omarchy-floating-workspace" } })
  win("0xd2", "app-b", 1, { focus_history_id = 1, tags = { "omarchy-floating-workspace" } })
  win("0xd3", "app-c", 1, { focus_history_id = 2, tags = { "omarchy-floating-workspace" } })
  key_state.Alt_L = true; key_state.Tab = true
  local function open_session(cfg)
    if M.session:is_open() then M.session:key(clock, "cancel"); M.apply({}) end
    setcfg(cfg .. '[windows]\nworkspaces = "current"\n')
    snapshot(); active = wa; reset(); execd = {}; binds["ALT + TAB"]()
    reset(); execd = {} -- the open itself injects a key
  end
  local function addrs() local t = {} for i, e in ipairs(M.entries) do t[i] = e.address end return table.concat(t, ",") end
  -- off by default: q types
  open_session("")
  binds["ALT + Q"]()
  assert(M.query == "q" and #dispatched == 0, "default (empty action_keys): q types into the search")
  -- close on the selected row, query empty; the row leaves and the selection stays on the next one
  open_session('action_keys = "q=close, m=minimize"\n')
  assert(addrs() == "0xd1,0xd2,0xd3" and M.session:selected() == 2, "fixture: second row selected, got " .. addrs())
  reset(); binds["ALT + Q"]()
  assert(names() == "close" and dispatched[1].args.window.address == "0xd2", "q closes the selected window")
  assert(M.query == "" and addrs() == "0xd1,0xd3" and M.session:selected() == 2 and M.entries[2].address == "0xd3", "list refreshed, selection on the next row")
  -- minimize goes through the async script (exec_cmd), never a synchronous hyprctl
  reset(); execd = {}; binds["ALT + M"]()
  assert(#dispatched == 0 and execd[1] == "omarchy-hyprland-window-minimize 0xd3", "m runs the minimize script on the selected row")
  assert(addrs() == "0xd1" and M.session:is_open() and M.session:selected() == 1, "minimized row left the list, selection clamped")
  -- closing the last row empties the list and ends the session
  reset(); binds["ALT + Q"]()
  assert(not M.session:is_open() and dispatched[1].args.window.address == "0xd1", "an empty list closes the session")
  -- once a letter is typed, the same key types
  open_session('action_keys = "q=close, m=minimize"\n')
  binds["ALT + B"]()
  reset(); binds["ALT + Q"]()
  assert(M.query == "bq" and #dispatched == 0 and M.session:is_open(), "with a query, q types and does not close")
  -- a conflict with a hint key: the hint keeps the key, the action key is dropped
  open_session('hints = "apps"\nhint_keys = "q=app-c"\naction_keys = "q=close, m=minimize"\n')
  assert(M.action_map.q == nil and M.action_map.m == "minimize", "q is a hint key: only m stays an action key")
  reset(); binds["ALT + Q"]()
  assert(names() == "focus,alter_zorder" and dispatched[1].args.window.address == "0xd3", "the hint wins: q jumps to the app")
  open_session('hints = "numbers"\naction_keys = "3=close, x=minimize"\n')
  assert(M.action_map["3"] == nil and M.action_map.x == "minimize", "a number hint key is not an action key")
  M.session:key(clock, "cancel"); M.apply({})
  setcfg('[windows]\nworkspaces = "all"\n')
end

-- v1.1b linger (search_linger_seconds): Alt up with a search keeps the list open; the overlay sends the whole query with a sequence number
do
  local function setcfg(text) local f = io.open(TESTDIR .. "/cfg/omahop/config.toml", "w"); f:write(text); f:close() end
  local function snapshot() local f = io.open(TESTDIR .. "/run/omahop/binds.txt", "w"); f:write("bind\n\tmodmask: 8\n\tkey: TAB\n\n"); f:close(); M.used = nil end
  local function has(line) return read_state():find("\n" .. line .. "\n", 1, true) ~= nil end
  windows = {}
  local wa = win("0xa5", "app-a", 1, { focus_history_id = 0, title = "alpha", tags = { "omarchy-floating-workspace" } })
  win("0xb5", "app-b", 1, { focus_history_id = 1, title = "bravo", tags = { "omarchy-floating-workspace" } })
  win("0xc5", "app-c", 1, { focus_history_id = 2, title = "charlie", tags = { "omarchy-floating-workspace" } })
  setcfg('reveal_delay_ms = 0\nsearch_linger_seconds = 3\n[windows]\nworkspaces = "current"\n')
  if M.session:is_open() then M.session:key(clock, "cancel"); M.apply({}) end
  -- open, reveal on the first tick, type with Alt held: the overlay is told to take the keyboard from the first letter
  local function linger_session(letter)
    snapshot(); key_state = { Alt_L = true, Alt_R = false, Tab = true }; active = wa; reset(); binds["ALT + TAB"](); advance(16)
    assert(has("grab=0"), "no grab before anything is typed")
    binds["ALT + " .. letter]()
    assert(has("grab=1") and M.session:is_open(), "a typed letter with linger on: grab=1")
    reset(); key_state = { Alt_L = false, Alt_R = false, Tab = false }; advance(16, 2)
  end
  linger_session("B")
  assert(M.session:is_open() and M.session:is_lingering() and names() == "", "Alt up with a search: still open, nothing activated")
  assert(has("linger_ms=3000") and has("linger_rev=1") and has("grab=1"), "state carries the linger length and revision")
  -- set_query: newer calls apply, an older one that lands late is dropped
  local seq0 = M.seq
  M.set_query(seq0 + 2, "char"); M.set_query(seq0 + 1, "alp")
  assert(M.query == "char" and #M.entries == 1 and M.entries[1].address == "0xc5", "the late older call did not undo the newer one")
  assert(has("seq=" .. (seq0 + 2)) and has("query=char"), "state carries the applied seq and query")
  local rev = read_state():match("linger_rev=(%d+)")
  M.set_query(seq0 + 3, "char")
  assert(read_state():match("linger_rev=(%d+)") ~= rev and M.query == "char", "the same text again still restarts the countdown")
  -- validation at the boundary
  M.set_query(seq0 + 4, 42); M.set_query("x", "a"); M.set_query(seq0 + 4, string.rep("a", M.query_max + 1)); M.set_query(seq0 + 4, "\xff\xfe")
  assert(M.query == "char" and M.seq == seq0 + 3, "non string, bad seq, too long and invalid UTF-8 are refused")
  M.set_query(seq0 + 4, "ch\nar\27"); assert(M.query == "char", "control characters are stripped")
  M.key(seq0 + 5, "delete"); M.key(seq0 + 5, "os.exit()")
  assert(M.session:is_open() and M.seq == seq0 + 4, "a key name outside the list is ignored")
  -- Return: open=0 is written first, the window is focused from a timer (a focus call is ignored while the overlay holds the keyboard)
  reset(); timer_opts = {}
  M.set_query(seq0 + 5, "char"); M.key(seq0 + 6, "return")
  assert(not M.session:is_open() and has("open=0") and has("grab=0"), "Return: the state says closed and no grab")
  assert(names() == "", "nothing focused yet")
  assert(timer_opts[#timer_opts].timeout == M.release_ms, "activation scheduled after release_ms")
  run_timers()
  assert(names() == "focus,alter_zorder" and dispatched[1].args.window.address == "0xc5", "the timer focuses the picked window, got " .. names())
  assert(binds["ALT + B"] == nil, "session chords unbound at the end")
  -- the deadline cancels, never picks
  linger_session("B"); reset()
  advance(500, 5)
  assert(M.session:is_open(), "still open before the deadline")
  advance(600)
  assert(not M.session:is_open() and has("open=0"), "closed at the deadline")
  run_timers(); assert(names() == "", "the timeout activated nothing")
  -- Escape clears, then cancels
  linger_session("B"); reset()
  M.key(M.seq + 1, "escape")
  assert(M.session:is_open() and M.query == "" and #M.entries == 3 and has("query="), "first Escape clears the search, the list stays")
  assert(has("grab=1") and has("linger_ms=3000"), "still lingering with the keyboard held: " .. read_state():sub(1, 200))
  M.key(M.seq + 1, "escape"); run_timers()
  assert(not M.session:is_open() and names() == "", "second Escape cancels")
  -- a click outside the list
  linger_session("B"); reset()
  M.key(M.seq + 1, "cancel"); run_timers()
  assert(not M.session:is_open() and names() == "" and has("open=0"), "cancel closes and activates nothing")
  -- a click on a row while lingering also defers the focus
  linger_session("A"); reset()
  M.pick(1)
  assert(names() == "" and has("open=0"), "pick while lingering: closed first")
  run_timers(); assert(names() == "focus,alter_zorder", "then focused from the timer")
  -- linger off: Alt up picks at once, as before (no timer in between)
  setcfg('reveal_delay_ms = 0\n[windows]\nworkspaces = "current"\n')
  snapshot(); key_state = { Alt_L = true, Alt_R = false, Tab = true }; active = wa; reset(); binds["ALT + TAB"](); advance(16); binds["ALT + B"]()
  assert(has("grab=0"), "linger off: never a grab")
  reset(); key_state.Alt_L = false; key_state.Tab = false; advance(16, 2)
  assert(not M.session:is_open() and names() == "focus,alter_zorder", "linger off: Alt up picks immediately, got " .. names())
  -- reload mid-linger: a fresh closed session, open=0 and no grab
  setcfg('reveal_delay_ms = 0\nsearch_linger_seconds = 3\n[windows]\nworkspaces = "current"\n')
  linger_session("B")
  assert(M.session:is_lingering(), "lingering before the reload")
  dofile(here .. "/omahop.lua"); M = _G.omahop; M.now = function() return clock end
  assert(not M.session:is_open() and has("open=0") and has("grab=0") and M.seq == 0, "reload mid-linger: closed, no grab, seq reset")
  reset(); M.set_query(1, "b"); M.key(2, "return"); run_timers()
  assert(names() == "" and not M.session:is_open(), "calls after the reload do nothing without a session")
  -- takeover = false: inert, the entry points do nothing
  for k in pairs(binds) do binds[k] = nil end
  _G.omahop_takeover = false
  dofile(here .. "/omahop.lua"); M = _G.omahop; M.now = function() return clock end
  reset(); M.set_query(1, "b"); M.key(2, "return"); M.key(3, "cancel"); run_timers()
  assert(next(binds) == nil and names() == "" and has("open=0") and has("grab=0"), "takeover off: no binds, no grab, nothing happens")
  _G.omahop_takeover = nil
  setcfg('[windows]\nworkspaces = "all"\n')
end

-- never a bare key: every chord bound in this whole run carries ALT
for chord in pairs(ever_bound) do assert(chord:find("^ALT %+ "), "a bind without ALT: " .. chord) end

print("glue ok")

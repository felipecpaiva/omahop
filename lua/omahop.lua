-- omahop: Hyprland glue. Loaded from hyprland.lua by a guarded dofile (a missing or broken file must never break the config):
--   pcall(dofile, os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.felipecpaiva.omahop/lua/omahop.lua")
-- Logic lives in pure modules next to this file (config, scope, windows, mru, session); this file only talks to Hyprland.
-- The overlay is a separate Quickshell service that watches the state file this module writes (see write_state).
local here = debug.getinfo(1, "S").source:match("^@(.*)/") or "."
local function mod(name) return dofile(here .. "/" .. name .. ".lua") end
local Config, Scope, Windows, Mru, Session, Search, Rules, Hints = mod("config"), mod("scope"), mod("windows"), mod("mru"), mod("session"), mod("search"), mod("rules"), mod("hints")

local M = {}
_G.omahop = M

M.tick_ms = 16 -- key polling interval: shorter means Alt release is noticed sooner (a tick costs about 8 microseconds, measured)
M.inject_key = "F24" -- see docs/research/spikes.md L1: without it, an app under the overlay sees a bare Alt tap and opens its menu bar
-- Chords active only while a session is open; ALT is held for the whole session. (Unbinding them at the end would also drop a
-- user's own bind on the same chord: shortcut, none exist in the stock set; upgrade by reading the bind list if one appears.)
M.session_keys = { ["ALT + DELETE"] = "delete", ["ALT + ESCAPE"] = "escape", ["ALT + RETURN"] = "return", ["ALT + LEFT"] = "left", ["ALT + RIGHT"] = "right", ["ALT + UP"] = "up", ["ALT + DOWN"] = "down" }

local state_dir = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omahop"
M.state_path = state_dir .. "/state"
local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
M.config_path = config_home .. "/omahop/config.toml"
local layouts_dir = (os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")) .. "/omarchy/workspace-layouts"

M.order = {}
M.entries = {}      -- what the session shows (filtered by the search query)
M.all_entries = {}  -- every window of this session, before the query
M.query = ""
M.bound = {}        -- chords bound for the running session, unbound exactly at its end
M.gen = 0

local function log(msg)
  local f = io.open(state_dir .. "/log", "a")
  if f then f:write(string.format("%.3f %s\n", M.now() / 1000, msg)); f:close() end
end

-- Milliseconds since boot (wall clock, not CPU time: os.clock does not advance while idle).
function M.now()
  local f = io.open("/proc/uptime", "r")
  if not f then return os.time() * 1000 end
  local s = f:read("n") or 0
  f:close()
  return math.floor(s * 1000)
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local t = f:read("a")
  f:close()
  return t
end

local function has_tag(w, tag)
  for _, t in ipairs(w.tags or {}) do if t == tag then return true end end
  return false
end

local function minimized_origin(w)
  for _, t in ipairs(w.tags or {}) do
    local id = tostring(t):match("^omarchy%-minimized%-from%-(%d+)$")
    if id then return tonumber(id) end
  end
end

-- One window object -> the plain table the pure modules use.
local function describe(w, floating_of, monitor_of)
  local ws_name = w.workspace and w.workspace.name or ""
  local minimized = ws_name == "special:minimized"
  local ws_id = w.workspace and w.workspace.id
  local monitor = w.monitor and w.monitor.name
  if minimized then
    ws_id = minimized_origin(w)
    monitor = ws_id and monitor_of(ws_id) or nil
  end
  return {
    address = w.address, class = w.class or "", title = w.title or "",
    workspace_id = ws_id, monitor = monitor, minimized = minimized,
    special = (not minimized) and ws_name:sub(1, 8) == "special:" or false,
    floating_workspace = ws_id ~= nil and floating_of(ws_id) or false,
    mapped = w.mapped ~= false and w.hidden ~= true,
    focus_history = w.focus_history_id or 1e9,
  }
end

-- Floating or not, cached per call (several windows share a workspace).
local function floating_resolver(all)
  local cache = {}
  return function(id)
    if cache[id] == nil then
      local tagged = false
      for _, w in ipairs(all) do
        if w.workspace and w.workspace.id == id and has_tag(w, "omarchy-floating-workspace") then tagged = true; break end
      end
      cache[id] = Scope.workspace_floating(read_file(layouts_dir .. "/" .. id .. ".lua"), read_file(layouts_dir .. "/default.lua"), tagged)
    end
    return cache[id]
  end
end

local function monitor_resolver()
  return function(id)
    local ok, ws = pcall(hl.get_workspace, tostring(id))
    return ok and ws and ws.monitor and ws.monitor.name or nil
  end
end

function M.current_context()
  local ws, mon = hl.get_active_workspace(), hl.get_active_monitor()
  return { workspace_id = ws and ws.id, monitor = mon and mon.name }
end

-- The list the switcher shows for the focused workspace, in recently-used order.
function M.build_entries()
  local all = hl.get_windows()
  local floating_of, monitor_of = floating_resolver(all), monitor_resolver()
  local plain = {}
  for _, w in ipairs(all) do plain[#plain + 1] = describe(w, floating_of, monitor_of) end
  table.sort(plain, function(a, b) return a.focus_history < b.focus_history end) -- Hyprland's own history: the order for windows we have not seen
  local kept = Windows.filter(plain, M.current_context(), M.cfg.windows, Config.ignore_set(M.cfg), Rules.set(M.cfg.windows.ignore_titles))
  return Rules.first_apps(Mru.sort(M.order, kept), Rules.set(M.cfg.windows.first))
end

function M.workspace_is_floating()
  local ctx = M.current_context()
  if not ctx.workspace_id then return false end
  local all = hl.get_windows()
  return floating_resolver(all)(ctx.workspace_id)
end

-- Keep the file the overlay watches in step with the session. Written to a temp file and renamed, so the reader never sees half of it.
function M.write_state()
  local s = M.session
  local lines = { "version=1", "open=" .. ((s and s:is_open()) and 1 or 0), "revealed=" .. ((s and s:is_revealed()) and 1 or 0),
    "selected=" .. (s and s:selected() or 0), "style=" .. M.cfg.style, "thumbnails=" .. M.cfg.thumbnails, "border=" .. M.cfg.border, "actions=" .. (M.cfg.actions and 1 or 0) }
  if s and s:is_open() then lines[#lines + 1] = "query=" .. (tostring(M.query):gsub("[%c]", " ")) end
  if s and s:is_open() then
    -- hint labels (a number or a letter on a row) only while nothing is typed: once there is a query, every key types
    local labels = M.query == "" and Hints.labels(M.entries, M.cfg.hints, Hints.parse_keys(M.cfg.hint_keys)) or {}
    for i, e in ipairs(M.entries) do
      local clean = function(v) return (tostring(v):gsub("[%c]", " ")) end
      lines[#lines + 1] = table.concat({ "w", e.address, clean(e.class), e.minimized and 1 or 0, labels[i] or "", clean(e.title) }, "\t")
    end
  end
  local content = table.concat(lines, "\n") .. "\n"
  -- Only write when something changed: the tick calls this every 16 ms, and every write makes the overlay re-read and redraw (measured: 133 writes in 3 s before this).
  if content == M.last_state then return end
  local tmp = M.state_path .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return end
  f:write(content)
  f:close()
  if os.rename(tmp, M.state_path) then M.last_state = content end
end

-- Bring a window to the front the way the dock does: a minimized one moves to the workspace in front of the user first.
-- Focus alone does not raise a floating window (docs/research/spikes.md S8), so focus and raise both.
function M.activate(entry)
  local w = hl.get_window("address:" .. entry.address)
  if not w then return end
  if entry.minimized then
    local ws = hl.get_active_workspace()
    if not ws or ws.id < 1 then return end -- a named workspace: leave it, as the dock does
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(ws.id), window = w }))
  end
  hl.dispatch(hl.dsp.focus({ window = w }))
  hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
end

-- The chords in use, from a snapshot of `hyprctl binds` that a detached command wrote to a file (hyprctl must never be called from here directly:
-- Hyprland would wait for itself, see docs/gotchas.md). nil until that file exists.
local function parse_used(text)
  local used = {}
  for block in (text .. "\n\n"):gmatch("(.-)\n\n") do
    local mod_, key = block:match("modmask: (%d+)"), block:match("key: ([^\n]+)")
    if mod_ and key then used[mod_ .. ":" .. key:upper()] = true end
  end
  return used
end

function M.refresh_binds()
  local path = state_dir .. "/binds.txt"
  hl.exec_cmd(string.format("sh -c 'hyprctl binds > \"%s.tmp\" && mv \"%s.tmp\" \"%s\"'", path, path, path))
end

local function load_used()
  if M.used then return M.used end
  local text = read_file(state_dir .. "/binds.txt")
  if text and #text > 0 then M.used = parse_used(text) end
  return M.used
end

-- Letters, digits, space and backspace, typed while Alt is held (modmask 8). Each maps to what it adds to the query.
local function typing_keys()
  local t = {}
  for c = string.byte("A"), string.byte("Z") do t[string.char(c)] = string.char(c):lower() end
  for c = string.byte("0"), string.byte("9") do t[string.char(c)] = string.char(c) end
  t.SPACE = " "; t.BACKSPACE = "backspace"
  return t
end

function M.refilter()
  if not M.names then
    M.names = {}
    local text = read_file(state_dir .. "/names")
    for line in (text or ""):gmatch("[^\n]+") do
      local class, name = line:match("^(.-)\t(.*)$")
      if class then M.names[class] = name end
    end
  end
  M.entries = Search.filter(M.all_entries, M.query, M.names)
  M.session:resize(#M.entries, #M.entries > 0 and 1 or 0)
  M.write_state()
end

function M.type_key(ch)
  if not M.session:is_open() then return end
  -- a hint key (a number, or a letter mapped to an app) jumps straight to a window, but only while nothing is typed yet
  if M.query == "" and M.cfg.hints ~= "off" and ch ~= "backspace" and ch ~= " " then
    local target = Hints.target(M.entries, M.cfg.hints, Hints.parse_keys(M.cfg.hint_keys), ch)
    if target then M.pick(target); return end
  end
  if ch == "backspace" then M.query = Search.backspace(M.query) else M.query = Search.append(M.query, ch) end
  M.refilter()
end

local function bind_session_keys(on)
  for _, chord in ipairs(M.bound) do pcall(hl.unbind, chord) end
  M.bound = {}
  if not on then return end
  local used = load_used()
  local function free(key) return used == nil or not used["8:" .. key] end
  local function add(chord, key, fn)
    -- keys with a bind of the user's own are left alone; unknown (no snapshot yet) is allowed for navigation keys, never for typing
    if pcall(hl.bind, chord, fn, {}) then M.bound[#M.bound + 1] = chord end
  end
  for chord, name in pairs(M.session_keys) do
    local key = chord:match("%+ (%w+)$")
    if free(key) then
      add(chord, key, function()
        if name == "escape" and M.query ~= "" then M.query = ""; M.refilter(); return end -- the first Escape clears what was typed
        if name == "delete" then M.close_selected(); return end                           -- quick action: close the picked window
        M.apply(M.session:key(M.now(), name))
      end)
    end
  end
  if M.cfg.search and used ~= nil then
    for key, ch in pairs(typing_keys()) do
      if free(key) then add("ALT + " .. key, key, function() M.type_key(ch) end) end
    end
  end
end

local function keys_down()
  local alt, tab = nil, nil
  for _, k in ipairs({ "Alt_L", "Alt_R" }) do
    local ok, r = pcall(hl.is_key_down, k)
    if ok and r ~= nil then alt = (alt or false) or r end
  end
  local ok, r = pcall(hl.is_key_down, "Tab")
  if ok then tab = r end
  return { alt = alt, tab = tab }
end

-- Entry points for the overlay's pointer (called from QML through `hyprctl eval`, so every argument is validated: addresses are hex only, an index is an integer).
local function valid_address(a) return type(a) == "string" and a:match("^0x%x+$") ~= nil end

-- A click on a row or card: that window is picked and the session ends.
function M.pick(index)
  index = math.tointeger(tonumber(index))
  if not index or not (M.session and M.session:is_open()) then return end
  if index < 1 or index > #M.entries then return end
  M.session:resize(#M.entries, index)
  M.apply(M.session:key(M.now(), "return"))
end

-- Closing is a request (the app may ask first), so the row leaves the list when the window is gone (on_window_closed), not here.
function M.close_window(address)
  if not valid_address(address) then return end
  local w = hl.get_window("address:" .. address)
  if w then hl.dispatch(hl.dsp.window.close({ window = w })) end
end

-- Omarchy's own minimize script (it sends the window to the dock's special workspace and remembers where it came from); only acts on floating workspaces.
function M.minimize_window(address)
  if not valid_address(address) then return end
  hl.exec_cmd("omarchy-hyprland-window-minimize " .. address)
end

-- A click on an app's window in the peek strip: bring it forward (a minimized one comes back to the workspace in front first), same as picking it in the list.
function M.focus_window(address, minimized)
  if not valid_address(address) then return end
  M.activate({ address = address, minimized = minimized == true })
end

function M.close_selected()
  if not (M.session and M.session:is_open()) then return end
  local e = M.entries[M.session:selected()]
  if e then M.close_window(e.address) end
end

-- A window went away: forget it, and while a session is open take it out of the list (selection stays in range, nothing left ends the session).
function M.on_window_closed(address)
  M.order = Mru.forget(M.order, address)
  if not (M.session and M.session:is_open()) then return end
  local function drop(list)
    local out = {}
    for _, e in ipairs(list) do if e.address ~= address then out[#out + 1] = e end end
    return out
  end
  local before = #M.all_entries
  M.all_entries, M.entries = drop(M.all_entries), drop(M.entries)
  if #M.all_entries == before then return end
  if #M.all_entries < 1 then M.apply(M.session:key(M.now(), "escape")); return end
  local sel = #M.entries == 0 and 0 or math.min(math.max(M.session:selected(), 1), #M.entries)
  M.session:resize(#M.entries, sel)
  M.write_state()
end

function M.apply(actions)
  local closed = false
  for _, a in ipairs(actions) do
    if a.type == "commit" then
      local e = M.entries[a.index]
      if e then M.activate(e) end
      closed = true
    elseif a.type == "cancel" then
      closed = true
    end
  end
  if closed then bind_session_keys(false); M.gen = M.gen + 1; M.query = "" end
  M.write_state()
end

-- Chained one-shot timers: hl.timer has no stop handle, a generation number does.
local function tick(gen)
  if gen ~= M.gen or not M.session:is_open() then return end
  local ok, err = pcall(function() M.apply(M.session:tick(M.now(), keys_down())) end)
  if not ok then
    log("tick error: " .. tostring(err))
    M.session:key(M.now(), "escape"); bind_session_keys(false); M.gen = M.gen + 1; M.write_state()
    return
  end
  if M.session:is_open() then hl.timer(function() tick(gen) end, { type = "oneshot", timeout = M.tick_ms }) end
end

-- The windows of the focused window's app (the same-app profile). Without a focused window the list is unchanged.
function M.same_app(entries, focused)
  if not focused or not focused.class then return entries end
  local want, out = tostring(focused.class):lower(), {}
  for _, e in ipairs(entries) do
    if (e.class or ""):lower() == want then out[#out + 1] = e end
  end
  return out
end

-- Give a chord's key back to the focused app (used when the same-app chord fires where omahop is not active). send_key_state, never pass: pass makes Hyprland call the bind again.
function M.pass_chord(chord)
  local key = chord and chord:match("%+ (%w+)$")
  local w = hl.get_active_window()
  if not key or not w then return end
  key = key:lower()
  pcall(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = "ALT", key = key, state = "down", window = w }))
    hl.dispatch(hl.dsp.send_key_state({ mods = "ALT", key = key, state = "up", window = w }))
  end)
end

-- Bind the same-app shortcut (and its Shift variant) once the snapshot of existing binds is there: a chord that is already used is left alone (never unbound).
-- Only chords that start with ALT work (omahop polls the Alt keys to know when to end).
function M.bind_same_app()
  local chord = M.cfg and M.cfg.same_app_key or ""
  if chord == "" then return end
  local key = chord:match("^ALT %+ (%w+)$")
  if not key then log("same_app_key must look like ALT + GRAVE, ignored: " .. chord); return end
  local used = load_used()
  if used == nil then log("same_app_key: no snapshot of the binds yet, not bound"); return end
  if used["8:" .. key:upper()] or used["9:" .. key:upper()] then log("same_app_key: " .. chord .. " is already used, left alone"); return end
  M.same_app_chord = chord
  hl.bind(chord, function() M.on_tab(1, "same_app") end, {})
  hl.bind("ALT + SHIFT + " .. key, function() M.on_tab(-1, "same_app") end, {})
end

-- Without this key the app under the overlay sees Alt down and Alt up and treats it as a tap (opens its menu bar).
-- send_key_state, not send_shortcut or pass: those make Hyprland call the Alt+Tab bind a second time at the Tab release (docs/research/spikes.md).
local function inject()
  local w = hl.get_active_window()
  if not w then return end
  pcall(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = "", key = M.inject_key, state = "down", window = w }))
    hl.dispatch(hl.dsp.send_key_state({ mods = "", key = M.inject_key, state = "up", window = w }))
  end)
end

-- What Alt+Tab does where omahop is not active: the stock Omarchy behaviour, so those workspaces are untouched.
function M.stock(delta)
  if delta > 0 then
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
  else
    hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom" }))
  end
end

-- Re-read the config file when a session is about to start, so edits (and the settings panel) apply to the next Alt+Tab with no reload.
-- A read of a small file costs microseconds and nothing is parsed when the text has not changed. `takeover` is the exception: it decides
-- whether the binds exist at all, so it only applies at load (the panel offers a reload for it).
function M.reload_config()
  local text = read_file(M.config_path) or ""
  if text == M.config_text then return end
  M.config_text = text
  local parsed, bad = Config.parse(text)
  local cfg, problems = Config.merge(parsed)
  for _, line in ipairs(bad) do problems[#problems + 1] = "unreadable line: " .. line end
  for _, p in ipairs(problems) do log("config: " .. p) end
  M.cfg = cfg
  M.session = Session.new(cfg)
end

function M.on_tab(delta, profile)
  if not (M.session and M.session:is_open()) then
    M.reload_config()
    -- Fullscreen apps and listed apps keep Alt+Tab to themselves: stock behaviour, decided at the press before anything opens.
    local aw = hl.get_active_window()
    if Rules.passthrough(aw and { class = aw.class, fullscreen = aw.fullscreen } or nil, M.cfg.passthrough_fullscreen, Rules.set(M.cfg.passthrough)) then return M.stock(delta) end
  end
  if not Scope.active(M.cfg.scope, M.workspace_is_floating()) then
    if profile == "same_app" then return M.pass_chord(M.same_app_chord) end -- the chord has no stock meaning: give the key back to the app
    return M.stock(delta)
  end
  inject()
  local now = M.now()
  if M.session:is_open() then
    M.apply(M.session:step(now, delta))
    return
  end
  M.entries = M.build_entries()
  local focused = hl.get_active_window()
  if profile == "same_app" then M.entries = M.same_app(M.entries, focused) end
  M.all_entries, M.query, M.names = M.entries, "", nil
  local first = Mru.first_pick(M.entries, focused and focused.address, delta)
  if #M.entries < 2 then M.entries = {}; return end -- nothing to switch to
  M.gen = M.gen + 1
  bind_session_keys(true)
  M.apply(M.session:open(now, #M.entries, first))
  hl.timer(function() tick(M.gen) end, { type = "oneshot", timeout = M.tick_ms })
end

local function seed_order()
  local all = hl.get_windows()
  table.sort(all, function(a, b) return (a.focus_history_id or 1e9) < (b.focus_history_id or 1e9) end)
  M.order = {}
  for _, w in ipairs(all) do M.order[#M.order + 1] = w.address end
end

-- Idempotent: safe to run twice (a reload clears binds, an eval-based reload does not).
function M.setup()
  M.gen = M.gen + 1
  bind_session_keys(false)
  os.execute("mkdir -p '" .. state_dir .. "'")
  M.config_text = nil
  M.reload_config()
  local cfg = M.cfg
  M.entries = {}
  M.last_state = nil
  M.write_state()
  if _G.omahop_takeover == false or cfg.takeover == false then return M end
  seed_order()
  M.used = nil
  pcall(hl.timer, M.bind_same_app, { type = "oneshot", timeout = 3500 }) -- after the snapshot below is on disk
  pcall(hl.timer, M.refresh_binds, { type = "oneshot", timeout = 2000 }) -- after the config has finished loading, so the snapshot shows the final binds
  pcall(hl.on, "window.active", function(w) if w and w.address then M.order = Mru.touch(M.order, w.address) end end)
  pcall(hl.on, "window.close", function(w) if w and w.address then M.on_window_closed(w.address) end end)
  for _, chord in ipairs({ "ALT + TAB", "ALT + SHIFT + TAB" }) do pcall(hl.unbind, chord) end
  hl.bind("ALT + TAB", function() M.on_tab(1) end, {})
  hl.bind("ALT + SHIFT + TAB", function() M.on_tab(-1) end, {})
  return M
end

return M.setup()

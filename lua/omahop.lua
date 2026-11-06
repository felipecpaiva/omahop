-- omahop: Hyprland glue. Loaded from hyprland.lua by a guarded dofile (a missing or broken file must never break the config):
--   pcall(dofile, os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.felipecpaiva.omahop/lua/omahop.lua")
-- Logic lives in pure modules next to this file (config, scope, windows, mru, session); this file only talks to Hyprland.
-- The overlay is a separate Quickshell service that watches the state file this module writes (see write_state).
local here = debug.getinfo(1, "S").source:match("^@(.*)/") or "."
local function mod(name) return dofile(here .. "/" .. name .. ".lua") end
local Config, Scope, Windows, Mru, Session = mod("config"), mod("scope"), mod("windows"), mod("mru"), mod("session")

local M = {}
_G.omahop = M

M.tick_ms = 25
M.inject_key = "F24" -- see docs/research/spikes.md L1: without it, an app under the overlay sees a bare Alt tap and opens its menu bar
-- Chords active only while a session is open; ALT is held for the whole session. (Unbinding them at the end would also drop a
-- user's own bind on the same chord: shortcut, none exist in the stock set; upgrade by reading the bind list if one appears.)
M.session_keys = { ["ALT + ESCAPE"] = "escape", ["ALT + RETURN"] = "return", ["ALT + LEFT"] = "left", ["ALT + RIGHT"] = "right", ["ALT + UP"] = "up", ["ALT + DOWN"] = "down" }

local state_dir = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omahop"
M.state_path = state_dir .. "/state"
local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
M.config_path = config_home .. "/omahop/config.toml"
local layouts_dir = (os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")) .. "/omarchy/workspace-layouts"

M.order = {}
M.entries = {}
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
  local kept = Windows.filter(plain, M.current_context(), M.cfg.windows, Config.ignore_set(M.cfg))
  return Mru.sort(M.order, kept)
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
    "selected=" .. (s and s:selected() or 0), "style=" .. M.cfg.style, "thumbnails=" .. M.cfg.thumbnails }
  if s and s:is_open() then
    for _, e in ipairs(M.entries) do
      local clean = function(v) return (tostring(v):gsub("[%c]", " ")) end
      lines[#lines + 1] = table.concat({ "w", e.address, clean(e.class), e.minimized and 1 or 0, clean(e.title) }, "\t")
    end
  end
  local tmp = M.state_path .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return end
  f:write(table.concat(lines, "\n"), "\n")
  f:close()
  os.rename(tmp, M.state_path)
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

local function bind_session_keys(on)
  for chord, name in pairs(M.session_keys) do
    pcall(hl.unbind, chord)
    if on then pcall(hl.bind, chord, function() M.apply(M.session:key(M.now(), name)) end, {}) end
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
  if closed then bind_session_keys(false); M.gen = M.gen + 1 end
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

function M.on_tab(delta)
  if not Scope.active(M.cfg.scope, M.workspace_is_floating()) then return M.stock(delta) end
  inject()
  local now = M.now()
  if M.session:is_open() then
    M.apply(M.session:step(now, delta))
    return
  end
  M.entries = M.build_entries()
  local focused = hl.get_active_window()
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
  local cfg, problems = Config.load(M.config_path)
  M.cfg = cfg
  for _, p in ipairs(problems) do log("config: " .. p) end
  M.session = Session.new(cfg)
  M.entries = {}
  M.write_state()
  if _G.omahop_takeover == false or cfg.takeover == false then return M end
  seed_order()
  pcall(hl.on, "window.active", function(w) if w and w.address then M.order = Mru.touch(M.order, w.address) end end)
  pcall(hl.on, "window.close", function(w) if w and w.address then M.order = Mru.forget(M.order, w.address) end end)
  for _, chord in ipairs({ "ALT + TAB", "ALT + SHIFT + TAB" }) do pcall(hl.unbind, chord) end
  hl.bind("ALT + TAB", function() M.on_tab(1) end, {})
  hl.bind("ALT + SHIFT + TAB", function() M.on_tab(-1) end, {})
  return M
end

return M.setup()

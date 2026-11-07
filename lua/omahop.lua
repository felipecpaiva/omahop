-- omahop: Hyprland glue. Loaded from hyprland.lua by a guarded dofile (a missing or broken file must never break the config):
--   pcall(dofile, os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.felipecpaiva.omahop/lua/omahop.lua")
-- Logic lives in pure modules next to this file (config, scope, windows, mru, session); this file only talks to Hyprland.
-- The overlay is a separate Quickshell service that watches the state file this module writes (see write_state).
local here = debug.getinfo(1, "S").source:match("^@(.*)/") or "."
local function mod(name) return dofile(here .. "/" .. name .. ".lua") end
local Config, Scope, Windows, Mru, Session, Search, Rules, Hints, Modifier = mod("config"), mod("scope"), mod("windows"), mod("mru"), mod("session"), mod("search"), mod("rules"), mod("hints"), mod("modifier")

local M = {}
_G.omahop = M

M.tick_ms = 16 -- key polling interval: shorter means the modifier's release is noticed sooner (a tick costs about 8 microseconds, measured)
M.release_ms = 50 -- after the overlay lets go of the keyboard, wait this long before focusing: a focus call is ignored while it holds the keyboard (linger spike)
M.query_max = 256 -- bytes of a search typed into the overlay (set_query); longer is refused
M.inject_key = "F24" -- see docs/research/spikes.md L1: without it, an app under the overlay sees a bare Alt tap and opens its menu bar
M.trigger_key = "TAB"
-- Keys active only while a session is open, each with the modifier (setting `modifier`, held for the whole session). (Unbinding them at the end would also drop a
-- user's own bind on the same chord: shortcut, none exist in the stock set; upgrade by reading the bind list if one appears.)
M.session_keys = { DELETE = "delete", ESCAPE = "escape", RETURN = "return", LEFT = "left", RIGHT = "right", UP = "up", DOWN = "down" }
M.mod = Modifier.get(Modifier.default) -- pinned in setup: the chords and the polled keys must stay the ones that were bound

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
M.seq = 0           -- the newest sequence number applied from the overlay (set_query, key)
M.grabbed = false   -- the overlay was told to hold the keyboard during this session

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
  local open, lingering = s and s:is_open(), s and s:is_lingering()
  -- the overlay holds the keyboard while lingering, and already from the first typed letter (Alt still held) so no key is lost at the Alt release
  local grab = open and s:is_revealed() and M.cfg.search_linger_seconds > 0 and (lingering or M.query ~= "")
  if grab then M.grabbed = true end
  local lines = { "version=1", "open=" .. (open and 1 or 0), "revealed=" .. ((s and s:is_revealed()) and 1 or 0),
    "selected=" .. (s and s:selected() or 0), "style=" .. M.cfg.style, "thumbnails=" .. M.cfg.thumbnails, "border=" .. M.cfg.border, "actions=" .. (M.cfg.actions and 1 or 0),
    "seq=" .. M.seq, "grab=" .. (grab and 1 or 0) }
  if lingering then
    lines[#lines + 1] = "linger_ms=" .. (M.cfg.search_linger_seconds * 1000)
    lines[#lines + 1] = "linger_rev=" .. s:linger_rev()
  end
  if open then lines[#lines + 1] = "query=" .. (tostring(M.query):gsub("[%c]", " ")) end
  if open then
    -- hint labels (a number or a letter on a row) only while nothing is typed and Alt is held: once there is a query, or while lingering, every key types
    local labels = (M.query == "" and not lingering) and Hints.labels(M.entries, M.cfg.hints, Hints.parse_keys(M.cfg.hint_keys)) or {}
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

-- Letters, digits, space and backspace, typed while the modifier is held. Each maps to what it adds to the query.
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
  M.entries = Search.filter(M.all_entries, M.query, M.names, { fuzzy = M.cfg.search_fuzzy })
  M.session:resize(#M.entries, #M.entries > 0 and 1 or 0)
  M.session:mark_query(M.query ~= "")
  M.write_state()
end

function M.type_key(ch)
  if not M.session:is_open() then return end
  -- a hint key (a number, or a letter mapped to an app) jumps straight to a window, but only while nothing is typed yet
  M.session:touch(M.now())
  if M.query == "" and not M.session:is_lingering() and M.cfg.hints ~= "off" and ch ~= "backspace" and ch ~= " " then
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
  -- keys with a bind of the user's own are left alone; unknown (no snapshot yet) is allowed for navigation keys, never for typing
  local function free(key) return Modifier.free(M.mod, used, key) ~= false end
  local function add(key, fn)
    local chord = Modifier.chord(M.mod, key)
    if pcall(hl.bind, chord, fn, {}) then M.bound[#M.bound + 1] = chord end
  end
  for key, name in pairs(M.session_keys) do
    if free(key) then
      add(key, function()
        if name == "delete" then M.close_selected(); return end                           -- quick action: close the picked window
        M.apply(M.session:key(M.now(), name))
      end)
    end
  end
  if M.cfg.search and used ~= nil then
    for key, ch in pairs(typing_keys()) do
      if free(key) then add(key, function() M.type_key(ch) end) end
    end
  end
end

local function keys_down()
  local ok, tab = pcall(hl.is_key_down, "Tab")
  return { mod = Modifier.held(M.mod, hl.is_key_down), tab = ok and tab or nil }
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
  if #M.all_entries < 1 then M.apply(M.session:key(M.now(), "cancel")); return end
  local sel = #M.entries == 0 and 0 or math.min(math.max(M.session:selected(), 1), #M.entries)
  M.session:resize(#M.entries, sel)
  M.write_state()
end

-- The keyboard while lingering (search_linger_seconds): the overlay owns the typed text and sends all of it, never a single key, with a sequence
-- number; an older call that lands late is dropped. Called through `hyprctl eval`, so every argument is checked here.
M.overlay_keys = { ["return"] = true, escape = true, cancel = true, up = true, down = true, left = true, right = true }

function M.set_query(seq, text)
  if not (M.session and M.session:is_open()) or type(text) ~= "string" then return end
  local n = Session.newer(M.seq, seq)
  text = text:gsub("%c", "")
  if not n or #text > M.query_max or not utf8.len(text) then return end
  M.seq = n
  M.session:touch(M.now())
  if text ~= M.query then M.query = text; M.refilter() else M.write_state() end
end

function M.key(seq, name)
  if not (M.session and M.session:is_open()) or not M.overlay_keys[name] then return end
  local n = Session.newer(M.seq, seq)
  if not n then return end
  M.seq = n
  M.apply(M.session:key(M.now(), name))
end

function M.apply(actions)
  local closed, target = false, nil
  for _, a in ipairs(actions) do
    if a.type == "commit" then target = M.entries[a.index]; closed = true
    elseif a.type == "cancel" then closed = true
    elseif a.type == "clear" then M.query = ""; M.refilter()
    end
  end
  if not closed then M.write_state(); return end
  local grabbed = M.grabbed
  bind_session_keys(false); M.gen = M.gen + 1; M.query = ""; M.grabbed = false
  M.write_state() -- open=0 first: the overlay lets go of the keyboard
  if not target then return end
  if grabbed then hl.timer(function() M.activate(target) end, { type = "oneshot", timeout = M.release_ms }) else M.activate(target) end
end

-- Chained one-shot timers: hl.timer has no stop handle, a generation number does.
local function tick(gen)
  if gen ~= M.gen or not M.session:is_open() then return end
  local ok, err = pcall(function() M.apply(M.session:tick(M.now(), keys_down())) end)
  if not ok then
    log("tick error: " .. tostring(err))
    M.session:key(M.now(), "cancel"); bind_session_keys(false); M.gen = M.gen + 1; M.write_state()
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

-- Give a chord's key back to the focused app (used when a chord with no stock meaning fires where omahop is not active). send_key_state, never pass: pass makes Hyprland call the bind again.
function M.pass_chord(chord, shift)
  local key = chord and chord:match("%+ (%w+)$")
  local w = hl.get_active_window()
  if not key or not w then return end
  key = key:lower()
  local mods = M.mod.bind .. (shift and " SHIFT" or "")
  pcall(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down", window = w }))
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up", window = w }))
  end)
end

-- Bind the same-app shortcut (and its Shift variant) once the snapshot of existing binds is there: a chord that is already used is left alone (never unbound).
-- Only chords that start with the modifier work (omahop polls that key to know when to end).
function M.bind_same_app()
  local chord = M.cfg and M.cfg.same_app_key or ""
  if chord == "" then return end
  local key = chord:match("^" .. M.mod.bind .. " %+ (%w+)$")
  if not key then log("same_app_key must start with the key to hold, like " .. Modifier.chord(M.mod, "GRAVE") .. ", ignored: " .. chord); return end
  local used = load_used()
  if used == nil then log("same_app_key: no snapshot of the binds yet, not bound"); return end
  if not Modifier.free(M.mod, used, key, true) then log("same_app_key: " .. chord .. " is already used, left alone"); return end
  M.same_app_chord = chord
  hl.bind(chord, function() M.on_tab(1, "same_app") end, {})
  hl.bind(Modifier.shift_chord(M.mod, key), function() M.on_tab(-1, "same_app") end, {})
end

local function bind_trigger_now()
  local chord, shifted = Modifier.chord(M.mod, M.trigger_key), Modifier.shift_chord(M.mod, M.trigger_key)
  for _, c in ipairs({ chord, shifted }) do pcall(hl.unbind, c) end
  hl.bind(chord, function() M.on_tab(1) end, {})
  hl.bind(shifted, function() M.on_tab(-1) end, {})
end

-- A modifier other than Alt: its Tab chord has no Omarchy meaning omahop could run itself, so it is bound only when the snapshot shows
-- it (and its Shift variant) free; otherwise nothing is bound and the reason is logged. Runs after the snapshot, like the same-app chord.
function M.bind_trigger()
  local chord, shifted = Modifier.chord(M.mod, M.trigger_key), Modifier.shift_chord(M.mod, M.trigger_key)
  local free = Modifier.free(M.mod, load_used(), M.trigger_key, true)
  if free == nil then log("modifier: no snapshot of the binds yet, " .. chord .. " not bound"); return end
  if not free then
    log("modifier: " .. chord .. " or " .. shifted .. " is already used, omahop is not bound. Free both in your bindings or choose another key to hold.")
    return
  end
  bind_trigger_now()
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

-- What the trigger does where omahop is not active: Omarchy's stock Alt+Tab when omahop replaced it, else the key goes back to the app.
function M.stock(delta)
  if not M.mod.replaces then return M.pass_chord(Modifier.chord(M.mod, M.trigger_key), delta < 0) end
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
-- whether the binds exist at all, so it only applies at load (the panel offers a reload for it); `modifier` too, for the same reason.
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
  M.mod = Modifier.get(cfg.modifier)
  M.entries = {}
  M.last_state = nil
  M.write_state()
  if _G.omahop_takeover == false or cfg.takeover == false then return M end
  seed_order()
  M.used = nil
  pcall(hl.timer, M.bind_same_app, { type = "oneshot", timeout = 3500 }) -- after the snapshot below is on disk
  if not M.mod.replaces then pcall(hl.timer, M.bind_trigger, { type = "oneshot", timeout = 3500 }) end
  pcall(hl.timer, M.refresh_binds, { type = "oneshot", timeout = 2000 }) -- after the config has finished loading, so the snapshot shows the final binds
  pcall(hl.on, "window.active", function(w) if w and w.address then M.order = Mru.touch(M.order, w.address) end end)
  pcall(hl.on, "window.close", function(w) if w and w.address then M.on_window_closed(w.address) end end)
  if M.mod.replaces then bind_trigger_now() end -- at once, unconditionally: it replaces Omarchy's own Alt+Tab (M.stock runs that out of scope)
  return M
end

return M.setup()

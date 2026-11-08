-- omahop: Hyprland glue. Loaded from hyprland.lua by a guarded dofile (a missing or broken file must never break the config):
--   pcall(dofile, os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.felipecpaiva.omahop/lua/omahop.lua")
-- Logic lives in pure modules next to this file (config, scope, windows, mru, session); this file only talks to Hyprland.
-- The overlay is a separate Quickshell service that watches the state file this module writes (see write_state).
local here = debug.getinfo(1, "S").source:match("^@(.*)/") or "."
local function mod(name) return dofile(here .. "/" .. name .. ".lua") end
local Config, Scope, Windows, Mru, Session, Search, Rules, Hints, Modifier, ActionKeys = mod("config"), mod("scope"), mod("windows"), mod("mru"), mod("session"), mod("search"), mod("rules"), mod("hints"), mod("modifier"), mod("action_keys")
local Tabs, Swipe = mod("tabs"), mod("swipe")

local M = {}
-- A gesture cannot be unregistered or registered twice (Hyprland refuses the second with a config error), and a reload makes a new
-- Lua state with no gestures. So a second load in the same state (eval-based) inherits the flag; the gesture calls whatever _G.omahop is.
M.swipe_registered = type(_G.omahop) == "table" and _G.omahop.swipe_registered == true
_G.omahop = M

M.tick_ms = 16 -- key polling interval: shorter means the modifier's release is noticed sooner (a tick costs about 8 microseconds, measured)
M.release_ms = 50 -- after the overlay lets go of the keyboard, wait this long before focusing: a focus call is ignored while it holds the keyboard (linger spike)
M.query_max = 256 -- bytes of a search typed into the overlay (set_query); longer is refused
M.inject_key = "F24" -- see docs/research/spikes.md L1: without it, an app under the overlay sees a bare Alt tap and opens its menu bar
M.action_map = {} -- key -> action name, from action_keys (see reload_config)
M.trigger_key = "TAB"
-- Keys active only while a session is open, each with the modifier (setting `modifier`, held for the whole session). (Unbinding them at the end would also drop a
-- user's own bind on the same chord: shortcut, none exist in the stock set; upgrade by reading the bind list if one appears.)
M.session_keys = { DELETE = "delete", ESCAPE = "escape", RETURN = "return", LEFT = "left", RIGHT = "right", UP = "up", DOWN = "down" }
M.mod = Modifier.get(Modifier.default) -- pinned in setup: the chords and the polled keys must stay the ones that were bound
M.swipe_direction = "horizontal" -- hl.gesture axis for the swipe trigger: left and right (the sign of each update's delta.x picks the way)

local state_dir = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/omahop"
M.state_path = state_dir .. "/state"
local config_home = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
M.config_path = config_home .. "/omahop/config.toml"
M.tabs_activate_cmd = here .. "/../tools/omahop-tabs-activate" -- detached helpers for browser tabs (setting browser_tabs)
M.tabs_request_cmd = here .. "/../tools/omahop-tabs-request" -- asks the extension for pictures (docs/file-contract.md)
M.tabs_files_cmd = here .. "/../tools/omahop-tabs-files"
M.tabs_flag = state_dir .. "/tabs.enabled"
M.tabs_draw_flag = state_dir .. "/tabs.draw" -- setting browser_tab_previews_draw: the extension may draw pictures of tabs never shown
M.tabs_pictures_flag = state_dir .. "/tabs.pictures" -- setting browser_tab_previews: the helper may keep page pictures only while it exists
local layouts_dir = (os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")) .. "/omarchy/workspace-layouts"

M.order = {}
M.entries = {}      -- what the session shows (filtered by the search query)
M.all_entries = {}  -- every window of this session, before the query
M.pic_requested = {} -- tabs already asked for a drawing in this session ("<hostpid>:<id>")
M.pic_pending = {} -- tabs a request is still waiting for a picture of; polling ends when it is empty
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
    pid = math.tointeger(w.pid),
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
    local clean = function(v) return (tostring(v):gsub("[%c]", " ")) end
    for i, e in ipairs(M.entries) do
      if e.tab then -- a browser tab row: only what the overlay draws (the title and the site), never the address
        lines[#lines + 1] = table.concat({ "t", e.address, clean(e.class), e.minimized and 1 or 0, e.tab.active and 1 or 0, e.tab.icon or "", e.tab.picture or "", e.tab.asleep and 1 or 0, e.tab.nopic or "", clean(e.tab.host), clean(e.title) }, "\t")
      else
        lines[#lines + 1] = table.concat({ "w", e.address, clean(e.class), e.minimized and 1 or 0, labels[i] or "", clean(e.title) }, "\t")
      end
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
  if entry.tab then M.request_tab(entry.tab) end -- the tab first, then the window (spike section 4: Hyprland owns focus)
  if entry.minimized then
    local ws = hl.get_active_workspace()
    if not ws or ws.id < 1 then return end -- a named workspace: leave it, as the dock does
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(ws.id), window = w }))
  end
  hl.dispatch(hl.dsp.focus({ window = w }))
  hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
end

-- ---- browser tabs (setting browser_tabs, off by default; docs/file-contract.md) ----
-- Off: no file is read and none is made. On: the flag file tells the omahop-tabs helper to write tab files; they are read once per
-- session, at the first typed letter (tab rows only show with a search), never on a timer. Titles and addresses are never logged.

local function sq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

-- Ask the browser to show a tab: a detached helper writes to the helper's FIFO. Never opened from here: a FIFO open for writing blocks
-- until a reader exists, and a blocked call here freezes the desktop (docs/gotchas.md).
function M.request_tab(tab)
  local pid, id = math.tointeger(tab and tab.hostpid), math.tointeger(tab and tab.id)
  if not (pid and id and pid > 0 and id >= 0) then return end
  hl.exec_cmd(("%s %d %d"):format(sq(M.tabs_activate_cmd), pid, id))
end

-- Make the flag and ignore files match the setting (detached helper, only when the setting or the list changed). When off and no flag
-- exists, nothing runs at all.
function M.sync_tabs_files()
  local names, bad = Tabs.ignore_list(M.cfg.browser_tabs_ignore)
  local pictures = M.cfg.browser_tabs and M.cfg.browser_tab_previews == true -- page pictures need tab search on as well
  local draw = pictures and M.cfg.browser_tab_previews_draw == true -- drawing needs page pictures on
  local key = M.cfg.browser_tabs and ("on " .. table.concat(names, " ") .. (pictures and " pictures" or "") .. (draw and " draw" or "")) or "off"
  if key == M.tabs_files_key then return end
  M.tabs_files_key = key
  if M.cfg.browser_tabs then
    for _, b in ipairs(bad) do log("config: browser_tabs_ignore: skipped a name that is not a site name: " .. b) end
    local quoted = {}
    for i, n in ipairs(names) do quoted[i] = sq(n) end -- globs (* ? [) must reach the helper unexpanded
    hl.exec_cmd(("%s %s on %s"):format(sq(M.tabs_files_cmd), sq(state_dir), table.concat(quoted, " ")))
    if pictures then
      hl.exec_cmd(("%s %s pictures-on"):format(sq(M.tabs_files_cmd), sq(state_dir)))
    else
      local f = io.open(M.tabs_pictures_flag, "r") -- nothing runs when there is no flag
      if f then f:close(); hl.exec_cmd(("%s %s pictures-off"):format(sq(M.tabs_files_cmd), sq(state_dir))) end
    end
    if draw then
      hl.exec_cmd(("%s %s draw-on"):format(sq(M.tabs_files_cmd), sq(state_dir)))
    else
      local f = io.open(M.tabs_draw_flag, "r")
      if f then f:close(); hl.exec_cmd(("%s %s draw-off"):format(sq(M.tabs_files_cmd), sq(state_dir))) end
    end
  else
    local f = io.open(M.tabs_flag, "r")
    if f then f:close(); hl.exec_cmd(("%s %s off"):format(sq(M.tabs_files_cmd), sq(state_dir))) end
  end
end

-- A process's parent pid from /proc, or nil when it is gone.
function M.parent_pid(pid)
  local text = read_file("/proc/" .. math.tointeger(pid) .. "/stat")
  return text and math.tointeger(tonumber(text:match(".*%) %S+ (%d+)")))
end

-- The tab files in the runtime folder, "<name> <mtime>" per line. Lua cannot list a folder, so `find` does it (not hyprctl: no deadlock).
function M.list_tab_files()
  local ok, text = pcall(function()
    local p = io.popen(("find %s -maxdepth 1 -type f -name 'tabs.*.json' -printf '%%f %%T@\\n' 2>/dev/null"):format(sq(state_dir)))
    if not p then return "" end
    local t = p:read("a"); p:close()
    return t
  end)
  if not ok then log("tabs: cannot list the runtime folder") end
  return ok and text or ""
end

local function read_tab_file(name)
  local f = io.open(state_dir .. "/" .. name, "r")
  if not f then return nil end
  local size = f:seek("end")
  local text = size and size <= Tabs.limits.bytes and f:seek("set") and f:read("a") or nil
  f:close()
  return text
end

-- The fresh tab files (host process alive, written recently) and the parent pids found on the way. Reads no file.
local function fresh_tab_files(quiet)
  local parents, files = {}, {}
  local function alive(pid) parents[pid] = parents[pid] or M.parent_pid(pid); return parents[pid] ~= nil end
  for _, file in ipairs(Tabs.listing(M.list_tab_files())) do
    local fresh, why = Tabs.fresh(file, os.time(), alive)
    if fresh then files[#files + 1] = file elseif not quiet then log("tabs: skipped " .. file.name .. ": " .. tostring(why)) end
  end
  return files, parents
end

-- Fresh, well-formed tab files, parsed. The skip reason never holds a title or an address (lua/tabs.lua).
local function tab_snapshots(quiet)
  local files, parents = fresh_tab_files(quiet)
  local snaps = {}
  for _, file in ipairs(files) do
    local snap, why = Tabs.parse(read_tab_file(file.name))
    if snap then
      snap.hostpid, snap.pids = file.pid, { [snap.pid] = true, [parents[file.pid]] = true }
      snaps[#snaps + 1] = snap
    elseif not quiet then
      log("tabs: skipped " .. file.name .. ": " .. tostring(why))
    end
  end
  return snaps
end

-- Tab rows for this session: fresh, well-formed files only, matched against every Hyprland window, ignored sites left out.
function M.load_tab_rows()
  if not M.cfg.browser_tabs then return {} end
  local snaps = tab_snapshots()
  if #snaps == 0 then return {} end
  local hwins = {}
  for _, w in ipairs(hl.get_windows()) do
    hwins[#hwins + 1] = { address = w.address, class = w.class or "", title = w.title or "", pid = math.tointeger(w.pid), focus_history = w.focus_history_id or 1e9 }
  end
  return Tabs.rows(snaps, hwins, (Tabs.ignore_list(M.cfg.browser_tabs_ignore)))
end

-- ---- page pictures on request (docs/file-contract.md, decision D26) ----
-- Detached again, never a FIFO opened here. `shown` (once per session, to every live host) asks the extension to photograph the tab each of its
-- windows shows; `draw` (at session start for the first 6 background tabs per host without a picture, then at search time for the rest, only with
-- browser_tab_previews_draw) asks it to draw tabs that have no picture. While a request
-- is recent the tab files are re-read about every 400 ms (files only, no hyprctl) so a picture shows as soon as it exists.
M.pic_window_ms, M.pic_poll_ms, M.draw_max_ids, M.draw_max_line = 6000, 400, 6, 63

local function pictures_on() return M.cfg.browser_tabs and M.cfg.browser_tab_previews == true end
local function draw_on() return pictures_on() and M.cfg.browser_tab_previews_draw == true end

-- keys: "<hostpid>:<id>" of the tabs this request is waiting for. The tab files are polled only while some are pending (and for 6 s at most).
local function send_request(hostpid, what, keys)
  local pid = math.tointeger(hostpid)
  if not (pid and pid > 0) then return end
  hl.exec_cmd(("%s %s %d %s"):format(sq(M.tabs_request_cmd), sq(state_dir), pid, what))
  for _, key in ipairs(keys or {}) do M.pic_pending[key] = true end
  if next(M.pic_pending) then M.pic_until, M.pic_next = M.now() + M.pic_window_ms, nil end
end

-- Session start: ask every live host for a fresh picture of its shown tabs. Only the shown tabs without a picture are waited for.
function M.request_shown()
  if not pictures_on() then return end
  for _, snap in ipairs(tab_snapshots(true)) do
    local keys = {}
    for _, w in ipairs(snap.windows) do
      for _, t in ipairs(w.tabs) do
        if t.active and not t.picture then keys[#keys + 1] = snap.hostpid .. ":" .. t.id end
      end
    end
    send_request(snap.hostpid, "shown", keys)
  end
end

local function send_draws(requests)
  for _, r in ipairs(requests) do
    local ids, keys = {}, {}
    for i, id in ipairs(r.ids) do ids[i] = ("%d"):format(id); keys[i] = r.hostpid .. ":" .. ids[i] end
    send_request(r.hostpid, "draw " .. table.concat(ids, " "), keys)
  end
end

-- Session start, before any letter (only with browser_tab_previews_draw): draw the first 6 background tabs of each host that have no picture.
function M.request_open_draws()
  if not draw_on() then return end
  local entries = {}
  for i, row in ipairs(M.load_tab_rows()) do entries[i] = { tab = row } end -- rows are flat; the request logic takes entries
  send_draws(Tabs.open_draw_requests(entries, M.pic_requested, M.draw_max_ids, M.draw_max_line))
end

-- After a search: ask for drawings of the visible tabs that have none (those not asked for at session start).
function M.request_draws()
  if not (M.tabs_loaded and draw_on()) then return end
  send_draws(Tabs.draw_requests(M.entries, M.pic_requested, M.draw_max_ids, M.draw_max_line))
end

-- While a request is recent: pull new picture names from the tab files into the entries and rewrite the state only when one changed.
function M.poll_pictures(now)
  if not M.pic_until then return end
  if now >= M.pic_until then M.pic_until = nil; return end
  if not M.tabs_loaded or (M.pic_next and now < M.pic_next) then return end
  M.pic_next = now + M.pic_poll_ms
  local ok, err = pcall(function()
    local pics, why = {}, {}
    for _, snap in ipairs(tab_snapshots(true)) do -- quiet: the same skip would be logged every 400 ms
      for _, w in ipairs(snap.windows) do
        for _, t in ipairs(w.tabs) do
          pics[snap.hostpid .. ":" .. t.id] = t.picture or false
          why[snap.hostpid .. ":" .. t.id] = t.nopic or false
        end
      end
    end
    for key in pairs(M.pic_pending) do
      -- it has a picture, the tab is gone, or the extension gave a lasting reason (queued and limit are temporary: still waiting)
      if pics[key] ~= false or (why[key] and why[key] ~= "queued" and why[key] ~= "limit") then M.pic_pending[key] = nil end
    end
    if not next(M.pic_pending) then M.pic_until = nil end -- nothing is waited for: no more polling
    local changed = false
    for _, list in ipairs({ M.all_entries, M.entries }) do
      for _, e in ipairs(list) do
        local key = e.tab and (e.tab.hostpid .. ":" .. e.tab.id)
        local p = key and pics[key]
        if p ~= nil and (p or nil) ~= e.tab.picture then e.tab.picture = p or nil; changed = true end
        local n = key and why[key]
        if n ~= nil and (n or nil) ~= e.tab.nopic then e.tab.nopic = n or nil; changed = true end
      end
    end
    if changed then M.write_state() end
  end)
  if not ok then log("tabs: picture poll failed: " .. tostring(err)) end
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
  if M.query ~= "" and not M.tabs_loaded then -- tab rows show only with a search: read the tab files once, at the first letter
    M.tabs_loaded = true
    M.all_entries = Tabs.interleave(M.all_entries, M.load_tab_rows())
  end
  M.entries = Tabs.without_copies(Search.filter(M.all_entries, M.query, M.names, { fuzzy = M.cfg.search_fuzzy }))
  M.session:resize(#M.entries, #M.entries > 0 and 1 or 0)
  M.session:mark_query(M.query ~= "")
  M.write_state()
  M.request_draws()
end

function M.type_key(ch)
  if not M.session:is_open() then return end
  -- a hint key (a number, or a letter mapped to an app) jumps straight to a window, but only while nothing is typed yet
  M.session:touch(M.now())
  if M.query == "" and not M.session:is_lingering() and M.cfg.hints ~= "off" and ch ~= "backspace" and ch ~= " " then
    local target = Hints.target(M.entries, M.cfg.hints, Hints.parse_keys(M.cfg.hint_keys), ch)
    if target then M.pick(target); return end
  end
  -- an action key (action_keys, for example q=close) acts on the selected row, same rule: only while nothing is typed yet
  local action = M.query == "" and not M.session:is_lingering() and M.action_map[ch]
  if action then M.act(action); return end
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
      -- a capital is Shift plus the letter: it types the same letter (the search ignores case), unless that chord is a bind of the user's own
      if key:match("^%a$") and Modifier.free(M.mod, used, key, true) ~= false then
        local chord = Modifier.shift_chord(M.mod, key)
        if pcall(hl.bind, chord, function() M.type_key(ch) end, {}) then M.bound[#M.bound + 1] = chord end
      end
    end
  end
end

local function keys_down()
  local ok, tab = pcall(hl.is_key_down, "Tab")
  if not ok then tab = nil end
  if M.swipe and M.swipe:is_active() then return { mod = true, tab = tab } end -- fingers on the touchpad hold the session, as the modifier does
  return { mod = Modifier.held(M.mod, hl.is_key_down), tab = tab }
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
  if e and not e.tab then M.close_window(e.address) end -- a tab row never closes its whole browser window
end

-- What an action key can do to the selected window; the names here are the only ones action_keys accepts. Both reuse the pointer's paths (never a synchronous hyprctl).
M.actions = { close = function(address) M.close_window(address) end, minimize = function(address) M.minimize_window(address) end }

-- Run a named action on the selected row, then take that row out of the list so the selection lands on the next one (an empty list ends the session).
function M.act(name)
  local e = M.entries[M.session:selected()]
  local run = M.actions[name]
  if not (e and run) or e.tab then return end
  run(e.address)
  M.drop_entry(e.address)
end

-- A window went away: forget it, and while a session is open take it out of the list (selection stays in range, nothing left ends the session).
function M.on_window_closed(address)
  M.order = Mru.forget(M.order, address)
  M.drop_entry(address)
end

-- Take a window out of the open session's list. Selection keeps its index, which is now the next row, clamped to the end.
function M.drop_entry(address)
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
  bind_session_keys(false); M.gen = M.gen + 1; M.query = ""; M.grabbed = false; M.pic_until = nil
  M.write_state() -- open=0 first: the overlay lets go of the keyboard
  if not target then return end
  if grabbed then hl.timer(function() M.activate(target) end, { type = "oneshot", timeout = M.release_ms }) else M.activate(target) end
end

-- Chained one-shot timers: hl.timer has no stop handle, a generation number does.
local function tick(gen)
  if gen ~= M.gen or not M.session:is_open() then return end
  local ok, err = pcall(function()
    local now = M.now()
    if M.swipe and M.swipe:expired(now) then M.swipe:stop(); M.apply(M.session:key(now, "cancel")); return end -- no finish event came: close, never pick
    M.apply(M.session:tick(now, keys_down()))
    if M.pic_until then M.poll_pictures(now) end
  end)
  if not ok then
    log("tick error: " .. tostring(err))
    M.session:key(M.now(), "cancel"); bind_session_keys(false); M.gen = M.gen + 1; M.write_state()
    return
  end
  if M.session:is_open() then hl.timer(function() tick(gen) end, { type = "oneshot", timeout = M.tick_ms }) end
end

-- The windows of the focused window's app (the same-app list). Without a focused window the list is unchanged.
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
  if M.mod.replaces then for _, c in ipairs({ chord, shifted }) do pcall(hl.unbind, c) end end -- only Alt replaces a bind; the others bind only free chords
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
  local cfg, problems = Config.resolve(parsed) -- the base settings with the chosen profile laid over them
  for _, line in ipairs(bad) do problems[#problems + 1] = "unreadable line: " .. line end
  for _, p in ipairs(problems) do log("config: " .. p) end
  M.cfg = cfg
  local synced, why = pcall(M.sync_tabs_files) -- a tabs problem must never stop the switcher loading
  if not synced then log("tabs: cannot update the flag files: " .. tostring(why)) end
  local known = {}
  for name in pairs(M.actions) do known[name] = true end
  local keys, key_problems = ActionKeys.resolve(cfg.action_keys, known, cfg.hints, Hints.parse_keys(cfg.hint_keys))
  for _, p in ipairs(key_problems) do log("config: " .. p) end
  M.action_map = keys
  M.session = Session.new(cfg)
end

-- `list` is "same_app" for the same-app shortcut, nil for the main one (not to be confused with the `profile` setting).
function M.on_tab(delta, list)
  if not (M.session and M.session:is_open()) then
    M.reload_config()
    -- Fullscreen apps and listed apps keep Alt+Tab to themselves: stock behaviour, decided at the press before anything opens.
    local aw = hl.get_active_window()
    if Rules.passthrough(aw and { class = aw.class, fullscreen = aw.fullscreen } or nil, M.cfg.passthrough_fullscreen, Rules.set(M.cfg.passthrough)) then return M.stock(delta) end
  end
  if not Scope.active(M.cfg.scope, M.workspace_is_floating()) then
    if list == "same_app" then return M.pass_chord(M.same_app_chord) end -- the chord has no stock meaning: give the key back to the app
    return M.stock(delta)
  end
  inject()
  local now = M.now()
  if M.session:is_open() then
    M.apply(M.session:step(now, delta))
    return
  end
  if M.swipe then M.swipe:stop() end -- a swipe whose finish never came must not hold this keyboard session open
  M.open_session(now, delta, list)
end

-- Start a session on the list for the focused workspace (shared by the keyboard and the swipe). Returns false when there is nothing to switch to.
function M.open_session(now, delta, list)
  M.entries = M.build_entries()
  local focused = hl.get_active_window()
  if list == "same_app" then M.entries = M.same_app(M.entries, focused) end
  M.all_entries, M.query, M.names, M.tabs_loaded = M.entries, "", nil, false
  local first = Mru.first_pick(M.entries, focused and focused.address, delta)
  if #M.entries < 2 then M.entries = {}; return false end -- nothing to switch to
  M.gen = M.gen + 1
  bind_session_keys(true)
  M.pic_requested, M.pic_pending, M.pic_until, M.pic_next = {}, {}, nil, nil
  for _, ask in ipairs({ M.request_shown, M.request_open_draws }) do
    local asked, why = pcall(ask) -- pictures must never stop the switcher opening
    if not asked then log("tabs: cannot ask for pictures: " .. tostring(why)) end
  end
  M.apply(M.session:open(now, #M.entries, first))
  hl.timer(function() tick(M.gen) end, { type = "oneshot", timeout = M.tick_ms })
  return true
end

-- ---- touchpad swipe (setting swipe_trigger, off by default; docs/research/swipe-spike.md) ----
-- Hyprland calls start, update and finish for a swipe of `swipe_fingers` fingers left or right. The first row of travel opens the list
-- (no Alt is involved, so nothing is injected), each further row steps, lifting picks. Lifting on the window the swipe started from, or a
-- swipe Hyprland reports as cancelled, closes without switching. Where omahop is not active the swipe does nothing (it has no stock meaning).

function M.swipe_start()
  if M.session and M.session:is_open() then return end -- a keyboard session is running: this swipe is not ours
  M.reload_config()
  if not M.cfg.swipe_trigger then return end -- turned off in the settings since the last reload: the gesture stays registered but idle
  local aw = hl.get_active_window()
  if Rules.passthrough(aw and { class = aw.class, fullscreen = aw.fullscreen } or nil, M.cfg.passthrough_fullscreen, Rules.set(M.cfg.passthrough)) then return end
  if not Scope.active(M.cfg.scope, M.workspace_is_floating()) then return end
  M.swipe, M.swipe_from = Swipe.new(M.cfg.swipe_distance), aw and aw.address
  M.swipe:start(M.now())
end

function M.swipe_update(e)
  local sw = M.swipe
  if not (sw and sw:is_active()) then return end
  local now = M.now()
  local rows, first = sw:update(now, type(e) == "table" and type(e.delta) == "table" and e.delta.x or nil)
  if rows == 0 then return end
  if first then
    local dir = rows > 0 and 1 or -1
    if M.session:is_open() or not M.open_session(now, dir) then sw:stop(); return end
    rows = rows - dir
  end
  if rows ~= 0 and M.session:is_open() then M.apply(M.session:step(now, rows)) end
end

function M.swipe_finish(e)
  local sw = M.swipe
  if not (sw and sw:is_active()) then return end
  if not (sw:finish() and M.session:is_open()) then return end
  local sel = M.entries[M.session:selected()]
  local back = sel ~= nil and sel.address == M.swipe_from
  local cancelled = type(e) == "table" and e.cancelled == true
  M.apply(M.session:key(M.now(), (cancelled or back) and "cancel" or "return"))
end

-- Register the swipe once per Lua state. The callbacks go through _G.omahop, so a second load in the same state is served by the new module.
-- Registered at load, after the user's own config lines (omahop's dofile is the last line): a swipe they already use keeps working and
-- Hyprland reports ours as a config error instead (it is not a Lua error, so pcall only guards an older Hyprland without hl.gesture).
function M.bind_swipe()
  if not M.cfg.swipe_trigger or M.swipe_registered then return end
  local ok, err = pcall(hl.gesture, { fingers = M.cfg.swipe_fingers, direction = M.swipe_direction, action = {
    start = function() _G.omahop.swipe_start() end,
    update = function(e) _G.omahop.swipe_update(e) end,
    finish = function(e) _G.omahop.swipe_finish(e) end,
  } })
  if not ok then log("swipe: hl.gesture failed, swipe trigger off: " .. tostring(err)); return end
  M.swipe_registered = true
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
  os.execute("mkdir -p '" .. state_dir .. "' && chmod 700 '" .. state_dir .. "'") -- private: the state file can carry window and tab titles
  M.config_text, M.tabs_files_key = nil, nil
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
  M.bind_swipe()
  return M
end

return M.setup()

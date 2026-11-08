-- omahop browser tabs: read the tab files the omahop-tabs helper writes, match each browser window to a Hyprland window, and build tab rows.
-- Pure: files arrive as text, the clock, process facts and windows as plain values, so it tests without a browser or Hyprland.
-- File contract (schema 1, docs/file-contract.md): tabs.<hostpid>.json = { schema, browser, pid, caller, profile, windows = [ { id, focused, type, tabs = [ { id, active, title, url, icon?, picture? } ] } ] }.
-- Privacy: titles and urls are never put in an error reason, so a caller may log a reason as it is.
local here = debug.getinfo(1, "S").source:match("^@(.*)/") or "."
local Json = dofile(here .. "/json.lua")

local T = {}

T.schema = 1
T.icon_digits = 16 -- length of an icon file name key (helper: ICON_KEY_DIGITS)
T.picture_max = 64 -- bytes of a page picture name: <hosthash>/<urlkey>-<n>[d] (helper): 16 lower-case hex digits, a slash, 16 hex digits, a dash, up to 12 digits, optional d
T.file_pattern = "^tabs%.(%d+)%.json$"
T.limits = {
  bytes = 1024 * 1024,    -- one file (200 tabs measured at 34 KB, docs/research/tabs-spike.md section 6)
  files = 8,              -- files read per open (one per browser profile)
  windows = 200,          -- browser windows per file
  tabs = 2000,            -- tabs per file
  title = 300,            -- bytes of a title kept (cut on a character boundary)
  url = 2048,             -- bytes of a url looked at
  text = 256,             -- bytes of browser, caller and profile
  age_s = 24 * 3600,      -- a file not rewritten for this long is stale (the host rewrites on every tab event)
}
T.window_type = "normal"  -- popups and app windows have no tab strip; their windows stay ordinary rows
T.title_sep = " - "       -- Chromium titles a window "<active tab title> - <browser name>"
-- Window classes per browser name, used only when no Hyprland window carries the browser's pid (a wrapper or a sandbox between them).
-- Keys are the helper's `browser` field: the browser's process name (/proc/<pid>/comm).
T.classes = { chrome = "google-chrome", chromium = "chromium", brave = "brave-browser", msedge = "microsoft-edge" }

-- ---- reading ----

-- "tabs.<pid>.json" -> the host pid, else nil. Anything else in the folder (the flag, the ignore file, FIFOs, temp files) is not a tab file.
function T.host_pid(name)
  local pid = tostring(name or ""):match(T.file_pattern)
  return pid and #pid <= 10 and math.tointeger(tonumber(pid)) or nil
end

-- The folder listing ("<name> <mtime seconds>" per line, as find -printf writes it) -> { { name, pid, mtime } } of tab files, newest first, at most limits.files.
function T.listing(text)
  local out = {}
  for line in tostring(text or ""):gmatch("[^\n]+") do
    local name, mtime = line:match("^(%S+) (%d+)%.?%d*$")
    local pid = T.host_pid(name)
    if pid then out[#out + 1] = { name = name, pid = pid, mtime = tonumber(mtime) } end
  end
  table.sort(out, function(a, b) return a.mtime > b.mtime end)
  while #out > T.limits.files do out[#out] = nil end
  return out
end

-- A file is fresh when its host process is alive and it was written within limits.age_s. alive: pid -> bool.
function T.fresh(file, now_s, alive)
  if not alive(file.pid) then return false, "host gone" end
  if now_s - file.mtime > T.limits.age_s then return false, "too old" end
  return true
end

-- Cut a string to at most n bytes without splitting a UTF-8 character.
local function cut(s, n)
  if #s <= n then return s end
  local stop = utf8.offset(s, 0, n + 1) or (n + 1) -- start of the character holding byte n+1
  return s:sub(1, stop - 1)
end

-- A page picture name -> itself when it is exactly 16 lower-case hex digits, a slash, 16 hex digits, a dash, 1 to 12 digits and
-- optionally one trailing "d" (a drawn picture, approximate; without it the picture is a shot, exact); else nil.
function T.picture_name(v)
  if type(v) ~= "string" or #v > T.picture_max then return nil end
  local site, page, n = v:match("^(%x+)/(%x+)%-(%d+)d?$")
  if not site or #site ~= 16 or #page ~= 16 or #n > 12 or v:find("%u") then return nil end
  return v
end

local function is_int(v) return math.type(v) == "integer" and v >= 0 end
local function opt_text(v) return v == nil or v == Json.null or (type(v) == "string" and #v <= T.limits.text) end

local function check_tab(t)
  if type(t) ~= "table" or not is_int(t.id) or type(t.active) ~= "boolean" or type(t.title) ~= "string" or type(t.url) ~= "string" then return nil end
  if not utf8.len(t.title) then return nil end
  -- icon: the name of a site icon file in tabicons/ (16 hex digits, written by the helper); anything else is dropped, so it can never name another path
  local icon = type(t.icon) == "string" and t.icon:match("^%x+$") and #t.icon == T.icon_digits and t.icon or nil
  -- picture: the name of a page picture in tabpics/ (<hosthash>/<urlkey>-<n>, setting browser_tab_previews); anything else is dropped, so it can never name another path
  local picture = T.picture_name(t.picture)
  return { id = t.id, active = t.active, title = cut(t.title:gsub("%c", " "), T.limits.title), url = t.url:sub(1, T.limits.url), icon = icon, picture = picture }
end

local function check_window(w, budget)
  if type(w) ~= "table" or not is_int(w.id) or type(w.focused) ~= "boolean" or type(w.type) ~= "string" or type(w.tabs) ~= "table" then return nil end
  local out = { id = w.id, focused = w.focused, type = w.type, tabs = {} }
  for _, t in ipairs(w.tabs) do
    budget.tabs = budget.tabs - 1
    if budget.tabs < 0 then return nil end
    local tab = check_tab(t)
    if not tab then return nil end
    out.tabs[#out.tabs + 1] = tab
  end
  return out
end

-- Text of one file -> a snapshot, or nil and a reason. Any wrong type, an unknown schema or a size over a limit rejects the whole file.
function T.parse(text)
  if type(text) ~= "string" then return nil, "unreadable" end
  if #text > T.limits.bytes then return nil, "too big" end
  local v, why = Json.decode(text)
  if type(v) ~= "table" then return nil, "not JSON: " .. tostring(why or "not an object") end
  if v.schema ~= T.schema then return nil, "unknown schema" end
  if type(v.browser) ~= "string" or #v.browser > T.limits.text or not is_int(v.pid) or not opt_text(v.caller) or not opt_text(v.profile) then return nil, "bad header" end
  if type(v.windows) ~= "table" or #v.windows > T.limits.windows then return nil, "bad windows" end
  local snap, budget = { browser = v.browser, pid = v.pid, windows = {} }, { tabs = T.limits.tabs }
  for _, w in ipairs(v.windows) do
    local win = check_window(w, budget)
    if not win then return nil, "bad window or tab" end
    snap.windows[#snap.windows + 1] = win
  end
  return snap
end

-- ---- urls and the ignore list ----

-- A url -> its host (lower case, no user, no port) and path (no query, no fragment). Only scheme://host urls have a host; data:, about: and the like give "", "".
function T.url_parts(url)
  local rest = tostring(url or ""):match("^%a[%w+.-]*://(.*)$")
  if not rest then return "", "" end
  local authority, path = rest:match("^([^/?#]*)([^?#]*)")
  local host = (authority or ""):gsub("^.*@", ""):gsub(":%d*$", ""):lower()
  return host, path or ""
end

-- The browser_tabs_ignore setting ("bank.example.com, *.corp.example") -> a list of lower-case patterns, and the items that were skipped.
-- Same rules as the helper (omahop-tabs docs/file-contract.md): a plain name hides that host and its subdomains; a glob (* ? [...], fnmatch)
-- must match the whole host. Only letters, digits, dot, dash and the glob characters pass: the list is also handed to a helper and a file.
function T.ignore_list(text)
  local out, bad = {}, {}
  for item in tostring(text or ""):gmatch("[^,]+") do
    local name = item:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if name:match("^[%w*?%[][%w.%-*?%[%]!]*$") and #name <= 253 then out[#out + 1] = name
    elseif name ~= "" then bad[#bad + 1] = name end
  end
  return out, bad
end

-- An fnmatch glob -> an anchored Lua pattern (* any run, ? one character, [abc] and [!abc] sets, anything else literal).
function T.glob_pattern(glob)
  local out, i = { "^" }, 1
  while i <= #glob do
    local c = glob:sub(i, i)
    local close = c == "[" and glob:find("]", i + 2, true)
    if c == "*" then out[#out + 1] = ".*"
    elseif c == "?" then out[#out + 1] = "."
    elseif close then
      local body = glob:sub(i + 1, close - 1):gsub("^!", "^"):gsub("([%%%.%(%)%+%*%?%$])", "%%%1")
      out[#out + 1] = "[" .. body .. "]"; i = close
    else out[#out + 1] = (c:gsub("%W", "%%%0")) end
    i = i + 1
  end
  return table.concat(out) .. "$"
end

-- A host is ignored when a pattern matches it whole, or it is a subdomain of a pattern. A tab with no host (data:, file:) never is.
function T.ignored(host, names)
  if host == "" then return false end
  for _, n in ipairs(names or {}) do
    if host:match(T.glob_pattern(n)) or host:sub(-(#n + 1)) == "." .. n then return true end
  end
  return false
end

-- ---- matching a browser window to a Hyprland window (docs/research/tabs-spike.md section 3) ----
-- hwins: { address, class, title, pid, focus_history } for every Hyprland window. A snapshot's process ids (`pids`, a set) are its `pid`
-- field and the host's parent process, filled in by the caller; either may be the browser's.

local function active_title(bw)
  for _, t in ipairs(bw.tabs) do if t.active then return t.title end end
  return nil
end

-- The Hyprland windows a snapshot can belong to: same process first, then the browser's class (spike section 3, failure d).
local function pool_of(snap, hwins)
  local out = {}
  for _, h in ipairs(hwins) do if h.pid and snap.pids[h.pid] then out[#out + 1] = h end end
  if #out > 0 then return out, "pid:" .. out[1].pid end
  local class = T.classes[tostring(snap.browser):lower()]
  for _, h in ipairs(hwins) do if class and tostring(h.class):lower() == class then out[#out + 1] = h end end
  return out, "class:" .. tostring(class)
end

-- Title rule: the Hyprland title is the active tab title, alone or followed by " - <browser name>". The suffix seen most often in a pool is
-- learned and, when it narrows a window's candidates without emptying them, applied (a tab titled "a - b" must not claim the window of tab "a").
local function title_candidates(bws, hs)
  local cands, seen = {}, {}
  for _, bw in ipairs(bws) do
    cands[bw] = {}
    local t = active_title(bw)
    for _, h in ipairs(hs) do
      local title = h.title or ""
      if t and t ~= "" and (title == t or title:sub(1, #t + #T.title_sep) == t .. T.title_sep) then
        local rest = title:sub(#t + 1)
        cands[bw][#cands[bw] + 1] = { h = h, rest = rest }
        seen[rest] = (seen[rest] or 0) + 1
      end
    end
  end
  local learned, best = nil, 0
  for rest, n in pairs(seen) do
    if n > best or (n == best and learned and #rest < #learned) then learned, best = rest, n end
  end
  local out = {}
  for bw, list in pairs(cands) do
    local narrow, all = {}, {}
    for _, c in ipairs(list) do
      all[#all + 1] = c.h
      if c.rest == learned then narrow[#narrow + 1] = c.h end
    end
    out[bw] = #narrow > 0 and narrow or all
  end
  return out
end

-- Pair off windows that have exactly one free candidate, until nothing changes. Returns the number paired.
local function eliminate(bws, cands, res, taken)
  local paired, changed = 0, true
  while changed do
    changed = false
    for _, bw in ipairs(bws) do
      if not res[bw] then
        local free = {}
        for _, h in ipairs(cands[bw]) do if not taken[h] then free[#free + 1] = h end end
        cands[bw] = free
        if #free == 1 then res[bw] = free[1]; taken[free[1]] = true; changed = true; paired = paired + 1 end
      end
    end
  end
  return paired
end

local function free_windows(hs, taken)
  local out = {}
  for _, h in ipairs(hs) do if not taken[h] then out[#out + 1] = h end end
  return out
end

-- The window the user was in most recently, of a list (Hyprland's focus history: lower is more recent).
local function most_recent(list)
  local best
  for _, h in ipairs(list) do if not best or (h.focus_history or 1e9) < (best.focus_history or 1e9) then best = h end end
  return best
end

-- Match the browser windows of one pool. res[bw] = Hyprland window; cands[bw] = what is left for an unresolved one.
local function match_pool(bws, hs)
  local res, taken = {}, {}
  if #bws == 1 and #hs == 1 then res[bws[1]] = hs[1]; return res, {} end -- one window each: exact, no title involved
  local cands = title_candidates(bws, hs)
  eliminate(bws, cands, res, taken)
  -- tie break by focus: the browser's focused window is the one of this pool the user was in last
  for _, bw in ipairs(bws) do
    if not res[bw] and bw.focused then
      local h = most_recent(#cands[bw] > 0 and cands[bw] or free_windows(hs, taken))
      if h then res[bw] = h; taken[h] = true; eliminate(bws, cands, res, taken) end
    end
  end
  -- one browser window and one Hyprland window left over: they belong together
  local left = {}
  for _, bw in ipairs(bws) do if not res[bw] then left[#left + 1] = bw end end
  local free = free_windows(hs, taken)
  if #left == 1 and #free == 1 then res[left[1]] = free[1]; taken[free[1]] = true end
  for _, bw in ipairs(bws) do
    if not res[bw] then cands[bw] = #cands[bw] > 0 and free_windows(cands[bw], taken) or free_windows(hs, taken) end
  end
  return res, cands
end

-- snapshots -> { [browser window] = { address = <matched>, candidates = { addresses } } }; address is nil when unresolved.
function T.match(snapshots, hwins)
  local pools, order = {}, {}
  for _, snap in ipairs(snapshots) do
    local hs, key = pool_of(snap, hwins)
    if not pools[key] then pools[key] = { hs = hs, bws = {} }; order[#order + 1] = key end
    for _, bw in ipairs(snap.windows) do
      if bw.type == T.window_type then table.insert(pools[key].bws, bw) end
    end
  end
  local out = {}
  for _, key in ipairs(order) do
    local p = pools[key]
    local res, cands = match_pool(p.bws, p.hs)
    for _, bw in ipairs(p.bws) do
      local list = {}
      for _, h in ipairs(cands[bw] or {}) do list[#list + 1] = h.address end
      out[bw] = { address = res[bw] and res[bw].address, candidates = list }
    end
  end
  return out
end

-- ---- rows ----

-- snapshots (each with `hostpid` and `pids`) -> tab rows { window = address, hostpid, id, title, host, path, active }, ignored hosts left out.
-- An unresolved window's tabs go under its first candidate. shortcut: no verify-and-retry (spike section 3 step 4); add it if live checks show wrong windows.
function T.rows(snapshots, hwins, ignore)
  local matched, out = T.match(snapshots, hwins), {}
  for _, snap in ipairs(snapshots) do
    for _, bw in ipairs(snap.windows) do
      local m = matched[bw]
      local address = m and (m.address or m.candidates[1])
      if address then
        for _, t in ipairs(bw.tabs) do
          local host, path = T.url_parts(t.url)
          if not T.ignored(host, ignore) then
            out[#out + 1] = { window = address, hostpid = snap.hostpid, id = t.id, title = t.title, host = host, path = path, active = t.active, icon = t.icon, picture = t.picture }
          end
        end
      end
    end
  end
  return out
end

-- Put each tab row right after its window's entry, as an entry of its own (same address, so focusing it focuses the window).
-- Rows whose window is not in the list are dropped: the switcher never reaches outside its own window set.
function T.interleave(entries, rows)
  local by_window = {}
  for _, r in ipairs(rows) do
    by_window[r.window] = by_window[r.window] or {}
    table.insert(by_window[r.window], r)
  end
  local out = {}
  for _, e in ipairs(entries) do
    if not e.tab then
      out[#out + 1] = e
      for _, r in ipairs(by_window[e.address] or {}) do
        out[#out + 1] = { address = e.address, class = e.class, minimized = e.minimized, title = r.title,
          search_extra = r.host .. " " .. r.path, tab = { hostpid = r.hostpid, id = r.id, host = r.host, active = r.active, icon = r.icon, picture = r.picture } }
      end
    end
  end
  return out
end

-- Which tabs to ask the extension to draw (setting browser_tab_previews_draw): the entries a search shows, in order. A tab qualifies when it
-- has no picture yet (the shown tab too: a window on another workspace cannot be photographed) and was not asked for in this session (`requested`,
-- keys "<hostpid>:<id>", filled in here). At most max_ids per host and a request line (`draw` and the ids) under max_line bytes.
-- -> ordered list of { hostpid, ids }.
function T.draw_requests(entries, requested, max_ids, max_line)
  local by_host, out = {}, {}
  for _, e in ipairs(entries) do
    local t = e.tab
    if t and not t.picture and math.type(t.hostpid) == "integer" and math.type(t.id) == "integer" then
      local key = t.hostpid .. ":" .. t.id
      local r = by_host[t.hostpid]
      if not requested[key] and (not r or (#r.ids < max_ids and r.len + 1 + #tostring(t.id) < max_line)) then
        if not r then r = { hostpid = t.hostpid, ids = {}, len = 4 }; by_host[t.hostpid] = r; out[#out + 1] = r end
        r.ids[#r.ids + 1] = t.id; r.len = r.len + 1 + #tostring(t.id)
        requested[key] = true
      end
    end
  end
  for _, r in ipairs(out) do r.len = nil end
  return out
end

-- At session open, before any letter: the same, for the tabs of the tab files, leaving out the tab a window shows (its shot, or the extension's
-- own fallback, covers it). Fills `requested`, so the search time request skips them and asks for the rest.
function T.open_draw_requests(entries, requested, max_ids, max_line)
  local background = {}
  for _, e in ipairs(entries) do
    if e.tab and not e.tab.active then background[#background + 1] = e end
  end
  return T.draw_requests(background, requested, max_ids, max_line)
end

-- After a search: the tab a browser window is showing is the window itself (the window row carries that tab's title), so its tab row would be a copy.
-- Drop an active tab row when its window row is in the result too; keep it when only the tab matched (for example by its site) and the window row did not.
function T.without_copies(entries)
  local has_window = {}
  for _, e in ipairs(entries) do
    if not e.tab then has_window[e.address] = true end
  end
  local out = {}
  for _, e in ipairs(entries) do
    if not (e.tab and e.tab.active and has_window[e.address]) then out[#out + 1] = e end
  end
  return out
end

return T

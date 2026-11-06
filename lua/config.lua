-- omahop config: a flat TOML subset (comments, [sections], key = true | 123 | "text") that Lua and the settings app both read.
-- Pure, so it tests under plain Lua 5.5 (Hyprland embeds 5.5).
-- shortcut: no arrays, no inline tables, no escaped quotes in strings; lists are comma separated strings. Upgrade if a setting needs more.
local C = {}

C.schema = 1

-- One table describes every setting: default, allowed values, and the text the settings panel shows (label, help, names for each value, unit).
-- The panel reads a generated copy of this table (spec.json, made by tools/gen-spec.lua, and run-all fails if the committed file drifts), so a new
-- setting is added here once. `reload = true` marks a setting that needs a Hyprland reload to apply; `hidden = true` keeps an unfinished setting out of the panel.
C.spec = {
  top = {
    schema = { default = C.schema, hidden = true },
    takeover = { default = true, group = "general", reload = true, label = "Take over Alt+Tab",
      help = "Turn off to leave Alt+Tab alone, for example if you set your own Alt+Tab bind. Applies after a Hyprland reload." },
    scope = { default = "floating", values = { "floating", "all" }, group = "general", label = "Where it takes over Alt+Tab",
      names = { floating = "Floating workspaces only", all = "All workspaces" },
      help = "On other workspaces Alt+Tab stays exactly as Omarchy has it." },
    style = { default = "list", values = { "list", "cards" }, group = "look", label = "Style", hidden = true,
      names = { list = "List", cards = "Cards with thumbnails" } },
    reveal_delay_ms = { default = 100, min = 0, max = 1000, group = "look", label = "Delay before the list shows", unit = "ms",
      help = "A quick tap flips between your last two windows with no list. 0 shows the list at once." },
    thumbnails = { default = "snapshot", values = { "live", "snapshot", "off" }, group = "look", label = "Thumbnails", hidden = true,
      names = { live = "Live", snapshot = "Snapshot when it opens", off = "Off (icons only)" } },
    border = { default = "auto", values = { "auto", "on", "off" }, group = "look", label = "Outline",
      names = { auto = "Follow Hyprland's window border", on = "Always", off = "Never" },
      help = "Auto draws no outline when you turned window borders off." },
  },
  windows = {
    workspaces = { default = "floating", values = { "current", "floating", "all" }, group = "windows", label = "Windows from",
      names = { current = "This workspace", floating = "Floating workspaces", all = "All workspaces" } },
    monitors = { default = "active", values = { "active", "all" }, group = "windows", label = "On",
      names = { active = "The monitor with focus", all = "All monitors" } },
    minimized = { default = "back", values = { "back", "hide" }, group = "windows", label = "Minimized windows",
      names = { back = "Listed last", hide = "Not listed" } },
    specials = { default = "hide", values = { "hide", "show" }, group = "windows", label = "Scratchpad windows",
      names = { hide = "Not listed", show = "Listed" } },
    ignore = { default = "", group = "windows", label = "Never list these apps",
      help = "Window classes, comma separated (for example: pavucontrol, steam). Case does not matter." },
  },
  keys = {
    repeat_delay_ms = { default = 250, min = 50, max = 2000, group = "keys", label = "Hold Tab: wait before repeating", unit = "ms" },
    repeat_ms = { default = 40, min = 10, max = 1000, group = "keys", label = "Hold Tab: repeat every", unit = "ms" },
  },
}

-- The order the panel shows things in: groups, then the settings of each, as "section.key".
C.groups = {
  { id = "general", title = "General" },
  { id = "windows", title = "Windows in the list" },
  { id = "look", title = "Look" },
  { id = "keys", title = "Keys" },
}
C.order = { "top.takeover", "top.scope", "windows.workspaces", "windows.monitors", "windows.minimized", "windows.specials", "windows.ignore",
  "top.style", "top.thumbnails", "top.reveal_delay_ms", "top.border", "keys.repeat_delay_ms", "keys.repeat_ms" }

local function contains(list, v)
  for _, x in ipairs(list) do if x == v then return true end end
  return false
end

local function valid(rule, v)
  if type(v) ~= type(rule.default) then return false end
  if rule.values and not contains(rule.values, v) then return false end
  if rule.min and (v < rule.min or v > rule.max) then return false end
  return true
end

local function value(raw)
  if raw == "true" then return true elseif raw == "false" then return false end
  local s = raw:match('^"(.*)"$')
  if s then return s end
  -- plain decimals only: tonumber alone would also accept 0x10 and 1e999
  if raw:match("^-?%d+$") then return math.tointeger(tonumber(raw)) end
  return nil -- not a value we know: the line is reported and ignored
end

-- Drop a trailing comment: a '#' preceded by whitespace and outside a double quoted string (so "steam, #hash" survives).
local function strip_comment(line)
  local in_string = false
  for i = 1, #line do
    local c = line:sub(i, i)
    if c == '"' then in_string = not in_string
    elseif c == "#" and not in_string and i > 1 and line:sub(i - 1, i - 1):match("%s") then return line:sub(1, i - 1) end
  end
  return line
end

-- Parse text into { top = {...}, windows = {...}, ... } and a list of unreadable lines (never raises).
function C.parse(text)
  local t, bad, section = { top = {} }, {}, "top"
  for line in (text or ""):gmatch("[^\r\n]+") do
    local l = strip_comment(line):gsub("^%s+", ""):gsub("%s+$", "")
    if l ~= "" and l:sub(1, 1) ~= "#" then
      local name = l:match("^%[([%w_]+)%]$")
      if name then
        section = name
        t[section] = t[section] or {}
      else
        local k, raw = l:match("^([%w_]+)%s*=%s*(.-)$")
        local v = raw and value(raw)
        if k and v ~= nil then t[section][k] = v else bad[#bad + 1] = line end
      end
    end
  end
  return t, bad
end

-- Merge parsed values over the defaults. Wrong types, unknown values and out-of-range numbers fall back to the default and are
-- listed in `problems` so the caller can log them; unknown keys are ignored here (the settings app keeps them in the file).
function C.merge(parsed)
  local cfg, problems = {}, {}
  for section, rules in pairs(C.spec) do
    local target = section == "top" and cfg or {}
    if section ~= "top" then cfg[section] = target end
    local from = parsed and parsed[section] or {}
    for key, rule in pairs(rules) do
      local v = from[key]
      if v ~= nil and valid(rule, v) then
        target[key] = v
      else
        target[key] = rule.default
        if v ~= nil then problems[#problems + 1] = section .. "." .. key .. " = " .. tostring(v) end
      end
    end
  end
  table.sort(problems)
  return cfg, problems
end

-- The ignore setting as a set of lower-case window classes.
function C.ignore_set(cfg)
  local set = {}
  for item in (cfg.windows.ignore or ""):gmatch("[^,]+") do
    local name = item:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if name ~= "" then set[name] = true end
  end
  return set
end

-- Read a file; a missing or unreadable file is the defaults (a new user has no file).
function C.load(path)
  local f = io.open(path, "r")
  if not f then return C.merge(nil) end
  local text = f:read("a")
  f:close()
  local parsed, bad = C.parse(text)
  local cfg, problems = C.merge(parsed)
  for _, line in ipairs(bad) do problems[#problems + 1] = "unreadable line: " .. line end
  return cfg, problems
end

return C

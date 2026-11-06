-- omahop config: a flat TOML subset (comments, [sections], key = true | 123 | "text") that Lua and the settings app both read.
-- Pure, so it tests under plain Lua 5.5 (Hyprland embeds 5.5).
-- shortcut: no arrays, no inline tables, no escaped quotes in strings; lists are comma separated strings. Upgrade if a setting needs more.
local C = {}

C.schema = 1

-- One table describes every setting: default, and for text settings the allowed values. The settings app reads the same shape,
-- so a new value is added here once (flexibility rule). Sections are "top" (no section) and "windows" and "keys".
C.spec = {
  top = {
    schema = { default = C.schema },
    takeover = { default = true }, -- false leaves the user's own Alt+Tab bind alone
    scope = { default = "floating", values = { "floating", "all" } }, -- where omahop takes over Alt+Tab
    style = { default = "list", values = { "list", "cards" } },
    reveal_delay_ms = { default = 100, min = 0, max = 1000 }, -- a quick tap flips windows with no overlay
    thumbnails = { default = "snapshot", values = { "live", "snapshot", "off" } }, -- used by the cards style
  },
  windows = {
    workspaces = { default = "floating", values = { "current", "floating", "all" } },
    monitors = { default = "active", values = { "active", "all" } },
    minimized = { default = "back", values = { "back", "hide" } },
    specials = { default = "hide", values = { "hide", "show" } },
    ignore = { default = "" }, -- window classes, comma separated
  },
  keys = {
    repeat_delay_ms = { default = 250, min = 50, max = 2000 }, -- hold Tab: wait this long, then repeat
    repeat_ms = { default = 40, min = 10, max = 1000 },
  },
}

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

-- Parse text into { top = {...}, windows = {...}, ... } and a list of unreadable lines (never raises).
function C.parse(text)
  local t, bad, section = { top = {} }, {}, "top"
  for line in (text or ""):gmatch("[^\r\n]+") do
    local l = line:gsub("%s+#.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
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

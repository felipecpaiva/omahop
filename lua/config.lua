-- omahop config: a flat TOML subset (comments, [sections], key = true | 123 | "text") that Lua and the settings app both read.
-- Pure, so it tests under plain Lua 5.5 (Hyprland embeds 5.5).
-- shortcut: no arrays, no inline tables, no escaped quotes in strings; lists are comma separated strings. Upgrade if a setting needs more.
local C = {}
local here = debug.getinfo(1, "S").source:match("^@(.*)/") or "."
local Modifier = dofile(here .. "/modifier.lua")

C.schema = 1

-- One table describes every setting: default, allowed values, and the text the settings panel shows (label, help, names for each value, unit).
-- The panel reads a generated copy of this table (spec.json, made by tools/gen-spec.lua, and run-all fails if the committed file drifts), so a new
-- setting is added here once. `reload = true` marks a setting that needs a Hyprland reload to apply; `hidden = true` keeps an unfinished setting out of the panel.
C.spec = {
  top = {
    schema = { default = C.schema, hidden = true },
    takeover = { default = true, group = "general", reload = true, label = "Take over Alt+Tab",
      help = "Turn off to leave Alt+Tab alone, for example if you set your own Alt+Tab bind. Applies after a Hyprland reload." },
    modifier = { default = Modifier.default, values = Modifier.names, names = Modifier.labels(), group = "general", reload = true, label = "Key to hold",
      help = "The key you hold while pressing Tab: Alt (the default), Super or Ctrl. Applies after a Hyprland reload. Super + Tab is Omarchy's next workspace: free it in your bindings first, or omahop leaves it alone and logs why. Omarchy uses Super with most letters, Return and the arrows, so with Super most of the keys that work while the list is up are skipped (a chord you already use is never taken). Ctrl + Tab switches tabs in browsers and editors; with Ctrl it opens omahop instead where omahop is active. The same-app shortcut must start with the same key." },
    scope = { default = "floating", values = { "floating", "all" }, group = "general", label = "Where it takes over Alt+Tab",
      names = { floating = "Floating workspaces only", all = "All workspaces" },
      help = "On other workspaces Alt+Tab stays exactly as Omarchy has it." },
    search = { default = true, group = "general", label = "Type to search",
      help = "While the list is up, typing letters filters it (hold Alt, press Tab, then type). Letters are only taken while Alt is held, and never replace a bind of your own." },
    search_fuzzy = { default = true, group = "general", label = "Fuzzy search",
      help = "Also match initials (gc finds Google Chrome) and letters in order inside a word (chrm finds chrome). These matches come after the plain ones." },
    search_linger_seconds = { default = 0, min = 0, max = 60, group = "general", label = "Keep the list open after typing", unit = "s",
      help = "0 (the default) keeps the usual way: releasing Alt picks. From 1 to 60: once you have typed a search, releasing Alt no longer picks. The list stays open this many seconds after your last key and takes the keyboard, so any character can be typed. Return picks, Escape clears the search and then closes, a click outside the list closes it, and when the time runs out it closes without picking." },
    style = { default = "list", values = { "list", "cards" }, group = "look", label = "Style",
      names = { list = "List", cards = "Cards with thumbnails" },
      help = "The list is plain and light. Cards show a picture of each window." },
    reveal_delay_ms = { default = 100, min = 0, max = 1000, group = "look", label = "Delay before the list shows", unit = "ms",
      help = "A quick tap flips between your last two windows with no list. 0 shows the list at once." },
    thumbnails = { default = "snapshot", values = { "live", "snapshot", "off" }, group = "look", label = "Thumbnails (cards)",
      names = { live = "Live", snapshot = "Snapshot when it opens", off = "Off (icons only)" },
      help = "Snapshot takes one picture of each window when the cards open and costs almost nothing. Live keeps them updating and uses noticeable CPU with many windows." },
    thumbnail_exclude = { default = "", group = "look", label = "Never take a picture of these apps",
      help = "Window classes, comma separated, that are never captured into a picture (a password manager, a bank, a private window). Cards and the peek strip show the app icon instead. Applies to Snapshot and Live alike." },
    actions = { default = true, group = "look", label = "Close and minimize buttons",
      help = "Show close and minimize buttons on the row or card under the pointer. Delete (with Alt held) closes the picked window either way." },
    peek = { default = "off", values = { "off", "edge", "always" }, group = "peek", label = "Peek strip",
      names = { off = "Off", edge = "Show when the pointer touches the screen edge", always = "Always visible" },
      help = "A slim row of your running apps. Hover an app to see a picture of each of its windows; click to go to one. Off by default: nothing is added to your desktop unless you turn it on." },
    peek_position = { default = "auto", values = { "auto", "bottom", "top", "left", "right" }, group = "peek", label = "Edge",
      names = { auto = "A free edge", bottom = "Bottom", top = "Top", left = "Left", right = "Right" },
      help = "Auto picks an edge that is not the dock's and not the bar's, so nothing competes or covers the bar." },
    passthrough_fullscreen = { default = false, group = "rules", label = "Step aside for fullscreen apps",
      help = "When the focused window is fullscreen (a game, a remote desktop, a virtual machine), Alt+Tab is left to it and works as Omarchy has it." },
    passthrough = { default = "", group = "rules", label = "Step aside for these apps",
      help = "Window classes, comma separated, for which Alt+Tab is always left alone, whatever their state." },
    same_app_key = { default = "ALT + GRAVE", group = "shortcuts", reload = true, label = "Same-app shortcut",
      help = "A second shortcut that lists only the windows of the app you are in, like Cmd+backtick on a Mac. It must start with the key to hold (for example ALT + GRAVE, or SUPER + GRAVE when that key is Super). Leave it empty to turn it off. Applies after a Hyprland reload; a chord you already use is never taken." },
    hints = { default = "off", values = { "off", "numbers", "apps" }, group = "shortcuts", label = "Quick jump keys",
      names = { off = "Off", numbers = "Number keys (1 to 9, with the key held)", apps = "App letters (set below)" },
      help = "While the list is up and nothing is typed yet, a hint key jumps straight to a window. Any other key still types into the search." },
    hint_keys = { default = "", group = "shortcuts", label = "App letters",
      help = "Pairs of letter and app class, comma separated, for example: c=google-chrome, t=kitty. Used when Quick jump keys is App letters." },
    action_keys = { default = "", group = "shortcuts", label = "Quit and minimize keys",
      help = "Pairs of key and action, comma separated, for example: q=close, m=minimize. While the list is up and nothing is typed yet, that key acts on the selected window and the selection moves to the next row; once you have typed a letter, every key types. Actions: close, minimize. Empty (the default) turns it off. A key a hint already uses is left to the hint." },
    icon_theme = { default = "", group = "look", label = "Icon theme",
      help = "Type the folder name of an installed icon theme, such as Papirus, to prefer its icons. Empty uses whichever installed theme the scan finds first. An app the theme has no icon for still gets one from the others. Applies after a shell restart." },
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
    ignore_titles = { default = "", group = "rules", label = "Never list windows whose title contains",
      help = "Fragments, comma separated (for example: picture in picture). Case does not matter." },
    first = { default = "", group = "rules", label = "List these apps first",
      help = "Window classes, comma separated. Their windows come before all others." },
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
  { id = "peek", title = "Peek strip" },
  { id = "rules", title = "App rules" },
  { id = "shortcuts", title = "Shortcuts" },
}
C.order = { "top.takeover", "top.modifier", "top.scope", "top.search", "top.search_fuzzy", "top.search_linger_seconds", "windows.workspaces", "windows.monitors", "windows.minimized", "windows.specials", "windows.ignore",
  "top.style", "top.thumbnails", "top.thumbnail_exclude", "top.reveal_delay_ms", "top.border", "top.icon_theme", "top.actions", "keys.repeat_delay_ms", "keys.repeat_ms", "top.peek", "top.peek_position",
  "windows.ignore_titles", "windows.first", "top.passthrough_fullscreen", "top.passthrough", "top.same_app_key", "top.hints", "top.hint_keys", "top.action_keys" }

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

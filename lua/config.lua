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
-- A profile ([profiles.<name>] tables, see C.resolve) may override any setting except those marked reload, hidden or `base_only` (C.overridable).
-- `choices = "profiles"` marks a choice whose values are the profile names in the file, not a fixed list.
C.spec = {
  top = {
    schema = { default = C.schema, hidden = true },
    profile = { default = "", group = "general", base_only = true, choices = "profiles", names = { [""] = "None" }, label = "Profile",
      help = "A named set of settings that replaces some of the ones below, for example a [profiles.work] table in ~/.config/omahop/config.toml with style = \"cards\". None uses the settings below as they are. Applies to the next Alt+Tab. A row the profile changes says so. Write a profile's values in the file (see docs/settings.md); Take over, Key to hold, the same-app shortcut and browser tabs are never changed by a profile." },
    takeover = { default = true, group = "general", reload = true, label = "Take over Alt+Tab",
      help = "Turn off to leave Alt+Tab alone, for example if you set your own Alt+Tab bind. Applies after a Hyprland reload." },
    modifier = { default = Modifier.default, values = Modifier.names, names = Modifier.labels(), group = "general", reload = true, label = "Key to hold",
      help = "The key you hold while pressing Tab: Alt (the default) or Ctrl. Applies after a Hyprland reload. Super is not offered: Omarchy owns Super + Tab and most Super chords, and omahop never takes them. Ctrl + Tab switches tabs in browsers and editors; with Ctrl it opens omahop instead where omahop is active, so leave this on Alt if you use those tabs. A chord you already use is never taken. The same-app shortcut must start with the same key." },
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
    audio_marker = { default = false, group = "look", label = "Mark windows playing sound",
      help = "Off by default. When on, a small speaker shows next to the app name of a window whose app is playing sound (a call, music, a video), so you can find it. Checked once each time the list opens, with pactl; nothing runs while the list is closed, and song or video titles are never logged or saved. Paused or muted sound shows no speaker. A browser plays all its tabs through one process, so every window of that browser gets the speaker." },
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
    browser_tabs = { default = false, group = "tabs", base_only = true, label = "Search browser tabs",
      help = "Off by default. When on, a search also finds the tabs of your browser windows, not only the tab each window shows, and Return opens that tab. Needs the omahop-tabs browser extension and its helper. Private: tab titles and addresses stay on this computer in a temporary folder that is emptied when you log out or turn this off; omahop never logs them." },
    browser_tabs_ignore = { default = "", group = "tabs", base_only = true, label = "Never list tabs from these sites",
      help = "Site names, comma separated, for example: bank.example.com, mail.example.org. A name also covers its subdomains; * and ? are wildcards that must match the whole site name (*.corp.example). Empty (the default) hides nothing. Those tabs are never written by the helper and never shown." },
    browser_tab_previews = { default = false, group = "tabs", base_only = true, label = "Show a picture of the page on found tabs (needs the extension's permission)",
      help = "Off by default, and it works in the cards style. A found tab card shows a picture of its page instead of the site logo. This is a second opt in: turn it on here, and also open the extension's options page (the omahop tabs extension, Options) and press Enable page pictures, which asks Chrome for the extra permission to take pictures. Neither alone does anything. Chrome only photographs the tab you are looking at, so a tab's picture is taken while it is shown and can be old by the time you search. Pictures stay in memory and in the same temporary folder as the tab list, are never taken for sites on the ignore list, and are deleted when you turn this off or log out. Needs Search browser tabs." },
    same_app_key = { default = "ALT + GRAVE", group = "shortcuts", reload = true, label = "Same-app shortcut",
      help = "A second shortcut that lists only the windows of the app you are in, like Cmd+backtick on a Mac. It must start with the key to hold (for example ALT + GRAVE, or CTRL + GRAVE when that key is Ctrl). Leave it empty to turn it off. Applies after a Hyprland reload; a chord you already use is never taken." },
    hints = { default = "off", values = { "off", "numbers", "apps" }, group = "shortcuts", label = "Quick jump keys",
      names = { off = "Off", numbers = "Number keys (1 to 9, with the key held)", apps = "App letters (set below)" },
      help = "While the list is up and nothing is typed yet, a hint key jumps straight to a window. Any other key still types into the search." },
    hint_keys = { default = "", group = "shortcuts", label = "App letters",
      help = "Pairs of letter and app class, comma separated, for example: c=google-chrome, t=kitty. Used when Quick jump keys is App letters." },
    action_keys = { default = "", group = "shortcuts", label = "Quit and minimize keys",
      help = "Pairs of key and action, comma separated, for example: q=close, m=minimize. While the list is up and nothing is typed yet, that key acts on the selected window and the selection moves to the next row; once you have typed a letter, every key types. Actions: close, minimize. Empty (the default) turns it off. A key a hint already uses is left to the hint." },
    icon_theme = { default = "", group = "look", label = "Icon theme",
      help = "Type the folder name of an installed icon theme, such as Papirus, to prefer its icons. Empty uses whichever installed theme the scan finds first. An app the theme has no icon for still gets one from the others. " },
    icon_pack = { default = "", group = "look", label = "Icon pack",
      help = "Type the folder name of an icon pack in ~/.config/omahop/packs, such as omahop-sample. Its icons come first; an app the pack has no icon for keeps its usual one. Empty uses no pack. A pack you made yourself or copied from someone: see docs/icon-packs.md for the format. Applies at once. To share a pack as one zip or install one, run tools/pack-export.sh <name> or tools/pack-import.sh <file.zip> from the plugin folder (~/.config/omarchy/plugins/io.github.felipecpaiva.omahop)." },
    swipe_trigger = { default = false, group = "swipe", reload = true, label = "Swipe on the touchpad to switch",
      help = "Off by default. When on, a swipe left or right with several fingers on the touchpad opens the list and moves the selection one row per stretch of travel; lifting the fingers picks. Swipe back to the window you started on and lift to close without switching. Touchpads only: a touchscreen swipe cannot reach omahop. Works where omahop takes over Alt+Tab. Applies after a Hyprland reload." },
    swipe_fingers = { default = 4, min = 3, max = 4, group = "swipe", reload = true, label = "Fingers",
      help = "3 or 4. Omarchy's example config uses 3 fingers left and right to change workspace; a swipe Hyprland already uses is never taken (Hyprland reports the clash as a config error and keeps the first one). Applies after a Hyprland reload." },
    swipe_distance = { default = 100, min = 20, max = 600, group = "swipe", label = "Swipe distance per row", unit = "px",
      help = "How far the fingers travel to move one row. Lower moves faster. Applies at once." },
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
  { id = "tabs", title = "Browser tabs" },
  { id = "swipe", title = "Touchpad swipe" },
}
C.order = { "top.profile", "top.takeover", "top.modifier", "top.scope", "top.search", "top.search_fuzzy", "top.search_linger_seconds", "windows.workspaces", "windows.monitors", "windows.minimized", "windows.specials", "windows.ignore",
  "top.style", "top.thumbnails", "top.thumbnail_exclude", "top.reveal_delay_ms", "top.border", "top.icon_theme", "top.icon_pack", "top.audio_marker", "top.actions", "keys.repeat_delay_ms", "keys.repeat_ms", "top.peek", "top.peek_position",
  "windows.ignore_titles", "windows.first", "top.passthrough_fullscreen", "top.passthrough", "top.same_app_key", "top.hints", "top.hint_keys", "top.action_keys",
  "top.browser_tabs", "top.browser_tabs_ignore", "top.browser_tab_previews", "top.swipe_trigger", "top.swipe_fingers", "top.swipe_distance" }

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

-- A table name: words of letters, digits and underscores joined by single dots (windows, profiles.work, profiles.work.windows).
function C.section_name_ok(name)
  return name:match("^[%w_]+$") ~= nil or (name:match("^[%w_][%w_%.]*[%w_]$") ~= nil and not name:find("..", 1, true))
end

-- Parse text into { top = {...}, windows = {...}, ... } and a list of unreadable lines (never raises).
function C.parse(text)
  local t, bad, section = { top = {} }, {}, "top"
  for line in (text or ""):gmatch("[^\r\n]+") do
    local l = strip_comment(line):gsub("^%s+", ""):gsub("%s+$", "")
    if l ~= "" and l:sub(1, 1) ~= "#" then
      local name = l:match("^%[([%w_%.]+)%]$")
      if name and C.section_name_ok(name) then
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

-- ---- profiles ----
local PROFILES = "profiles"

-- Whether a profile may set this setting: not the ones read only at load (reload), not hidden ones, not the ones kept in the base on purpose.
function C.overridable(rule)
  return not (rule.reload or rule.hidden or rule.base_only)
end

-- The names of the profiles in a parsed file ([profiles.<name>] or [profiles.<name>.<section>]), sorted.
function C.profile_names(parsed)
  local seen, names = {}, {}
  for section in pairs(parsed or {}) do
    local name = section:match("^" .. PROFILES .. "%.([%w_]+)")
    if name and not seen[name] then seen[name] = true; names[#names + 1] = name end
  end
  table.sort(names)
  return names
end

-- The values a profile sets for one spec section ("top" is the profile's own table), or nil.
local function profile_bag(parsed, name, section)
  local base = PROFILES .. "." .. name
  return parsed[section == "top" and base or base .. "." .. section]
end

-- Lay the profile named by cfg.profile over a merged cfg: a valid overridable value wins, a bad or non-overridable one is reported and the
-- base value stays. An unknown name is reported and the base is used (cfg.profile becomes ""). Mirrored by ConfigIO.resolve (parity test).
function C.apply_profile(cfg, parsed, problems)
  local name = cfg.profile
  if name == "" then return cfg end
  if not contains(C.profile_names(parsed), name) then
    problems[#problems + 1] = "profile = " .. name .. ": no such profile, using the base settings"
    cfg.profile = ""
    return cfg
  end
  for section, rules in pairs(C.spec) do
    local target = section == "top" and cfg or cfg[section]
    local prefix = PROFILES .. "." .. name .. "." .. (section == "top" and "" or section .. ".")
    for key, v in pairs(profile_bag(parsed, name, section) or {}) do
      local rule = not (rules[key] and rules[key].hidden) and rules[key] or nil -- a hidden setting is unknown to a profile, as to the panel
      if rule and not C.overridable(rule) then
        problems[#problems + 1] = prefix .. key .. ": not overridable in a profile, ignored"
      elseif rule and valid(rule, v) then
        target[key] = v
      elseif rule then
        problems[#problems + 1] = prefix .. key .. " = " .. tostring(v)
      end
    end
  end
  return cfg
end

-- The settings in use: the base merged over the defaults, then the active profile over that. Problems sorted.
function C.resolve(parsed)
  local cfg, problems = C.merge(parsed)
  C.apply_profile(cfg, parsed or {}, problems)
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
  local cfg, problems = C.resolve(parsed)
  for _, line in ipairs(bad) do problems[#problems + 1] = "unreadable line: " .. line end
  return cfg, problems
end

return C

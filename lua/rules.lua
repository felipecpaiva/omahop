-- omahop app rules: what to leave out of the list, what to list first, and when to step aside entirely. Pure, so it tests without Hyprland.
local Rules = {}

-- "steam, Pavucontrol" -> { steam = true, pavucontrol = true } (lower case, trimmed, empty items dropped). Used for class lists and title fragments alike.
function Rules.set(text)
  local set = {}
  for item in (text or ""):gmatch("[^,]+") do
    local v = item:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if v ~= "" then set[v] = true end
  end
  return set
end

-- Does the title contain any of the fragments? (case ignored, plain text match: a fragment is not a pattern)
function Rules.title_matches(title, fragments)
  local t = tostring(title or ""):lower()
  for f in pairs(fragments) do
    if t:find(f, 1, true) then return true end
  end
  return false
end

-- Windows of the listed apps go to the front, in their own order; everything else keeps its order after them. The list is a new table, the entries are the same tables.
function Rules.first_apps(entries, classes)
  if next(classes) == nil then return entries end
  local front, rest = {}, {}
  for _, e in ipairs(entries) do
    if classes[(e.class or ""):lower()] then front[#front + 1] = e else rest[#rest + 1] = e end
  end
  for _, e in ipairs(rest) do front[#front + 1] = e end
  return front
end

-- Should omahop step aside for this focused window, so that stock Alt+Tab runs? A fullscreen window (Hyprland fullscreen state 2, not a maximized one) when the setting
-- is on, or a window whose class is in the pass-through list whatever its state. `active` is { class, fullscreen } or nil (nothing focused: do not step aside).
function Rules.passthrough(active, fullscreen_on, classes)
  if not active then return false end
  if classes[(active.class or ""):lower()] then return true end
  return fullscreen_on == true and (tonumber(active.fullscreen) or 0) >= 2
end

return Rules

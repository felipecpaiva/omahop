-- omahop hints: quick jump keys for the list. Pure, so it tests without Hyprland.
--   numbers: with an empty query, the digits 1 to 9 pick the n-th row.
--   apps:    with an empty query, a letter mapped to an app class picks that app's first (most recent) window; the mapping is "c=google-chrome, t=kitty".
-- A key that is not a hint, and every key once a query exists, still types into the search: search never breaks.
local Hints = {}

-- "c=google-chrome, T = Kitty" -> { c = "google-chrome", t = "kitty" } (key: one letter or digit, lower case; class lower case). Bad items are skipped.
function Hints.parse_keys(text)
  local map = {}
  for item in (text or ""):gmatch("[^,]+") do
    local k, class = item:match("^%s*([%w])%s*=%s*(.-)%s*$")
    if k and class ~= "" then map[k:lower()] = class:lower() end
  end
  return map
end

-- The label shown on each entry (an array of strings, "" for none). Numbers label the first nine rows; apps label the first window of each mapped app with its letter.
function Hints.labels(entries, mode, map)
  local out = {}
  for i = 1, #entries do out[i] = "" end
  if mode == "numbers" then
    for i = 1, math.min(9, #entries) do out[i] = tostring(i) end
  elseif mode == "apps" then
    local done = {}
    for i, e in ipairs(entries) do
      local class = (e.class or ""):lower()
      for k, c in pairs(map or {}) do
        if c == class and not done[k] then out[i] = k; done[k] = true end
      end
    end
  end
  return out
end

-- Which entry does a typed key jump to? Index or nil. Only call it while the query is empty.
function Hints.target(entries, mode, map, ch)
  if mode == "numbers" then
    local n = tonumber(ch)
    if n and n >= 1 and n <= 9 and n <= #entries then return n end
  elseif mode == "apps" then
    local class = (map or {})[(ch or ""):lower()]
    if class then
      for i, e in ipairs(entries) do
        if (e.class or ""):lower() == class then return i end
      end
    end
  end
  return nil
end

return Hints

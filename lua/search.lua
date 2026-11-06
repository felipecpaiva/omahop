-- omahop search: filter the window list by what the user types. Pure, so it tests without Hyprland.
-- A window matches when every word of the query appears in its text: the app's class, its display name (when known) and its title,
-- with - _ . : / turned into spaces and case ignored. Matches keep the recently-used order, except that a window whose app name or class starts
-- with the first word comes before one that only contains it somewhere (typing "fi" finds Files before a document called "profile").
local Search = {}

local function normalize(s)
  return (tostring(s or ""):lower():gsub("[%-_%.:/\\]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end
Search.normalize = normalize

local function words(s)
  local out = {}
  for w in normalize(s):gmatch("%S+") do out[#out + 1] = w end
  return out
end

-- entries: windows with class and title. names: optional { [class] = "Display Name" } from the overlay. Returns a new list (same entry tables).
function Search.filter(entries, query, names)
  local q = words(query)
  if #q == 0 then return entries end
  local out = {}
  for i, e in ipairs(entries) do
    local app = normalize((names and names[e.class]) or "") .. " " .. normalize(e.class)
    local hay = app .. " " .. normalize(e.title)
    local ok = true
    for _, w in ipairs(q) do
      if not hay:find(w, 1, true) then ok = false; break end
    end
    if ok then
      local starts = false
      for aw in app:gmatch("%S+") do if aw:sub(1, #q[1]) == q[1] then starts = true; break end end
      out[#out + 1] = { e = e, rank = starts and 0 or 1, pos = i }
    end
  end
  table.sort(out, function(a, b) if a.rank ~= b.rank then return a.rank < b.rank end return a.pos < b.pos end)
  local res = {}
  for i, o in ipairs(out) do res[i] = o.e end
  return res
end

-- Characters a typed key adds to the query: letters and digits only (the glue maps SPACE and BACKSPACE itself).
function Search.append(query, ch) return (query or "") .. ch end
function Search.backspace(query) return (query or ""):sub(1, -2) end

return Search

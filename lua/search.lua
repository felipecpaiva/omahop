-- omahop search: filter the window list by what the user types. Pure, so it tests without Hyprland.
-- A window matches when every word of the query appears in its text: the app's class, its display name (when known) and its title,
-- with - _ . : / turned into spaces and case ignored. Matches keep the recently-used order, except that a window whose app name or class starts
-- with the first word comes before one that only contains it somewhere (typing "fi" finds Files before a document called "profile").
-- Accents are folded (acao finds ação). With fuzzy on, a single-word query also matches initials (gc: Google Chrome) and letters in order
-- inside one word (chrm: chrome, 3+ letters); those matches come last, in the recently-used order.
-- Browser tab rows (entries with `tab`, setting browser_tabs) show only while a query is typed; they match on their title and their
-- `search_extra` (the site and path of the address), never on the browser's class, so typing the browser's name does not list every tab.
local Search = {}

-- UTF-8 letters to their base letter (Latin-1 and Latin Extended-A, both cases). Anything not listed stays as it is.
local FOLD = {}
local function fold_set(base, chars) for ch in chars:gmatch(utf8.charpattern) do FOLD[ch] = base end end
for base, chars in pairs({
  a = "àáâãäåāăąÀÁÂÃÄÅĀĂĄ", c = "çćĉċčÇĆĈĊČ", d = "ďđĎĐ", e = "èéêëēĕėęěÈÉÊËĒĔĖĘĚ", g = "ĝğġģĜĞĠĢ", h = "ĥħĤĦ",
  i = "ìíîïĩīĭįıÌÍÎÏĨĪĬĮİ", j = "ĵĴ", k = "ķĶ", l = "ĺļľŀłĹĻĽĿŁ", n = "ñńņňÑŃŅŇ", o = "òóôõöøōŏőÒÓÔÕÖØŌŎŐ",
  r = "ŕŗřŔŖŘ", s = "śŝşšŚŜŞŠ", t = "ţťŧŢŤŦ", u = "ùúûüũūŭůűųÙÚÛÜŨŪŬŮŰŲ", w = "ŵŴ", y = "ýÿŷÝŸŶ", z = "źżžŹŻŽ",
  oe = "œŒ", ae = "æÆ", ss = "ß", ij = "ĳĲ",
}) do fold_set(base, chars) end

local function fold(s) return (s:gsub(utf8.charpattern, FOLD)) end
Search.fold = function(s) return fold(tostring(s or "")) end

local function normalize(s)
  return (fold(tostring(s or "")):lower():gsub("[%-_%.:/\\]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end
Search.normalize = normalize

local function words(s)
  local out = {}
  for w in normalize(s):gmatch("%S+") do out[#out + 1] = w end
  return out
end

-- true when the letters of q appear in order in s (not necessarily next to each other)
local function subsequence(q, s)
  local from = 1
  for i = 1, #q do
    local at = s:find(q:sub(i, i), from, true)
    if not at then return false end
    from = at + 1
  end
  return true
end

local function fuzzy_match(q, hay)
  local initials = {}
  for w in hay:gmatch("%S+") do
    initials[#initials + 1] = w:sub(1, 1)
    if #q >= 3 and subsequence(q, w) then return true end
  end
  return #q >= 2 and subsequence(q, table.concat(initials))
end

-- opts.fuzzy: false turns fuzzy matching off (default on). entries: windows with class and title. names: optional { [class] = "Display Name" } from the overlay. Returns a new list (same entry tables).
function Search.filter(entries, query, names, opts)
  local q = words(query)
  if #q == 0 then
    local out = {}
    for _, e in ipairs(entries) do if not e.tab then out[#out + 1] = e end end
    return #out == #entries and entries or out
  end
  local fuzzy = not (opts and opts.fuzzy == false) and #q == 1
  local out = {}
  for i, e in ipairs(entries) do
    local app = e.tab and "" or (normalize((names and names[e.class]) or "") .. " " .. normalize(e.class))
    local hay = app .. " " .. normalize(e.title) .. " " .. normalize(e.search_extra)
    local ok = true
    for _, w in ipairs(q) do
      if not hay:find(w, 1, true) then ok = false; break end
    end
    if not ok and fuzzy and fuzzy_match(q[1], hay) then
      out[#out + 1] = { e = e, rank = 2, pos = i }
    elseif ok then
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

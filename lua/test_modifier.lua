-- Plain Lua self-check:  lua lua/test_modifier.lua   (run with Lua 5.5, like Hyprland)
local dir = arg[0]:match("^(.*)/") or "."
local K = dofile(dir .. "/modifier.lua")

-- every listed name has a complete row, and every row is listed (the settings window shows `names`)
local listed = {}
for _, n in ipairs(K.names) do
  local m = K.by_name[n]
  assert(m and type(m.bind) == "string" and math.type(m.mask) == "integer" and #m.keys >= 1 and type(m.replaces) == "boolean" and m.label, "complete row: " .. n)
  assert(m.mask & K.shift_mask == 0, "a modifier mask never includes Shift: " .. n)
  listed[n] = true
end
for n in pairs(K.by_name) do assert(listed[n], "row not listed in names: " .. n) end
assert(K.by_name[K.default] and K.default == "alt", "default is alt")
assert(K.by_name.alt.replaces and not K.by_name.ctrl.replaces, "only alt replaces a stock bind")
assert(K.by_name.alt.mask == 8 and K.by_name.ctrl.mask == 4, "masks as hyprctl binds prints them")

-- unknown or missing values are the default row
assert(K.get("super") == K.by_name.alt and K.get("hyper") == K.by_name.alt and K.get(nil) == K.by_name.alt and K.get(1) == K.by_name.alt, "get falls back to alt")

-- chords
assert(K.chord(K.get("ctrl"), "TAB") == "CTRL + TAB" and K.shift_chord(K.get("ctrl"), "GRAVE") == "CTRL + SHIFT + GRAVE", "chord strings")

-- free: per modifier mask, Shift variant on request, unknown without a snapshot
local used = { ["4:TAB"] = true, ["9:GRAVE"] = true, ["8:X"] = true }
local alt, ctrl = K.get("alt"), K.get("ctrl")
assert(K.free(ctrl, used, "TAB") == false and K.free(alt, used, "TAB") == true and K.free(ctrl, used, "Tab") == false, "free by mask, key case ignored")
assert(K.free(alt, used, "GRAVE") == true and K.free(alt, used, "GRAVE", true) == false, "Shift variant checked only when asked")
assert(K.free(ctrl, used, "X") == true and K.free(alt, used, "X") == false, "ALT + X does not block CTRL + X")
assert(K.free(alt, nil, "TAB") == nil, "no snapshot: unknown")

-- held: either key; nil when nothing can be read; a reader that raises counts as unreadable
local function reader(state) return function(k) return state[k] end end
assert(K.held(alt, reader({ Alt_L = false, Alt_R = true })) == true, "right Alt held")
assert(K.held(alt, reader({ Alt_L = false, Alt_R = false })) == false, "both up")
assert(K.held(alt, reader({ Control_L = true })) == nil, "Ctrl says nothing about Alt: unknown")
assert(K.held(ctrl, reader({ Control_L = true })) == true and K.held(ctrl, reader({ Control_L = false })) == false, "ctrl, one key readable")
assert(K.held(alt, function() error("boom") end) == nil, "a raising reader is unknown, never an error")

-- labels for the settings window
local l = K.labels()
assert(l.alt == "Alt" and l.ctrl == "Ctrl", "labels")

print("modifier ok")

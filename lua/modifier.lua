-- omahop modifier: the key held for the whole switch (setting `modifier`). Pure data plus small helpers, so it tests under plain Lua 5.5.
-- One row per allowed value; a new modifier is one more row (and its name in `names`, the order the settings window lists them).
--   bind     the modifier as Hyprland's bind string spells it ("ALT + TAB")
--   mask     its bit in `hyprctl binds` modmask (Shift adds 1), used to check that a chord is free
--   keys     the xkb names polled with hl.is_key_down to notice the release (either key counts)
--   replaces true: the trigger chord is Omarchy's own stock bind, which omahop replaces at load and runs itself out of scope.
--            false: the chord is bound only when the bind snapshot shows it free, and out of scope the key goes back to the app.
-- Shift is left out on purpose: it already means "reverse" in every chord (Shift+Tab) and types capitals.
-- Super is left out on purpose: Omarchy owns Super + Tab and most Super chords, so omahop never takes them. Ctrl + Alt is no option either: Omarchy binds Ctrl + Alt + Tab
-- (focus next monitor). Alt and Ctrl are the two modifiers whose Tab chord is free on stock Omarchy.
-- shortcut: one modifier only, no combos such as CTRL + ALT; a combo would need every key group held. Upgrade if someone asks.
local K = {}

K.default = "alt"
K.names = { "alt", "ctrl" }
K.by_name = {
  alt = { label = "Alt", bind = "ALT", mask = 8, keys = { "Alt_L", "Alt_R" }, replaces = true },
  ctrl = { label = "Ctrl", bind = "CTRL", mask = 4, keys = { "Control_L", "Control_R" }, replaces = false },
}
K.shift_mask = 1

-- The row for a setting value; anything unknown is the default (config.merge has already logged it).
function K.get(name)
  return K.by_name[name] or K.by_name[K.default]
end

-- "ALT + TAB" and "ALT + SHIFT + TAB" for a row and a key name.
function K.chord(m, key) return m.bind .. " + " .. key end
function K.shift_chord(m, key) return m.bind .. " + SHIFT + " .. key end

-- Whether a key (upper case, as `hyprctl binds` prints it) is free with this modifier, alone or with Shift too.
-- used: the snapshot set ("8:TAB" = true), or nil when there is no snapshot yet.
function K.free(m, used, key, with_shift)
  if used == nil then return nil end
  key = key:upper()
  if used[m.mask .. ":" .. key] then return false end
  if with_shift and used[(m.mask + K.shift_mask) .. ":" .. key] then return false end
  return true
end

-- Whether the modifier is held, from a key reader (hl.is_key_down). nil when no key could be read: the session counts that as held.
function K.held(m, is_down)
  local held = nil
  for _, k in ipairs(m.keys) do
    local ok, r = pcall(is_down, k)
    if ok and r ~= nil then held = (held or false) or r end
  end
  return held
end

-- "label" names for the settings window, from the rows.
function K.labels()
  local t = {}
  for _, n in ipairs(K.names) do t[n] = K.by_name[n].label end
  return t
end

return K

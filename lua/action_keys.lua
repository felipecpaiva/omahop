-- omahop action keys: a key that acts on the selected row while the list is up and nothing is typed yet ("q=close, m=minimize"). Pure, so it tests without Hyprland.
-- Same rule as hints: once a query exists, every key types into the search. The action names come from the caller (the glue owns what each one does).
local ActionKeys = {}

-- "q=close, M = Minimize, x=nope, ab=close" -> { q = "close", m = "minimize" }, plus a list of what was skipped and why.
-- A key is one letter or digit: named keys (arrows, Return, Delete, Escape, Tab, Space, Backspace) stay navigation and can never be an action key.
function ActionKeys.parse(text, known)
  local map, problems = {}, {}
  for item in (text or ""):gmatch("[^,]+") do
    local trimmed = item:gsub("^%s+", ""):gsub("%s+$", "")
    local k, name = trimmed:match("^(%S-)%s*=%s*(.-)$")
    if trimmed ~= "" then
      if not k or not k:match("^%w$") then
        problems[#problems + 1] = "action_keys: '" .. trimmed .. "' needs one letter or digit as the key (navigation keys cannot be used)"
      elseif not known[name:lower()] then
        problems[#problems + 1] = "action_keys: unknown action '" .. name .. "' for key " .. k
      else
        map[k:lower()] = name:lower()
      end
    end
  end
  return map, problems
end

-- Drop the keys that a hint also uses (the hint wins, it was there first) and report each one. hint_mode is the `hints` setting, hint_map the parsed hint_keys.
function ActionKeys.drop_conflicts(map, hint_mode, hint_map)
  local out, problems = {}, {}
  for k, name in pairs(map) do
    local clash = (hint_mode == "numbers" and k:match("^[1-9]$")) or (hint_mode == "apps" and (hint_map or {})[k])
    if clash then problems[#problems + 1] = "action_keys: " .. k .. " is also a hint key (hints = " .. hint_mode .. "), left to the hint"
    else out[k] = name end
  end
  table.sort(problems)
  return out, problems
end

-- parse + drop_conflicts in one call: the usable map and every problem found.
function ActionKeys.resolve(text, known, hint_mode, hint_map)
  local map, bad = ActionKeys.parse(text, known)
  local usable, clashes = ActionKeys.drop_conflicts(map, hint_mode, hint_map)
  for _, p in ipairs(clashes) do bad[#bad + 1] = p end
  return usable, bad
end

return ActionKeys

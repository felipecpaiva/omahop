-- omahop recently-used order: pure functions over a list of window addresses, most recent first.
local M = {}

local function index_of(list, addr)
  for i, a in ipairs(list) do if a == addr then return i end end
end

-- Move addr to the front (it was just focused). Returns a new list.
function M.touch(order, addr)
  local out = { addr }
  for _, a in ipairs(order) do if a ~= addr then out[#out + 1] = a end end
  return out
end

-- Drop a closed window.
function M.forget(order, addr)
  local out = {}
  for _, a in ipairs(order) do if a ~= addr then out[#out + 1] = a end end
  return out
end

-- Sort windows by `order`. Windows never seen (opened before we started) keep `windows` order, which the caller fills from
-- Hyprland's own focus history, and come after the known ones. Minimized windows always go last, in the same relative order.
function M.sort(order, windows)
  local rank, seen = {}, #order
  for i, a in ipairs(order) do rank[a] = i end
  local items = {}
  for pos, w in ipairs(windows) do
    items[#items + 1] = { w = w, minimized = w.minimized and 1 or 0, rank = rank[w.address] or (seen + pos), pos = pos }
  end
  table.sort(items, function(a, b)
    if a.minimized ~= b.minimized then return a.minimized < b.minimized end
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.pos < b.pos
  end)
  local out = {}
  for i, it in ipairs(items) do out[i] = it.w end
  return out
end

-- Which entry a switch starts on. `list` is sorted, `focused` the address that has focus (or nil), delta 1 or -1.
-- Forward: the most recent window that is not the focused one (index 2 when the focused one leads), so a quick tap flips between two windows.
-- Backward: the last window. Never selects the focused window when another exists.
function M.first_pick(list, focused, delta)
  local n = #list
  if n == 0 then return 0 end
  if n == 1 then return 1 end
  local at = nil
  for i, w in ipairs(list) do if w.address == focused then at = i; break end end
  if delta < 0 then return (at == n) and n - 1 or n end
  return (at == 1) and 2 or 1 -- the most recent window that is not the focused one
end

M.index_of = index_of
return M

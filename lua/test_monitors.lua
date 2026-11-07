-- Plain Lua self-check:  lua lua/test_monitors.lua
-- The window set on 1 to 6 monitors, built from a generated topology, with no hardware: every monitor is the focus in turn, under every
-- monitors/workspaces combination, checked against a brute-force oracle written differently from W.filter. Then monitors are "unplugged":
-- their windows move to another monitor (what Hyprland does) or keep a name no monitor has (a stale record), and nothing may raise.
local dir = arg[0]:match("^(.*)/") or "."
local W = dofile(dir .. "/windows.lua")
local C = dofile(dir .. "/config.lua")

local failures = 0
local function check(name, ok, detail)
  if not ok then failures = failures + 1; print("FAIL " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or "")) end
end

-- Monitor i has floating workspace 10i+1 (3 windows, one of them minimized) and tiling workspace 10i+2 (1 window).
local function topology(n)
  local wins = {}
  local function add(addr, ws, mon, floating, extra)
    local t = { address = addr, class = "app-" .. addr, workspace_id = ws, monitor = mon, floating_workspace = floating, minimized = false, special = false, mapped = true }
    for k, v in pairs(extra or {}) do t[k] = v end
    wins[#wins + 1] = t
  end
  for i = 1, n do
    local mon = "M" .. i
    add("f" .. i .. "a", 10 * i + 1, mon, true)
    add("f" .. i .. "b", 10 * i + 1, mon, true)
    add("f" .. i .. "min", 10 * i + 1, mon, true, { minimized = true })
    add("t" .. i, 10 * i + 2, mon, false)
  end
  return wins
end

local function names(list) local t = {} for i, x in ipairs(list) do t[i] = x.address end table.sort(t) return table.concat(t, ",") end

-- Oracle: a plain loop with the rules from docs/settings.md, no shared code with W.filter.
local function expected(wins, ctx, monitors_mode, workspaces_mode)
  local out = {}
  for _, w in ipairs(wins) do
    local on_monitor = monitors_mode == "all" or w.monitor == ctx.monitor
    local in_ws
    if workspaces_mode == "all" then in_ws = true
    elseif workspaces_mode == "current" then in_ws = w.workspace_id == ctx.workspace_id
    else in_ws = w.floating_workspace == true end
    if on_monitor and in_ws then out[#out + 1] = w end
  end
  return names(out)
end

local function list(wins, ctx, monitors_mode, workspaces_mode)
  local cfg = C.merge({ windows = { monitors = monitors_mode, workspaces = workspaces_mode } })
  return names(W.filter(wins, ctx, cfg.windows, C.ignore_set(cfg)))
end

local checks = 0
for n = 1, 6 do
  local wins = topology(n)
  for focus = 1, n do
    local ctx = { workspace_id = 10 * focus + 1, monitor = "M" .. focus }
    for _, mm in ipairs({ "active", "all" }) do
      for _, wm in ipairs({ "current", "floating", "all" }) do
        local got, want = list(wins, ctx, mm, wm), expected(wins, ctx, mm, wm)
        checks = checks + 1
        check(("%d monitors, focus M%d, monitors=%s workspaces=%s"):format(n, focus, mm, wm), got == want, got .. " vs " .. want)
      end
    end
    -- the default (monitors active, floating): exactly this monitor's three floating windows, never another monitor's
    local default = list(wins, ctx, "active", "floating")
    checks = checks + 1
    check(("%d monitors, focus M%d: default lists %d floating windows of this monitor"):format(n, focus, 3),
      default == ("f%da,f%db,f%dmin"):format(focus, focus, focus), default)
  end
  -- monitors = all lists every monitor's floating windows, whatever the focus
  local all_floating = list(wins, { workspace_id = 11, monitor = "M1" }, "all", "floating")
  checks = checks + 1
  check(n .. " monitors: monitors=all lists " .. 3 * n .. " floating windows", select(2, all_floating:gsub(",", ",")) + 1 == 3 * n, all_floating)
end

-- Unplug monitor k of n: (a) Hyprland moves its workspaces to the first remaining monitor, so those windows now report that monitor
for n = 2, 6 do
  for k = 1, n do
    local wins = topology(n)
    local target = k == 1 and 2 or 1
    for _, w in ipairs(wins) do if w.monitor == "M" .. k then w.monitor = "M" .. target end end
    local ctx = { workspace_id = 10 * target + 1, monitor = "M" .. target }
    local got = list(wins, ctx, "active", "floating")
    local want = expected(wins, ctx, "active", "floating")
    checks = checks + 1
    check(("%d monitors, M%d unplugged, windows moved to M%d: active lists both monitors' windows there"):format(n, k, target), got == want and select(2, got:gsub(",", ",")) + 1 == 6, got)
    -- (b) a stale record: windows still name the gone monitor, focus is elsewhere or unknown; nothing raises, "all" still lists them
    local stale = topology(n)
    local ok1, a = pcall(list, stale, { workspace_id = nil, monitor = nil }, "active", "floating")
    local ok2, b = pcall(list, stale, { workspace_id = 11, monitor = "gone" }, "active", "floating")
    local ok3, c = pcall(list, stale, { workspace_id = nil, monitor = nil }, "all", "all")
    checks = checks + 1
    check(("%d monitors, stale focus: no error"):format(n), ok1 and ok2 and ok3, tostring(a) .. tostring(b) .. tostring(c))
    check(("%d monitors, focus on a monitor nobody has: active lists nothing"):format(n), b == "", b)
    check(("%d monitors, unknown focus: monitors=all still lists every window"):format(n), select(2, c:gsub(",", ",")) + 1 == #stale, c)
  end
end

if failures > 0 then print(("%d of %d monitor checks failed"):format(failures, checks)); os.exit(1) end
print(("ok   %d monitor-topology checks (1 to 6 monitors, every focus, unplug as move and as stale record)"):format(checks))

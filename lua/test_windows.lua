-- Plain Lua self-check:  lua lua/test_windows.lua   Every row of docs/settings.md "Combinations" is checked here.
local dir = arg[0]:match("^(.*)/") or "."
local W = dofile(dir .. "/windows.lua")
local C = dofile(dir .. "/config.lua")

-- Fixture: laptop panel (eDP) has floating workspace 1 and tiling workspace 2; a second monitor (DP) has floating workspace 11.
local function w(addr, ws, mon, floating, extra)
  local t = { address = addr, class = "app-" .. addr, workspace_id = ws, monitor = mon, floating_workspace = floating, minimized = false, special = false, mapped = true }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end
local all = {
  w("f1", 1, "eDP", true), w("f2", 1, "eDP", true), w("t1", 2, "eDP", false), w("d1", 11, "DP", true), w("dt", 12, "DP", false),
  w("min", 1, "eDP", true, { minimized = true }),          -- minimized from floating workspace 1
  w("mint", 2, "eDP", false, { minimized = true }),        -- minimized from tiling workspace 2
  w("minx", nil, "eDP", false, { minimized = true }),      -- minimized, origin unknown
  w("ghost", 1, "eDP", true, { mapped = false }),
  w("pad", -99, "eDP", false, { special = true }),
}
local function names(list) local t = {} for i, x in ipairs(list) do t[i] = x.address end table.sort(t) return table.concat(t, ",") end
local function run(ctx, over)
  local cfg = C.merge({ windows = over or {} })
  return names(W.filter(all, ctx, cfg.windows, C.ignore_set(cfg)))
end
local on_floating_laptop = { workspace_id = 1, monitor = "eDP" }
local on_tiling_laptop = { workspace_id = 2, monitor = "eDP" }

-- default: floating workspaces, active monitor, minimized last-listed, no ghosts, no specials
assert(run(on_floating_laptop) == "f1,f2,min", "default: this monitor's floating windows, including one minimized from a floating workspace")
-- row: floating, floating, all monitors
assert(run(on_floating_laptop, { monitors = "all" }) == "d1,f1,f2,min", "floating windows on every monitor")
-- row: current workspace only
assert(run(on_floating_laptop, { workspaces = "current" }) == "f1,f2,min", "current workspace only")
assert(run(on_tiling_laptop, { workspaces = "current" }) == "mint,t1", "current workspace on a tiling desktop: its own minimized window too")
-- row: all workspaces, active monitor (tiled windows appear)
assert(run(on_floating_laptop, { workspaces = "all" }) == "f1,f2,min,mint,minx,t1", "all workspaces on this monitor, minimized with unknown origin included")
-- row: all, all
assert(run(on_floating_laptop, { workspaces = "all", monitors = "all" }) == "d1,dt,f1,f2,min,mint,minx,t1", "everything everywhere, still no ghosts and no specials")
-- minimized hidden
assert(run(on_floating_laptop, { minimized = "hide" }) == "f1,f2", "minimized hidden")
-- specials shown
assert(run(on_floating_laptop, { specials = "show", workspaces = "all" }):find("pad"), "special windows shown on request")
-- ignore list, case insensitive
assert(run(on_floating_laptop, { ignore = "APP-f2" }) == "f1,min", "ignore by class, case insensitive")
-- other monitor focused
assert(run({ workspace_id = 11, monitor = "DP" }) == "d1", "the other monitor: its own floating window, not the laptop's minimized one")
-- empty result is an empty list, not an error
assert(#W.filter({}, on_floating_laptop, C.merge(nil).windows, {}) == 0, "no windows")
assert(run({ workspace_id = 5, monitor = "NONE" }) == "", "nothing on this monitor: empty list")

-- ignore by title fragment (plain text, case ignored); a window with no title is never excluded by it
local titled = { w("t1", 1, "eDP", true, { title = "Picture in picture" }), w("t2", 1, "eDP", true, { title = "Main window" }), w("t3", 1, "eDP", true) }
local cfg0 = C.merge(nil)
local kept = W.filter(titled, on_floating_laptop, cfg0.windows, {}, { ["picture in"] = true })
assert(names(kept) == "t2,t3", "title fragment drops the matching window only, got " .. names(kept))
assert(names(W.filter(titled, on_floating_laptop, cfg0.windows, {}, {})) == "t1,t2,t3" and names(W.filter(titled, on_floating_laptop, cfg0.windows, {})) == "t1,t2,t3", "no fragments, nothing dropped")

print("windows ok")

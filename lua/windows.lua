-- omahop window set: which windows the switcher lists. Pure: takes plain tables, so it tests without Hyprland.
-- Rules live in docs/settings.md; every row of its combinations table is a test in test_windows.lua.
local W = {}

-- A window is { address, class, title, workspace_id, monitor, floating_workspace, minimized, special, mapped }.
-- For a minimized window the glue fills workspace_id, monitor and floating_workspace from the workspace it was minimized from
-- (Omarchy tags it omarchy-minimized-from-<id>); nil workspace_id means the origin is unknown.
-- ctx is { workspace_id, monitor } of the focus. opts is cfg.windows, ignore is config.ignore_set(cfg).
local function in_workspaces(w, ctx, mode)
  if mode == "all" then return true end
  if w.workspace_id == nil then return false end
  if mode == "current" then return w.workspace_id == ctx.workspace_id end
  return w.floating_workspace == true -- "floating"
end

-- title_fragments: a set of lower-case fragments; a window whose title contains one (plain text, case ignored) is never listed.
function W.filter(windows, ctx, opts, ignore, title_fragments)
  local out = {}
  for _, w in ipairs(windows) do
    local keep = w.mapped ~= false -- ghost windows (Wine, Proton) have no real toplevel: never listed
    keep = keep and not (ignore and w.class and ignore[w.class:lower()])
    if keep and title_fragments and next(title_fragments) ~= nil then
      local t = tostring(w.title or ""):lower()
      for f in pairs(title_fragments) do
        if t:find(f, 1, true) then keep = false; break end
      end
    end
    keep = keep and not (w.special and opts.specials ~= "show")
    keep = keep and not (w.minimized and opts.minimized == "hide")
    keep = keep and (opts.monitors == "all" or w.monitor == ctx.monitor)
    keep = keep and in_workspaces(w, ctx, opts.workspaces)
    if keep then out[#out + 1] = w end
  end
  return out
end

return W

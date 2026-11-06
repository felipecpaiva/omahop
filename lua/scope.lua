-- omahop scope: is a workspace in floating mode, and is omahop active on it. Pure; the glue reads the files and passes the text in.
-- Mirrors omarchy-hyprland-workspace-layout-current: the workspace's own saved mode, else the saved default, else the layout Hyprland reports.
local Scope = {}

local function mode_of(text) return text and text:match('mode%s*=%s*"([a-z]+)"') end
local function default_of(text) return text and text:match('default%s*=%s*"([a-z]+)"') end

-- ws_file / default_file: text of ~/.local/state/omarchy/workspace-layouts/<id>.lua and default.lua (nil when missing).
-- tagged: some window on the workspace carries omarchy-floating-workspace (used only when no file says anything).
function Scope.workspace_floating(ws_file, default_file, tagged)
  local mode = mode_of(ws_file)
  if mode == nil and default_file ~= nil then mode = default_of(default_file) end
  if mode == nil then return tagged == true end
  return mode == "floating"
end

-- scope is the setting ("floating" or "all").
function Scope.active(scope, floating)
  return scope == "all" or floating == true
end

return Scope

-- Which touchpad swipes the Hyprland config already uses, and whether the omahop swipe (3 or 4 fingers, left and right) is free.
-- Hyprland has no query for gestures (`hyprctl gestures` is an unknown request in 0.56.2), so this reads the Lua config files that
-- Omarchy loads and lists every hl.gesture call outside a comment. Read-only. Sibling of tools/key-map.py.
--   lua tools/gesture-map.lua           Markdown for docs/research/swipe-spike.md
--   lua tools/gesture-map.lua --check   self-test of the parser (run-all does this)
-- shortcut: a gesture registered from a computed table or a loop is not seen; upgrade if Hyprland gains a gesture query.
local G = {}

-- Axes a direction claims, as Hyprland's addGesture compares them: "swipe" claims both, left or right claims horizontal.
local axis = { horizontal = "horizontal", horiz = "horizontal", left = "horizontal", l = "horizontal", right = "horizontal", r = "horizontal",
  vertical = "vertical", vert = "vertical", up = "vertical", u = "vertical", top = "vertical", t = "vertical", down = "vertical",
  d = "vertical", bottom = "vertical", b = "vertical", swipe = "both" }

local function strip_comments(text)
  text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "") -- block comments
  return (text:gsub("%-%-[^\n]*", ""))
end

-- Every hl.gesture({...}) call in a Lua file's text: { fingers, direction, action, mods }.
function G.parse(text)
  local out = {}
  for body in strip_comments(text or ""):gmatch("hl%.gesture%s*%(%s*(%b{})") do
    local fingers = tonumber(body:match("fingers%s*=%s*(%d+)"))
    local direction = body:match("direction%s*=%s*[\"'](%w+)[\"']")
    local action = body:match("action%s*=%s*[\"'](%w+)[\"']") or (body:match("action%s*=%s*function") and "function") or "callbacks"
    local mods = body:match("mods%s*=%s*[\"']([^\"']*)[\"']") or ""
    if fingers and direction then out[#out + 1] = { fingers = fingers, direction = direction:lower(), action = action, mods = mods } end
  end
  return out
end

-- Whether a gesture with no mods on the horizontal axis with `fingers` is already taken by one of `list`.
function G.horizontal_taken(list, fingers)
  for _, g in ipairs(list) do
    local a = axis[g.direction]
    if g.fingers == fingers and g.mods == "" and (a == "horizontal" or a == "both") then return g end
  end
  return nil
end

local function check()
  local text = [[
-- hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
--[==[ hl.gesture({ fingers = 4, direction = "left", action = "move" }) ]==]
hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace"
})
hl.gesture({ fingers = 3, direction = "up", action = function() hl.dispatch(hl.dsp.focus({ workspace = "empty" })) end })
hl.gesture({ fingers = 4, direction = "LEFT", mods = "SUPER", action = "move" })
hl.gesture({ fingers = 5, direction = "swipe", action = "close" })
]]
  local list = G.parse(text)
  assert(#list == 4, "four live gestures, comments skipped, got " .. #list)
  assert(list[1].fingers == 3 and list[1].direction == "horizontal" and list[1].action == "workspace", "multi-line call parsed")
  assert(list[2].action == "function", "a function action is named")
  assert(G.horizontal_taken(list, 3), "3 fingers horizontal is taken")
  assert(not G.horizontal_taken(list, 4), "4 fingers with a modifier does not clash with a swipe without one")
  assert(G.horizontal_taken(list, 5), "a swipe in any direction claims horizontal too")
  print("gesture-map ok")
end

local function lua_files()
  local home = os.getenv("HOME") or ""
  local roots = { (os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")) .. "/hypr", (os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr" }
  local files = {}
  for _, root in ipairs(roots) do
    local p = io.popen(("find '%s' -name '*.lua' -type f 2>/dev/null | sort"):format(root:gsub("'", "'\\''")))
    if p then
      for line in p:lines() do files[#files + 1] = line end
      p:close()
    end
  end
  return files
end

local function main()
  local all = {}
  print("| Fingers | Direction | Mods | Action | File |")
  print("|---|---|---|---|---|")
  for _, path in ipairs(lua_files()) do
    local f = io.open(path, "r")
    if f then
      local text = f:read("a"); f:close()
      for _, g in ipairs(G.parse(text)) do
        all[#all + 1] = g
        print(("| %d | %s | %s | %s | %s |"):format(g.fingers, g.direction, g.mods ~= "" and g.mods or "none", g.action, path:gsub("^" .. (os.getenv("HOME") or "~"):gsub("%p", "%%%0"), "~")))
      end
    end
  end
  print("\nomahop swipe (left and right, no mods):\n")
  for _, n in ipairs({ 3, 4 }) do
    local g = G.horizontal_taken(all, n)
    print(("- %d fingers: %s"):format(n, g and ("taken (" .. g.direction .. ", " .. g.action .. ")") or "free"))
  end
end

if arg and arg[1] == "--check" then check() else main() end

-- Plain Lua self-check:  lua lua/test_config.lua   (run with Lua 5.5, like Hyprland)
local dir = arg[0]:match("^(.*)/") or "."
local C = dofile(dir .. "/config.lua")

-- defaults: every spec entry is a valid value for its own rule
local d = C.merge(nil)
assert(d.scope == "floating" and d.takeover == true and d.style == "list" and d.reveal_delay_ms == 100, "top defaults")
assert(d.windows.workspaces == "floating" and d.windows.monitors == "active" and d.windows.minimized == "back", "window defaults")
assert(d.keys.repeat_delay_ms == 250 and d.keys.repeat_ms == 40, "key defaults")

-- parse: values, sections, comments, trailing comments, unreadable lines
local t, bad = C.parse([[
# a comment
schema = 1
scope = "all"   # trailing comment
reveal_delay_ms = 0
takeover = false
[windows]
workspaces = "current"
ignore = "steam, Pavucontrol"
[keys]
repeat_ms = 25
garbage line
oops = notavalue
]])
assert(t.top.scope == "all" and t.top.takeover == false and t.top.reveal_delay_ms == 0, "top parsed")
assert(t.windows.workspaces == "current" and t.keys.repeat_ms == 25, "sections parsed")
assert(#bad == 2, "two unreadable lines, got " .. #bad)

local cfg, problems = C.merge(t)
assert(cfg.scope == "all" and cfg.takeover == false and cfg.reveal_delay_ms == 0, "merge applies values (0 is valid, not 'missing')")
assert(cfg.windows.workspaces == "current" and cfg.windows.monitors == "active" and cfg.keys.repeat_ms == 25, "merge keeps other defaults")
assert(#problems == 0, "no problems for valid input")

-- bad values fall back and are reported, never raise
local c2, p2 = C.merge({ top = { scope = "everywhere", style = 5, reveal_delay_ms = 99999 }, windows = { monitors = "both" }, keys = { repeat_ms = 1 } })
assert(c2.scope == "floating" and c2.style == "list" and c2.reveal_delay_ms == 100, "bad top values use defaults")
assert(c2.windows.monitors == "active" and c2.keys.repeat_ms == 40, "bad nested values use defaults")
assert(#p2 == 5, "five problems reported, got " .. #p2)

-- defaults are not shared with the merged copy
local c3 = C.merge(nil)
c3.windows.workspaces = "all"
assert(C.spec.windows.workspaces.default == "floating" and C.merge(nil).windows.workspaces == "floating", "defaults not mutated")

-- ignore set
local set = C.ignore_set({ windows = { ignore = " Steam ,pavucontrol,, " } })
assert(set.steam and set.pavucontrol and not set[""], "ignore set is trimmed and lower case")

-- load: missing file is the defaults; a real file round trip
local none, np = C.load("/nonexistent/omahop.toml")
assert(none.scope == "floating" and #np == 0, "missing file is defaults")
local path = os.tmpname()
local f = assert(io.open(path, "w")); f:write('scope = "all"\n[windows]\nmonitors = "all"\nbad line\n'); f:close()
local lc, lp = C.load(path)
os.remove(path)
assert(lc.scope == "all" and lc.windows.monitors == "all" and #lp == 1, "file loads and reports an unreadable line")

print("config ok")

-- Plain Lua self-check:  lua lua/test_config.lua   (run with Lua 5.5, like Hyprland)
local dir = arg[0]:match("^(.*)/") or "."
local C = dofile(dir .. "/config.lua")

-- defaults: every spec entry is a valid value for its own rule
local d = C.merge(nil)
assert(d.scope == "floating" and d.takeover == true and d.style == "list" and d.reveal_delay_ms == 100, "top defaults")
assert(d.windows.workspaces == "floating" and d.windows.monitors == "active" and d.windows.minimized == "back", "window defaults")
assert(d.keys.repeat_delay_ms == 250 and d.keys.repeat_ms == 40, "key defaults")
assert(d.border == "auto" and C.merge({ top = { border = "off" } }).border == "off" and C.merge({ top = { border = "thick" } }).border == "auto", "border setting: auto default, off accepted, bad value falls back")
assert(d.browser_tabs == false and d.browser_tabs_ignore == "", "browser tabs are off by default with an empty ignore list")
assert(C.merge({ top = { browser_tabs = "yes" } }).browser_tabs == false, "browser_tabs: a non-boolean falls back to off")
assert(d.browser_tab_previews == false and C.merge({ top = { browser_tab_previews = "yes" } }).browser_tab_previews == false, "browser_tab_previews is off by default and a non-boolean falls back to off")
assert(not C.overridable(C.spec.top.browser_tab_previews), "page pictures are never changed by a profile")
assert(d.audio_marker == false and C.merge({ top = { audio_marker = "on" } }).audio_marker == false and C.merge({ top = { audio_marker = true } }).audio_marker == true, "audio_marker: off by default, a non-boolean falls back to off")

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

-- a # inside a quoted string is not a comment; after whitespace outside a string it is
local hs = C.parse('[windows]\nignore = "steam, #hash"   # note\nworkspaces = "all" # x\n')
assert(hs.windows.ignore == "steam, #hash" and hs.windows.workspaces == "all", "quote-aware comment stripping")

-- bad values fall back and are reported, never raise
local c2, p2 = C.merge({ top = { scope = "everywhere", style = 5, reveal_delay_ms = 99999 }, windows = { monitors = "both" }, keys = { repeat_ms = 1 } })
assert(c2.scope == "floating" and c2.style == "list" and c2.reveal_delay_ms == 100, "bad top values use defaults")
assert(c2.windows.monitors == "active" and c2.keys.repeat_ms == 40, "bad nested values use defaults")
assert(#p2 == 5, "five problems reported, got " .. #p2)

-- search_linger_seconds: 0 is off (the default), 1 to 60 is on; anything else falls back to 0
assert(d.search_linger_seconds == 0, "linger off by default")
assert(C.merge({ top = { search_linger_seconds = 1 } }).search_linger_seconds == 1 and C.merge({ top = { search_linger_seconds = 60 } }).search_linger_seconds == 60, "1 and 60 accepted")
local lc_, lp_ = C.merge({ top = { search_linger_seconds = 61 } })
assert(lc_.search_linger_seconds == 0 and #lp_ == 1, "61 falls back to 0 and is reported")
assert(C.merge({ top = { search_linger_seconds = -1 } }).search_linger_seconds == 0 and C.merge({ top = { search_linger_seconds = "5" } }).search_linger_seconds == 0, "negative and text fall back")

-- modifier: alt by default, the allowed values are the modifier table's names, anything else falls back to alt and is reported; it needs a reload
local Modifier = dofile(dir .. "/modifier.lua")
assert(d.modifier == "alt" and C.spec.top.modifier.reload == true, "modifier: alt by default, applies after a reload")
assert(table.concat(C.spec.top.modifier.values, ",") == table.concat(Modifier.names, ","), "values come from the modifier table")
assert(C.merge({ top = { modifier = "super" } }).modifier == "alt" and C.merge({ top = { modifier = "ctrl" } }).modifier == "ctrl", "ctrl accepted, super is not an option (falls back to alt)")
for _, bad in ipairs({ "hyper", "ALT", "shift", "", 1, true }) do
  local mc, mp = C.merge({ top = { modifier = bad } })
  assert(mc.modifier == "alt" and #mp == 1 and mp[1]:find("^top%.modifier = "), "bad modifier falls back to alt and is reported: " .. tostring(bad))
end
local pm = C.merge((C.parse('modifier = "ctrl"\n')))
assert(pm.modifier == "ctrl", "parsed from the file")

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

-- profiles: dotted table names parse, the named profile is laid over the base, bad and non-overridable values keep the base and are reported
local pt, pbad = C.parse([[
profile = "work"
style = "list"
takeover = true
[windows]
ignore = "steam"
monitors = "all"
[profiles.work]
style = "cards"
thumbnails = "sometimes"
takeover = false
modifier = "ctrl"
browser_tabs = true
unknown_key = 1
[profiles.work.windows]
ignore = "slack, discord"
[profiles.work.keys]
repeat_ms = 20
[profiles.gaming]
passthrough_fullscreen = true
[profiles..bad]
[profiles.bad.]
]])
assert(pt["profiles.work"].style == "cards" and pt["profiles.work.windows"].ignore == "slack, discord", "dotted tables parse")
assert(#pbad == 2, "empty segments are unreadable headers, got " .. #pbad)
assert(table.concat(C.profile_names(pt), ",") == "gaming,work", "profile names, sorted")
local pc, pp = C.resolve(pt)
assert(pc.profile == "work" and pc.style == "cards", "the profile wins over the base")
assert(pc.windows.ignore == "slack, discord" and pc.windows.monitors == "all", "nested profile section overrides one key, the base keeps the rest")
assert(pc.keys.repeat_ms == 20 and pc.keys.repeat_delay_ms == 250, "keys section overridable")
assert(pc.thumbnails == "snapshot", "a bad profile value keeps the base (here the default)")
assert(pc.takeover == true and pc.modifier == "alt" and pc.browser_tabs == false, "reload and base_only settings are never taken from a profile")
assert(pc.passthrough_fullscreen == false, "another profile's values are not used")
local want = { "profiles.work.browser_tabs: not overridable in a profile, ignored", "profiles.work.modifier: not overridable in a profile, ignored",
  "profiles.work.takeover: not overridable in a profile, ignored", "profiles.work.thumbnails = sometimes" }
assert(table.concat(pp, "|") == table.concat(want, "|"), "problems: " .. table.concat(pp, "|"))
-- a bad profile value falls back to the BASE value, not the default
local fb = C.resolve(C.parse('profile = "p"\nreveal_delay_ms = 0\n[profiles.p]\nreveal_delay_ms = 5000\n'))
assert(fb.reveal_delay_ms == 0, "bad profile value keeps the base value")
-- no profile chosen, an unknown profile, a profile that cannot choose another profile
local base_only = C.resolve(C.parse('style = "cards"\n[profiles.work]\nstyle = "list"\n'))
assert(base_only.profile == "" and base_only.style == "cards", "no profile chosen: the base")
local uc, up = C.resolve(C.parse('profile = "ghost"\nstyle = "cards"\n[profiles.work]\nstyle = "list"\n'))
assert(uc.profile == "" and uc.style == "cards" and up[1] == "profile = ghost: no such profile, using the base settings", "unknown profile is reported, base used")
local cc, cp = C.resolve(C.parse('profile = "a"\n[profiles.a]\nprofile = "b"\nstyle = "cards"\n[profiles.b]\nstyle = "list"\n'))
assert(cc.profile == "a" and cc.style == "cards" and cp[1] == "profiles.a.profile: not overridable in a profile, ignored", "no profile chains")
-- C.merge is unchanged: it ignores profiles
assert(C.merge(pt).style == "list", "merge alone is the base")
-- overridable: reload, hidden and base_only rules are out, everything else is in
for section, rules in pairs(C.spec) do
  for key, rule in pairs(rules) do
    assert(C.overridable(rule) == not (rule.reload or rule.hidden or rule.base_only), "overridable rule for " .. section .. "." .. key)
  end
end
assert(C.overridable(C.spec.top.style) and C.overridable(C.spec.windows.ignore) and not C.overridable(C.spec.top.same_app_key), "examples")
-- a profile file round trip through load
local ppath = os.tmpname()
local pf = assert(io.open(ppath, "w")); pf:write('profile = "work"\n[profiles.work]\nstyle = "cards"\n'); pf:close()
local plc = C.load(ppath)
os.remove(ppath)
assert(plc.style == "cards", "load applies the profile")

-- the panel order lists every setting exactly once (schema is not shown), and every setting names a known group
local seen = {}
for _, path in ipairs(C.order) do
  assert(not seen[path], "listed twice in C.order: " .. path); seen[path] = true
  local section, key = path:match("^(%w+)%.([%w_]+)$")
  assert(C.spec[section] and C.spec[section][key], "C.order names an unknown setting: " .. path)
end
local groups = {}
for _, g in ipairs(C.groups) do groups[g.id] = true end
for section, rules in pairs(C.spec) do
  for key, rule in pairs(rules) do
    local path = section .. "." .. key
    if key ~= "schema" then
      assert(seen[path], "setting missing from C.order (the panel would never show it): " .. path)
      assert(groups[rule.group], "unknown group for " .. path)
      assert(rule.label, "no label for " .. path)
      if rule.values then for _, v in ipairs(rule.values) do assert(rule.names and rule.names[v], "no display name for " .. path .. " = " .. v) end end
    end
  end
end

print("config ok")

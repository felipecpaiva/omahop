-- Plain Lua self-check:  lua lua/test_rules.lua
local dir = arg[0]:match("^(.*)/") or "."
local R = dofile(dir .. "/rules.lua")

local s = R.set(" Steam ,pavucontrol,, ")
assert(s.steam and s.pavucontrol and next(s) and not s[""], "set: trimmed, lower case, no empties")
assert(next(R.set("")) == nil and next(R.set(nil)) == nil, "empty and nil give an empty set")

assert(R.title_matches("Picture in picture - Chrome", R.set("picture in picture")), "a fragment of the title matches, case ignored")
assert(R.title_matches("Sign In", R.set("sign in, other")))
assert(not R.title_matches("Document", R.set("sign in")), "no fragment, no match")
assert(not R.title_matches("anything", {}), "no fragments: nothing is excluded")
assert(R.title_matches("a.b (c)", R.set("a.b (c)")), "a fragment is plain text, not a pattern")
assert(not R.title_matches("axb", R.set("a.b")), "so a dot matches only a dot")

local function e(c) return { class = c } end
local list = { e("kitty"), e("chrome"), e("slack"), e("Chrome") }
local out = R.first_apps(list, R.set("chrome"))
assert(out[1].class == "chrome" and out[2].class == "Chrome" and out[3].class == "kitty" and out[4].class == "slack", "listed apps first in their own order, others keep theirs")
assert(R.first_apps(list, {}) == list, "no rule: the same list")
assert(#list == 4 and list[1].class == "kitty", "input not mutated")

assert(R.passthrough({ class = "game", fullscreen = 2 }, true, {}) == true, "fullscreen window with the setting on")
assert(R.passthrough({ class = "game", fullscreen = 2 }, false, {}) == false, "fullscreen but the setting is off")
assert(R.passthrough({ class = "game", fullscreen = 1 }, true, {}) == false, "a maximized window (state 1) is not fullscreen")
assert(R.passthrough({ class = "Remmina", fullscreen = 0 }, false, R.set("remmina")) == true, "a listed app steps aside in any state")
assert(R.passthrough(nil, true, R.set("x")) == false, "nothing focused: do not step aside")
assert(R.passthrough({ class = "app", fullscreen = nil }, true, {}) == false, "missing fullscreen field counts as 0")
print("rules ok")

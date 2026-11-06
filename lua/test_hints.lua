-- Plain Lua self-check:  lua lua/test_hints.lua
local dir = arg[0]:match("^(.*)/") or "."
local H = dofile(dir .. "/hints.lua")

local m = H.parse_keys("c=google-chrome, T = Kitty ,bad, =x, 9=slack, ab=two")
assert(m.c == "google-chrome" and m.t == "kitty" and m["9"] == "slack", "parse: keys and classes lower case, spaces ignored")
assert(m.ab == nil and m[""] == nil, "a key must be one character; bad items are skipped")
assert(next(H.parse_keys("")) == nil and next(H.parse_keys(nil)) == nil, "empty gives an empty map")

local function e(c) return { class = c } end
local list = { e("kitty"), e("google-chrome"), e("slack"), e("kitty"), e("mpv") }
local function join(t) return table.concat(t, ",") end

assert(join(H.labels(list, "off", {})) == ",,,,", "off: no labels")
assert(join(H.labels(list, "numbers", {})) == "1,2,3,4,5", "numbers: one per row")
local many = {} for i = 1, 12 do many[i] = e("app" .. i) end
assert(#join(H.labels(many, "numbers", {})) == 9 * 2 + 3 - 1 + 0 or H.labels(many, "numbers", {})[10] == "", "only the first nine rows get a number")
assert(H.labels(many, "numbers", {})[9] == "9" and H.labels(many, "numbers", {})[10] == "", "row 10 and beyond have no number")
local lab = H.labels(list, "apps", { c = "google-chrome", t = "kitty" })
assert(lab[1] == "t" and lab[2] == "c" and lab[4] == "" , "apps: the first window of each mapped app carries the letter, a second kitty window does not")

assert(H.target(list, "numbers", {}, "3") == 3, "number picks the row")
assert(H.target(list, "numbers", {}, "0") == nil and H.target(list, "numbers", {}, "9") == nil, "0 and a row that does not exist: nothing")
assert(H.target(list, "numbers", {}, "a") == nil, "letters are not number hints")
assert(H.target(list, "apps", { c = "google-chrome", t = "kitty" }, "t") == 1, "the first window of the app")
assert(H.target(list, "apps", { c = "google-chrome" }, "C") == 2, "case ignored")
assert(H.target(list, "apps", { c = "google-chrome" }, "z") == nil, "an unmapped letter types")
assert(H.target(list, "apps", { z = "firefox" }, "z") == nil, "a mapped app with no window: nothing")
assert(H.target(list, "off", { c = "x" }, "c") == nil and H.target(list, "off", {}, "1") == nil, "off: never")
print("hints ok")

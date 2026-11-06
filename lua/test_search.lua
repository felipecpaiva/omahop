-- Plain Lua self-check:  lua lua/test_search.lua
local dir = arg[0]:match("^(.*)/") or "."
local S = dofile(dir .. "/search.lua")

local function e(class, title) return { class = class, title = title } end
local list = { e("google-chrome", "Release notes - Example"), e("kitty", "~/projects/api: cargo test"), e("org.gnome.Nautilus", "Projects"), e("slack", "design-review"), e("com.anthropic.Claude", "Planning") }
local names = { ["google-chrome"] = "Google Chrome", ["org.gnome.Nautilus"] = "Files", ["com.anthropic.Claude"] = "Claude" }
local function classes(l) local t = {} for i, x in ipairs(l) do t[i] = x.class end return table.concat(t, ",") end

assert(S.filter(list, "", names) == list, "empty query returns the list unchanged")
assert(classes(S.filter(list, "chrome", names)) == "google-chrome", "matches the class")
assert(classes(S.filter(list, "files", names)) == "org.gnome.Nautilus", "matches the display name the overlay knows (class has no 'files')")
assert(classes(S.filter(list, "FILES", names)) == "org.gnome.Nautilus", "case is ignored")
assert(classes(S.filter(list, "cargo", names)) == "kitty", "matches the title")
assert(classes(S.filter(list, "google chr", names)) == "google-chrome", "several words, separators ignored (class google-chrome)")
assert(classes(S.filter(list, "design review", names)) == "slack", "a hyphen in the title matches a space typed")
assert(classes(S.filter(list, "zzz", names)) == "", "no match: empty list")
-- rank: app name starting with the word comes first, the rest keep their order
local l2 = { e("kitty", "profile editor"), e("firefox", "Home"), e("figma", "Design") }
assert(classes(S.filter(l2, "fi", nil)) == "firefox,figma,kitty", "apps that start with 'fi' first, a title that contains it last")
-- entries are the same tables (the caller keeps addresses)
assert(S.filter(list, "kitty", names)[1] == list[2], "same entry objects")
-- no names known: class only
assert(classes(S.filter(list, "files", nil)) == "", "without the names file only class and title are searched")
-- typing helpers
assert(S.append("ab", "c") == "abc" and S.backspace("abc") == "ab" and S.backspace("") == "", "append and backspace")
print("search ok")

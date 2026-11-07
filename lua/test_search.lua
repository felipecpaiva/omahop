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
-- accents: folded both ways, both cases
local acc = { e("a", "ação"), e("b", "Ação"), e("c", "Café"), e("d", "Straße"), e("e", "Søren"), e("f", "cœur"), e("g", "Łódź"), e("h", "naïve ñandú") }
local function has(q, cls) for _, x in ipairs(S.filter(acc, q, nil)) do if x.class == cls then return true end end return false end
assert(has("acao", "a") and has("acao", "b"), "acao finds ação and Ação")
assert(has("ACAO", "a") and has("ACAO", "b"), "ACAO finds Ação")
assert(has("ação", "a") and has("AÇÃO", "a"), "accented query finds accented title")
assert(has("cafe", "c") and has("café", "c"), "cafe finds Café")
assert(has("strasse", "d") and has("soren", "e") and has("coeur", "f") and has("lodz", "g") and has("naive nandu", "h"), "ß ø œ ł ï ñ ú")
assert(S.fold("ÀÉÎÕÜÇ ÿ æ Æ") == "aeiouc y ae ae", "fold uppercase forms")
assert(S.fold("日本 ★ x") == "日本 ★ x", "unknown characters unchanged")
assert(S.fold("") == "" and S.fold(nil) == "", "empty and nil")

-- fuzzy: initials and letters in order inside a word
local f = { e("google-chrome", "Release notes"), e("kitty", "cargo test"), e("slack", "design-review"), e("org.gnome.Nautilus", "Files") }
local fn = { ["google-chrome"] = "Google Chrome" }
assert(classes(S.filter(f, "gc", fn)) == "google-chrome", "initials: gc finds Google Chrome")
assert(classes(S.filter(f, "chrm", fn)) == "google-chrome", "in-word letters: chrm finds chrome")
assert(classes(S.filter(f, "ct", fn)) == "kitty", "initials of title words: ct finds cargo test")
assert(classes(S.filter(f, "chr", fn)) == "google-chrome", "plain substring still works")
assert(classes(S.filter(f, "chrm", fn, { fuzzy = false })) == "", "fuzzy off: chrm finds nothing")
assert(classes(S.filter(f, "gc", fn, { fuzzy = false })) == "", "fuzzy off: gc finds nothing")
assert(S.filter(f, "", fn) == f, "empty query, fuzzy on: unchanged")
-- rank: app prefix, then plain contains, then fuzzy, each in the given order
local r = { e("zed", "gc notes"), e("alpha", "grand cafe"), e("gcalc", "x"), e("gcc", "y"), e("beta", "gcx") }
assert(classes(S.filter(r, "gc", nil)) == "gcalc,gcc,zed,beta,alpha", "rank order")
assert(classes(S.filter(r, "gc", nil, { fuzzy = false })) == "gcalc,gcc,zed,beta", "fuzzy off equals the plain rule")
-- speed
local t0 = os.clock()
for _ = 1, 100 do S.filter({ e("x", string.rep("word ", 200)) }, "zzq", nil) end
local t_long = (os.clock() - t0) / 100
assert(t_long < 0.01, "1000 char title fast")
local many = {}
for i = 1, 200 do many[i] = e("app" .. i, "Some window title number " .. i .. " with ação") end
t0 = os.clock()
for _ = 1, 20 do S.filter(many, "wtn", nil); S.filter(many, "acao", nil) end
local t_many = (os.clock() - t0) / 40
assert(t_many < 0.05, "200 windows fast")
print(("search speed: 1000-char title %.3f ms, 200 windows %.3f ms per filter"):format(t_long * 1000, t_many * 1000))
print("search ok")

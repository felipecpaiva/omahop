-- Plain Lua self-check:  lua lua/test_tabs.lua   (Lua 5.5, like Hyprland). JSON decoder, tab file parse, staleness, ignore list, matching, rows.
-- Fixtures are made up (example.com style); no real titles or addresses.
local dir = arg[0]:match("^(.*)/") or "."
local J = dofile(dir .. "/json.lua")
local T = dofile(dir .. "/tabs.lua")

-- ---- JSON ----
do
  local v = J.decode('{"a": [1, -2.5, true, false, null, "x\\n\\u00e7\\ud83d\\ude00"], "b": {}}')
  assert(v.a[1] == 1 and math.type(v.a[1]) == "integer" and v.a[2] == -2.5 and v.a[3] == true and v.a[4] == false and v.a[5] == J.null, "values")
  assert(v.a[6] == "x\nç😀" and next(v.b) == nil, "escapes, a surrogate pair and an empty object")
  for _, bad in ipairs({ "", "{", "[1,]", "{\"a\" 1}", "{\"a\":1} x", "\"\\ud800\"", "\"a\nb\"", "tru", "01x", "{1:2}", "[1 2]", "\"\\q\"", "-", "1e" }) do
    local r, why = J.decode(bad)
    assert(r == nil and type(why) == "string", "rejected: " .. bad)
  end
  assert(J.decode(string.rep("[", 17) .. string.rep("]", 17)) == nil, "too deep is rejected")
  assert(J.decode(string.rep("[", 16) .. string.rep("]", 16)) ~= nil, "16 levels is fine")
  assert(J.decode(nil) == nil, "not text")
  local _, why = J.decode('{"title": "secret words"')
  assert(not why:find("secret"), "a reason never quotes the input")
end

-- ---- file names, listing, staleness ----
assert(T.host_pid("tabs.123.json") == 123 and T.host_pid("tabs.enabled") == nil and T.host_pid("tabs.ignore") == nil, "only tab files")
assert(T.host_pid("tabs.12.activate") == nil and T.host_pid("tabs.-1.json") == nil and T.host_pid("tabs.1.json.tmp") == nil and T.host_pid("x/tabs.1.json") == nil, "no FIFOs, temps or paths")
assert(T.host_pid("tabs.99999999999.json") == nil, "absurd pid")
do
  local l = T.listing("tabs.5.json 1000.5\ntabs.enabled 1001\ntabs.7.json 2000\ntabs.ignore 3\n")
  assert(#l == 2 and l[1].pid == 7 and l[2].pid == 5 and l[2].mtime == 1000, "listing: tab files only, newest first")
  local many = {}
  for i = 1, 20 do many[#many + 1] = ("tabs.%d.json %d"):format(i, i) end
  l = T.listing(table.concat(many, "\n"))
  assert(#l == T.limits.files and l[1].pid == 20, "at most limits.files, the newest kept")
  local alive = function(pid) return pid == 7 end
  assert(T.fresh({ pid = 7, mtime = 1000 }, 1010, alive), "live host, recent file")
  assert(not T.fresh({ pid = 5, mtime = 1000 }, 1010, alive), "host gone: stale")
  assert(not T.fresh({ pid = 7, mtime = 1000 }, 1000 + T.limits.age_s + 1, alive), "too old: stale")
end

-- ---- parse ----
local function file(windows, extra)
  local parts = { '"schema": 1', '"browser": "chromium"', '"pid": 4242', '"caller": "chrome-extension://abc/"', '"profile": null' }
  for k, v in pairs(extra or {}) do parts[#parts + 1] = ('"%s": %s'):format(k, v) end
  return "{" .. table.concat(parts, ", ") .. ', "windows": [' .. table.concat(windows, ",") .. "]}"
end
local function window(id, focused, tabs, typ)
  return ('{"id": %d, "focused": %s, "type": "%s", "tabs": [%s]}'):format(id, tostring(focused), typ or "normal", table.concat(tabs, ","))
end
local function tab(id, active, title, url)
  return ('{"id": %d, "active": %s, "title": "%s", "url": "%s"}'):format(id, tostring(active), title, url)
end
do
  local s = T.parse(file({ window(1, true, { tab(10, true, "Alpha page", "https://a.example.com/x?q=1"), tab(11, false, "Beta", "https://b.example.org/") }) }))
  assert(T.parse((file({ window(1, true, {}) }):gsub('"profile": null', '"profile": "Profile 1"'))), "profile as text is fine too")
  assert(T.parse((file({ window(1, true, {}) }):gsub('"profile": null', '"profile": 5'))) == nil, "profile of another type is not")
  assert(T.parse(file({ window(1, true, {}) }, { later = '{"x": 1}' })), "unknown fields are ignored")
  assert(s and s.browser == "chromium" and s.pid == 4242 and #s.windows == 1 and #s.windows[1].tabs == 2, "a good file parses")
  assert(s.windows[1].tabs[1].title == "Alpha page" and s.windows[1].tabs[1].active == true, "tab fields")
  local function rejects(text, what) local r = T.parse(text); assert(r == nil, "rejected: " .. what) end
  rejects((file({}, { schema = 2 }):gsub('"schema": 1, ', "")), "unknown schema")
  rejects('{"schema": 1, "browser": "x", "pid": "12", "windows": []}', "pid as text")
  rejects('{"schema": 1, "browser": "x", "pid": 1}', "no windows")
  rejects('{"schema": 1, "browser": 5, "pid": 1, "windows": []}', "browser not text")
  rejects('[1, 2]', "not an object")
  rejects("not json at all", "garbage")
  rejects(file({ window(1, "yes", {}) }), "focused not boolean")
  rejects(file({ window(1, true, { '{"id": 1, "active": true, "title": 5, "url": "u"}' }) }), "title not text")
  rejects(file({ window(1, true, { '{"id": -1, "active": true, "title": "t", "url": "u"}' }) }), "negative tab id")
  rejects(file({ window(1, true, { '{"id": 1.5, "active": true, "title": "t", "url": "u"}' }) }), "fractional tab id")
  rejects(string.rep(" ", T.limits.bytes + 1), "oversize")
  local lots = {}
  for i = 1, T.limits.tabs + 1 do lots[i] = tab(i, false, "t", "https://example.com/") end
  rejects(file({ window(1, true, lots) }), "too many tabs")
  -- long titles are cut on a character boundary; control characters become spaces
  local long = string.rep("é", 400)
  local s2 = T.parse(file({ window(1, true, { tab(1, true, long .. "\\nx", "https://example.com/") }) }))
  assert(#s2.windows[1].tabs[1].title <= T.limits.title and utf8.len(s2.windows[1].tabs[1].title), "title cut on a character boundary")
  local s3 = T.parse(file({ window(1, true, { tab(1, true, "a\\tb\\nc", "https://example.com/") }) }))
  assert(s3.windows[1].tabs[1].title == "a b c", "no control characters survive")
end

-- ---- urls and ignore ----
do
  local h, p = T.url_parts("https://user:pw@Mail.Example.COM:8443/inbox/1?token=x#frag")
  assert(h == "mail.example.com" and p == "/inbox/1", "host without user and port, path without query or fragment")
  h, p = T.url_parts("data:text/html,hello")
  assert(h == "" and p == "", "data url: nothing")
  h = T.url_parts("chrome://settings/")
  assert(h == "settings", "scheme urls keep their host")
  local names, bad = T.ignore_list(" Bank.Example.com, *.mail.example.org,, bad name, x;rm -rf ")
  assert(#names == 2 and names[1] == "bank.example.com" and names[2] == "*.mail.example.org" and #bad == 2, "ignore list: lower case, globs kept, bad items skipped")
  assert(T.ignored("bank.example.com", names) and T.ignored("www.bank.example.com", names), "plain name: exact and subdomain")
  assert(not T.ignored("notbank.example.com", names) and not T.ignored("example.com", names), "a longer or shorter name is not a subdomain")
  assert(T.ignored("x.mail.example.org", names) and not T.ignored("mail.example.org", names), "a glob matches the whole host, like fnmatch")
  local g = T.ignore_list("sh?p.example, [ab]x.example, [!c]y.example, a.b")
  assert(T.ignored("shop.example", g) and not T.ignored("shoop.example", g), "? is one character")
  assert(T.ignored("ax.example", g) and not T.ignored("cx.example", g), "a set")
  assert(T.ignored("by.example", g) and not T.ignored("cy.example", g), "a negated set")
  assert(not T.ignored("axb", g) and T.ignored("a.b", g), "a dot is literal")
  assert(not T.ignored("", { "*" }), "a tab with no host is never hidden")
end

-- ---- matching ----
local function hw(address, pid, title, focus, class)
  return { address = address, pid = pid, title = title, focus_history = focus or 5, class = class or "chromium" }
end
local function snap(pid, windows, extra)
  local s = { browser = "chromium", pid = pid, pids = { [pid] = true }, hostpid = 900, windows = windows }
  for k, v in pairs(extra or {}) do s[k] = v end
  return s
end
local function bw(id, focused, active_title, more)
  local tabs = { { id = id * 10, active = true, title = active_title, url = "https://example.com/" .. id } }
  for i, t in ipairs(more or {}) do tabs[#tabs + 1] = { id = id * 10 + i, active = false, title = t, url = "https://example.net/" .. i } end
  return { id = id, focused = focused, type = "normal", tabs = tabs }
end
do
  -- unique pid, one window each: exact, the title does not matter
  local s = snap(100, { bw(1, false, "Something else") })
  local m = T.match({ s }, { hw("0x1", 100, "Totally different - Chromium"), hw("0x9", 200, "Something else - Chromium") })
  assert(m[s.windows[1]].address == "0x1", "unique pid: matched without the title")
  -- title prefix with the learned suffix
  local a, b = bw(1, false, "Alpha"), bw(2, false, "Beta")
  m = T.match({ snap(100, { a, b }) }, { hw("0x1", 100, "Beta - Chromium"), hw("0x2", 100, "Alpha - Chromium") })
  assert(m[a].address == "0x2" and m[b].address == "0x1", "title prefix decides")
  -- a title that is a prefix of another window's title: the learned suffix keeps them apart
  local p1, p2 = bw(1, false, "Plan"), bw(2, false, "Plan - draft")
  m = T.match({ snap(100, { p1, p2 }) }, { hw("0x1", 100, "Plan - draft - Chromium"), hw("0x2", 100, "Plan - Chromium") })
  assert(m[p1].address == "0x2" and m[p2].address == "0x1", "title prefix of another title")
  -- the learned suffix: an extra window of the browser (incognito, not in the file) titled "A - B - Chromium" does not claim tab "A"
  local l1, l2 = bw(1, false, "A"), bw(2, false, "C")
  m = T.match({ snap(100, { l1, l2 }) }, { hw("0x1", 100, "A - B - Chromium"), hw("0x2", 100, "A - Chromium"), hw("0x3", 100, "C - Chromium") })
  assert(m[l1].address == "0x2" and m[l2].address == "0x3", "learned suffix narrows the candidates")
  -- equal titles broken by focus: the browser's focused window is the one the user was in last
  local e1, e2 = bw(1, false, "New Tab"), bw(2, true, "New Tab")
  m = T.match({ snap(100, { e1, e2 }) }, { hw("0x1", 100, "New Tab - Chromium", 7), hw("0x2", 100, "New Tab - Chromium", 2) })
  assert(m[e2].address == "0x2" and m[e1].address == "0x1", "equal titles: focus decides, the other one is what is left")
  -- unresolved: equal titles, no focus: candidates listed, no address
  local u1, u2 = bw(1, false, "Same"), bw(2, false, "Same")
  m = T.match({ snap(100, { u1, u2 }) }, { hw("0x1", 100, "Same - Chromium"), hw("0x2", 100, "Same - Chromium") })
  assert(m[u1].address == nil and #m[u1].candidates == 2 and m[u2].address == nil, "unresolved: a candidate list")
  -- no window with that pid: fall back to the browser's class
  local c = bw(1, false, "Alpha")
  m = T.match({ snap(555, { c }, { browser = "chrome" }) }, { hw("0x7", 999, "Alpha - Google Chrome", 1, "google-chrome"), hw("0x8", 998, "Alpha - x", 1, "kitty") })
  assert(m[c].address == "0x7", "class fallback when no pid matches")
  -- a popup window is not matched (it has no tab strip)
  local pop = bw(2, false, "Popup"); pop.type = "popup"
  m = T.match({ snap(100, { bw(1, false, "Main"), pop }) }, { hw("0x1", 100, "Main - Chromium") })
  assert(m[pop] == nil, "popups are left out")
  -- two profiles of one browser share the pid and its windows
  local pa, pb = bw(1, false, "Profile one"), bw(2, false, "Profile two")
  m = T.match({ snap(100, { pa }), snap(100, { pb }) }, { hw("0x1", 100, "Profile two - Chromium"), hw("0x2", 100, "Profile one - Chromium") })
  assert(m[pa].address == "0x2" and m[pb].address == "0x1", "two profiles, one pool")
  -- the host's parent pid is enough when the pid field names the host itself
  local h = snap(4242, { bw(1, false, "X") }); h.pids[100] = true
  m = T.match({ h }, { hw("0x1", 100, "X - Chromium") })
  assert(m[h.windows[1]].address == "0x1", "pid field or parent pid")
end

-- ---- rows and interleave ----
do
  local s = snap(100, { bw(1, true, "Alpha", { "Hidden one", "Bank" }) })
  s.windows[1].tabs[3].url = "https://www.bank.example.com/acct"
  local rows = T.rows({ s }, { hw("0x1", 100, "Alpha - Chromium") }, { "bank.example.com" })
  assert(#rows == 2 and rows[1].active and rows[2].title == "Hidden one" and rows[2].host == "example.net" and rows[2].hostpid == 900, "rows with host, ignored site dropped")
  local entries = { { address = "0x5", class = "kitty", title = "k" }, { address = "0x1", class = "chromium", title = "Alpha - Chromium", minimized = false } }
  local out = T.interleave(entries, rows)
  assert(#out == 4 and out[2].address == "0x1" and not out[2].tab and out[3].tab and out[3].tab.active and out[4].title == "Hidden one", "tab rows follow their window")
  assert(out[4].search_extra == "example.net /1" and out[4].tab.id == 11 and out[4].class == "chromium", "a tab entry carries what search and activation need")
  assert(#T.interleave({ entries[1] }, rows) == 1, "rows of a window outside the list are dropped")
  assert(#T.interleave(out, rows) == 4, "interleave twice does not duplicate rows")
  -- unresolved windows go under their first candidate
  local u = snap(100, { bw(1, false, "Same"), bw(2, false, "Same") })
  rows = T.rows({ u }, { hw("0x1", 100, "Same - Chromium"), hw("0x2", 100, "Same - Chromium") }, {})
  assert(#rows == 2 and rows[1].window == "0x1", "unresolved rows land on a candidate")
  -- no browser window at all: no rows
  assert(#T.rows({ snap(100, { bw(1, false, "A") }) }, { hw("0x1", 1, "kitty", 1, "kitty") }, {}) == 0, "no matching window, no rows")
end

-- ---- scale: 200 tabs in 10 windows parse and match quickly ----
do
  local ws, hs = {}, {}
  for w = 1, 10 do
    local tabs = {}
    for t = 1, 20 do tabs[t] = tab(w * 100 + t, t == 1, "Page " .. w .. " " .. t, "https://site" .. t .. ".example.com/p/" .. w) end
    ws[w] = window(w, w == 1, tabs)
    hs[w] = hw("0x" .. w, 100, "Page " .. w .. " 1 - Chromium", w)
  end
  local text = file(ws)
  local t0 = os.clock()
  local rows
  for _ = 1, 10 do
    local s = T.parse(text); s.pids = { [100] = true }; s.hostpid = 1
    rows = T.rows({ s }, hs, {})
  end
  local ms = (os.clock() - t0) / 10 * 1000
  assert(#rows == 200, "200 rows")
  assert(ms < 50, "200 tabs under 50 ms, took " .. ms)
  print(("tabs speed: %d KB file, parse and match %.2f ms"):format(#text // 1024, ms))
end

print("tabs ok")

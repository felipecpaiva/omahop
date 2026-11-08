// Node check of ConfigIO.js:  node tests/config_io.test.mjs
import { readFileSync, readdirSync } from "node:fs"
import { execFileSync } from "node:child_process"
import assert from "node:assert/strict"
const src = readFileSync(new URL("../ConfigIO.js", import.meta.url), "utf8").replace(".pragma library", "")
const IO = new Function(src + "; return { parse, get, set, unset, format, visible, indexById, isOn }")()

// parse
const sample = `# my notes
schema = 1
scope = "all"   # trailing comment
reveal_delay_ms = 0
[windows]
workspaces = "current"
ignore = "steam, #hash"
[keys]
repeat_ms = 25
garbage line
oops = notavalue
`
const p = IO.parse(sample)
assert.equal(p.top.scope, "all"); assert.equal(p.top.reveal_delay_ms, 0); assert.equal(p.sections.windows.ignore, "steam, #hash", "a # inside a string is not a comment")
assert.equal(p.sections.keys.repeat_ms, 25); assert.equal(p.bad.length, 2)

// set: change an existing value, keep the trailing comment and every other line
let t = IO.set(sample, "top", "scope", "floating")
assert.equal(t, sample.replace('scope = "all"   # trailing comment', 'scope = "floating"   # trailing comment'))
// set: add a key to an existing section (after its last key, before the next header)
t = IO.set(sample, "windows", "monitors", "all")
assert.ok(t.includes('ignore = "steam, #hash"\nmonitors = "all"\n[keys]'), "added at the end of the section")
// set: add a top-level key (before the first header)
t = IO.set(sample, "top", "border", "off")
assert.ok(t.indexOf('border = "off"') < t.indexOf("[windows]") && t.indexOf('border = "off"') > t.indexOf("reveal_delay_ms"), "top-level key stays above the sections")
// set: new section at the end, with a blank line before it
t = IO.set("scope = \"all\"\n", "windows", "workspaces", "all")
assert.equal(t, 'scope = "all"\n\n[windows]\nworkspaces = "all"\n')
// set: empty file
assert.equal(IO.set("", "top", "takeover", false), "takeover = false\n")
// set: types
assert.equal(IO.format(true), "true"); assert.equal(IO.format(12.6), "13"); assert.equal(IO.format('a "q"\nb'), '"a qb"')
// every other line survives a save, byte for byte (comments, unknown keys and sections, bad lines)
const rich = "# top comment\n\nschema = 1\nunknown_top = 7\n\n[windows]\n# explain\nworkspaces = \"floating\"\n\n[future_section]\nx = 1\n"
t = IO.set(rich, "windows", "workspaces", "all")
assert.equal(t, rich.replace('workspaces = "floating"', 'workspaces = "all"'))
// round trip through set of the same value changes nothing
for (const [s, k, v] of [["top", "schema", 1], ["windows", "workspaces", "floating"]]) assert.equal(IO.set(rich, s, k, v), rich)

// unset removes only that line
t = IO.unset(sample, "windows", "workspaces")
assert.equal(t, sample.replace('workspaces = "current"\n', ""))
assert.equal(IO.unset(sample, "windows", "nothing"), sample, "unset of a missing key changes nothing")
assert.equal(IO.get(sample, "windows", "workspaces"), "current"); assert.equal(IO.get(sample, "keys", "missing"), undefined)

// the same text read by Lua (the source of truth) and by ConfigIO gives the same values
const dump = JSON.stringify
const lua = `local C = dofile("lua/config.lua"); local t = C.parse([==[${sample}]==])
local out = {} for sec, bag in pairs(t) do for k, v in pairs(bag) do out[#out+1] = sec .. "." .. k .. "=" .. tostring(v) .. ":" .. type(v) end end
table.sort(out); print(table.concat(out, "\\n"))`
const fromLua = execFileSync("lua", ["-e", lua], { cwd: new URL("..", import.meta.url).pathname }).toString().trim().split("\n")
const fromJs = []
for (const [k, v] of Object.entries(p.top)) fromJs.push(`top.${k}=${v}:${typeof v}`)
for (const [sec, bag] of Object.entries(p.sections)) for (const [k, v] of Object.entries(bag)) fromJs.push(`${sec}.${k}=${v}:${typeof v}`)
fromJs.sort()
const norm = (a) => a.map((x) => x.replace(":number", ":number").replace(":boolean", ":boolean")).sort()
assert.deepEqual(norm(fromJs), norm(fromLua), "Lua and JavaScript parsers disagree")

// ---- profiles ----
const P = new Function(src + "; return { parse, set, unset, resolve, flatSettings, profileNames }")()
const root = new URL("..", import.meta.url).pathname
const settings = P.flatSettings(JSON.parse(readFileSync(root + "spec.json", "utf8")))

// dotted table names: parsed, and a write to the base never lands inside a profile
const withProfiles = 'style = "list"\n\n[profiles.work]   # note\nstyle = "cards"\n\n[profiles.work.windows]\nignore = "slack"\n'
const pp = P.parse(withProfiles)
assert.equal(pp.sections["profiles.work"].style, "cards"); assert.equal(pp.sections["profiles.work.windows"].ignore, "slack")
assert.deepEqual(P.profileNames(pp), ["work"])
assert.equal(P.parse("[profiles..x]\n[profiles.x.]\n").bad.length, 2, "empty segments are unreadable headers")
t = P.set(withProfiles, "top", "style", "cards")
assert.equal(t, withProfiles.replace('style = "list"', 'style = "cards"'), "the base line changes, the profile's does not")
t = P.set(withProfiles, "top", "profile", "work")
assert.ok(t.indexOf('profile = "work"') < t.indexOf("[profiles.work]"), "a new top-level key goes above the first table, never into a profile")
t = P.set(withProfiles, "windows", "monitors", "all")
assert.ok(t.endsWith('ignore = "slack"\n\n[windows]\nmonitors = "all"\n'), "a missing base section is added, not merged into a profile")
assert.equal(P.unset(withProfiles, "top", "style"), withProfiles.replace('style = "list"\n', ""), "unset of a base key leaves the profile")

// overridden values are reported for the settings window
const r = P.resolve(P.parse('profile = "work"\n' + withProfiles), settings)
assert.equal(r.profile, "work"); assert.equal(r.values["top.style"], "cards"); assert.deepEqual(r.overridden, { "top.style": "cards", "windows.ignore": "slack" })

// parity: Lua C.resolve (the switcher) and ConfigIO.resolve (the overlay and the settings window) give the same values and problems on every fixture
const luaResolve = (file) => {
  const code = `local C = dofile("lua/config.lua"); local f = assert(io.open(${JSON.stringify(file)})); local text = f:read("a"); f:close()
  local cfg, problems = C.resolve((C.parse(text)))
  for id in io.read("a"):gmatch("[^\\n]+") do
    local section, key = id:match("^(%w+)%.([%w_]+)$")
    local v = (section == "top" and cfg or cfg[section])[key]
    print("v " .. id .. "=" .. tostring(v) .. ":" .. type(v))
  end
  for _, p in ipairs(problems) do print("p " .. p) end`
  return execFileSync("lua", ["-e", code], { cwd: root, input: settings.map((s) => s.id).join("\n") }).toString().trim().split("\n")
}
const jsType = { boolean: "boolean", number: "number", string: "string" }
const dir = root + "tests/fixtures/profiles/"
const fixtures = readdirSync(dir).filter((f) => f.endsWith(".toml")).sort()
assert.ok(fixtures.length >= 4, "profile fixtures found")
for (const name of fixtures) {
  const res = P.resolve(P.parse(readFileSync(dir + name, "utf8")), settings)
  const fromJs = settings.map((s) => `v ${s.id}=${res.values[s.id]}:${jsType[typeof res.values[s.id]]}`).concat(res.problems.map((p) => "p " + p))
  assert.deepEqual(fromJs, luaResolve(dir + name), `Lua and JavaScript disagree on ${name}`)
}
const work = P.resolve(P.parse(readFileSync(dir + "work.toml", "utf8")), settings)
assert.equal(work.values["top.style"], "cards"); assert.equal(work.values["top.reveal_delay_ms"], 0, "bad profile value keeps the base")
assert.equal(work.values["top.takeover"], true); assert.equal(work.values["top.browser_tabs"], false, "base-only settings are never taken from a profile")
console.log(`config io ok (profile parity on ${fixtures.length} fixtures)`)

// ---- settings window layout: dependents hide with their parent, advanced rows fold ----
{
  const V = IO
  const by = V.indexById(settings)
  const val = (vals) => (s) => (s.id in vals ? vals[s.id] : s.default)
  const get = (key) => by["top." + key]
  assert.equal(V.visible(get("browser_tabs_ignore"), by, val({}), false), false, "off parent hides the child")
  assert.equal(V.visible(get("browser_tabs_ignore"), by, val({ "top.browser_tabs": true }), false), true)
  assert.equal(V.visible(get("browser_tab_previews_draw"), by, val({ "top.browser_tabs": true }), false), false, "grandchild needs the whole chain")
  assert.equal(V.visible(get("browser_tab_previews_draw"), by, val({ "top.browser_tabs": true, "top.browser_tab_previews": true }), false), true)
  assert.equal(V.visible(get("peek_position"), by, val({ "top.peek": "edge" }), false), true, "a choice other than off counts as on")
  assert.equal(V.visible(get("peek_position"), by, val({}), false), false)
  assert.equal(V.visible(get("border"), by, val({}), false), false, "advanced is folded")
  assert.equal(V.visible(get("border"), by, val({}), true), true)
  assert.equal(V.visible(by["top.schema"] || { hidden: true }, by, val({}), true), false, "hidden never shows")
  for (const s of settings) assert.ok(s.subgroup && typeof s.depth === "number", "spec.json lacks layout fields for " + s.id)
}

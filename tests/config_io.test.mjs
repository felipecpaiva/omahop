// Node check of ConfigIO.js:  node tests/config_io.test.mjs
import { readFileSync } from "node:fs"
import { execFileSync } from "node:child_process"
import assert from "node:assert/strict"
const src = readFileSync(new URL("../ConfigIO.js", import.meta.url), "utf8").replace(".pragma library", "")
const IO = new Function(src + "; return { parse, get, set, unset, format }")()

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
console.log("config io ok")

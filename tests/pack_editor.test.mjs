// Node check of PackEditor.js (the icon pack editor's pure logic):  node tests/pack_editor.test.mjs
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"
const load = (file, names) => new Function(readFileSync(new URL("../" + file, import.meta.url), "utf8").replace(".pragma library", "") + "; return {" + names + "}")()
const P = load("PackEditor.js", "iconStem, appRows, parseImportSummary, command, initial, begin, finish, cancel, refuse")
const R = load("IconResolve.js", "parseIndex, packPick")

// iconStem: the stem tools/pack-edit.sh makes (tests/pack_edit.test.sh compares the two on the same ids)
assert.equal(P.iconStem("firefox"), "firefox")
assert.equal(P.iconStem("com.Mitchellh.Ghostty"), "com.mitchellh.ghostty")
assert.equal(P.iconStem("Steam App 440"), "steam-app-440")
assert.equal(P.iconStem("a \t b"), "a-b", "a run of whitespace is one dash")
for (const bad of ["", "../x", "a/b", "-x", ".hidden", "a:b", "café", "x y", "$(touch x)", "a".repeat(201), null, undefined])
  assert.equal(P.iconStem(bad), "", "refused: " + JSON.stringify(bad))
assert.equal(P.iconStem("a".repeat(200)), "a".repeat(200), "200 characters is the limit")

// appRows: open windows first, then installed apps by name, then pack icons no app uses; one row per stem; the pack file in use
const pack = R.parseIndex("/p/icons/ghostty.svg\n/p/icons/Firefox.png\n/p/icons/orphan.svg\n")
const pick = (key, icon) => R.packPick(pack, key, icon)
const windows = [{ appId: "com.mitchellh.ghostty", name: "Ghostty", icon: "com.mitchellh.ghostty" }, { appId: "firefox", name: "Firefox", icon: "firefox" }, { appId: "firefox" }]
const entries = [
  { id: "zed", name: "Zed", icon: "zed" },
  { id: "org.mozilla.firefox", name: "Firefox", icon: "firefox", startupClass: "firefox" },
  { id: "hidden", name: "Hidden", noDisplay: true },
  { id: "bad", name: "Bad", startupClass: "a/b" },
  { id: "abc", name: "Abc" },
]
const rows = P.appRows(windows, entries, ["/p/icons/ghostty.svg", "/p/icons/Firefox.png", "/p/icons/orphan.svg"], pick, "")
assert.deepEqual(rows.map((r) => r.key), ["com.mitchellh.ghostty", "firefox", "abc", "zed", "orphan"])
assert.equal(rows[0].running, true)
assert.equal(rows[0].packFile, "ghostty.svg", "a reverse-DNS id uses its last part's pack file")
assert.equal(rows[1].packPath, "/p/icons/Firefox.png", "case-blind like the switcher")
assert.equal(rows[2].packFile, "", "no pack icon")
assert.equal(rows[4].packFile, "orphan.svg", "a pack file no app uses can still be removed")
assert.equal(rows[2].running, false)
assert.deepEqual(P.appRows(windows, entries, [], pick, "  ZE ").map((r) => r.key), ["zed"], "filter on name and id, case-blind")
assert.deepEqual(P.appRows(windows, entries, [], pick, "mitchellh").map((r) => r.key), ["com.mitchellh.ghostty"])
assert.deepEqual(P.appRows(null, undefined, null, () => "", ""), [], "nothing in, nothing out")
const many = Array.from({ length: 2000 }, (_, i) => ({ id: "app" + i, name: "App " + i }))
const t0 = Date.now()
assert.equal(P.appRows([], many, [], pick, "").length, 2000)
assert.ok(Date.now() - t0 < 500, "2000 apps in well under a second")

// parseImportSummary: the --dry-run output of pack-import.sh
const summary = P.parseImportSummary("Pack:     My Pack\nAuthor:   Me\nLicense:  CC0-1.0\nIcons:    3\nInstall:  /h/.config/omahop/packs/my-pack (replaces the installed one)\nInstalled already: yes\nFiles:\n  pack.toml\n")
assert.deepEqual(summary, { name: "My Pack", author: "Me", license: "CC0-1.0", icons: 3, target: "/h/.config/omahop/packs/my-pack", installed: true })
assert.equal(P.parseImportSummary("").installed, false)

// command: argument arrays, never a shell line; misreadable values refused before anything runs
const tools = { edit: "/t/pack-edit.sh", exporter: "/t/pack-export.sh", importer: "/t/pack-import.sh" }
assert.deepEqual(P.command(tools, "add", { folder: "my-pack", appId: "Foo Bar", path: "/x/$(rm -rf ~).png" }).argv,
  ["bash", "/t/pack-edit.sh", "add", "my-pack", "Foo Bar", "/x/$(rm -rf ~).png"], "shell text stays one inert argument")
assert.deepEqual(P.command(tools, "export", { folder: "p", replace: true }).argv, ["bash", "/t/pack-export.sh", "p", "--force"])
assert.deepEqual(P.command(tools, "export", { folder: "p" }).argv, ["bash", "/t/pack-export.sh", "p"])
assert.deepEqual(P.command(tools, "importCheck", { path: "/d/p.zip" }).argv, ["bash", "/t/pack-import.sh", "/d/p.zip", "--dry-run"])
assert.deepEqual(P.command(tools, "importInstall", { path: "/d/p.zip", replace: true }).argv, ["bash", "/t/pack-import.sh", "/d/p.zip", "--yes", "--replace"])
assert.deepEqual(P.command(tools, "pickImage", {}).argv, ["bash", "/t/pack-edit.sh", "pick", "image"])
assert.deepEqual(P.command(tools, "pickZip", {}).argv, ["bash", "/t/pack-edit.sh", "pick", "zip"])
assert.deepEqual(P.command(tools, "init", { name: "N", author: "A", license: "L", description: "" }).argv, ["bash", "/t/pack-edit.sh", "init", "N", "A", "L", ""])
for (const [op, args] of [
  ["export", { folder: "--force" }], ["export", { folder: "" }], ["add", { folder: "p", appId: "x", path: "-rf.png" }],
  ["add", { folder: "p", appId: "x", path: "rel/x.png" }], ["importCheck", { path: "--yes" }], ["importInstall", { path: "x.zip" }],
  ["meta", { folder: "p", name: "a\nb", author: "a", license: "l", description: "" }], ["init", { name: "a\u0000", author: "a", license: "l", description: "" }],
  ["remove", { folder: "p", file: "" }], ["add", { folder: "p", appId: 7, path: "/x.png" }], ["nope", {}],
]) assert.ok(P.command(tools, op, args).error, "refused: " + op + " " + JSON.stringify(args))

// state machine
let s = P.initial()
s = P.begin(s, "add")
assert.equal(s.phase, "busy")
assert.equal(P.begin(s, "remove"), s, "one action at a time")
const added = P.finish(s, "add", 0, "firefox.svg\n", "", { folder: "p" })
assert.equal(added.phase, "idle")
assert.equal(added.message, "Added icons/firefox.svg.")
assert.deepEqual(added.effect, { refresh: true, select: "p", changed: true })
const refused = P.finish(s, "add", 1, "", "omahop pack edit: not added, the image must be a PNG or a plain SVG:\nskipped icons/x.svg: not a plain SVG\n", {})
assert.equal(refused.error, true)
assert.equal(refused.message, "not added, the image must be a PNG or a plain SVG: skipped icons/x.svg: not a plain SVG")
assert.equal(P.finish(s, "add", 2, "", "", {}).message, "Failed (exit 2)")
// the picker: cancel is quiet, a failure offers the typed path, a pick runs the next command
assert.deepEqual([P.finish(s, "pickImage", 1, "", "", {}).message, P.finish(s, "pickImage", 1, "", "", {}).error], ["", false])
assert.equal(P.finish(s, "pickImage", 2, "", "boom", {}).manualPath, true)
assert.equal(P.finish(s, "pickImage", 0, "relative.png\n", "", {}).manualPath, true, "only a full path is taken")
assert.deepEqual(P.finish(s, "pickImage", 0, "/a b/x.png\n/second.png\n", "", { folder: "p", appId: "kitty" }).effect,
  { run: "add", args: { folder: "p", appId: "kitty", path: "/a b/x.png" } }, "first line only")
assert.deepEqual(P.finish(s, "pickZip", 0, "/d/p.zip\n", "", {}).effect.run, "importCheck")
// import: the dry run asks, replace only when a pack of that name is installed
const asked = P.finish(s, "importCheck", 0, "Pack:     X\nInstalled already: no\n", "", { path: "/d/p.zip" })
assert.equal(asked.phase, "confirm")
assert.deepEqual([asked.confirm.kind, asked.confirm.replace, asked.confirm.path], ["import", false, "/d/p.zip"])
assert.equal(P.finish(s, "importCheck", 0, "Installed already: yes\n", "", { path: "/d/p.zip" }).confirm.replace, true)
assert.equal(P.finish(s, "importCheck", 1, "", "omahop pack import: refused, the zip holds ../x: a path that leads out of the pack", {}).message,
  "refused, the zip holds ../x: a path that leads out of the pack")
assert.equal(P.finish(s, "importInstall", 0, "Pack: X\nInstalled. Set Icon pack to x in the settings to use it.\n", "", {}).effect.changed, true)
// export: an existing zip asks before replacing
const ex = P.finish(s, "export", 1, "", "omahop pack export: /h/p.omahop-pack.zip exists, add --force to replace it\n", {})
assert.deepEqual([ex.phase, ex.confirm.kind], ["confirm", "export"])
assert.equal(P.finish(s, "export", 0, "Exported p (2 icons) to /h/p.omahop-pack.zip\n", "", {}).message, "Exported p (2 icons) to /h/p.omahop-pack.zip")
assert.deepEqual(P.finish(s, "init", 0, "my-pack\n", "", {}).effect, { refresh: true, select: "my-pack", changed: false })
assert.equal(P.cancel(asked).phase, "idle")
assert.equal(P.cancel(asked).confirm, null)
assert.deepEqual([P.refuse(P.initial(), "no pack chosen").message, P.refuse(P.initial(), "x").error], ["no pack chosen", true])
assert.equal(P.refuse(s, "x"), s, "a refusal never interrupts a running action")

console.log("ok   pack editor: stems, rows, import summary, argument arrays, state machine")

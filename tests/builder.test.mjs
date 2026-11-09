// Node check of Builder.js (the icon builder's pure logic):  node tests/builder.test.mjs
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"
const B = new Function(readFileSync(new URL("../Builder.js", import.meta.url), "utf8").replace(".pragma library", "") +
  "; return { parseDraft, parseFind, suggestQuery, nowNames, nowPick, decorate, draftUrl, previewRows, gridMove, action, command, initial, begin, finish, refuse }")()
const E = new Function(readFileSync(new URL("../PackEditor.js", import.meta.url), "utf8").replace(".pragma library", "") + "; return { appRows, iconStem }")()

// reading the scripts' output
assert.deepEqual(B.parseDraft("kitty\tkitty.svg\t/c/draft/icons/kitty.svg\nbad\tbad.png\trelative\n\nlone\n"), [{ stem: "kitty", file: "kitty.svg", path: "/c/draft/icons/kitty.svg" }])
assert.deepEqual(B.parseFind("Papirus\tfirefox\t/u/Papirus/firefox.svg\nYaru\tfire\tnot-absolute\nYaru\tfire\t/u/Yaru/fire.png\n"),
  [{ theme: "Papirus", name: "firefox", path: "/u/Papirus/firefox.svg" }, { theme: "Yaru", name: "fire", path: "/u/Yaru/fire.png" }])
assert.deepEqual(B.parseFind(""), [])

// the first search text
assert.equal(B.suggestQuery("firefox", "firefox-esr"), "firefox-esr", "the entry's icon name first")
assert.equal(B.suggestQuery("org.gnome.Nautilus", ""), "nautilus", "last part of a dotted id")
assert.equal(B.suggestQuery("Steam App 1", "/abs/icon.png"), "steam-app-1", "a path is not a name")
assert.equal(B.suggestQuery("a$(x);b", ""), "axb", "nothing a shell would read")

// the "Now" icon
assert.deepEqual(B.nowNames(["firefox", "/abs/x.png", "a b", "Fire.Fox"]), ["firefox", "Fire.Fox"])
assert.equal(B.nowPick(["a", "b"], { b: "/t/b.svg" }), "/t/b.svg")
assert.equal(B.nowPick(["a"], {}), "")

// rows: the editor's app rows fed the draft's files, plus the changed flag
const pick = (key) => (key === "kitty" ? "/c/draft/icons/kitty.svg" : "")
const rows = B.decorate(E.appRows([{ appId: "kitty", name: "Kitty", icon: "kitty" }], [{ id: "firefox", name: "Firefox", icon: "firefox" }, { id: "zed", name: "Zed", icon: "zed" }], ["/c/draft/icons/kitty.svg", "/c/draft/icons/orphan.png"], pick, ""))
assert.deepEqual(rows.map((r) => [r.key, r.running, r.changed]), [["kitty", true, true], ["firefox", false, false], ["zed", false, false], ["orphan", false, true]],
  "open first, then installed by name, then draft icons no app uses")
const filtered = B.decorate(E.appRows([], [{ id: "firefox", name: "Firefox", icon: "" }, { id: "zed", name: "Zed", icon: "" }], [], () => "", "  FIRE "))
assert.deepEqual(filtered.map((r) => r.key), ["firefox"], "the filter works on name and id, any case")
assert.equal(B.draftUrl(rows[0], 3), "file:///c/draft/icons/kitty.svg?v=3")
assert.equal(B.draftUrl(rows[1], 3), "", "an unchanged app has no draft url")
assert.deepEqual(B.previewRows(rows, 3, 3).map((r) => r.key), ["orphan", "kitty", "firefox"], "wraps")
assert.deepEqual(B.previewRows([], 0, 3), [])
assert.equal(B.previewRows(rows, 0, 9).length, rows.length)

// grid movement (4 columns, 10 cells)
assert.equal(B.gridMove(0, "Right", 10, 4), 1)
assert.equal(B.gridMove(9, "Right", 10, 4), 9)
assert.equal(B.gridMove(1, "Up", 10, 4), 1, "top row stays")
assert.equal(B.gridMove(5, "Up", 10, 4), 1)
assert.equal(B.gridMove(7, "Down", 10, 4), 9, "a short last row clamps")
assert.equal(B.gridMove(0, "Left", 10, 4), 0)
assert.equal(B.gridMove(0, "Home", 10, 4), -1, "not a grid key")
assert.equal(B.gridMove(0, "Down", 0, 4), -1, "empty grid")

// keys
const S = (zone, baseOpen = false) => ({ zone, baseOpen })
assert.deepEqual(B.action("Escape", false, S("apps")), { act: "back" })
assert.deepEqual(B.action("Escape", false, S("icons", true)), { act: "closeBase" })
assert.deepEqual(B.action("z", true, S("apps")), { act: "undo" })
assert.deepEqual(B.action("z", false, S("apps")), { act: "none" }, "typing z is typing")
assert.deepEqual(B.action("r", true, S("icons")), { act: "resetApp" })
assert.deepEqual(B.action("Tab", false, S("apps")), { act: "zone" })
assert.deepEqual(B.action("Down", false, S("apps")), { act: "appMove", key: "Down" })
assert.deepEqual(B.action("Down", false, S("icons")), { act: "gridMove", key: "Down" })
assert.deepEqual(B.action("Down", false, S("icons", true)), { act: "baseMove", key: "Down" })
assert.deepEqual(B.action("Return", false, S("apps")), { act: "zone" })
assert.deepEqual(B.action("Return", false, S("icons")), { act: "apply" })
assert.deepEqual(B.action("Return", false, S("apps", true)), { act: "baseChoose" })
assert.deepEqual(B.action("Left", false, S("apps")), { act: "none" }, "left and right edit the text in the app filter")

// commands are argument arrays; a hostile value is refused before anything runs
const tools = { draft: "/t/draft-edit.sh", find: "/t/icon-find.sh", preview: "/t/icon-preview.sh", pick: "/t/pack-edit.sh" }
assert.deepEqual(B.command(tools, "add", { appId: "kitty", path: "/x/a.png" }).argv, ["bash", "/t/draft-edit.sh", "add", "kitty", "/x/a.png"])
assert.deepEqual(B.command(tools, "reset", { appId: "kitty" }).argv, ["bash", "/t/draft-edit.sh", "reset-app", "kitty"])
assert.deepEqual(B.command(tools, "pick", {}).argv, ["bash", "/t/pack-edit.sh", "pick", "image"])
assert.deepEqual(B.command(tools, "find", { query: "fox" }).argv, ["bash", "/t/icon-find.sh", "fox", "120"])
assert.deepEqual(B.command(tools, "now", { theme: "", names: ["a", "b c"] }).argv, ["bash", "/t/icon-preview.sh", "-", "a"], "no theme is a dash; a bad name is dropped")
for (const bad of [{ appId: "", path: "/x" }, { appId: "k", path: "rel.png" }, { appId: "k\nx", path: "/x" }, { appId: "k", path: "/x\ny" }, { appId: "k\0", path: "/x" }])
  assert.ok(B.command(tools, "add", bad).error, JSON.stringify(bad))
assert.ok(B.command(tools, "find", { query: "a" }).error, "one letter is too short")
assert.ok(B.command(tools, "nope", {}).error)

// the state machine
let st = B.initial()
st = B.begin(st, "add")
assert.equal(st.phase, "busy")
assert.equal(B.begin(st, "undo"), st, "one action at a time")
assert.equal(B.refuse(st, "x"), st, "a refusal does not interrupt a running action")
let done = B.finish(st, "add", 0, "kitty.svg\n", "", { appId: "kitty" })
assert.deepEqual([done.phase, done.error, done.effect], ["idle", false, { refresh: true }])
done = B.finish(B.begin(B.initial(), "add"), "add", 1, "", "omahop draft edit: not added, the image must be a PNG or a plain SVG:\nline 2\n", {})
assert.equal(done.error, true)
assert.match(done.message, /^not added, the image must be a PNG or a plain SVG: line 2$/, "the script's prefix is dropped")
assert.equal(B.finish(B.begin(B.initial(), "undo"), "undo", 1, "", "", {}).message, "Failed (exit 1)")
let pickDone = B.finish(B.begin(B.initial(), "pick"), "pick", 0, "/home/x/a.png\n", "", { appId: "kitty" })
assert.deepEqual(pickDone.effect, { run: "add", args: { appId: "kitty", path: "/home/x/a.png" } }, "a picked file goes to add for the app chosen at the time")
pickDone = B.finish(B.begin(B.initial(), "pick"), "pick", 1, "", "", {})
assert.deepEqual([pickDone.error, pickDone.message, pickDone.manualPath], [false, "", false], "nothing picked is not an error")
pickDone = B.finish(B.begin(B.initial(), "pick"), "pick", 2, "", "no chooser", {})
assert.deepEqual([pickDone.error, pickDone.manualPath], [true, true], "a chooser that did not open offers a typed path")
assert.equal(B.finish(B.begin(pickDone, "add"), "add", 0, "a.png", "", {}).manualPath, false, "a successful add clears it")
console.log("ok   builder logic: parsers, rows, preview, grid, keys, commands, state machine")

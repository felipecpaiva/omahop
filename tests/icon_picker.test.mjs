// Node check of IconPicker.js (the icon picker's pure logic):  node tests/icon_picker.test.mjs
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"
const P = new Function(readFileSync(new URL("../IconPicker.js", import.meta.url), "utf8").replace(".pragma library", "") + "; return { KINDS, kindFor, parseThemes, parsePreview, choices, filter, indexOfValue, move }")()

assert.equal(P.kindFor("icon_pack").id, "pack")
assert.equal(P.kindFor("whatever").id, "theme", "an unknown setting opens the theme page")

const themes = P.parseThemes("Papirus\tPapirus\nYaru-blue\tYaru Blue\n\nbroken\n")
assert.deepEqual(themes, [{ value: "Papirus", title: "Papirus" }, { value: "Yaru-blue", title: "Yaru Blue" }, { value: "broken", title: "broken" }])

const list = P.choices(P.KINDS[0], themes)
assert.equal(list[0].value, "", "Automatic is first")
assert.equal(list[0].title, "Automatic")
assert.equal(list[2].help, "Yaru-blue", "the folder name shows when it differs from the title")
assert.equal(P.choices(P.KINDS[1], []).length, 1, "no packs still leaves No pack")

assert.deepEqual(P.filter(list, "  YARU ").map((c) => c.value), ["Yaru-blue"])
assert.deepEqual(P.filter(list, "blue").map((c) => c.value), ["Yaru-blue"], "folder name matches too")
assert.equal(P.filter(list, "").length, 4)
assert.equal(P.filter(list, "zzz").length, 0)

assert.equal(P.indexOfValue(list, "Papirus"), 1)
assert.equal(P.indexOfValue(list, "gone"), 0, "an unknown current value highlights the first card")

assert.equal(P.move(0, "Up", 4), 0)
assert.equal(P.move(3, "Down", 4), 3)
assert.equal(P.move(1, "Down", 4), 2)
assert.equal(P.move(2, "Home", 4), 0)
assert.equal(P.move(0, "End", 4), 3)
assert.equal(P.move(0, "PageDown", 10), 4)
assert.equal(P.move(0, "x", 4), -1, "not a movement key")
assert.equal(P.move(0, "Down", 0), -1, "empty list")

const map = P.parsePreview("firefox\t/a/firefox.svg\nbad line\nconstructor\t/c.png\n")
assert.equal(map.firefox, "/a/firefox.svg")
assert.equal(map.constructor, "/c.png")
assert.equal(map["bad line"], undefined)
assert.equal(Object.keys(P.parsePreview("")).length, 0)
console.log("ok   icon picker: choices, filter, movement, script output")

// Node check of State.js:  node tests/state.test.mjs
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"
const src = readFileSync(new URL("../State.js", import.meta.url), "utf8").replace(".pragma library", "")
const State = new Function(src + "; return { parse, visibleRows, borderWidth, normalizeAddress, visibleCards }")()

const text = "version=1\nopen=1\nrevealed=1\nselected=2\nstyle=list\nthumbnails=snapshot\nw\t0xa\tkitty\t0\tfirst title\nw\t0xb\tgoogle-chrome\t1\tsecond\ttitle with a tab\n"
const s = State.parse(text)
assert.equal(s.open, true); assert.equal(s.revealed, true); assert.equal(s.selected, 2); assert.equal(s.style, "list")
assert.equal(s.entries.length, 2)
assert.deepEqual(s.entries[0], { address: "0xa", appId: "kitty", minimized: false, title: "first title" })
assert.equal(s.entries[1].minimized, true); assert.equal(s.entries[1].title, "second\ttitle with a tab")

// closed or garbage input never throws and shows nothing
assert.equal(State.parse("").open, false)
assert.equal(State.parse(null).open, false)
assert.equal(State.parse("open=1\nrevealed=1\nselected=5\nw\t0xa\tk\t0\tt\n").open, false, "selection outside the list: not shown")
assert.equal(State.parse("open=1\nselected=0\n").open, false)
assert.equal(State.parse("junk line\n=\nopen\n").entries.length, 0)
assert.equal(State.parse("open=0\nrevealed=0\nselected=1\nw\t0xa\tk\t0\tt\n").open, false)

// visible rows: bounded by the cap and by the screen
assert.equal(State.visibleRows(1080, 48, 9), 9)
assert.equal(State.visibleRows(600, 48, 9), 8)
assert.equal(State.visibleRows(100, 48, 9), 1)
// border: auto follows Hyprland (0 = no outline), on/off override it
assert.equal(State.borderWidth("auto", 0, 2), 0, "auto with window borders off: none")
assert.equal(State.borderWidth("auto", 3, 2), 3, "auto follows a 3 px border")
assert.equal(State.borderWidth("auto", -1, 2), 2, "auto while Hyprland's value is unknown: the fallback")
assert.equal(State.borderWidth("on", 0, 2), 2, "on forces an outline even when Hyprland has none")
assert.equal(State.borderWidth("on", 4, 2), 4)
assert.equal(State.borderWidth("off", 4, 2), 0, "off removes it")
assert.equal(State.parse("border=off\nopen=0\n").border, "off"); assert.equal(State.parse("").border, "auto")
assert.equal(State.normalizeAddress("0x55CB5923D480"), "55cb5923d480"); assert.equal(State.normalizeAddress("55cb5923d480"), "55cb5923d480"); assert.equal(State.normalizeAddress(null), "")
assert.equal(State.visibleCards(1280, 240, 12, 6), 4, "four 240 px cards fit in 90% of 1280 (five need 1248 of 1152 px)")
assert.equal(State.visibleCards(3000, 240, 12, 6), 6, "capped")
assert.equal(State.visibleCards(200, 240, 12, 6), 1, "at least one")
// search: the query is read; a search with no match stays open with an empty list; a bad selection without a query still hides everything
assert.equal(State.parse("open=1\nrevealed=1\nselected=1\nquery=chr\nw\t0xa\tk\t0\tt\n").query, "chr")
const none = State.parse("open=1\nrevealed=1\nselected=0\nquery=zzz\n")
assert.equal(none.open, true); assert.equal(none.entries.length, 0)
assert.equal(State.parse("open=1\nrevealed=1\nselected=0\n").open, false, "no query and nothing selected: hidden")
assert.equal(State.parse("").query, "")
console.log("state ok")

// Node check of State.js:  node tests/state.test.mjs
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"
const src = readFileSync(new URL("../State.js", import.meta.url), "utf8").replace(".pragma library", "")
const State = new Function(src + "; return { parse, visibleRows }")()

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
console.log("state ok")

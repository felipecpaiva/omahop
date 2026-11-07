// Node check of Linger.js:  node tests/linger.test.mjs
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"
const src = readFileSync(new URL("../Linger.js", import.meta.url), "utf8").replace(".pragma library", "")
const L = new Function(src + "; return { reduce, nextSeq, adopt, luaString, code }")()

// typing: any character, capitals and accents included; control characters never enter the text
assert.deepEqual(L.reduce("", "", "B"), { text: "B", key: "" })
assert.deepEqual(L.reduce("a", "", "ç"), { text: "aç", key: "" })
assert.deepEqual(L.reduce("a", "", "\t"), { text: "a", key: "" }, "Tab's text is a control character")
assert.deepEqual(L.reduce("a", "", ""), { text: "a", key: "" }, "a key with no text (Shift) changes nothing")
// backspace removes one character, also one outside the BMP
assert.equal(L.reduce("ab", "backspace", "\b").text, "a")
assert.equal(L.reduce("a\u{1F600}", "backspace", "").text, "a")
assert.equal(L.reduce("", "backspace", "").text, "")
// Escape clears first, then is sent; navigation and Return are sent with the text unchanged
assert.deepEqual(L.reduce("br", "escape", ""), { text: "", key: "" })
assert.deepEqual(L.reduce("", "escape", ""), { text: "", key: "escape" })
assert.deepEqual(L.reduce("br", "return", "\r"), { text: "br", key: "return" })
for (const k of ["up", "down", "left", "right"]) assert.equal(L.reduce("x", k, "").key, k)

// sequence: past our own counter and past Lua's (a restarted shell starts at 0 while Lua is at 40)
assert.equal(L.nextSeq(0, 0), 1)
assert.equal(L.nextSeq(5, 3), 6)
assert.equal(L.nextSeq(0, 40), 41)

// adopt Lua's query only when nothing of ours is pending or in flight
assert.equal(L.adopt(false, 0, 0), true, "nothing sent yet: Lua's query (typed with Alt held) is the truth")
assert.equal(L.adopt(true, 0, 0), false, "a coalesced edit waits: ours")
assert.equal(L.adopt(false, 6, 5), false, "sent 6, Lua applied 5: ours")
assert.equal(L.adopt(false, 6, 6), true, "Lua caught up: adopt (Escape typed with Alt held clears there)")

// the Lua literal: quotes, backslashes, newlines cannot break out of the string
assert.equal(L.luaString("it's"), "'it\\'s'")
assert.equal(L.luaString("a\\b"), "'a\\\\b'")
assert.equal(L.luaString("x')\nos.exit() --"), "'x\\')os.exit() --'")
assert.equal(L.luaString("ação"), "'ação'")
assert.equal(L.luaString("\\'"), "'\\\\\\''", "a backslash before a quote: both escaped, the quote stays inside")

// the eval code: the query alone, or the query then the key in one process
assert.deepEqual(L.code(4, "br", ""), { code: "_G.omahop.set_query(4, 'br')", last: 4 })
assert.deepEqual(L.code(4, "br", "return"), { code: "_G.omahop.set_query(4, 'br'); _G.omahop.key(5, 'return')", last: 5 })

// a burst: ordered seqs, the key always after the text it applies to
let counter = 0, text = "", sent = []
for (const ch of "bra") { text = L.reduce(text, "", ch).text }
let c = L.code(L.nextSeq(counter, 0), text, ""); counter = c.last; sent.push(c.code)
const r = L.reduce(text, "return", "\r")
c = L.code(L.nextSeq(counter, 0), r.text, r.key); counter = c.last; sent.push(c.code)
assert.deepEqual(sent, ["_G.omahop.set_query(1, 'bra')", "_G.omahop.set_query(2, 'bra'); _G.omahop.key(3, 'return')"])
console.log("linger ok")

// Node check of AudioMarker.js:  node tests/audio_marker.test.mjs
// Fixtures only: no real audio stream is started and no mixer state is read or changed.
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"
const src = readFileSync(new URL("../AudioMarker.js", import.meta.url), "utf8").replace(".pragma library", "")
const A = new Function(src + "; return { parseSample, parseStreams, parseParents, playingAddresses, SEPARATOR }")()
const pactl = readFileSync(new URL("./fixtures/pactl-sink-inputs.json", import.meta.url), "utf8")
const norm = (a) => String(a).toLowerCase().replace(/^0x/, "")

// Process tree of the fixture. 5000 is Chromium (3 windows), 5012 its audio utility process, 5010 a zygote between them on purpose.
// 6000 is mpv (own window). 7000 Firefox, 8000 Slack. 9000 kitty, 9050 its shell, 9100 paplay started from that shell (no window).
// 9900 has no window and its tree ends at pid 1. 2 is a host kernel thread (the sandbox reports its own pid 2).
const ps = [
  "1 0", "2 0", "900 1", "5000 900", "5010 5000", "5012 5010", "6000 900", "7000 900", "8000 900",
  "9000 900", "9050 9000", "9100 9050", "9900 1",
].map((l) => "  " + l.replace(" ", "   ")).join("\n")
const sample = A.parseSample(pactl + "\n" + A.SEPARATOR + "\n" + ps + "\n")

const windows = [
  { address: "0xC1", pid: 5000, appId: "chromium" },
  { address: "0xc2", pid: 5000, appId: "chromium" },
  { address: "0xc3", pid: 5000, appId: "chromium" },
  { address: "0xa1", pid: 6000, appId: "mpv" },
  { address: "0xf1", pid: 7000, appId: "org.mozilla.firefox" },
  { address: "0x51", pid: 8000, appId: "Slack" },
  { address: "0x5b", pid: 4242, appId: "us.zoom.Zoom" },
  { address: "0xb1", pid: 9000, appId: "kitty" },
  { address: "0xd1", pid: 0, appId: "" },
]

// ---- parsing keeps only what the matcher needs
assert.equal(sample.streams.length, 8)
assert.deepEqual(sample.streams[0], { pid: 5012, binary: "chromium", app: "chromium", playing: true })
assert.equal(JSON.stringify(sample).includes("private song"), false, "media titles are dropped at parse time")
assert.equal(sample.parents[5012], 5010)
assert.equal(sample.parents[9100], 9050)

// ---- the match
const marked = A.playingAddresses(sample, windows, norm)
assert.deepEqual(Object.keys(marked).sort(), ["5b", "a1", "b1", "c1", "c2", "c3"])
// browser: the audio process is two steps below the window's process, and all three browser windows are marked (known limit)
assert.ok(marked.c1 && marked.c2 && marked.c3)
// two streams from one pid: one window, marked once
assert.equal(marked.a1, true)
// corked (paused) and muted streams: no marker
assert.equal(marked.f1, undefined, "corked stream: no marker")
assert.equal(marked["51"], undefined, "muted stream: no marker")
// sandbox: pid 2 owns no window (and its tree stops at once), so the binary name finds the last dot part of the class
assert.equal(marked["5b"], true)
// a player with no window, started from a terminal: the terminal is marked
assert.equal(marked.b1, true)
// a stream whose tree owns no window and whose names match no class: nothing
assert.equal(marked.d1, undefined)

// ---- nearest owner wins: a player with its own window does not also mark the terminal it was started from
{
  const s = A.parseSample(JSON.stringify([{ corked: false, mute: false, properties: { "application.process.id": "300" } }]) + "\n--\n300 200\n200 100\n100 1\n")
  const m = A.playingAddresses(s, [{ address: "0x3", pid: 300, appId: "mpv" }, { address: "0x1", pid: 100, appId: "kitty" }], norm)
  assert.deepEqual(Object.keys(m), ["3"])
}

// ---- a parent loop or a very deep tree ends
{
  const s = A.parseSample(JSON.stringify([{ corked: false, mute: false, properties: { "application.process.id": "10" } }]) + "\n--\n10 11\n11 10\n")
  assert.deepEqual(A.playingAddresses(s, [{ address: "0x9", pid: 99, appId: "x" }], norm), {})
  let tree = ""
  for (let p = 1000; p > 900; p--) tree += p + " " + (p - 1) + "\n"
  const deep = A.parseSample(JSON.stringify([{ corked: false, mute: false, properties: { "application.process.id": "1000" } }]) + "\n--\n" + tree)
  assert.deepEqual(A.playingAddresses(deep, [{ address: "0x9", pid: 901, appId: "x" }], norm), {}, "more than 16 steps up: not this window")
}

// ---- strict playing flag: missing or odd corked and mute values never mark
{
  const odd = [{ mute: false, properties: { "application.process.id": "5" } }, { corked: "false", mute: false, properties: { "application.process.id": "5" } },
    { corked: false, properties: { "application.process.id": "5" } }]
  const s = A.parseSample(JSON.stringify(odd) + "\n--\n5 1\n")
  assert.deepEqual(A.playingAddresses(s, [{ address: "0x5", pid: 5, appId: "a" }], norm), {})
}

// ---- garbage never throws and marks nothing
for (const text of ["", null, undefined, "--", "not json\n--\n1 0", "{}\n--\n", "[1, null, \"x\"]\n--\nfoo bar\n", "[]"]) {
  const s = A.parseSample(text)
  assert.deepEqual(A.playingAddresses(s, windows, norm), {})
}
assert.deepEqual(A.playingAddresses(null, windows, norm), {})
assert.deepEqual(A.playingAddresses(sample, [], norm), {})
assert.deepEqual(A.playingAddresses(sample, undefined, norm), {})

console.log("audio marker ok")

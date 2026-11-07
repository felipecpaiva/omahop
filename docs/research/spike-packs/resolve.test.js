const assert = require("node:assert/strict")
const R = require("./PackResolve.js")
const sys = R.parseIndex("/sys/firefox.svg\n/sys/kitty.svg\n/sys/application-x-executable.svg\n")
const pack = { index: R.parseIndex("/p/firefox.png\n/p/Terminal.svg\n/p/dev-icon.png\n"), aliases: R.parseAliases("com.mitchellh.ghostty=Terminal, Kitty=terminal") }
const mine = { index: R.parseIndex("/m/firefox.png\n"), aliases: {} }
assert.equal(R.resolve(sys, [null, null], "firefox", "").path, "/sys/firefox.svg", "no pack: system")
assert.deepEqual(R.resolve(sys, [null, pack], "firefox", ""), { path: "/p/firefox.png", fallback: "/sys/firefox.svg", from: "pack" })
assert.equal(R.resolve(sys, [mine, pack], "firefox", "").path, "/m/firefox.png", "override beats pack")
assert.equal(R.resolve(sys, [mine, pack], "kitty", "").path, "/p/Terminal.svg", "alias by window class, case-insensitive")
assert.equal(R.resolve(sys, [mine, pack], "com.mitchellh.ghostty", "").path, "/p/Terminal.svg", "alias by app id")
assert.equal(R.resolve(sys, [pack], "Whatever", "dev-icon").path, "/p/dev-icon.png", "pack matched by desktop entry icon name")
assert.equal(R.resolve(sys, [pack], "nope", "/abs/x.png").path, "/abs/x.png", "pack ignores an absolute entry path; system layer takes it")
assert.equal(R.resolve(sys, [pack], "nope", "").path, "/sys/application-x-executable.svg", "miss: generic")
assert.equal(R.resolve(R.parseIndex(""), [{ index: R.parseIndex(""), aliases: {} }], "x", "").path, "", "all empty: empty string, no throw")
// scale: 1000 icons
const big = R.parseIndex(Array.from({ length: 1000 }, (_, i) => `/p/app-${i}.png`).join("\n"))
const t = process.hrtime.bigint()
const bp = { index: big, aliases: {} }
for (let i = 0; i < 1000; i++) R.resolve(sys, [bp], "app-" + i, "")
console.log("1000 resolves against 1000 icons:", Number(process.hrtime.bigint() - t) / 1e6, "ms")
console.log("resolve ok")

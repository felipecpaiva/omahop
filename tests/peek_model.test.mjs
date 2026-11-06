// Node check of PeekModel.js:  node tests/peek_model.test.mjs
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"
const src = readFileSync(new URL("../PeekModel.js", import.meta.url), "utf8").replace(".pragma library", "")
const M = new Function(src + "; return { group, resolvePosition, isVertical, slotAt }")()

const w = (address, appId, extra = {}) => ({ address, appId, title: "t " + address, workspace: 1, floating: true, minimized: false, monitor: "eDP-1", ...extra })
const list = [w("1", "kitty"), w("2", "chrome"), w("3", "kitty"), w("4", "slack", { floating: false, workspace: 2 }), w("5", "kitty", { minimized: true, floating: false }), w("6", "mpv", { monitor: "DP-1" }), w("7", "")]

// grouping: by app, first-appearance order, windows keep order
let g = M.group(list, {})
assert.deepEqual(g.map((x) => x.appId), ["kitty", "chrome", "slack", "mpv"], "apps in first-appearance order, windows without an app id skipped")
assert.deepEqual(g[0].windows.map((x) => x.address), ["1", "3", "5"], "an app's windows keep their order")
// floating only: tiling window dropped, minimized kept
g = M.group(list, { onlyFloating: true })
assert.deepEqual(g.map((x) => x.appId), ["kitty", "chrome", "mpv"], "floating only drops slack (tiling)")
assert.deepEqual(g[0].windows.map((x) => x.address), ["1", "3", "5"], "a minimized window stays")
// monitor: another screen's windows dropped, minimized ones listed everywhere
g = M.group(list, { onlyFloating: true, monitor: "eDP-1" })
assert.deepEqual(g.map((x) => x.appId), ["kitty", "chrome"], "only this screen's windows")
assert.equal(g[0].windows.length, 3, "the minimized window shows on every screen")
assert.deepEqual(M.group([], {}), [], "no windows, no groups")
assert.deepEqual(M.group(list), M.group(list, {}), "options are optional")

// edge choice: an explicit edge wins; auto is a free edge (not the dock's, not the bar's), preferring right
assert.equal(M.resolvePosition("auto", "bottom", "top"), "right", "Omarchy's defaults leave right free")
assert.equal(M.resolvePosition("auto", undefined, undefined), "right", "unknown positions count as the defaults")
assert.equal(M.resolvePosition("auto", "right", "top"), "left", "dock on the right: left")
assert.equal(M.resolvePosition("auto", "right", "left"), "top", "dock right and bar left: top")
assert.equal(M.resolvePosition("auto", "left", "right"), "top")
assert.equal(M.resolvePosition("bottom", "bottom", "top"), "bottom", "an explicit edge wins, even a busy one")
assert.equal(M.resolvePosition("junk", "bottom", "top"), "right", "an unknown setting behaves like auto")
assert.ok(M.isVertical("left") && M.isVertical("right") && !M.isVertical("top"))
// slot hit test
assert.equal(M.slotAt(10, 8, 48, 3), 0); assert.equal(M.slotAt(60, 8, 48, 3), 1); assert.equal(M.slotAt(300, 8, 48, 3), -1); assert.equal(M.slotAt(2, 8, 48, 3), -1)
console.log("peek model ok")

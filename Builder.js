.pragma library
// The icon builder's pure logic (tests/builder.test.mjs): reading the scripts' output, the commands as argument arrays, the key map, the preview rows and the page's
// state machine. Every rule about draft files lives in tools/draft-edit.sh and pack-lib.sh; this file only decides what to run and what a result means.
// App rows come from PackEditor.appRows (fed the draft's files instead of a pack's), so the builder and the pack editor list apps the same way. Design: D29.

const FIND_MIN = 2   // the shortest search text; icon-find.sh refuses less
const LICENCES = ["CC0-1.0", "MIT", "CC-BY-4.0", "All rights reserved"]   // the save dialog's choices; the script accepts any text it can store
const DEFAULT_NAME = "my-icons"

function lines(text) { return String(text || "").split("\n").map((l) => l.trim()).filter((l) => l !== "") }

// draft-edit.sh list: "stem<TAB>file<TAB>path" lines to [{stem, file, path}] (paths only when absolute).
function parseDraft(text) {
  const out = []
  for (const line of String(text || "").split("\n")) {
    const [stem, file, ...rest] = line.split("\t")
    const path = rest.join("\t").trim()
    if (stem && file && path.charAt(0) === "/") out.push({ stem: stem, file: file, path: path })
  }
  return out
}

// icon-find.sh: "theme<TAB>name<TAB>path" lines to [{theme, name, path}], the order kept, a line without an absolute path dropped.
function parseFind(text) {
  const out = []
  for (const line of String(text || "").split("\n")) {
    const [theme, name, ...rest] = line.split("\t")
    const path = rest.join("\t").trim()
    if (theme && name && path.charAt(0) === "/") out.push({ theme: theme, name: name, path: path })
  }
  return out
}

// The text to search for first when an app is chosen: the icon name its desktop entry gives (not a path), else the last part of a dotted id, else the id.
function suggestQuery(appId, entryIcon) {
  const icon = String(entryIcon || "")
  const id = String(appId || "")
  const parts = id.split(".")
  const pick = icon !== "" && icon.charAt(0) !== "/" && icon.indexOf("file://") !== 0 ? icon : (parts.length > 2 ? parts[parts.length - 1] : id)
  return pick.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9._+-]/g, "")
}

// Names the system would try for an app that icon-preview.sh accepts (it skips a name with anything else), best first.
function nowNames(candidates) { return (candidates || []).filter((n) => /^[A-Za-z0-9._+-]+$/.test(n)) }

// The icon file the base theme gives: the first of the names that icon-preview.sh found (map: name to path), or "".
function nowPick(names, map) {
  for (const n of names) if (map && map[n]) return map[n]
  return ""
}

// Rows for the list: PackEditor.appRows output plus `changed`, whether the draft has an icon for the app.
function decorate(rows) { return (rows || []).map((r) => Object.assign({}, r, { changed: r.packPath !== "" })) }

// The file url of a row's draft icon with a counter, so a replaced file (same name) is read again; "" when the row is not changed.
function draftUrl(row, rev) { return row && row.packPath ? "file://" + row.packPath + "?v=" + (rev || 0) : "" }

// `count` rows to show in the preview: the chosen row first, then the ones after it (wrapping).
function previewRows(rows, cursor, count) {
  if (!rows || rows.length === 0) return []
  const out = []
  for (let i = 0; i < Math.min(count, rows.length); i++) out.push(rows[(Math.max(0, cursor) + i) % rows.length])
  return out
}

// Cursor movement in a grid of `cols` columns. Returns the new index or -1 for a key that is not a movement. Left and right stop at the ends, up and down keep the column.
function gridMove(index, key, count, cols) {
  if (count <= 0) return -1
  const last = count - 1
  const steps = { Left: index - 1, Right: index + 1, Up: index - cols, Down: index + cols, PageUp: index - 3 * cols, PageDown: index + 3 * cols }
  if (!(key in steps)) return -1
  const to = steps[key]
  if (to < 0 && index >= 0 && (key === "Up" || key === "PageUp") && index < cols) return index   // already on the top row
  return Math.max(0, Math.min(last, to))
}

// The key map. name: "Up", "Down", "Left", "Right", "PageUp", "PageDown", "Home", "End", "Return", "Escape", "Tab", "Backtab" or a letter in lower case.
// s: {zone: "apps"|"icons", baseOpen: bool}. Returns {act, key?}; act "none" means leave the key to the text field.
// Ctrl+Z undoes, Ctrl+R resets the chosen app, Tab goes between the app list and the icon side, Escape closes the base theme list first and then the page.
function action(name, ctrl, s) {
  if (name === "Escape") return { act: s.baseOpen ? "closeBase" : "back" }
  if (ctrl && name === "z") return { act: "undo" }
  if (ctrl && name === "r") return { act: "resetApp" }
  if (name === "Tab" || name === "Backtab") return { act: s.baseOpen ? "none" : "zone" }
  if (s.baseOpen) {
    if (["Up", "Down", "PageUp", "PageDown", "Home", "End"].indexOf(name) >= 0) return { act: "baseMove", key: name }
    return name === "Return" ? { act: "baseChoose" } : { act: "none" }
  }
  if (s.zone === "apps") {
    if (["Up", "Down", "PageUp", "PageDown"].indexOf(name) >= 0) return { act: "appMove", key: name }
    return name === "Return" ? { act: "zone" } : { act: "none" }
  }
  if (["Up", "Down", "Left", "Right", "PageUp", "PageDown"].indexOf(name) >= 0) return { act: "gridMove", key: name }
  return name === "Return" ? { act: "apply" } : { act: "none" }
}

// ---- commands: argument arrays for Process, never a shell line.
// tools: {draft, find, preview, pick (pack-edit.sh), export (pack-export.sh), import (pack-import.sh)}. Returns {argv} or {error}.
function plain(v) { return typeof v === "string" && v.indexOf("\0") === -1 && v.indexOf("\n") === -1 }

function command(tools, op, a) {
  const need = (ok, why) => { if (!ok) throw new Error(why) }
  try {
    switch (op) {
      case "list": return { argv: ["bash", tools.draft, "list"] }
      case "add":
        need(plain(a.appId) && a.appId !== "", "no app chosen")
        need(plain(a.path) && a.path.charAt(0) === "/", "give the image as a full path, starting with /")
        return { argv: ["bash", tools.draft, "add", a.appId, a.path] }
      case "reset":
        need(plain(a.appId) && a.appId !== "", "no app chosen")
        return { argv: ["bash", tools.draft, "reset-app", a.appId] }
      case "undo": return { argv: ["bash", tools.draft, "undo"] }
      case "find":
        need(plain(a.query) && a.query.length >= FIND_MIN, "type at least " + FIND_MIN + " letters")
        return { argv: ["bash", tools.find, a.query, "120"] }
      case "now": return { argv: ["bash", tools.preview, plain(a.theme) && a.theme !== "" ? a.theme : "-"].concat(nowNames(a.names)) }
      case "save": {
        need(plain(a.name) && a.name.trim() !== "", "give the pack a name")
        need(plain(a.author) && plain(a.licence) && a.licence !== "", "choose a licence")
        need(plain(a.description || "") && plain(a.basedOn || ""), "the description must be one line")
        const flags = (a.replace ? ["--replace"] : []).concat(a.basedOn ? ["--based-on", a.basedOn] : [])
        return { argv: ["bash", tools.draft, "save"].concat(flags, [a.name.trim(), a.author.trim(), a.licence], a.description ? [a.description] : []) }
      }
      case "openPack":
        need(plain(a.name) && /^[A-Za-z0-9._-]+$/.test(a.name), "no pack chosen")
        return { argv: ["bash", tools.draft, "open-pack"].concat(a.force ? ["--force"] : [], [a.name]) }
      case "discard": return { argv: ["bash", tools.draft, "discard"] }
      case "packs": return { argv: ["bash", tools.pick, "list"] }
      case "pick": return { argv: ["bash", tools.pick, "pick", "image"] }
      case "pickDir": return { argv: ["bash", tools.pick, "pick", "dir"] }
      case "pickZip": return { argv: ["bash", tools.pick, "pick", "zip"] }
      case "exportDir": return { argv: ["bash", tools.pick, "export-dir"] }
      case "export":
        need(plain(a.name) && /^[A-Za-z0-9._-]+$/.test(a.name), "no pack chosen")
        need(plain(a.out) && a.out.charAt(0) === "/" && /\.zip$/i.test(a.out), "give the zip's full path, starting with / and ending in .zip")
        return { argv: ["bash", tools.export, a.name, a.out].concat(a.force ? ["--force"] : []) }
      case "importCheck":
        need(plain(a.zip) && a.zip.charAt(0) === "/", "give the zip as a full path, starting with /")
        return { argv: ["bash", tools.import, a.zip, "--dry-run"] }
      case "importDo":
        need(plain(a.zip) && a.zip.charAt(0) === "/", "give the zip as a full path, starting with /")
        return { argv: ["bash", tools.import, a.zip, "--yes"].concat(a.replace ? ["--replace"] : []) }
      case "openZip":
        need(plain(a.zip) && a.zip.charAt(0) === "/", "give the zip as a full path, starting with /")
        return { argv: ["bash", tools.draft, "open-zip"].concat(a.force ? ["--force"] : [], [a.zip]) }
      default: return { error: "unknown action " + op }
    }
  } catch (e) {
    return { error: e.message }
  }
}

// ---- the state of the mutating actions: one at a time.
// phase "idle" or "busy"; message/error: the status line; manualPath: the file chooser did not open, so a typed path is offered.
// Export and Import (slice 3): effect {exported: {name, icons, bytes, path}}, {overwrite: true} (the zip exists: ask), {dir} (the chosen folder), {run: "importCheck"} after a chosen zip,
// {summary} (the dry run's result), {installed: folder}, {opened: true} (Edit as draft loaded the icons), {needForce: true} (also for open-zip).
// effect (from finish): {refresh: true} reload the draft ({saved: folder} too after a save), {run: "add", args} (a picked file goes to add), {clash: true} the pack name is taken
// (ask Replace or Cancel), {needForce: true} open-pack refused over a draft with changes (ask).
// packNames(text): the installed pack folders, one per line.
function packNames(text) { return lines(text).filter((n) => /^[A-Za-z0-9._-]+$/.test(n)) }
const EXIT_NOTHING_PICKED = 1

// pack-import.sh --dry-run output to {name, author, licence, icons, folder, installed, files}; null when it is not that.
function parseSummary(text) {
  const get = (re) => { const m = String(text || "").match(re); return m ? m[1].trim() : "" }
  const name = get(/^Pack:(.*)$/m)
  const target = get(/^Install:(.*)$/m).replace(/ \(.*\)$/, "")
  const icons = parseInt(get(/^Icons:(.*)$/m), 10)
  if (name === "" || target === "" || !(icons >= 0)) return null
  const files = String(text).split("\n").filter((l) => /^ {2}\S/.test(l)).map((l) => l.trim())
  return { name: name, author: get(/^Author:(.*)$/m), licence: get(/^License:(.*)$/m), icons: icons, folder: target.slice(target.lastIndexOf("/") + 1), installed: get(/^Installed already:(.*)$/m) === "yes", files: files }
}

// "Exported <name> (<n> icons, <bytes> bytes) to <path>" to {name, icons, bytes, path}, or null.
function parseExported(text) {
  const m = String(text || "").match(/^Exported (\S+) \((\d+) icons, (\d+) bytes\) to (.+)$/m)
  return m ? { name: m[1], icons: Number(m[2]), bytes: Number(m[3]), path: m[4] } : null
}

// 1536 to "1.5 KB": the size shown after an export.
function sizeText(bytes) {
  const n = Number(bytes) || 0
  if (n < 1024) return n + " B"
  return n < 1048576 ? (n / 1024).toFixed(1) + " KB" : (n / 1048576).toFixed(1) + " MB"
}

// The path offered for an export: <folder>/<pack>.zip.
function defaultZipPath(dir, name) { return String(dir || "").replace(/\/+$/, "") + "/" + name + ".zip" }

function initial() { return { phase: "idle", op: "", message: "", error: false, manualPath: false, effect: null } }

function begin(state, op) { return state.phase === "busy" ? state : { phase: "busy", op: op, message: /^pick/.test(op) ? "" : "Working...", error: false, manualPath: state.manualPath, effect: null } }

function reason(stderr, code) {
  const text = lines(stderr).map((l) => l.replace(/^omahop (draft|pack) (edit|import|export): /, "")).join(" ")
  return text !== "" ? text : "Failed (exit " + code + ")"
}

function settled(state, message, error, extra) { return Object.assign({ phase: "idle", op: "", message: message, error: error, manualPath: state.manualPath, effect: null }, extra || {}) }

// ctx: {appId}. A picked file runs add for the app that was chosen when the chooser opened.
function finish(state, op, code, stdout, stderr, ctx) {
  const out = lines(stdout)
  const c = ctx || {}
  if (op === "pick") {
    if (code === EXIT_NOTHING_PICKED) return settled(state, "", false)
    const path = out.length > 0 ? out[0] : ""
    if (code !== 0 || path.charAt(0) !== "/") return settled(state, "The file picker did not open. Type the file's full path instead.", true, { manualPath: true })
    return settled(state, "", false, { effect: { run: "add", args: { appId: c.appId, path: path } } })
  }
  if (op === "pickDir" || op === "pickZip") {
    if (code === EXIT_NOTHING_PICKED) return settled(state, "", false)
    const picked = out.length > 0 ? out[0] : ""
    if (code !== 0 || picked.charAt(0) !== "/") return settled(state, "The file picker did not open. Type the full path instead.", true, { manualPath: true })
    return settled(state, "", false, { effect: op === "pickDir" ? { dir: picked } : { run: "importCheck", args: { zip: picked } } })
  }
  if (code !== 0 && op === "export" && /exists, add --force/.test(stderr)) return settled(state, "", false, { effect: { overwrite: true } })
  if (code !== 0 && op === "openZip" && /has changes/.test(stderr)) return settled(state, "", false, { effect: { needForce: true } })
  if (code !== 0 && op === "save" && /already exists/.test(stderr)) return settled(state, "", false, { effect: { clash: true } })
  if (code !== 0 && op === "openPack" && /has changes/.test(stderr)) return settled(state, "", false, { effect: { needForce: true } })
  if (code !== 0) return settled(state, reason(stderr, code), true)
  const last = out.length > 0 ? out[out.length - 1] : "Done"
  switch (op) {
    case "add": return settled(state, "Set icons/" + last + " in the draft.", false, { manualPath: false, effect: { refresh: true } })
    case "undo": return settled(state, "Undid the last step (" + last + ").", false, { effect: { refresh: true } })
    case "save": return settled(state, "Saved the pack " + last + ".", false, { effect: { refresh: true, saved: last } })
    case "openPack": return settled(state, last + ".", false, { effect: { refresh: true } })
    case "export": {
      const x = parseExported(stdout)
      return x ? settled(state, "Exported " + x.name + " (" + x.icons + " icons, " + sizeText(x.bytes) + ") to " + x.path, false, { effect: { exported: x } }) : settled(state, last, false)
    }
    case "importCheck": {
      const sum = parseSummary(stdout)
      return sum ? settled(state, "", false, { effect: { summary: sum } }) : settled(state, "That did not look like a pack summary.", true)
    }
    case "importDo": return settled(state, "Installed " + (c.name || last) + ". Set Icon pack to it in the settings, or use Open a pack.", false, { effect: { installed: c.folder || "" } })
    case "openZip": return settled(state, last + ".", false, { effect: { refresh: true, opened: true } })
    case "discard": return settled(state, "Discarded the draft.", false, { effect: { refresh: true } })
    case "reset": return settled(state, last + ".", false, { effect: { refresh: true } })
    default: return settled(state, last, false)
  }
}

function refuse(state, why) { return state.phase === "busy" ? state : settled(state, why, true) }

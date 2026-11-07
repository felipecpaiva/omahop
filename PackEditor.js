.pragma library
// The icon pack editor's logic, pure so Node can test it (tests/pack_editor.test.mjs): the app rows, the commands as argument arrays, and
// the editor's state machine. Every rule about pack files lives in tools/pack-lib.sh; this file only decides what to run and what a
// result means. Design: docs/research/pack-editor-spike.md.

// The icon file stem for an app id, as tools/pack-edit.sh stem makes it: lower case, runs of whitespace as one dash. "" when it cannot be a
// file name (the shell refuses it too; tests/pack_edit.test.sh compares both on hostile ids).
const STEM_RULE = /^[a-z0-9][a-z0-9._+-]{0,199}$/
function iconStem(appId) {
  const stem = String(appId || "").toLowerCase().replace(/[ \t\n\v\f\r]+/g, "-")
  return STEM_RULE.test(stem) ? stem : ""
}

function lines(text) {
  return String(text || "").split("\n").map((l) => l.trim()).filter((l) => l !== "")
}

function fileName(path) { return String(path).slice(String(path).lastIndexOf("/") + 1) }

// The rows of the app list: open windows first (in their order), then installed apps by name, then pack icons no listed app uses (so they
// can still be removed). One row per icon stem. pick(appId, entryIcon) returns the pack file the switcher would use for that app, or ""
// (IconResolve.packPick on the pack's index). windows: [{appId, name, icon}] (name and icon from the window's desktop entry), entries: [{id, name, icon, startupClass, noDisplay}], packFiles: paths.
// A row: {key, name, icon (the entry's icon name), running, stem, packPath, packFile}.
function appRows(windows, entries, packFiles, pick, filter) {
  const rows = []
  const seen = Object.create(null)
  const used = Object.create(null)
  const add = (key, name, icon, running) => {
    const stem = iconStem(key)
    if (stem === "" || seen[stem]) return
    seen[stem] = true
    const packPath = pick(key, icon) || ""
    if (packPath !== "") used[packPath] = true
    rows.push({ key: key, name: name || key, icon: icon || "", running: running, stem: stem, packPath: packPath, packFile: packPath === "" ? "" : fileName(packPath) })
  }
  for (const w of windows || []) add(String(w.appId || ""), String(w.name || ""), String(w.icon || ""), true)
  const shown = (entries || []).filter((e) => !e.noDisplay && (e.startupClass || e.id))
  shown.sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")))
  for (const e of shown) add(String(e.startupClass || e.id), String(e.name || ""), String(e.icon || ""), false)
  for (const path of packFiles || []) {
    if (used[path]) continue
    const file = fileName(path)
    const stem = file.replace(/\.(png|svg)$/, "")
    if (seen[stem.toLowerCase()]) continue
    seen[stem.toLowerCase()] = true
    rows.push({ key: stem, name: stem, icon: "", running: false, stem: stem.toLowerCase(), packPath: path, packFile: file })
  }
  const words = String(filter || "").trim().toLowerCase()
  return words === "" ? rows : rows.filter((r) => (r.name + " " + r.key).toLowerCase().indexOf(words) !== -1)
}

// The summary pack-import.sh --dry-run prints ("Pack:     x" lines, then Files).
function parseImportSummary(text) {
  const out = { name: "", author: "", license: "", icons: 0, target: "", installed: false }
  for (const line of lines(text)) {
    const m = /^(Pack|Author|License|Icons|Install|Installed already):\s*(.*)$/.exec(line)
    if (!m) continue
    if (m[1] === "Pack") out.name = m[2]
    else if (m[1] === "Author") out.author = m[2]
    else if (m[1] === "License") out.license = m[2]
    else if (m[1] === "Icons") out.icons = parseInt(m[2], 10) || 0
    else if (m[1] === "Install") out.target = m[2].replace(/ \(.*\)$/, "")
    else out.installed = m[2] === "yes"
  }
  return out
}

// ---- commands: argument arrays for Process, never a shell line. A value that could be misread is refused before anything runs.
// The file chooser runs through pack-edit.sh pick, so a missing chooser is exit 2 like a failed one, never a process that cannot start.
const PICK_KIND = { pickImage: "image", pickZip: "zip" }

function plain(v) { return typeof v === "string" && v.indexOf("\0") === -1 && v.indexOf("\n") === -1 }
function folderOk(v) { return plain(v) && v !== "" && v.charAt(0) !== "-" }
function fullPath(v) { return plain(v) && v.charAt(0) === "/" }

// tools: {edit, exporter, importer} script paths. Returns {argv} or {error}.
function command(tools, op, a) {
  const edit = ["bash", tools.edit]
  const need = (ok, why) => { if (!ok) throw new Error(why) }
  try {
    switch (op) {
      case "list": return { argv: edit.concat(["list"]) }
      case "init":
        need([a.name, a.author, a.license, a.description].every(plain), "a field holds a line break")
        return { argv: edit.concat(["init", a.name, a.author, a.license, a.description]) }
      case "meta":
        need(folderOk(a.folder), "no pack chosen")
        need([a.name, a.author, a.license, a.description].every(plain), "a field holds a line break")
        return { argv: edit.concat(["meta", a.folder, a.name, a.author, a.license, a.description]) }
      case "add":
        need(folderOk(a.folder), "no pack chosen")
        need(plain(a.appId) && a.appId !== "", "no app chosen")
        need(fullPath(a.path), "give the image as a full path, starting with /")
        return { argv: edit.concat(["add", a.folder, a.appId, a.path]) }
      case "remove":
        need(folderOk(a.folder), "no pack chosen")
        need(plain(a.file) && a.file !== "", "no icon chosen")
        return { argv: edit.concat(["remove", a.folder, a.file]) }
      case "export":
        need(folderOk(a.folder), "no pack chosen")
        return { argv: ["bash", tools.exporter, a.folder].concat(a.replace ? ["--force"] : []) }
      case "importCheck":
        need(fullPath(a.path), "give the zip as a full path, starting with /")
        return { argv: ["bash", tools.importer, a.path, "--dry-run"] }
      case "importInstall":
        need(fullPath(a.path), "give the zip as a full path, starting with /")
        return { argv: ["bash", tools.importer, a.path, "--yes"].concat(a.replace ? ["--replace"] : []) }
      case "pickImage":
      case "pickZip":
        return { argv: edit.concat(["pick", PICK_KIND[op]]) }
      default: return { error: "unknown action " + op }
    }
  } catch (e) {
    return { error: e.message }
  }
}

// ---- the editor's state: one action at a time.
// phase: "idle", "busy" (op running) or "confirm" (an import or a replacing export waits for a yes). message and error: the status line.
// manualPath: the picker did not open, so a typed path is offered. effect (from finish): what the page does next, or null:
//   {run: op, args}     run another command (a picked file goes to add or importCheck)
//   {refresh: true, select: folder, changed: bool}   reload the pack list and icons; changed: tell the switcher the pack changed
const EXIT_NOTHING_PICKED = 1

function initial() { return { phase: "idle", op: "", message: "", error: false, confirm: null, manualPath: false, effect: null } }

function begin(state, op) {
  if (state.phase === "busy") return state
  return { phase: "busy", op: op, message: op === "pickImage" || op === "pickZip" ? "" : "Working...", error: false, confirm: null,
    manualPath: state.manualPath, effect: null }
}

// The reason a script gave, without its "omahop pack edit:" style prefix.
function reason(stderr, code) {
  const text = lines(stderr).map((l) => l.replace(/^omahop pack [a-z]+: /, "")).join(" ")
  return text !== "" ? text : "Failed (exit " + code + ")"
}

function settled(state, message, error, extra) {
  return Object.assign({ phase: "idle", op: "", message: message, error: error, confirm: null, manualPath: state.manualPath, effect: null }, extra || {})
}

// ctx: what the page knows about the action: {folder, appId, path, replace}.
function finish(state, op, code, stdout, stderr, ctx) {
  const out = lines(stdout)
  const c = ctx || {}
  if (op === "pickImage" || op === "pickZip") {
    if (code === EXIT_NOTHING_PICKED) return settled(state, "", false)
    const path = out.length > 0 ? out[0] : ""
    if (code !== 0 || path.charAt(0) !== "/")
      return settled(state, "The file picker did not open. Type the file's full path below instead.", true, { manualPath: true })
    return settled(state, "", false, { effect: { run: op === "pickImage" ? "add" : "importCheck", args: { folder: c.folder, appId: c.appId, path: path } } })
  }
  if (op === "importCheck") {
    if (code !== 0) return settled(state, reason(stderr, code), true)
    const summary = parseImportSummary(stdout)
    return { phase: "confirm", op: "", message: "", error: false, manualPath: state.manualPath, effect: null,
      confirm: { kind: "import", replace: summary.installed, summary: summary, path: c.path } }
  }
  if (op === "export" && code !== 0 && /exists, add --force/.test(String(stderr)))
    return { phase: "confirm", op: "", message: "", error: false, manualPath: state.manualPath, effect: null,
      confirm: { kind: "export", replace: true, summary: null, path: "" } }
  if (code !== 0) return settled(state, reason(stderr, code), true)
  const last = out.length > 0 ? out[out.length - 1] : "Done"
  switch (op) {
    case "init": return settled(state, "Made the pack " + last + ".", false, { effect: { refresh: true, select: last, changed: false } })
    case "add": return settled(state, "Added icons/" + last + ".", false, { manualPath: false, effect: { refresh: true, select: c.folder, changed: true } })
    case "remove":
    case "meta": return settled(state, last + ".", false, { effect: { refresh: true, select: c.folder, changed: op === "remove" } })
    case "importInstall": return settled(state, last, false, { effect: { refresh: true, select: "", changed: true } })
    default: return settled(state, last, false)
  }
}

function cancel(state) { return settled(state, "", false) }

// A command that was refused before it ran (command() gave an error).
function refuse(state, why) { return state.phase === "busy" ? state : settled(state, why, true) }

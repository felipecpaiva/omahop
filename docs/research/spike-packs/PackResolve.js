// Spike: pack layer in front of the system icon index. Pure, no Qt. Same shape as IconResolve.js
// (parseIndex and candidates are copied so the spike runs alone).
const GENERIC = "application-x-executable"

function parseIndex(text) {
  const exact = {}, lower = {}
  for (const line of String(text).split("\n")) {
    const path = line.trim()
    if (path === "") continue
    const file = path.slice(path.lastIndexOf("/") + 1)
    const dot = file.lastIndexOf(".")
    const name = dot > 0 ? file.slice(0, dot) : file
    if (exact[name] === undefined) exact[name] = path
    if (lower[name.toLowerCase()] === undefined) lower[name.toLowerCase()] = path
  }
  return { exact, lower }
}

function candidates(appId, entryIcon) {
  const out = []
  const add = (v) => { if (v && out.indexOf(v) === -1) out.push(v) }
  const id = String(appId || "")
  add(entryIcon); add(id); add(id.toLowerCase()); add(id.replace(/\s+/g, "-").toLowerCase())
  const parts = id.split(".")
  if (parts.length > 2) add(parts[parts.length - 1].toLowerCase())
  return out
}

// aliases: "Class=file, Other=file" from pack.toml (a flat TOML string). Left side is a window class or app id, case-insensitive.
function parseAliases(s) {
  const out = {}
  for (const pair of String(s || "").split(",")) {
    const i = pair.indexOf("=")
    if (i < 1) continue
    const k = pair.slice(0, i).trim().toLowerCase(), v = pair.slice(i + 1).trim()
    if (k && v) out[k] = v
  }
  return out
}

// A pack is { index, aliases }. Order inside a pack: alias, then the app id forms (what the user sees), then the desktop entry's icon name.
// A pack never follows an absolute path from a desktop entry: only the system layer does.
function packPick(pack, appId, entryIcon) {
  if (!pack) return ""
  const id = String(appId || "")
  const names = []
  const alias = pack.aliases && pack.aliases[id.toLowerCase()]
  if (alias) names.push(alias)
  for (const n of candidates(id, "")) names.push(n)
  if (entryIcon && entryIcon.charAt(0) !== "/" && entryIcon.indexOf("file://") !== 0) names.push(entryIcon)
  for (const n of names) {
    const hit = pack.index.exact[n] || pack.index.lower[n.toLowerCase()]
    if (hit) return hit
  }
  return ""
}

function systemPick(index, appId, entryIcon) {
  for (const name of candidates(appId, entryIcon)) {
    if (name.charAt(0) === "/") return name
    if (name.indexOf("file://") === 0) return name.slice(7)
    const hit = index.exact[name] || index.lower[name.toLowerCase()]
    if (hit) return hit
  }
  return ""
}

// layers: [mine, activePack] (either may be null). Returns the file plus a fallback (the system icon) for a file that fails to load.
function resolve(system, layers, appId, entryIcon) {
  const sys = systemPick(system, appId, entryIcon) || system.exact[GENERIC] || ""
  for (const pack of layers) {
    const hit = packPick(pack, appId, entryIcon)
    if (hit) return { path: hit, fallback: sys, from: "pack" }
  }
  return { path: sys, fallback: "", from: "system" }
}
module.exports = { parseIndex, parseAliases, candidates, resolve }

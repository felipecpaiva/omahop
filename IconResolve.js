.pragma library
// Picks the icon file for an app. Pure functions, no Quickshell, so Node can test them.
// The index maps an icon name to a file path (built from tools/icon-index.sh). An icon may be named in a desktop entry (a name or an absolute path)
// or only be the window class, which can differ in case or form from the icon name.

const GENERIC = "application-x-executable"

function parseIndex(text) {
  // No prototype, so an app id such as "constructor" is a miss, not an inherited function.
  const index = Object.create(null)
  const lower = Object.create(null)
  for (const line of String(text).split("\n")) {
    const path = line.trim()
    if (path === "") continue
    const file = path.slice(path.lastIndexOf("/") + 1)
    const dot = file.lastIndexOf(".")
    const name = dot > 0 ? file.slice(0, dot) : file
    if (index[name] === undefined) index[name] = path
    const low = name.toLowerCase()
    if (lower[low] === undefined) lower[low] = path
  }
  return { exact: index, lower: lower }
}

// Names to try, most specific first: the desktop entry's icon, the app id, then looser forms of it.
function candidates(appId, entryIcon) {
  const out = []
  const add = (v) => { if (v && out.indexOf(v) === -1) out.push(v) }
  add(entryIcon)
  add(appId)
  const id = String(appId || "")
  add(id.toLowerCase())
  add(id.replace(/\s+/g, "-").toLowerCase())
  const parts = id.split(".")
  if (parts.length > 2) add(parts[parts.length - 1].toLowerCase())
  return out
}

// A file path, or "" when nothing matches. An absolute path or file URL is returned as is.
function pick(index, names) {
  for (const name of names) {
    if (name.charAt(0) === "/") return name
    if (name.indexOf("file://") === 0) return name.substring("file://".length)
    const hit = index.exact[name] || index.lower[name.toLowerCase()]
    if (hit) return hit
  }
  return ""
}

// A pack's file for an app, or "". A pack index holds only files from the pack folder (tools/pack-index.sh), so a pack is asked by
// name only: the app id forms first (what the user named the file after), then the desktop entry's icon name. Never an absolute path or URL.
function packPick(pack, appId, entryIcon) {
  if (!pack) return ""
  const names = candidates(appId, "")
  const icon = String(entryIcon || "")
  if (icon !== "" && icon.charAt(0) !== "/" && icon.indexOf("file://") !== 0) names.push(icon)
  for (const name of names) {
    const hit = pack.exact[name] || pack.lower[name.toLowerCase()]
    if (hit) return hit
  }
  return ""
}

// layers: pack indexes in priority order (optional). The first pack that has the app wins, then the system index as before.
function resolve(index, appId, entryIcon, layers) {
  for (const pack of layers || []) {
    const hit = packPick(pack, appId, entryIcon)
    if (hit) return hit
  }
  return pick(index, candidates(appId, entryIcon)) || index.exact[GENERIC] || ""
}

// Spike: data-only validation of an icon pack zip. Pure functions, no I/O, so Node tests them and the shell can import them later.
// Phase 1 checks the zip LISTING (from `unzip -Zl`) before anything is extracted. Phase 2 checks every extracted file's bytes, in a
// staging folder, before it is moved into place. Nothing here runs or interprets pack content.

const LIMITS = {
  zipBytes: 50 * 1024 * 1024,   // the archive file itself
  entries: 2100,                // files plus directories (2000 icons plus pack.toml, preview, licence)
  fileBytes: 2 * 1024 * 1024,   // any one file, uncompressed
  svgBytes: 256 * 1024,
  totalBytes: 100 * 1024 * 1024,// all files, uncompressed
  ratio: 100,                   // uncompressed / compressed, per file (a 10 MB file of zeros compresses about 1000 to 1)
  pixels: 4096 * 4096 / 4,      // PNG width * height, 4 Mpx: a 1 MB PNG can still decode to hundreds of MB
  depth: 2,                     // icons/<file> only: no deeper nesting
}
const EXT = ["png", "svg"]
const TOP_FILES = ["pack.toml", "preview.png", "LICENSE", "LICENSE.txt", "README.md", "README.txt"]

// One line of `unzip -Zl`: perms version os size text csize method date time name
function parseListing(text) {
  const entries = []
  for (const line of String(text).split("\n")) {
    // The permission field is 10 chars from a Unix zip, 7 from a DOS/Windows zip, and starts with "?" when a tool wrote no type (python, some GUIs).
    const m = /^([-dlcbps?])\S+\s+\S+\s+\S+\s+(\d+)\s+\S+\s+(\d+)\s+\S+\s+\S+\s+\S+\s+(.*)$/.exec(line)
    if (!m) continue
    const kind = m[1] === "?" ? (m[4].endsWith("/") ? "d" : "-") : m[1]
    entries.push({ kind, size: Number(m[2]), csize: Number(m[3]), name: m[4] })
  }
  return entries
}

// One line of `bsdtar -tvf` (libarchive: always present on Arch, pacman needs it): perms links uid gid size month day time-or-year name.
// No compressed size, so csize is 0 and the ratio rule is skipped; the extraction caps (ulimit -f, timeout, post-check) are the backstop.
// A symlink line ends in " -> target", which is cut off here: its kind "l" is what gets it rejected.
function parseBsdtar(text) {
  const entries = []
  for (const line of String(text).split("\n")) {
    const m = /^([-dlcbps])\S+\s+\d+\s+\S+\s+\S+\s+(\d+)\s+\S+\s+\d+\s+\S+\s+(.*)$/.exec(line)
    if (!m) continue
    entries.push({ kind: m[1], size: Number(m[2]), csize: 0, name: m[1] === "l" ? m[3].replace(/ -> .*$/, "") : m[3] })
  }
  return entries
}

function lower(s) { return s.toLowerCase() }
function ext(name) { const i = name.lastIndexOf("."); return i < 0 ? "" : lower(name.slice(i + 1)) }

// A path inside the pack: relative, forward slashes, no dot segments, no control characters, no drive or home forms.
function badPath(name) {
  if (name === "" || name.length > 200) return "empty or long name"
  if (name.charAt(0) === "/" || name.charAt(0) === "~" || /^[A-Za-z]:/.test(name)) return "absolute path"
  if (name.indexOf("\\") !== -1) return "backslash"
  if (/[\u0000-\u001f\u007f]/.test(name)) return "control character"
  for (const seg of name.replace(/\/$/, "").split("/")) {
    if (seg === "" || seg === "." || seg === "..") return "dot segment or empty segment"
    if (seg.charAt(0) === "." ) return "hidden file"
  }
  return ""
}

// Returns { ok, errors[], files[] }. Every error names the entry, so the dialog can say why.
function validateListing(entries, zipBytes, limits) {
  const L = Object.assign({}, LIMITS, limits || {})
  const errors = [], files = [], seen = {}
  let total = 0, hasToml = false
  if (zipBytes > L.zipBytes) errors.push("archive too large")
  if (entries.length > L.entries) errors.push("too many entries")
  if (entries.length === 0) errors.push("empty archive")
  for (const e of entries) {
    const bad = badPath(e.name)
    if (bad) { errors.push(e.name + ": " + bad); continue }
    if (e.kind === "d") {
      if (e.name !== "icons/") errors.push(e.name + ": only icons/ may be a folder")
      continue
    }
    if (e.kind !== "-") { errors.push(e.name + ": not a regular file (link or special)"); continue }
    const key = lower(e.name)
    if (seen[key]) { errors.push(e.name + ": duplicate name (case-insensitive)"); continue }
    seen[key] = true
    const parts = e.name.split("/")
    const isIcon = parts.length === 2 && parts[0] === "icons" && EXT.indexOf(ext(e.name)) !== -1
    const isTop = parts.length === 1 && TOP_FILES.indexOf(e.name) !== -1
    if (!isIcon && !isTop) { errors.push(e.name + ": not an allowed file (only pack.toml, icons/*.png|svg, preview.png, LICENSE, README)"); continue }
    if (parts.length > L.depth) { errors.push(e.name + ": too deep"); continue }
    const cap = ext(e.name) === "svg" ? L.svgBytes : L.fileBytes
    if (e.size > cap) errors.push(e.name + ": file too large")
    if (e.size > 1024 && e.csize > 0 && e.size / e.csize > L.ratio) errors.push(e.name + ": compression ratio too high")
    total += e.size
    if (e.name === "pack.toml") hasToml = true
    files.push(e)
  }
  if (total > L.totalBytes) errors.push("total size too large")
  if (!hasToml) errors.push("pack.toml missing")
  return { ok: errors.length === 0, errors, files }
}

// Phase 2: bytes of one extracted file. `bytes` is a Uint8Array (the first 64 KB is enough for png; svg needs the whole file, capped).
function validateBytes(name, bytes, limits) {
  const L = Object.assign({}, LIMITS, limits || {})
  const e = ext(name)
  if (e === "png") {
    const sig = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
    if (bytes.length < 33 || sig.some((b, i) => bytes[i] !== b)) return "not a PNG"
    const dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
    if (dv.getUint32(12) !== 0x49484452) return "PNG without IHDR"
    const w = dv.getUint32(16), h = dv.getUint32(20)
    if (w === 0 || h === 0 || w > 4096 || h > 4096 || w * h > L.pixels) return "PNG dimensions too large"
    return ""
  }
  if (e === "svg") {
    if (bytes.length > L.svgBytes) return "SVG too large"
    const t = Buffer.from(bytes).toString("utf8")
    if (/<!ENTITY|<!DOCTYPE[^>]*\[/i.test(t)) return "SVG with entity declarations"
    if (!/^\s*(<\?xml[^>]*\?>\s*)?(<!--[\s\S]*?-->\s*)*<svg[\s>]/i.test(t)) return "not an SVG"
    if (/<\s*(script|foreignObject|iframe|embed|object)\b/i.test(t)) return "SVG with active or foreign content"
    if (/\bon[a-z]+\s*=/i.test(t)) return "SVG with event handler"
    // Only in-document references and embedded raster data may be loaded: no files, no URLs.
    for (const m of t.matchAll(/(?:xlink:)?href\s*=\s*["']([^"']*)["']/gi)) {
      if (m[1].charAt(0) !== "#" && !/^data:image\/(png|jpeg|webp);base64,/i.test(m[1])) return "SVG references an external resource"
    }
    if (/url\(\s*["']?(?!#)/i.test(t)) return "SVG url() to an external resource"
    return ""
  }
  return "unknown type"
}

// pack.toml: the flat TOML subset ConfigIO already reads. Required: schema = 1, id, name. Optional: version, author, licence, description, aliases.
const ID_RE = /^[a-z0-9][a-z0-9-]{0,39}$/
function validateManifest(top) {
  const errors = []
  if (top.schema !== 1) errors.push("schema must be 1 (newer packs need a newer omahop)")
  if (typeof top.id !== "string" || !ID_RE.test(top.id)) errors.push("id must be 1-40 chars of a-z 0-9 and hyphen")
  if (typeof top.name !== "string" || top.name === "" || top.name.length > 60) errors.push("name missing or longer than 60")
  for (const k of ["author", "licence", "description", "version"]) {
    if (top[k] !== undefined && (typeof top[k] !== "string" || top[k].length > 200)) errors.push(k + " must be text up to 200 chars")
  }
  if (top.aliases !== undefined && (typeof top.aliases !== "string" || top.aliases.length > 20000)) errors.push("aliases must be text up to 20000 chars")
  return errors
}

module.exports = { LIMITS, parseListing, parseBsdtar, badPath, validateListing, validateBytes, validateManifest }

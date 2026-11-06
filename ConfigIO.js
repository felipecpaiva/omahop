.pragma library
// omahop config reader and writer. Pure JavaScript (no Qt), so Node tests it and the settings panel imports it.
// The format is the flat TOML subset that lua/config.lua reads; Lua is the source of truth for what a value means. A cross-check test
// (tests/config_io.test.mjs) runs both parsers on the same text.
//
// Writing changes ONE line and leaves everything else byte for byte: comments, order, unknown keys and sections survive, so the user's
// hand edits are never lost when the panel saves.

function valueOf(raw) {
  if (raw === "true") return true
  if (raw === "false") return false
  var m = /^"(.*)"$/.exec(raw)
  if (m) return m[1]
  if (/^-?\d+$/.test(raw)) return parseInt(raw, 10)
  return undefined // not a value we know: the line is ignored, as in Lua
}

// Where a trailing comment starts: a '#' preceded by whitespace and outside a double quoted string. -1 if none.
function commentStart(s) {
  var inString = false
  for (var i = 0; i < s.length; i++) {
    var c = s[i]
    if (c === '"') inString = !inString
    else if (c === "#" && !inString && i > 0 && /\s/.test(s[i - 1])) return i
  }
  return -1
}

function splitLine(line) {
  var cut = commentStart(line)
  var body = cut < 0 ? line : line.slice(0, cut)
  return { body: body.replace(/\s+$/, ""), comment: cut < 0 ? "" : line.slice(cut), gap: cut < 0 ? "" : line.slice(0, cut).match(/\s*$/)[0] }
}

// { top: {key: value}, sections: {name: {key: value}} } and the lines that could not be read.
function parse(text) {
  var out = { top: {}, sections: {} }, bad = [], section = null
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var l = splitLine(lines[i]).body.replace(/^\s+/, "")
    if (l === "" || l[0] === "#") continue
    var h = /^\[([A-Za-z0-9_]+)\]$/.exec(l)
    if (h) { section = h[1]; if (!out.sections[section]) out.sections[section] = {}; continue }
    var kv = /^([A-Za-z0-9_]+)\s*=\s*(.*)$/.exec(l)
    var v = kv ? valueOf(kv[2]) : undefined
    if (kv && v !== undefined) (section === null ? out.top : out.sections[section])[kv[1]] = v
    else bad.push(lines[i])
  }
  return { top: out.top, sections: out.sections, bad: bad }
}

function get(text, section, key) {
  var p = parse(text)
  var bag = section === "top" ? p.top : p.sections[section]
  return bag ? bag[key] : undefined
}

// The text of a value as it is written. A string cannot hold a double quote or a line break (the format has no escapes): they are dropped.
function format(v) {
  if (typeof v === "boolean") return v ? "true" : "false"
  if (typeof v === "number") return String(Math.round(v))
  return '"' + String(v).replace(/["\r\n]/g, "") + '"'
}

// Line index range [from, to) holding the keys of a section ("top" is everything before the first header).
function range(lines, section) {
  var from = section === "top" ? 0 : -1, to = lines.length
  for (var i = 0; i < lines.length; i++) {
    var h = /^\s*\[([A-Za-z0-9_]+)\]\s*(#.*)?$/.exec(lines[i])
    if (!h) continue
    if (section !== "top" && from < 0 && h[1] === section) from = i + 1
    else if (from >= 0 || section === "top") { to = i; break }
  }
  return from < 0 ? null : [from, to]
}

function findKey(lines, r, key) {
  var re = new RegExp("^\\s*" + key + "\\s*=")
  for (var i = r[0]; i < r[1]; i++) if (re.test(lines[i])) return i
  return -1
}

// Set one key. Changes the value of an existing line (keeping its trailing comment), or adds a line to its section, or adds the section.
function set(text, section, key, value) {
  var lines = String(text || "").split("\n")
  if (lines.length && lines[lines.length - 1] === "") lines.pop()
  var r = range(lines, section)
  if (r) {
    var at = findKey(lines, r, key)
    if (at >= 0) {
      var sp = splitLine(lines[at])
      var eq = /^(\s*[A-Za-z0-9_]+\s*=\s*)/.exec(sp.body)
      lines[at] = eq[1] + format(value) + (sp.comment ? sp.gap + sp.comment : "")
    } else {
      var last = r[1]
      while (last > r[0] && lines[last - 1].replace(/\s+/g, "") === "") last--  // after the last non-blank line of the section
      lines.splice(last, 0, key + " = " + format(value))
    }
  } else {
    if (lines.length && lines[lines.length - 1].replace(/\s+/g, "") !== "") lines.push("")
    lines.push("[" + section + "]", key + " = " + format(value))
  }
  return lines.join("\n") + "\n"
}

// Remove one key (back to its default). A section left empty stays: removing someone's header is not ours to do.
function unset(text, section, key) {
  var lines = String(text || "").split("\n")
  var hadEnd = lines.length && lines[lines.length - 1] === ""
  if (hadEnd) lines.pop()
  var r = range(lines, section)
  var at = r ? findKey(lines, r, key) : -1
  if (at >= 0) lines.splice(at, 1)
  return lines.join("\n") + (hadEnd || lines.length ? "\n" : "")
}

.pragma library
// Which windows are playing sound (setting audio_marker, D21, research/audio-spike.md). Pure, so Node tests it (tests/audio_marker.test.mjs).
// Input is what tools/audio-sample.sh prints: the JSON of `pactl -f json list sink-inputs`, a line SEPARATOR, then `ps -e -o pid=,ppid=` lines.
// Privacy: the pactl text holds media titles (media.name). Only pid, binary, app name and the playing flag are kept; nothing here logs.

var SEPARATOR = "--"
var MAX_DEPTH = 16 // parent steps from a stream's process to a window's process (a browser's audio process is one or two below the browser)
var PROP_PID = "application.process.id"
var PROP_BINARY = "application.process.binary"
var PROP_APP = "application.name"

function lower(value) {
  return String(value || "").trim().toLowerCase()
}

function toPid(value) {
  var n = parseInt(value, 10)
  return n > 0 ? n : 0
}

// A stream plays only when pactl says plainly that it is neither corked (paused) nor muted.
function isPlaying(sinkInput) {
  return sinkInput.corked === false && sinkInput.mute === false
}

function parseStreams(jsonText) {
  var list
  try { list = JSON.parse(jsonText) } catch (e) { return [] }
  if (!Array.isArray(list)) return []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var s = list[i]
    if (!s || typeof s !== "object") continue
    var props = s.properties && typeof s.properties === "object" ? s.properties : {}
    out.push({ pid: toPid(props[PROP_PID]), binary: lower(props[PROP_BINARY]), app: lower(props[PROP_APP]), playing: isPlaying(s) })
  }
  return out
}

function parseParents(psText) {
  var parents = {}
  var lines = String(psText || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var f = lines[i].trim().split(/\s+/)
    var pid = toPid(f[0]), ppid = toPid(f[1])
    if (pid > 0) parents[pid] = ppid
  }
  return parents
}

// The sampling script's output -> { streams, parents }. Garbage gives empty lists, never a throw.
function parseSample(text) {
  var lines = String(text || "").split("\n")
  var cut = lines.indexOf(SEPARATOR)
  if (cut < 0) return { streams: [], parents: {} }
  return { streams: parseStreams(lines.slice(0, cut).join("\n")), parents: parseParents(lines.slice(cut + 1).join("\n")) }
}

function addTo(index, key, address) {
  if (!index[key]) index[key] = []
  index[key].push(address)
}

// The windows that own each pid, and each class (whole, and its last dot part: org.mozilla.firefox also answers to firefox).
function indexWindows(windows) {
  var byPid = {}, byClass = {}
  for (var i = 0; i < windows.length; i++) {
    var w = windows[i], address = w.address
    if (!address) continue
    var pid = toPid(w.pid), cls = lower(w.appId)
    if (pid > 0) addTo(byPid, pid, address)
    if (cls === "") continue
    addTo(byClass, cls, address)
    var dot = cls.lastIndexOf(".")
    if (dot >= 0 && dot < cls.length - 1) addTo(byClass, cls.slice(dot + 1), address)
  }
  return { byPid: byPid, byClass: byClass }
}

// The windows of the nearest process, from the stream's own up through its parents, that owns any. Empty when none does.
function ownersByProcess(pid, parents, byPid) {
  var seen = {}
  for (var depth = 0; pid > 1 && depth <= MAX_DEPTH && !seen[pid]; depth++) {
    if (byPid[pid]) return byPid[pid]
    seen[pid] = true
    pid = parents[pid] || 0
  }
  return []
}

// Fallback for a stream whose process tree owns no window (a sandbox reports its own pid): binary, then app name, against window classes.
function ownersByName(stream, byClass) {
  return byClass[stream.binary] || byClass[stream.app] || []
}

// sample: from parseSample. windows: [{ address, pid, appId }]. Returns { <normalized address>: true } for every window with a playing stream.
// shortcut: one browser process plays for all its windows, so all of them are marked; the tabs extension's audible flag could narrow it later.
function playingAddresses(sample, windows, normalize) {
  var marked = {}
  if (!sample || !sample.streams || sample.streams.length === 0) return marked
  var index = indexWindows(windows || [])
  for (var i = 0; i < sample.streams.length; i++) {
    var s = sample.streams[i]
    if (!s.playing) continue
    var owners = ownersByProcess(s.pid, sample.parents || {}, index.byPid)
    if (owners.length === 0) owners = ownersByName(s, index.byClass)
    for (var j = 0; j < owners.length; j++) marked[normalize(owners[j])] = true
  }
  return marked
}

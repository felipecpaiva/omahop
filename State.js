.pragma library
// omahop state file parser. The Lua side (lua/omahop.lua write_state) writes it; the overlay reads it. Pure, so Node tests it (tests/state.test.mjs).
// Format: "key=value" lines, then one tab-separated line per window: w <address> <class> <minimized 0|1> <title>.

function parse(text) {
  var st = { open: false, revealed: false, selected: 0, style: "list", thumbnails: "snapshot", entries: [] }
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line.indexOf("w\t") === 0) {
      var f = line.split("\t")
      if (f.length >= 5) st.entries.push({ address: f[1], appId: f[2], minimized: f[3] === "1", title: f.slice(4).join("\t") })
      continue
    }
    var eq = line.indexOf("=")
    if (eq < 1) continue
    var k = line.slice(0, eq), v = line.slice(eq + 1)
    if (k === "open") st.open = v === "1"
    else if (k === "revealed") st.revealed = v === "1"
    else if (k === "selected") st.selected = parseInt(v, 10) || 0
    else if (k === "style") st.style = v
    else if (k === "thumbnails") st.thumbnails = v
  }
  // A selection outside the list means a half-written or stale file: show nothing rather than a wrong row.
  if (st.selected < 1 || st.selected > st.entries.length) st.open = false
  return st
}

// How many rows fit before the list scrolls, for a screen height and a row height (keeps the card inside the screen).
function visibleRows(screenHeight, rowHeight, maxRows) {
  var fit = Math.floor((screenHeight * 0.7) / rowHeight)
  return Math.max(1, Math.min(maxRows, fit))
}

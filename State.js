.pragma library
// omahop state file parser. The Lua side (lua/omahop.lua write_state) writes it; the overlay reads it. Pure, so Node tests it (tests/state.test.mjs).
// Format: "key=value" lines (seq, grab, linger_ms, linger_rev: see lua/omahop.lua write_state and Linger.js), then one tab-separated line per window: w <address> <class> <minimized 0|1> <hint> <title> (hint: a number or letter, empty for none), and while a search is typed with browser_tabs on, tab rows: t <address> <class> <minimized> <active> <icon> <picture> <asleep 0|1> <site> <title> (asleep: Chrome put the tab to sleep; icon: the file name key of the site icon in tabicons/, picture: the name of the page picture in tabpics/, each empty for none).

// The thumbnail_exclude setting ("kitty, 1Password") as a set of lower-case window classes. Whole classes only, never a substring match.
function thumbnailExcludeSet(text) {
  var set = {}, items = String(text || "").split(",")
  for (var i = 0; i < items.length; i++) {
    var name = items[i].trim().toLowerCase()
    if (name !== "") set[name] = true
  }
  return set
}

function isThumbnailExcluded(excludeSet, appId) {
  var name = String(appId || "").trim().toLowerCase()
  return name !== "" && excludeSet[name] === true
}

function parse(text) {
  var st = { open: false, revealed: false, selected: 0, style: "list", thumbnails: "snapshot", border: "auto", actions: true, query: "", seq: 0, grab: false, lingerMs: 0, lingerRev: 0, entries: [] }
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line.indexOf("w\t") === 0) {
      var f = line.split("\t")
      if (f.length >= 6) st.entries.push({ address: f[1], appId: f[2], minimized: f[3] === "1", hint: f[4], title: f.slice(5).join("\t") })
      continue
    }
    if (line.indexOf("t\t") === 0) { // a browser tab row (setting browser_tabs): t <address> <class> <minimized> <active 0|1> <icon> <picture> <asleep 0|1> <site> <title>
      var t = line.split("\t")
      if (t.length >= 10) st.entries.push({ address: t[1], appId: t[2], minimized: t[3] === "1", hint: "", tab: true, active: t[4] === "1", icon: t[5], picture: t[6], asleep: t[7] === "1", host: t[8], title: t.slice(9).join("\t") })
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
    else if (k === "border") st.border = v
    else if (k === "query") st.query = v
    else if (k === "actions") st.actions = v === "1"
    else if (k === "seq") st.seq = parseInt(v, 10) || 0
    else if (k === "grab") st.grab = v === "1"
    else if (k === "linger_ms") st.lingerMs = parseInt(v, 10) || 0
    else if (k === "linger_rev") st.lingerRev = parseInt(v, 10) || 0
  }
  // A selection outside the list means a half-written or stale file: show nothing rather than a wrong row.
  // The one exception: a search that matched nothing is an open session with an empty list (the overlay says so).
  var emptySearch = st.entries.length === 0 && st.selected === 0 && st.query !== ""
  if (!emptySearch && (st.selected < 1 || st.selected > st.entries.length)) st.open = false
  if (!st.open) { st.grab = false; st.lingerMs = 0 } // a closed or unreadable session never holds the keyboard
  return st
}

// How many rows fit before the list scrolls, for a screen height and a row height (keeps the card inside the screen).
function visibleRows(screenHeight, rowHeight, maxRows) {
  var fit = Math.floor((screenHeight * 0.7) / rowHeight)
  return Math.max(1, Math.min(maxRows, fit))
}

// The list's height in rows of mixed size: window rows are rowHeight, tab rows tabHeight; at most maxRows rows count (the rest scroll).
function listHeight(entries, rowHeight, tabHeight, maxRows) {
  var h = 0, n = Math.min(entries.length, maxRows)
  for (var i = 0; i < n; i++) h += entries[i].tab ? tabHeight : rowHeight
  return h
}

// The picture of a tab card or row: its site icon file when the helper wrote one (a key of hex digits only), else the fallback (the browser's own icon).
function tabIcon(entry, dir, fallback) {
  var key = String(entry && entry.icon || "")
  return /^[0-9a-f]{16}$/.test(key) && dir ? "file://" + dir + "/" + key + ".png" : fallback
}

// The page picture of a tab card: its file when the helper wrote one (<hosthash>/<urlkey>-<n>[d]: 16 hex digits, a slash, 16 hex digits, a dash, digits, an optional d; nothing else is ever a path), else empty.
var pictureName = /^[0-9a-f]{16}\/[0-9a-f]{16}-[0-9]{1,12}d?$/
function tabPicture(entry, dir) {
  var name = String(entry && entry.picture || "")
  return pictureName.test(name) && dir ? "file://" + dir + "/" + name + ".jpg" : ""
}

// How a tab's picture was made: "shot" (exact, the browser photographed the tab), "drawn" (approximate, the page drawn from its content, name ends in d), "" for none.
function tabPictureKind(entry) {
  var name = String(entry && entry.picture || "")
  return !pictureName.test(name) ? "" : name.slice(-1) === "d" ? "drawn" : "shot"
}

// The caption of a tab card or row: its site, and a note when it is the tab its window shows.
function tabCaption(entry, activeNote) {
  var host = String(entry && entry.host || "")
  return entry && entry.active ? (host === "" ? activeNote : host + "  ·  " + activeNote) : host
}

// The card's border width in pixels. mode is "auto", "on" or "off"; hyprBorder is Hyprland's general:border_size (-1 while unknown); fallback is the width to use
// when a border is wanted but Hyprland's value cannot say (unknown, or 0 with mode "on").
function borderWidth(mode, hyprBorder, fallback) {
  if (mode === "off") return 0
  if (mode === "on") return hyprBorder > 0 ? hyprBorder : fallback
  if (hyprBorder === 0) return 0          // auto and the user turned window borders off: no outline
  return hyprBorder > 0 ? Math.max(1, hyprBorder) : fallback
}

// A Hyprland window address with or without the 0x prefix, lower case: how two sources name the same window.
function normalizeAddress(address) {
  return String(address || "").toLowerCase().replace(/^0x/, "")
}

// How many cards fit across before the strip scrolls: from the screen width, a card width and the gap, at most maxCards, at least 1.
function visibleCards(screenWidth, cardWidth, gap, maxCards) {
  var fit = Math.floor((screenWidth * 0.9 + gap) / (cardWidth + gap))
  return Math.max(1, Math.min(maxCards, fit))
}

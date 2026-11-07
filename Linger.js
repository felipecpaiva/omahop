.pragma library
// omahop linger keys: while the overlay holds the keyboard (search_linger_seconds), it owns the typed text and sends the WHOLE query to Lua with a
// sequence number, never a single key: each `hyprctl eval` is its own process and can land out of order, and Lua drops a seq older than the last
// one it applied. Pure, so Node tests it (tests/linger.test.mjs); LingerKeys.qml wires it to key events and a coalescing timer.

var KEYS = ["return", "escape", "up", "down", "left", "right"] // the names lua/omahop.lua M.overlay_keys accepts, plus "cancel" (a click outside)

// Text typed so far after one key. name is "backspace", one of KEYS, or "" for a key that only has text; text is the event's text.
// Returns { text, key }: the new text, and the key name to send to Lua now ("" for none). Escape with text typed clears it here (Lua then
// sees an empty query), so it never reaches Lua as a key; a second Escape does.
function reduce(current, name, text) {
  current = String(current || "")
  if (name === "backspace") return { text: Array.from(current).slice(0, -1).join(""), key: "" }
  if (name === "escape" && current !== "") return { text: "", key: "" }
  if (KEYS.indexOf(name) >= 0) return { text: current, key: name }
  var clean = String(text || "").replace(/[\u0000-\u001f\u007f]/g, "")
  return { text: current + clean, key: "" }
}

// The next sequence number: past both our own counter and what Lua last applied (the state's seq), so a restarted shell continues where Lua is.
function nextSeq(counter, stateSeq) {
  return Math.max(counter || 0, stateSeq || 0) + 1
}

// Whether the overlay should take Lua's query as its own text: nothing of ours waits to be sent and Lua has applied everything we sent
// (while Alt is held, Lua's own Alt + letter binds type, and Escape clears there).
function adopt(dirty, sentSeq, stateSeq) {
  return !dirty && (stateSeq || 0) >= (sentSeq || 0)
}

// A Lua single-quoted string literal for any text: backslash and quote escaped, control characters dropped (Lua strips them again).
function luaString(text) {
  return "'" + String(text || "").replace(/[\u0000-\u001f\u007f]/g, "").replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'"
}

// The code for one `hyprctl eval`: the query always (Lua ignores an unchanged one), then the key if any, in one process so they keep their order.
// Returns { code, last }: last is the highest seq used.
function code(seq, text, key) {
  var out = "_G.omahop.set_query(" + seq + ", " + luaString(text) + ")"
  if (!key) return { code: out, last: seq }
  return { code: out + "; _G.omahop.key(" + (seq + 1) + ", " + luaString(key) + ")", last: seq + 1 }
}

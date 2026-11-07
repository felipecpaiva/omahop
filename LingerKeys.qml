import QtQuick
import "Linger.js" as Linger

// The keyboard while the overlay holds it (setting search_linger_seconds): typed text, Backspace, arrows, Return and Escape go to Lua as the
// whole query with a sequence number (Linger.js). Keys with Alt, Ctrl or Super are left alone: chords with the held modifier (setting `modifier`) are omahop's own binds, the rest are not ours.
Item {
  id: keys

  property var st: null
  property var send: function (code) {}
  readonly property int coalesceMs: 30 // key repeat sends the latest text only, at most this often

  property string text: ""
  property bool dirty: false
  property int counter: 0
  property int sentSeq: 0

  focus: true

  onStChanged: {
    if (!keys.st || !keys.st.open) { keys.text = ""; keys.dirty = false; keys.sentSeq = 0; flushTimer.stop(); return }
    if (Linger.adopt(keys.dirty, keys.sentSeq, keys.st.seq)) keys.text = keys.st.query
  }

  function flush(key) {
    flushTimer.stop()
    var c = Linger.code(Linger.nextSeq(keys.counter, keys.st ? keys.st.seq : 0), keys.text, key)
    keys.counter = c.last
    keys.sentSeq = c.last
    keys.dirty = false
    keys.send(c.code)
  }

  // A click outside the list: close without picking.
  function cancel() {
    if (keys.st && keys.st.grab) keys.flush("cancel")
  }

  Timer {
    id: flushTimer
    interval: keys.coalesceMs
    onTriggered: if (keys.dirty) keys.flush("")
  }

  function nameOf(key) {
    switch (key) {
    case Qt.Key_Backspace: return "backspace"
    case Qt.Key_Return: case Qt.Key_Enter: return "return"
    case Qt.Key_Escape: return "escape"
    case Qt.Key_Up: return "up"
    case Qt.Key_Down: return "down"
    case Qt.Key_Left: return "left"
    case Qt.Key_Right: return "right"
    }
    return ""
  }

  Keys.onPressed: function (event) {
    if (!keys.st || !keys.st.grab) return
    if (event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier)) return
    event.accepted = true
    var r = Linger.reduce(keys.text, keys.nameOf(event.key), event.text)
    if (r.key !== "") { keys.text = r.text; keys.flush(r.key); return }
    if (r.text === keys.text) return
    keys.text = r.text
    keys.dirty = true
    if (!flushTimer.running) flushTimer.start()
  }
}

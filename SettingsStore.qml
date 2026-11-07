import QtQuick
import Quickshell
import Quickshell.Io
import "ConfigIO.js" as ConfigIO
import "Paths.js" as Paths

// Reads spec.json (the one definition of every setting) and reads and writes ~/.config/omahop/config.toml.
// The file text is the model: a change edits one line (ConfigIO.set), so comments and unknown keys survive every save.
// omahop re-reads the file when the next Alt+Tab starts, so nothing needs telling; only settings marked `reload` in the spec (takeover, modifier, same_app_key) need a Hyprland reload.
Item {
  id: store

  readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omahop"
  readonly property string path: dir + "/config.toml"

  property var spec: ({ groups: [] })
  property string text: ""
  property var parsed: ConfigIO.parse("")
  property bool loaded: false
  property string status: ""       // "", "Saving...", "Saved", or an error message
  property bool failed: false
  property bool needsReload: false // a setting that only applies after a Hyprland reload was changed
  readonly property bool pending: saveTimer.running

  function reload() { file.reload() }

  // The value in use: what the file says, else the default from the spec.
  function value(setting) {
    var bag = setting.section === "top" ? parsed.top : parsed.sections[setting.section]
    var v = bag ? bag[setting.key] : undefined
    return v === undefined ? setting.default : v
  }
  function isSet(setting) {
    var bag = setting.section === "top" ? parsed.top : parsed.sections[setting.section]
    return !!bag && bag[setting.key] !== undefined
  }

  function setValue(setting, v) {
    store.text = ConfigIO.set(store.text, setting.section, setting.key, v)
    store.changed(setting)
  }
  function resetValue(setting) {
    store.text = ConfigIO.unset(store.text, setting.section, setting.key)
    store.changed(setting)
  }
  function changed(setting) {
    store.parsed = ConfigIO.parse(store.text)
    if (setting.reload) store.needsReload = true
    store.status = ""
    saveTimer.restart()
  }

  function saveNow() {
    saveTimer.stop()
    store.status = "Saving..."
    store.failed = false
    mkdirProc.running = true
  }

  function reloadHyprland() { hyprReload.running = true }

  Process { id: mkdirProc; command: ["mkdir", "-p", store.dir]; onExited: file.setText(store.text) }
  Process { id: hyprReload; command: ["hyprctl", "reload"]; onExited: store.needsReload = false }

  Timer { id: saveTimer; interval: 450; onTriggered: store.saveNow() }
  Timer { interval: 2000; running: store.status === "Saved"; onTriggered: store.status = "" }

  FileView {
    id: specFile
    path: Paths.fromUrl(Qt.resolvedUrl("spec.json"))
    onLoaded: { try { store.spec = JSON.parse(text()) } catch (e) { store.status = "Could not read spec.json" } }
  }

  FileView {
    id: file
    path: store.path
    atomicWrites: true
    printErrors: false
    onLoaded: { store.text = text(); store.parsed = ConfigIO.parse(store.text); store.loaded = true }
    onLoadFailed: { store.text = ""; store.parsed = ConfigIO.parse(""); store.loaded = true }
    onSaved: store.status = "Saved"
    onSaveFailed: { store.failed = true; store.status = "Could not write " + store.path }
  }
}

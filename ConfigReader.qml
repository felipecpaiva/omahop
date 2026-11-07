import QtQuick
import Quickshell
import Quickshell.Io
import "ConfigIO.js" as ConfigIO
import "Paths.js" as Paths

// Reads the config file and the spec, and keeps the values in use current while the file changes. For parts of the overlay that run outside a switch session
// (the peek strip), which cannot wait for the Lua side to write a state file. Read only: the settings window is the one that writes.
// The values in use follow the same rule as the Lua side (ConfigIO.resolve mirrors lua/config.lua C.resolve): bad values fall back, the chosen profile is laid over the base.
Item {
  id: reader

  readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omahop/config.toml"
  property var settings: []
  property var parsed: ConfigIO.parse("")
  readonly property var resolved: ConfigIO.resolve(parsed, settings)

  // The value in use for "section.key" (section "top" for keys above the first table). Undefined until spec.json is read.
  function value(section, key) {
    return reader.resolved.values[section + "." + key]
  }

  FileView {
    path: Paths.fromUrl(Qt.resolvedUrl("spec.json"))
    onLoaded: {
      try { reader.settings = ConfigIO.flatSettings(JSON.parse(text())) } catch (e) {}
    }
  }

  FileView {
    path: reader.path
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: reader.parsed = ConfigIO.parse(text())
    onLoadFailed: reader.parsed = ConfigIO.parse("")
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import "ConfigIO.js" as ConfigIO
import "Paths.js" as Paths

// Reads the config file and the spec's defaults, and keeps them current while the file changes. For parts of the overlay that run outside a switch session
// (the peek strip), which cannot wait for the Lua side to write a state file. Read only: the settings window is the one that writes.
Item {
  id: reader

  readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omahop/config.toml"
  property var defaults: ({})
  property var parsed: ConfigIO.parse("")

  // The value in use: what the file says, else the spec's default ("section.key", with section "top" for keys above the first header).
  function value(section, key) {
    var bag = section === "top" ? parsed.top : parsed.sections[section]
    var v = bag ? bag[key] : undefined
    return v === undefined ? defaults[section + "." + key] : v
  }

  FileView {
    path: Paths.fromUrl(Qt.resolvedUrl("spec.json"))
    onLoaded: {
      try {
        var spec = JSON.parse(text()), d = {}
        for (var g = 0; g < spec.groups.length; g++)
          for (var i = 0; i < spec.groups[g].settings.length; i++) {
            var s = spec.groups[g].settings[i]
            d[s.section + "." + s.key] = s.default
          }
        reader.defaults = d
      } catch (e) {}
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

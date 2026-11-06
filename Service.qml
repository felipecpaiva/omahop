import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "State.js" as State

// omahop overlay. Watches the state file that lua/omahop.lua writes and draws the switcher while a session is revealed.
// It never takes the keyboard (Lua owns the keys) and never takes the pointer (empty input mask), so it cannot disturb focus.
Item {
  id: root

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null

  readonly property string statePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omahop/state"
  property var st: State.parse("")
  // The list model is replaced only when the windows themselves change, not on every selection change: replacing it rebuilds every row and reloads every icon.
  property var entries: []
  property string entriesKey: ""
  property var resolved: ({})

  // Hyprland's window border size (general:border_size), -1 until read. The card's outline follows it, so a user who removed window borders
  // does not get one on the card. Read at load, when the config reloads, and each time a session opens.
  property int hyprBorder: -1
  readonly property int outline: State.borderWidth(root.st.border, root.hyprBorder, Math.max(1, Style.space(2)))
  Process {
    id: borderProc
    command: ["hyprctl", "getoption", "general:border_size", "-j"]
    stdout: StdioCollector {
      onStreamFinished: { try { var v = JSON.parse(text).int; if (typeof v === "number") root.hyprBorder = v } catch (e) {} }
    }
  }
  function refreshBorder() { if (!borderProc.running) borderProc.running = true }
  Connections {
    target: Hyprland
    function onRawEvent(event) { if (event && String(event.name) === "configreloaded") root.refreshBorder() }
  }
  Connections {
    target: root
    function onStChanged() { if (root.st.open && !root.wasOpen) root.refreshBorder(); root.wasOpen = root.st.open }
  }
  property bool wasOpen: false

  function apply(text) {
    var next = State.parse(text)
    var key = next.entries.map(function (e) { return e.address + "|" + e.title + "|" + e.minimized }).join("\n")
    if (key !== root.entriesKey) {
      root.entriesKey = key
      root.entries = next.entries
    }
    root.st = next
  }

  // DesktopEntries is lazy: the first read is empty, so it is touched at load.
  Component.onCompleted: { var touch = DesktopEntries.applications.values.length; root.refreshBorder() }

  function resolve(appId) {
    if (root.resolved[appId] !== undefined) return root.resolved[appId]
    var result = lookup(appId)
    root.resolved[appId] = result
    return result
  }

  function lookup(appId) {
    var entry = DesktopEntries.heuristicLookup(appId)
    var icon = entry && entry.icon ? entry.icon : appId
    var library = root.shell ? root.shell.appLibrary : null
    var source = library ? library.iconSource(icon) : Quickshell.iconPath(icon)
    // No desktop entry and no icon of that name: a generic application icon, not the checkerboard of a missing image.
    if (!source || String(source) === "") source = Quickshell.iconPath("application-x-executable")
    return { icon: source, name: entry && entry.name ? entry.name : appId }
  }

  FileView {
    id: file
    path: root.statePath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.apply(text())
    onLoadFailed: root.apply("")
  }

  OverlayWindow {
    id: window
    shown: root.st.open && root.st.revealed
    shownKeyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "omahop"
    mask: Region {}

    ListStyle {
      anchors.centerIn: parent
      visible: window.contentRevealed
      entries: root.entries
      outline: root.outline
      selected: root.st.selected
      screenHeight: window.height
      resolve: root.resolve
    }
  }
}

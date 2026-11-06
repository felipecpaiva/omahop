import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "State.js" as State
import "Paths.js" as Paths

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

  // The launcher entry for the settings panel. Omarchy has no install hook, so the service writes a .desktop file at load and removes it at
  // destruction (the idiom omagnet uses). Only a file that carries our marker is ever written over or deleted.
  readonly property string desktopSource: Paths.fromUrl(Qt.resolvedUrl("omahop.desktop"))
  readonly property string desktopDest: Quickshell.env("HOME") + "/.local/share/applications/omahop.desktop"
  readonly property string desktopMarker: "^X-Omahop-Managed=true$"
  readonly property string installScript:
      '[ -f "$1" ] || exit 0\n'
    + 'if [ -e "$2" ] && ! grep -q "$3" "$2"; then exit 0; fi\n'
    + 'mkdir -p "${2%/*}" || exit 0\n'
    + 'tmp=$2.omahop.new\n'
    + 'cp "$1" "$tmp" || exit 0\n'
    + 'if cmp -s "$tmp" "$2"; then rm -f "$tmp"; else mv -f "$tmp" "$2"; fi\n'
  readonly property string removeScript: 'grep -q "$2" "$1" 2>/dev/null && rm -f "$1"\n'
  property bool desktopInstalled: false
  Component.onDestruction: {
    if (!root.desktopInstalled) return
    Quickshell.execDetached(["sh", "-c", root.removeScript, "sh", root.desktopDest, root.desktopMarker])
  }

  // DesktopEntries is lazy: the first read is empty, so it is touched at load.
  Component.onCompleted: {
    var touch = DesktopEntries.applications.values.length
    root.refreshBorder()
    if (root.desktopSource !== "") {
      root.desktopInstalled = true
      Quickshell.execDetached(["sh", "-c", root.installScript, "sh", root.desktopSource, root.desktopDest, root.desktopMarker])
    }
  }

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

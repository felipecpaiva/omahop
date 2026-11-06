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
    function onStChanged() { if (root.st.open && !root.wasOpen) { root.refreshBorder(); Hyprland.refreshToplevels() }; root.wasOpen = root.st.open }
  }
  property bool wasOpen: false

  function apply(text) {
    var next = State.parse(text)
    var key = next.entries.map(function (e) { return e.address + "|" + e.title + "|" + e.minimized }).join("\n")
    if (key !== root.entriesKey) {
      root.entriesKey = key
      root.entries = next.entries
      if (next.open && next.query === "") root.writeNames()
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

  // The Wayland toplevel to capture for a Hyprland window address, or null (a window with no toplevel, such as a Wine ghost, shows its icon instead).
  function toplevelFor(address) {
    var key = State.normalizeAddress(address)
    var all = Hyprland.toplevels.values
    for (var i = 0; i < all.length; i++) {
      if (State.normalizeAddress(all[i].address) === key) return all[i].wayland || null
    }
    return null
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

  // Display names of the windows' apps, for the Lua side to search by (it only knows window classes). Written when the full list is on show.
  FileView {
    id: namesFile
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omahop/names"
    atomicWrites: true
    printErrors: false
  }
  function writeNames() {
    var seen = {}, lines = []
    for (var i = 0; i < root.entries.length; i++) {
      var id = root.entries[i].appId
      if (seen[id]) continue
      seen[id] = true
      lines.push(id + "\t" + root.resolve(id).name)
    }
    namesFile.setText(lines.join("\n") + "\n")
  }

  FileView {
    id: file
    path: root.statePath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.apply(text())
    onLoadFailed: root.apply("")
  }

  // The pointer: a click on a row or card, and its close and minimize buttons, call into the Lua side through `hyprctl eval` from here (never the other way round:
  // hyprctl called from Lua would freeze the compositor). Arguments are checked here and again in Lua.
  function lua(code) { Quickshell.execDetached(["hyprctl", "eval", code]) }
  function pick(index) { if (Number.isInteger(index) && index >= 1) root.lua("_G.omahop.pick(" + index + ")") }
  function closeWindow(address) { if (/^0x[0-9a-fA-F]+$/.test(String(address))) root.lua("_G.omahop.close_window('" + address + "')") }
  function minimizeWindow(address) { if (/^0x[0-9a-fA-F]+$/.test(String(address))) root.lua("_G.omahop.minimize_window('" + address + "')") }

  // Where the rows or cards are on screen, one rectangle per line, for the live tests that click with a virtual mouse. Rewritten shortly after the list changes.
  FileView {
    id: geometryFile
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omahop/geometry"
    atomicWrites: true
    printErrors: false
  }
  Timer {
    id: geometryTimer
    interval: 120
    onTriggered: {
      var item = styleLoader.item
      geometryFile.setText(item && item.rects ? item.rects().join("\n") + "\n" : "")
    }
  }

  OverlayWindow {
    id: window
    shown: root.st.open && root.st.revealed
    shownKeyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "omahop"
    // The pointer is taken only over the card (and the search line); everywhere else clicks go through to the windows below.
    mask: Region { item: column }

    Column {
      id: column
      anchors.centerIn: parent
      spacing: Style.space(8)
      visible: window.contentRevealed

      SearchChip {
        anchors.horizontalCenter: parent.horizontalCenter
        query: root.st.query
        empty: root.entries.length === 0
        outline: root.outline
      }
      Loader {
        id: styleLoader
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.entries.length > 0
        onLoaded: geometryTimer.restart()
        sourceComponent: root.st.style === "cards" ? cardsStyle : listStyle
      }
    }

    Component {
      id: listStyle
      ListStyle {
        entries: root.entries
        selected: root.st.selected
        screenHeight: window.height
        resolve: root.resolve
        outline: root.outline
        actions: root.st.actions
        onPicked: function (index) { root.pick(index) }
        onCloseRequested: function (address) { root.closeWindow(address) }
        onMinimizeRequested: function (address) { root.minimizeWindow(address) }
        onEntriesChanged: geometryTimer.restart()
        onSelectedChanged: geometryTimer.restart()
      }
    }

    Component {
      id: cardsStyle
      CardsStyle {
        entries: root.entries
        selected: root.st.selected
        thumbnails: root.st.thumbnails
        screenWidth: window.width
        resolve: root.resolve
        toplevelFor: root.toplevelFor
        outline: root.outline
        actions: root.st.actions
        onPicked: function (index) { root.pick(index) }
        onCloseRequested: function (address) { root.closeWindow(address) }
        onMinimizeRequested: function (address) { root.minimizeWindow(address) }
        onEntriesChanged: geometryTimer.restart()
        onSelectedChanged: geometryTimer.restart()
      }
    }
  }
}

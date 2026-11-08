import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "State.js" as State
import "Paths.js" as Paths
import "IconResolve.js" as IconResolve
import "AudioMarker.js" as AudioMarker

// omahop overlay. Watches the state file that lua/omahop.lua writes and draws the switcher while a session is revealed.
// It takes the pointer only over its card, and the keyboard only when Lua says so (grab=1: setting search_linger_seconds, a search typed);
// then a click anywhere else closes the list, and Lua focuses the picked window only after the grab is gone.
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
    function onStChanged() {
      if (root.st.open && !root.wasOpen) { root.refreshBorder(); Hyprland.refreshToplevels() }
      if (root.st.open && root.st.revealed && root.audioSample === null) root.sampleAudio() // once per shown list; a quick tap shows none and samples nothing
      if (!root.st.open) root.audioSample = null // a closed list forgets the sample, so the next one never flashes a stale speaker
      root.wasOpen = root.st.open
    }
  }
  property bool wasOpen: false

  // ---- audio marker (setting audio_marker, off by default, D21): one pactl sample when the list shows, nothing while it is closed or on a quick tap.
  // The sample's text holds media titles: it is parsed in memory (AudioMarker.js keeps pids and app names only) and never logged or written.
  readonly property bool audioMarker: configReader.value("top", "audio_marker") === true
  property var audioSample: null
  function sampleAudio() { if (root.audioMarker && !audioProc.running) audioProc.running = true }
  Process {
    id: audioProc
    command: ["bash", Paths.fromUrl(Qt.resolvedUrl("tools/audio-sample.sh"))]
    stdout: StdioCollector {
      onStreamFinished: if (root.st.open && root.audioMarker) root.audioSample = AudioMarker.parseSample(text)
    }
  }
  // The windows that own a playing stream, by normalized address. Re-evaluated when the sample or Hyprland's window list (pid, class) changes.
  readonly property var audioPlaying: root.audioMarker && root.audioSample ? AudioMarker.playingAddresses(root.audioSample, root.audioWindows(), State.normalizeAddress) : ({})
  function audioWindows() {
    var all = Hyprland.toplevels.values, out = []
    for (var i = 0; i < all.length; i++) {
      var ipc = all[i].lastIpcObject || {}
      out.push({ address: all[i].address, pid: ipc.pid, appId: ipc.class })
    }
    return out
  }

  function apply(text) {
    var next = State.parse(text)
    var key = next.entries.map(function (e) { return e.address + "|" + e.title + "|" + e.minimized + "|" + (e.tab ? "t" + e.active + e.host : "") }).join("\n")
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
    if (root.tabFilesOn) Quickshell.execDetached(["bash", Paths.fromUrl(Qt.resolvedUrl("tools/omahop-tabs-files")), root.runtimeDir, "off"])
    if (!root.desktopInstalled) return
    Quickshell.execDetached(["sh", "-c", root.removeScript, "sh", root.desktopDest, root.desktopMarker])
  }

  // DesktopEntries is lazy: the first read is empty, so it is touched at load.
  Component.onCompleted: {
    var touch = DesktopEntries.applications.values.length
    root.refreshBorder()
    root.scanIcons()
    root.scanPack()
    packChanged.setText("0\n")
    if (root.desktopSource !== "") {
      root.desktopInstalled = true
      Quickshell.execDetached(["sh", "-c", root.installScript, "sh", root.desktopSource, root.desktopDest, root.desktopMarker])
    }
  }

  // Icon name -> file path. The shell hands its app library only to menu plugins, so omahop indexes the XDG icon folders itself
  // (tools/icon-index.sh). Nothing is cached before the scan ends, so no row keeps a missing icon.
  property var iconIndex: IconResolve.parseIndex("")
  property bool iconIndexReady: false
  // The icon theme to prefer (setting icon_theme, "" = none). The index is rebuilt when it changes; the scan in flight finishes first, then the rescan runs.
  readonly property string iconTheme: String(configReader.value("top", "icon_theme") || "")
  property string scannedTheme: ""
  onIconThemeChanged: root.scanIcons()
  function scanIcons() {
    if (iconScan.running) return
    root.scannedTheme = root.iconTheme
    iconScan.running = true
  }
  Process {
    id: iconScan
    command: ["bash", Paths.fromUrl(Qt.resolvedUrl("tools/icon-index.sh")), root.scannedTheme]
    onRunningChanged: if (!running && root.iconTheme !== root.scannedTheme) root.scanIcons()
    stdout: StdioCollector {
      onStreamFinished: {
        root.iconIndex = IconResolve.parseIndex(text)
        root.resolved = ({})
        root.iconIndexReady = true
      }
    }
  }

  // The hand-made icon pack (setting icon_pack, "" = none): a folder under ~/.config/omahop/packs, listed and checked by tools/pack-index.sh,
  // which writes why it refused a file or the pack to stderr (shown in the shell log). Its icons come before the system index. A separate scan, so
  // changing the pack never reruns the slow system scan; rescanned the same way as the theme.
  readonly property string iconPack: String(configReader.value("top", "icon_pack") || "")
  property string scannedPack: ""
  property var packIndex: IconResolve.parseIndex("")
  onIconPackChanged: root.scanPack()
  function scanPack() {
    if (packScan.running) return
    root.scannedPack = root.iconPack
    packScan.running = true
  }
  Process {
    id: packScan
    command: ["bash", Paths.fromUrl(Qt.resolvedUrl("tools/pack-index.sh")), root.scannedPack]
    onRunningChanged: if (!running && root.iconPack !== root.scannedPack) root.scanPack()
    stdout: StdioCollector {
      onStreamFinished: {
        root.packIndex = IconResolve.parseIndex(text)
        root.resolved = ({})
      }
    }
    stderr: StdioCollector {
      onStreamFinished: if (text.trim() !== "") console.warn(text.trim())
    }
  }

  // The settings window's pack editor writes this file after it changed a pack; the pack is rescanned (never the system index). Written once
  // here at load so the watch has a file to watch.
  FileView {
    id: packChanged
    path: root.runtimeDir + "/pack-changed"
    watchChanges: true
    printErrors: false
    onFileChanged: root.scanPack()
  }

  function resolve(appId) {
    if (root.resolved[appId] !== undefined) return root.resolved[appId]
    var result = lookup(appId)
    if (root.iconIndexReady) root.resolved[appId] = result
    return result
  }

  // The Wayland toplevel to capture for a Hyprland window address, or null (a window with no toplevel, such as a Wine ghost, or an app in thumbnail_exclude, shows its icon instead).
  // Classes from the live config that are never captured (State.thumbnailExcludeSet); the check is here so no capture object exists for them.
  readonly property var thumbExcluded: State.thumbnailExcludeSet(configReader.value("top", "thumbnail_exclude"))
  function toplevelFor(address, appId) {
    if (State.isThumbnailExcluded(root.thumbExcluded, appId)) return null
    var key = State.normalizeAddress(address)
    var all = Hyprland.toplevels.values
    for (var i = 0; i < all.length; i++) {
      if (State.normalizeAddress(all[i].address) === key) return all[i].wayland || null
    }
    return null
  }

  function lookup(appId) {
    var entry = DesktopEntries.heuristicLookup(appId)
    var path = IconResolve.resolve(root.iconIndex, appId, entry && entry.icon ? entry.icon : "", [root.packIndex])
    // Nothing in any icon folder, not even a generic one: the themed name, which the image provider may still know.
    var source = path !== "" ? "file://" + path : Quickshell.iconPath(entry && entry.icon ? entry.icon : appId)
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
  function focusWindow(address, minimized) { if (/^0x[0-9a-fA-F]+$/.test(String(address))) root.lua("_G.omahop.focus_window('" + address + "', " + (minimized === true ? "true" : "false") + ")") }
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

  // ---- the peek strip: only loaded when the setting is on (off by default, so nothing is added to the desktop unless asked)
  ConfigReader { id: configReader }

  // ---- browser tabs (setting browser_tabs, off by default): the flag and ignore files follow the setting at once, from the settings window too.
  // The Lua side does the same at a Hyprland reload and at the next Alt+Tab; the helper is idempotent. Off with nothing on: nothing runs.
  readonly property bool browserTabs: configReader.value("top", "browser_tabs") === true
  readonly property string browserTabsIgnore: String(configReader.value("top", "browser_tabs_ignore") || "")
  readonly property bool browserTabPreviews: root.browserTabs && configReader.value("top", "browser_tab_previews") === true
  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omahop"
  property bool tabFilesOn: false
  function syncTabFiles() {
    if (!root.browserTabs && !root.tabFilesOn) return
    root.tabFilesOn = root.browserTabs
    // the raw items; tools/omahop-tabs-files keeps only valid names (no shell: arguments go straight to bash)
    var sites = root.browserTabs ? root.browserTabsIgnore.split(",").map(function (x) { return x.trim() }).filter(function (x) { return x !== "" }) : []
    Quickshell.execDetached(["bash", Paths.fromUrl(Qt.resolvedUrl("tools/omahop-tabs-files")), root.runtimeDir, root.browserTabs ? "on" : "off"].concat(sites))
  }
  // The pictures flag follows the setting (and tab search) at once; pictures-off also removes every picture. Idempotent, like the call above.
  property bool tabPicturesOn: false
  function syncTabPictures() {
    if (!root.browserTabPreviews && !root.tabPicturesOn) return
    root.tabPicturesOn = root.browserTabPreviews
    Quickshell.execDetached(["bash", Paths.fromUrl(Qt.resolvedUrl("tools/omahop-tabs-files")), root.runtimeDir, root.browserTabPreviews ? "pictures-on" : "pictures-off"])
  }
  onBrowserTabPreviewsChanged: root.syncTabPictures()
  onBrowserTabsChanged: root.syncTabFiles()
  onBrowserTabsIgnoreChanged: if (root.browserTabs) root.syncTabFiles()

  // The stock dock's and the bar's edges (from the shell's own config), so the strip can default to a free edge. Empty if unknown (Omarchy's defaults apply: dock bottom, bar top).
  property string dockPosition: ""
  property string barPosition: ""
  FileView {
    path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { var d = JSON.parse(text()); root.dockPosition = d.dock && d.dock.position ? String(d.dock.position) : ""; root.barPosition = d.bar && d.bar.position ? String(d.bar.position) : "" } catch (e) { root.dockPosition = ""; root.barPosition = "" } }
  }

  Variants {
    model: configReader.value("top", "peek") === "off" || configReader.value("top", "peek") === undefined ? [] : Quickshell.screens
    PeekStrip {
      required property var modelData
      modelScreen: modelData
      reader: configReader
      service: root
      dockPosition: root.dockPosition
      barPosition: root.barPosition
    }
  }

  OverlayWindow {
    id: window
    shown: root.st.open && root.st.revealed
    shownKeyboardFocus: root.st.grab ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "omahop"
    // The pointer is taken only over the card (and the search line); everywhere else clicks go through to the windows below.
    // While the overlay holds the keyboard, the whole screen is ours (Hyprland sends every click to an exclusive layer anyway) and a click off the card cancels.
    mask: Region { item: root.st.grab ? backdrop : column }

    MouseArea {
      id: backdrop
      anchors.fill: parent
      enabled: root.st.grab
      acceptedButtons: Qt.AllButtons
      onPressed: function (mouse) {
        var p = mapToItem(column, mouse.x, mouse.y)
        if (!column.contains(p)) lingerKeys.cancel()
      }
    }

    LingerKeys {
      id: lingerKeys
      st: root.st
      send: root.lua
    }

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
      CountdownLine {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(160)
        visible: root.st.lingerMs > 0
        duration: root.st.lingerMs
        rev: root.st.lingerRev
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
        tabIconDir: root.runtimeDir + "/tabicons"
        outline: root.outline
        actions: root.st.actions
        playing: root.audioPlaying
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
        tabIconDir: root.runtimeDir + "/tabicons"
        tabPictureDir: root.runtimeDir + "/tabpics"
        toplevelFor: root.toplevelFor
        outline: root.outline
        actions: root.st.actions
        playing: root.audioPlaying
        onPicked: function (index) { root.pick(index) }
        onCloseRequested: function (address) { root.closeWindow(address) }
        onMinimizeRequested: function (address) { root.minimizeWindow(address) }
        onEntriesChanged: geometryTimer.restart()
        onSelectedChanged: geometryTimer.restart()
      }
    }
  }
}

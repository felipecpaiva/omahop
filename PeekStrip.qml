import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Ui
import "PeekModel.js" as PeekModel

// The peek strip (opt-in, setting `peek`): a slim row of the running apps on one screen edge. Hover an app for a card per window (picture, title, close and minimize),
// click a card or the app to go to that window. One instance per screen. Nothing here runs unless the setting is on (the Service loads this component only then).
PanelWindow {
  id: win

  required property var modelScreen   // the Quickshell screen this strip lives on
  property var reader: null           // ConfigReader
  property var service: null          // Service.qml: resolve(), toplevelFor(), focusWindow(), closeWindow(), minimizeWindow()
  property string dockPosition: ""    // the stock dock's edge, "" if unknown
  property string barPosition: ""     // the bar's edge, "" if unknown

  screen: modelScreen
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.namespace: "omahop-peek"

  readonly property string edge: PeekModel.resolvePosition(reader.value("top", "peek_position"), dockPosition, barPosition)
  readonly property bool vertical: PeekModel.isVertical(edge)
  readonly property bool always: reader.value("top", "peek") === "always"
  readonly property string thumbnails: reader.value("top", "thumbnails")
  readonly property bool actions: reader.value("top", "actions") === true

  readonly property int slot: Style.space(48)
  readonly property int pad: Style.space(8)
  readonly property int cardW: Style.space(220)
  readonly property int cardH: Style.space(176)
  readonly property int gap: Style.space(8)
  readonly property int hotSize: 2
  readonly property int popupRoom: cardH + 2 * pad + gap

  anchors {
    left: win.edge !== "right"
    right: win.edge !== "left"
    top: win.edge !== "bottom"
    bottom: win.edge !== "top"
  }
  implicitWidth: win.vertical ? win.slot + 2 * win.pad + win.gap + win.cardW + 2 * win.pad : 0
  implicitHeight: win.vertical ? 0 : win.slot + 2 * win.pad + win.gap + win.popupRoom

  // ---- the model: every window Hyprland knows, grouped by app (PeekModel.group)
  property int revision: 0
  readonly property var groups: {
    void win.revision
    var out = [], values = Hyprland.toplevels.values, monitors = Hyprland.monitors.values
    var screenName = win.modelScreen ? win.modelScreen.name : ""
    for (var i = 0; i < values.length; i++) {
      var t = values[i], ipc = t.lastIpcObject || {}
      var wl = t.wayland
      if (!wl || wl.parent) continue
      var ws = t.workspace ? String(t.workspace.name) : ""
      var tags = ipc.tags || []
      var mon = ""
      for (var m = 0; m < monitors.length; m++) if (monitors[m].id === ipc.monitor) mon = monitors[m].name
      out.push({ address: String(t.address).indexOf("0x") === 0 ? String(t.address) : "0x" + t.address, appId: String(wl.appId || ""), title: String(wl.title || ""),
        workspace: ws, floating: tags.indexOf("omarchy-floating-workspace") >= 0, minimized: ws === "special:minimized", monitor: mon })
    }
    return PeekModel.group(out, { onlyFloating: true, monitor: screenName })
  }

  property bool revealed: win.always
  property int hovered: -1          // the strip slot under the pointer, -1 none
  readonly property var shownGroup: win.hovered >= 0 && win.hovered < win.groups.length ? win.groups[win.hovered] : null

  // Hyprland's window details (tags, monitor) are only refreshed on request: refresh when the strip appears and while it is up.
  Timer { interval: 2000; running: win.revealed; repeat: true; triggeredOnStart: true; onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshMonitors(); win.revision++ } }

  Timer {
    id: hideTimer
    interval: 450   // long enough to cross the gap between the edge, the strip and a popup
    onTriggered: if (!win.always && !stripHover.hovered && !popupHover.hovered && !hotHover.hovered) { win.revealed = false; win.hovered = -1 }
  }
  Timer {
    id: popupHideTimer
    interval: 250
    onTriggered: if (!popupHover.hovered && !slotsHoverCount()) win.hovered = -1
  }
  function slotsHoverCount() { return stripHover.hovered && win.hovered >= 0 }

  mask: Region {
    item: win.revealed && win.groups.length > 0 ? strip : null
    Region { item: !win.always && !win.revealed ? hot : null }
    Region { item: win.shownGroup ? popup : null }
  }

  // Where the slots and the popup cards are on screen, for the live tests that click with a virtual mouse (nothing else reads this). Rewritten shortly after anything moves.
  FileView {
    id: geometry
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omahop/peek-geometry-" + (win.modelScreen ? win.modelScreen.name : "x")
    atomicWrites: true
    printErrors: false
  }
  // The window's top-left corner on the screen: a strip window is only as big as it needs to be, so its own coordinates are not the screen's.
  readonly property real originX: win.anchors.left ? 0 : (win.modelScreen ? win.modelScreen.width : 0) - win.width
  readonly property real originY: win.anchors.top ? 0 : (win.modelScreen ? win.modelScreen.height : 0) - win.height
  Timer {
    id: geometryTimer
    interval: 150
    onTriggered: {
      var lines = []
      if (win.revealed) {
        for (var i = 0; i < slotRepeater.count; i++) {
          var it = slotRepeater.itemAt(i)
          if (!it) continue
          var p = it.mapToItem(null, 0, 0)
          lines.push(["slot", it.modelData.appId, Math.round(win.originX + p.x), Math.round(win.originY + p.y), Math.round(it.width), Math.round(it.height)].join(","))
        }
        for (var j = 0; j < cardRepeater.count; j++) {
          var c = cardRepeater.itemAt(j)
          if (!c) continue
          var q = c.mapToItem(null, 0, 0)
          lines.push(["card", c.modelData.address, Math.round(win.originX + q.x), Math.round(win.originY + q.y), Math.round(c.width), Math.round(c.height)].join(","))
        }
      }
      geometry.setText(lines.join("\n") + (lines.length ? "\n" : ""))
    }
  }
  onGroupsChanged: geometryTimer.restart()
  onHoveredChanged: geometryTimer.restart()
  onRevealedChanged: geometryTimer.restart()

  // The thin strip along the screen edge that reveals the strip.
  Item {
    id: hot
    width: win.vertical ? win.hotSize : win.width
    height: win.vertical ? win.height : win.hotSize
    x: win.edge === "right" ? win.width - width : 0
    y: win.edge === "bottom" ? win.height - height : 0
    HoverHandler { id: hotHover; onHoveredChanged: if (hovered) { win.revealed = true; hideTimer.stop() } else hideTimer.restart() }
  }

  // ---- the strip
  BorderSurface {
    id: strip
    visible: win.revealed && win.groups.length > 0
    readonly property int along: win.groups.length * win.slot + 2 * win.pad
    readonly property int across: win.slot + 2 * win.pad
    width: win.vertical ? across : along
    height: win.vertical ? along : across
    x: win.vertical ? (win.edge === "right" ? win.width - width : 0) : (win.width - width) / 2
    y: win.vertical ? (win.height - height) / 2 : (win.edge === "bottom" ? win.height - height : 0)
    color: Util.alpha(Color.background, 0.97)
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
    radius: Style.cornerRadius

    HoverHandler { id: stripHover; onHoveredChanged: if (hovered) hideTimer.stop(); else { hideTimer.restart(); popupHideTimer.restart() } }

    Flow {
      anchors.fill: parent
      anchors.margins: win.pad
      flow: win.vertical ? Flow.TopToBottom : Flow.LeftToRight
      Repeater {
        id: slotRepeater
        model: win.groups
        Item {
          id: appSlot
          required property var modelData
          required property int index
          width: win.slot; height: win.slot
          readonly property var info: win.service.resolve(modelData.appId)
          readonly property bool allMinimized: modelData.windows.every(function (w) { return w.minimized })

          Rectangle {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            radius: Style.cornerRadius
            color: win.hovered === appSlot.index ? Style.selectedFillFor(Color.foreground, Color.accent, Color.urgent) : "transparent"
          }
          IconImage {
            anchors.centerIn: parent
            implicitSize: Style.space(32)
            source: appSlot.info.icon
            opacity: appSlot.allMinimized ? 0.55 : 1
          }
          // how many windows the app has, when more than one
          Rectangle {
            visible: modelData.windows.length > 1
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: Style.space(3)
            width: badge.implicitWidth + Style.space(8); height: badge.implicitHeight + Style.space(2)
            radius: height / 2
            color: Color.accent
            Text { id: badge; anchors.centerIn: parent; textFormat: Text.PlainText; text: appSlot.modelData.windows.length; color: Color.background; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
          }
          HoverHandler { onHoveredChanged: if (hovered) { win.hovered = appSlot.index; popupHideTimer.stop() } else popupHideTimer.restart() }
          // a click goes to the app's first window that is not minimized, else its first window
          MouseArea {
            anchors.fill: parent
            onClicked: {
              var ws = appSlot.modelData.windows, pick = ws[0]
              for (var i = 0; i < ws.length; i++) if (!ws[i].minimized) { pick = ws[i]; break }
              win.service.focusWindow(pick.address, pick.minimized)
            }
          }
        }
      }
    }
  }

  // ---- the popup: a card per window of the hovered app
  BorderSurface {
    id: popup
    visible: win.shownGroup !== null
    readonly property int count: win.shownGroup ? Math.min(win.shownGroup.windows.length, 5) : 0
    readonly property int along: count * win.cardW + Math.max(0, count - 1) * win.gap + 2 * win.pad
    readonly property int across: win.cardH + 2 * win.pad
    width: win.vertical ? across : along
    height: win.vertical ? along : across
    // centred on the hovered slot along the strip, kept inside the window
    readonly property real centre: strip.x + (win.vertical ? 0 : win.pad + (win.hovered + 0.5) * win.slot)
    readonly property real centreY: strip.y + (win.vertical ? win.pad + (win.hovered + 0.5) * win.slot : 0)
    x: win.vertical ? (win.edge === "right" ? strip.x - win.gap - width : strip.x + strip.width + win.gap) : Math.max(0, Math.min(win.width - width, centre - width / 2))
    y: win.vertical ? Math.max(0, Math.min(win.height - height, centreY - height / 2)) : (win.edge === "bottom" ? strip.y - win.gap - height : strip.y + strip.height + win.gap)
    color: Util.alpha(Color.background, 0.97)
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
    radius: Style.cornerRadius

    HoverHandler { id: popupHover; onHoveredChanged: if (hovered) { hideTimer.stop(); popupHideTimer.stop() } else { hideTimer.restart(); popupHideTimer.restart() } }

    Flow {
      anchors.fill: parent
      anchors.margins: win.pad
      spacing: win.gap
      flow: win.vertical ? Flow.TopToBottom : Flow.LeftToRight
      Repeater {
        id: cardRepeater
        model: win.shownGroup ? win.shownGroup.windows.slice(0, 5) : []
        CardItem {
          required property var modelData
          width: win.cardW; height: win.cardH
          readonly property var info: win.service.resolve(modelData.appId)
          iconSource: info.icon
          appName: info.name
          title: modelData.title
          minimized: modelData.minimized
          thumbnails: win.thumbnails
          toplevel: win.service.toplevelFor(modelData.address)
          actions: win.actions
          onPicked: win.service.focusWindow(modelData.address, modelData.minimized)
          onCloseRequested: win.service.closeWindow(modelData.address)
          onMinimizeRequested: win.service.minimizeWindow(modelData.address)
        }
      }
    }
  }
}

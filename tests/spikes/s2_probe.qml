// Spike S2: thumbnails of our three coloured test windows (class omahop-A, -B, -C) in an overlay while the workspace is visible, so one is
// occluded and one is minimized. Logs one line per view: appId, hasContent, sourceSize. Env: S2_LIVE=1|0, S2_REPEAT=n copies of each view.
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
  id: root
  readonly property bool live: Quickshell.env("S2_LIVE") !== "0"
  readonly property int repeat: parseInt(Quickshell.env("S2_REPEAT") || "1")
  PanelWindow {
    anchors { top: true; left: true }
    margins { top: 60; left: 40 }
    implicitWidth: 1200; implicitHeight: 700
    color: "#222"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    Flow {
      anchors.fill: parent; spacing: 6
      Repeater {
        model: ToplevelManager.toplevels
        delegate: Repeater {
          id: rep
          required property var modelData
          model: (modelData.appId.indexOf("omahop-") === 0) ? repeat : 0
          delegate: Rectangle {
            required property int index
            width: 190; height: 120; color: "#444"
            ScreencopyView {
              id: sv
              anchors.fill: parent
              captureSource: rep.modelData
              live: root.live
              onHasContentChanged: console.log("S2: " + rep.modelData.appId + "#" + index + " hasContent=" + hasContent + " size=" + sourceSize.width + "x" + sourceSize.height + " minimized=" + rep.modelData.minimized)
            }
            Text { text: rep.modelData.appId + (rep.modelData.minimized ? " (min)" : ""); color: "white"; font.pixelSize: 11 }
          }
        }
      }
    }
  }
}

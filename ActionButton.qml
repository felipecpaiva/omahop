import QtQuick
import qs.Commons
import qs.Ui

// A small square button drawn with plain shapes (no icon font): kind "close" (a cross) or "minimize" (a bar). Pure presentation, emits clicked().
Item {
  id: btn

  property string kind: "close"
  readonly property bool hovered: hover.hovered
  signal clicked()

  implicitWidth: Style.space(24)
  implicitHeight: Style.space(24)

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: btn.hovered ? Util.alpha(btn.kind === "close" ? Color.urgent : Color.popups.text, 0.35) : Util.alpha(Color.popups.text, 0.12)
  }

  // minimize: one bar
  Rectangle {
    visible: btn.kind === "minimize"
    anchors.centerIn: parent
    width: parent.width * 0.46; height: Math.max(2, Style.space(2))
    color: Color.popups.text
  }
  // close: two crossed bars
  Repeater {
    model: btn.kind === "close" ? [45, -45] : []
    Rectangle {
      required property int modelData
      anchors.centerIn: parent
      width: btn.width * 0.5; height: Math.max(2, Style.space(2))
      rotation: modelData
      color: Color.popups.text
    }
  }

  HoverHandler { id: hover }
  MouseArea { anchors.fill: parent; onClicked: btn.clicked() }
}

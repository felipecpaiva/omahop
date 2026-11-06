import QtQuick
import Quickshell.Widgets
import qs.Commons
import qs.Ui

// One row of the list style: app icon, app name, window title. Pure presentation: the caller resolves icon and name.
Item {
  id: row

  property string iconSource: ""
  property string appName: ""
  property string title: ""
  property bool selected: false
  property bool minimized: false
  property bool actions: true   // show the close and minimize buttons while the pointer is over the row
  property string hint: ""      // a number or letter that jumps here (empty for none); shown in the place of the buttons until the pointer arrives
  readonly property bool hovered: hover.hovered

  signal picked()
  signal closeRequested()
  signal minimizeRequested()

  implicitHeight: Style.space(46)
  opacity: row.minimized ? 0.6 : 1

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    // Hover is visual only: a light fill, clearly weaker than the keyboard selection. Nothing is told to Lua on hover.
    color: row.selected ? Style.selectedFillFor(Color.foreground, Color.accent, Color.urgent) : (row.hovered ? Util.alpha(Color.popups.text, 0.07) : "transparent")
  }

  HoverHandler { id: hover }
  MouseArea { anchors.fill: parent; onClicked: row.picked() }

  Rectangle {
    visible: row.hint !== "" && !(row.actions && row.hovered)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(24); height: Style.space(24)
    radius: Style.cornerRadius
    color: Util.alpha(Color.popups.text, 0.12)
    Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: row.hint; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
  }

  Row {
    id: buttons
    anchors.right: parent.right
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(6)
    opacity: row.actions && row.hovered ? 1 : 0
    visible: row.actions
    ActionButton { kind: "minimize"; onClicked: row.minimizeRequested() }
    ActionButton { kind: "close"; onClicked: row.closeRequested() }
  }

  IconImage {
    id: icon
    anchors.left: parent.left
    anchors.leftMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    implicitSize: Style.space(28)
    source: row.iconSource
  }

  Column {
    anchors.left: icon.right
    anchors.leftMargin: Style.space(12)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(12) + (row.actions ? Style.space(60) : 0)
    anchors.verticalCenter: parent.verticalCenter

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: row.appName
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
      maximumLineCount: 1
    }
    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: row.title
      color: Util.alpha(Color.popups.text, 0.65)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }
}

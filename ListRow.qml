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

  implicitHeight: Style.space(46)
  opacity: row.minimized ? 0.6 : 1

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: row.selected ? Style.selectedFillFor(Color.foreground, Color.accent, Color.urgent) : "transparent"
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
    anchors.rightMargin: Style.space(12)
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

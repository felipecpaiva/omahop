import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons

// The icon builder's app list: open windows first, then installed apps (PackEditor.appRows). Each row shows the icon in use (the draft's, else the system's), the name, and a
// dot when the draft changes the app. A ListView, so only the rows on screen exist. Draws what it is given; BuilderPage owns the data, the filter and the keys.
ListView {
  id: list

  property var rows: []
  property int cursor: 0
  property int rev: 0
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily

  signal clicked(int index)

  clip: true
  boundsBehavior: Flickable.StopAtBounds
  model: list.rows
  onCursorChanged: if (list.cursor >= 0 && list.cursor < list.rows.length) list.positionViewAtIndex(list.cursor, ListView.Contain)

  delegate: Rectangle {
    required property var modelData
    required property int index
    width: list.width
    height: Style.space(40)
    radius: Style.cornerRadius
    color: index === list.cursor ? Qt.rgba(list.accent.r, list.accent.g, list.accent.b, 0.22) : "transparent"

    MouseArea { anchors.fill: parent; onClicked: list.clicked(index) }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.spacing.sm
      anchors.rightMargin: Style.spacing.sm
      spacing: Style.spacing.sm
      Image {
        Layout.preferredWidth: Style.space(26)
        Layout.preferredHeight: Style.space(26)
        sourceSize.width: Style.space(26)
        sourceSize.height: Style.space(26)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        source: modelData.packPath ? "file://" + modelData.packPath + "?v=" + list.rev : Quickshell.iconPath(modelData.icon || modelData.key || "", "application-x-executable")
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: modelData.name
          color: list.foreground
          font.family: list.fontFamily
          font.pixelSize: Style.font.body
          font.bold: index === list.cursor
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          visible: modelData.running
          textFormat: Text.PlainText
          text: "open"
          color: Qt.darker(list.foreground, 1.6)
          font.family: list.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
      Rectangle {
        visible: modelData.changed
        Layout.preferredWidth: Style.space(8)
        Layout.preferredHeight: Style.space(8)
        radius: width / 2
        color: list.accent
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: list.rows.length === 0
    textFormat: Text.PlainText
    text: "No app matches"
    color: Qt.darker(list.foreground, 1.6)
    font.family: list.fontFamily
    font.pixelSize: Style.font.body
  }
}

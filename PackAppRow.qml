import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Ui

// One app in the pack editor's list: the icon it gets now (the pack's, else the system's), its name and id, and the two actions.
// Draws a row from PackEditor.appRows; decides nothing.
Item {
  id: row

  property var app: ({})
  property bool busy: false
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily

  signal chooseImage()
  signal removeIcon()

  implicitHeight: Style.space(44)

  RowLayout {
    anchors.fill: parent
    spacing: Style.spacing.sm

    // The pack file without Qt's image cache, so a replaced icon shows at once.
    Image {
      visible: !!row.app.packPath
      Layout.preferredWidth: Style.space(28)
      Layout.preferredHeight: Style.space(28)
      sourceSize.width: Style.space(28)
      sourceSize.height: Style.space(28)
      fillMode: Image.PreserveAspectFit
      cache: false
      asynchronous: true
      source: row.app.packPath ? "file://" + row.app.packPath : ""
    }
    IconImage {
      visible: !row.app.packPath
      implicitSize: Style.space(28)
      source: row.app.packPath ? "" : Quickshell.iconPath(row.app.icon || row.app.key || "", "application-x-executable")
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: row.app.name || ""
        color: row.foreground
        font.family: row.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: (row.app.running ? "open, " : "") + (row.app.key || "") + (row.app.packFile ? ", pack icon " + row.app.packFile : ", system icon")
        color: Qt.darker(row.foreground, 1.6)
        font.family: row.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideMiddle
      }
    }

    Button {
      text: "Choose image"
      enabled: !row.busy
      foreground: row.foreground
      accent: row.accent
      fontFamily: row.fontFamily
      fontSize: Style.font.caption
      onClicked: row.chooseImage()
    }
    Button {
      visible: !!row.app.packFile
      text: "Remove"
      enabled: !row.busy
      foreground: row.foreground
      accent: row.accent
      fontFamily: row.fontFamily
      fontSize: Style.font.caption
      onClicked: row.removeIcon()
    }
  }
}

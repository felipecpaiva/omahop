import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons

// The icon builder's preview: the switcher's own list row (ListRow) and card (CardItem), fed the draft icon the way the switcher feeds them (a file url, else the system
// icon name's source). Only data goes in; no window is captured (thumbnails "off", no toplevel). `rows` are builder app rows (BuilderPage), the first one is the chosen app.
Rectangle {
  id: preview

  property var rows: []
  property int rev: 0
  property var nowPath: ({})      // {app key: file the base theme gives}, for the apps whose lookup has run
  property color foreground: Color.menu.text

  implicitHeight: Style.space(112)
  radius: Style.cornerRadius
  color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)

  function source(row) {
    if (row.packPath) return "file://" + row.packPath + "?v=" + preview.rev
    if (preview.nowPath[row.key]) return "file://" + preview.nowPath[row.key]
    return Quickshell.iconPath(row.icon || row.key || "", "application-x-executable")
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: Style.spacing.sm
    spacing: Style.spacing.md

    Column {
      Layout.preferredWidth: Style.space(250)
      Layout.fillHeight: true
      spacing: Style.space(2)
      Repeater {
        model: preview.rows.slice(0, 2)
        ListRow {
          required property var modelData
          required property int index
          width: parent.width
          iconSource: preview.source(modelData)
          appName: modelData.name
          title: modelData.key
          selected: index === 0
          actions: false
        }
      }
    }

    Row {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.spacing.sm
      Repeater {
        model: preview.rows.slice(0, 3)
        CardItem {
          required property var modelData
          required property int index
          width: Style.space(104)
          height: parent.height
          thumbnails: "off"
          iconSource: preview.source(modelData)
          appName: modelData.name
          title: modelData.key
          selected: index === 0
          actions: false
        }
      }
    }
  }
}

import QtQuick
import QtQuick.Layouts
import qs.Commons

// One choice of the icon picker: its name, a mark when it is the saved value, and the same sample app icons every choice shows.
// Draws what it is given and decides nothing (IconPickerPage.qml owns the data and the keys). `icons` holds a file path per sample app, "" for an app the choice has no icon for.
Rectangle {
  id: card

  property string title: ""
  property string help: ""
  property var icons: []
  property bool highlighted: false   // the keyboard cursor is here
  property bool saved: false         // this is the value in the settings file now
  property real iconSize: Style.space(32)
  property bool interactive: true
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily

  signal clicked()
  signal activated()

  implicitHeight: iconSize + Style.space(20)
  radius: Style.cornerRadius
  color: highlighted ? Qt.rgba(accent.r, accent.g, accent.b, 0.22) : "transparent"
  border.width: saved ? Math.max(1, Style.space(1)) : 0
  border.color: accent

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.spacing.sm
    anchors.rightMargin: Style.spacing.sm
    spacing: Style.spacing.md

    ColumnLayout {
      Layout.preferredWidth: Style.space(150)
      Layout.maximumWidth: Style.space(150)
      spacing: 0
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: (card.saved ? "✓ " : "") + card.title
        color: card.foreground
        font.family: card.fontFamily
        font.pixelSize: Style.font.body
        font.bold: card.highlighted
        elide: Text.ElideRight
      }
      Text {
        visible: card.help !== ""
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: card.help
        color: Qt.darker(card.foreground, 1.6)
        font.family: card.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Row {
      Layout.fillWidth: true
      spacing: Style.spacing.sm
      Repeater {
        model: card.icons
        Item {
          required property string modelData
          width: card.iconSize
          height: card.iconSize
          Image {
            anchors.fill: parent
            visible: modelData !== ""
            sourceSize.width: card.iconSize
            sourceSize.height: card.iconSize
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            source: modelData === "" ? "" : "file://" + modelData
          }
          // an app this choice has no icon for: a faint outline, so the gap is honest and the row keeps its shape
          Rectangle {
            anchors.centerIn: parent
            visible: modelData === ""
            width: parent.width * 0.6
            height: width
            radius: width / 4
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b, 0.3)
          }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: card.interactive
    onClicked: card.clicked()
    onDoubleClicked: card.activated()
  }
}

import QtQuick
import qs.Commons

// The icon builder's search results: one cell per icon the search found (picture, name, theme). Lazy: a GridView creates only the cells on screen, so only those pictures
// are decoded however many results there are. Draws what it is given; BuilderPage owns the data and the keys.
GridView {
  id: grid

  property var results: []        // [{theme, name, path}] from icon-find.sh
  property int cursor: 0
  property string note: ""         // shown in the middle when there is nothing to list
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily
  readonly property int columns: Math.max(1, Math.floor(grid.width / grid.cellWidth))

  signal clicked(int index)
  signal activated(int index)

  clip: true
  cellWidth: Style.space(92)
  cellHeight: Style.space(86)
  boundsBehavior: Flickable.StopAtBounds
  model: grid.results
  onCursorChanged: if (grid.cursor >= 0 && grid.cursor < grid.results.length) grid.positionViewAtIndex(grid.cursor, GridView.Contain)

  delegate: Item {
    required property var modelData
    required property int index
    width: grid.cellWidth
    height: grid.cellHeight
    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(2)
      radius: Style.cornerRadius
      color: index === grid.cursor ? Qt.rgba(grid.accent.r, grid.accent.g, grid.accent.b, 0.22) : "transparent"
      border.width: index === grid.cursor ? 1 : 0
      border.color: grid.accent
    }
    Image {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Style.space(6)
      width: Style.space(40)
      height: width
      sourceSize.width: width
      sourceSize.height: width
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      source: "file://" + modelData.path
    }
    Column {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(4)
      anchors.margins: Style.space(4)
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: modelData.name
        color: grid.foreground
        font.family: grid.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideMiddle
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: modelData.theme
        color: Qt.darker(grid.foreground, 1.6)
        font.family: grid.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
    MouseArea {
      anchors.fill: parent
      onClicked: grid.clicked(index)
      onDoubleClicked: grid.activated(index)
    }
  }

  Text {
    anchors.centerIn: parent
    visible: grid.results.length === 0 && grid.note !== ""
    width: parent.width - Style.space(20)
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    text: grid.note
    color: Qt.darker(grid.foreground, 1.6)
    font.family: grid.fontFamily
    font.pixelSize: Style.font.body
  }
}

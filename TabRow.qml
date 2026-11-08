import QtQuick
import Quickshell.Widgets
import qs.Commons
import qs.Ui

// One browser tab in the list style (setting browser_tabs): a compact line under its window, with the browser's own icon (no favicons),
// the tab title and its site. A small accent dot marks the tab its window shows. Pure presentation; no buttons (a tab row never closes the window).
Item {
  id: row

  property string iconSource: ""
  property string title: ""
  property string caption: ""   // the site, and a note for the shown tab (State.tabCaption)
  property bool active: false
  property bool asleep: false   // Chrome put the tab to sleep: a small dim "asleep" after the site
  property string nopic: ""     // why the tab has no picture, as a short sentence (State.nopicText); shown the same way, "asleep" wins
  readonly property string note: asleep ? qsTr("asleep") : nopic
  property bool selected: false
  readonly property bool hovered: hover.hovered

  signal picked()

  implicitHeight: Style.space(32)

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: row.selected ? Style.selectedFillFor(Color.foreground, Color.accent, Color.urgent) : (row.hovered ? Util.alpha(Color.popups.text, 0.07) : "transparent")
  }

  HoverHandler { id: hover }
  MouseArea { anchors.fill: parent; onClicked: row.picked() }

  // Indented to sit under the window row's icon.
  Rectangle {
    id: dot
    anchors.left: parent.left
    anchors.leftMargin: Style.space(30)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(6); height: width; radius: width / 2
    color: row.active ? Color.accent : "transparent"
  }

  IconImage {
    id: icon
    anchors.left: dot.right
    anchors.leftMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    implicitSize: Style.space(18)
    source: row.iconSource
  }

  Text {
    id: titleText
    anchors.left: icon.right
    anchors.leftMargin: Style.space(10)
    anchors.right: captionText.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: row.title
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
    maximumLineCount: 1
  }

  Text {
    id: asleepText
    visible: row.note !== ""
    anchors.right: parent.right
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: row.note
    color: Util.alpha(Color.popups.text, 0.4)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.italic: true
  }

  Text {
    id: captionText
    anchors.right: row.note !== "" ? asleepText.left : parent.right
    anchors.rightMargin: row.note !== "" ? Style.space(8) : Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, row.width * 0.35)
    textFormat: Text.PlainText
    text: row.caption
    color: Util.alpha(Color.popups.text, 0.55)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    elide: Text.ElideMiddle
    maximumLineCount: 1
  }
}

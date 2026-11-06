import QtQuick
import Quickshell.Widgets
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// One card of the cards style: a window thumbnail with the app icon and title under it. Pure presentation: the caller resolves icon, name and the toplevel to capture.
Item {
  id: card

  property var toplevel: null          // a Wayland Toplevel to capture, or null (icon only)
  property string thumbnails: "snapshot"  // "live", "snapshot" or "off"
  property string iconSource: ""
  property string appName: ""
  property string title: ""
  property bool selected: false
  property bool minimized: false
  property bool actions: true   // show the close and minimize buttons while the pointer is over the card
  readonly property bool hovered: hover.hovered

  signal picked()
  signal closeRequested()
  signal minimizeRequested()

  readonly property int pad: Style.space(8)
  readonly property int footer: Style.space(34)
  // A view is created only for a card that can show one: never for "off", never without a toplevel (L6 in docs/lessons-from-others.md).
  readonly property bool capturing: card.thumbnails !== "off" && card.toplevel !== null

  opacity: card.minimized ? 0.7 : 1

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    // Hover is visual only: a light fill, clearly weaker than the keyboard selection. Nothing is told to Lua on hover.
    color: card.selected ? Style.selectedFillFor(Color.foreground, Color.accent, Color.urgent) : Util.alpha(Color.popups.text, card.hovered ? 0.1 : 0.04)
    border.width: card.selected ? Math.max(1, Style.space(2)) : 0
    border.color: Color.accent
  }

  HoverHandler { id: hover }
  MouseArea { anchors.fill: parent; onClicked: card.picked() }

  Item {
    id: thumb
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: card.pad
    height: parent.height - card.footer - 2 * card.pad
    clip: true

    Rectangle { anchors.fill: parent; radius: Style.cornerRadius; color: Util.alpha(Color.popups.text, 0.06) }

    // The thumbnail keeps the window's own shape and sits in the middle of its box.
    Loader {
      id: capture
      active: card.capturing
      anchors.centerIn: parent
      readonly property real sw: item ? item.sourceSize.width : 0
      readonly property real sh: item ? item.sourceSize.height : 0
      readonly property real fitScale: (sw > 0 && sh > 0) ? Math.min(thumb.width / sw, thumb.height / sh) : 1
      width: sw > 0 ? sw * fitScale : thumb.width
      height: sh > 0 ? sh * fitScale : thumb.height
      visible: item ? item.hasContent : false
      sourceComponent: ScreencopyView {
        captureSource: card.toplevel
        live: card.thumbnails === "live"
      }
    }

    // No picture (icons only, a window that cannot be captured, or a frame not here yet): the app icon in the middle.
    IconImage {
      anchors.centerIn: parent
      visible: !capture.visible
      implicitSize: Math.min(thumb.width, thumb.height) * 0.4
      source: card.iconSource
    }
  }

  Row {
    id: buttons
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: card.pad + Style.space(4)
    spacing: Style.space(6)
    opacity: card.actions && card.hovered ? 1 : 0
    visible: card.actions
    ActionButton { kind: "minimize"; onClicked: card.minimizeRequested() }
    ActionButton { kind: "close"; onClicked: card.closeRequested() }
  }

  Row {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: card.pad
    height: card.footer - card.pad
    spacing: Style.space(8)

    IconImage {
      anchors.verticalCenter: parent.verticalCenter
      implicitSize: Style.space(20)
      source: card.iconSource
    }
    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - Style.space(28)
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: card.appName
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        elide: Text.ElideRight
        maximumLineCount: 1
      }
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: card.title
        color: Util.alpha(Color.popups.text, 0.65)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        maximumLineCount: 1
      }
    }
  }
}

import QtQuick
import Quickshell.Widgets
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "AudioMarker.js" as AudioMarker

// One card of the cards style: a window thumbnail with the app icon and title under it. Pure presentation: the caller resolves icon, name and the toplevel to capture.
Item {
  id: card

  property var toplevel: null          // a Wayland Toplevel to capture, or null (icon only)
  property string thumbnails: "snapshot"  // "live", "snapshot" or "off"
  property string iconSource: ""
  property string picture: ""   // a tab card (setting browser_tab_previews): the picture of its page, a file url; empty for none
  property bool asleep: false   // a tab Chrome put to sleep (no page in memory): marked so
  property string nopic: ""     // why a tab card has no picture, as a short sentence (State.nopicText); empty for none. "asleep" wins when both apply
  property bool drawn: false    // its picture was drawn from the page's content, not photographed: approximate, marked so
  property string appName: ""
  property string title: ""
  property bool selected: false
  property bool minimized: false
  property bool actions: true   // show the close and minimize buttons while the pointer is over the card
  property string hint: ""      // a number or letter that jumps here (empty for none)
  property bool playing: false  // its app is playing sound (setting audio_marker): a small speaker after the app name
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

    // A browser tab's page picture (a file the helper keeps in memory, a small jpeg): shown while it is loaded; until then, and when there is none, the icon below.
    Image {
      id: page
      anchors.fill: parent
      visible: status === Image.Ready
      source: card.picture
      asynchronous: true
      cache: false
      fillMode: Image.PreserveAspectCrop
      horizontalAlignment: Image.AlignTop
    }

    // A drawn picture (setting browser_tab_previews_draw) is a rough render of the page, so it says so; a photographed one carries nothing.
    Rectangle {
      visible: card.drawn && page.visible
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(4)
      width: approx.implicitWidth + Style.space(10); height: approx.implicitHeight + Style.space(4)
      radius: Style.cornerRadius
      color: Util.alpha(Color.background, 0.85)
      border.width: 1; border.color: Util.alpha(Color.popups.text, 0.3)
      Text { id: approx; anchors.centerIn: parent; textFormat: Text.PlainText; text: qsTr("approximate"); color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
    }

    // A tab Chrome discarded (Memory Saver) has no page in memory, so it has no fresh picture; say so, with or without an older picture.
    // The same corner says why any other tab card has no picture (a Chrome page, too heavy, queued, ...).
    Rectangle {
      visible: card.asleep || card.nopic !== ""
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: Style.space(4)
      width: asleepText.implicitWidth + Style.space(10); height: asleepText.implicitHeight + Style.space(4)
      radius: Style.cornerRadius
      color: Util.alpha(Color.background, 0.85)
      border.width: 1; border.color: Util.alpha(Color.popups.text, 0.3)
      Text { id: asleepText; anchors.centerIn: parent; textFormat: Text.PlainText; text: card.asleep ? qsTr("asleep") : card.nopic; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
    }

    // No picture (icons only, a window that cannot be captured, or a frame not here yet): the app icon in the middle.
    IconImage {
      anchors.centerIn: parent
      visible: !capture.visible && !page.visible
      implicitSize: Math.min(thumb.width, thumb.height) * 0.4
      source: card.iconSource
    }
  }

  Rectangle {
    visible: card.hint !== "" && !(card.actions && card.hovered)
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: card.pad + Style.space(4)
    width: Style.space(24); height: Style.space(24)
    radius: Style.cornerRadius
    color: Util.alpha(Color.background, 0.85)
    border.width: 1; border.color: Util.alpha(Color.popups.text, 0.3)
    Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: card.hint; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
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
      Row {
        width: parent.width
        spacing: Style.space(4)
        Text {
          width: Math.min(implicitWidth, parent.width - (speaker.visible ? speaker.width + parent.spacing : 0))
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
          id: speaker
          visible: card.playing
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: AudioMarker.GLYPH
          color: Util.alpha(Color.popups.text, 0.8)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
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

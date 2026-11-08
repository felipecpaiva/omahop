import QtQuick
import qs.Commons
import qs.Ui
import "State.js" as State

// The cards style: a horizontal strip of CardItem with thumbnails. Keyboard only in v0.2 (the overlay takes no pointer). It only draws what it is given.
BorderSurface {
  id: strip

  property var entries: []
  property int selected: 1
  property string thumbnails: "snapshot"
  property real screenWidth: 1280
  property bool actions: true
  property var playing: ({})   // normalized window address -> true while its app plays sound (setting audio_marker); empty when off

  signal picked(int index)
  signal closeRequested(string address)
  signal minimizeRequested(string address)

  // Where each visible card is, in window coordinates (the live tests click on these; nothing else uses them).
  function rects() {
    var out = []
    for (var i = 0; i < view.count; i++) {
      var it = view.itemAtIndex(i)
      if (!it) continue
      var p = it.mapToItem(null, 0, 0)
      out.push([Math.round(p.x), Math.round(p.y), Math.round(it.width), Math.round(it.height)].join(","))
    }
    return out
  }
  property int outline: Math.max(1, Style.space(2))
  // The owner supplies these, so this file needs no desktop-entry or Hyprland knowledge.
  property string tabIconDir: ""   // folder of the site icons the helper writes (setting browser_tabs)
  property string tabPictureDir: ""   // folder of the page pictures the helper writes (setting browser_tab_previews)
  property var resolve: function (appId) { return { icon: "", name: appId } }
  property var toplevelFor: function (address, appId) { return null }

  readonly property int cardWidth: Style.space(220)
  readonly property int cardHeight: Style.space(176)
  readonly property int gap: Style.space(10)
  readonly property int pad: Style.space(12)
  readonly property int cards: State.visibleCards(strip.screenWidth, strip.cardWidth, strip.gap, 7)

  width: Math.min(strip.entries.length, strip.cards) * strip.cardWidth + Math.max(0, Math.min(strip.entries.length, strip.cards) - 1) * strip.gap + 2 * strip.pad + borderLeft + borderRight
  height: strip.cardHeight + 2 * strip.pad + borderTop + borderBottom
  color: Util.alpha(Color.background, 0.97)
  borderSpec: strip.outline > 0 ? Border.surfaceSpec("popups", "border", Color.popups.border, strip.outline) : Border.none()
  radius: Style.cornerRadius

  ListView {
    id: view
    anchors.fill: parent
    anchors.topMargin: strip.borderTop + strip.pad
    anchors.bottomMargin: strip.borderBottom + strip.pad
    anchors.leftMargin: strip.borderLeft + strip.pad
    anchors.rightMargin: strip.borderRight + strip.pad
    orientation: ListView.Horizontal
    spacing: strip.gap
    clip: true
    interactive: false
    // Cards outside the strip are not built, so no capture runs for a window that is not on screen.
    cacheBuffer: 0
    model: strip.entries
    function follow() { if (strip.selected >= 1) positionViewAtIndex(strip.selected - 1, ListView.Contain) }
    onCountChanged: Qt.callLater(follow)
    Connections {
      target: strip
      function onSelectedChanged() { Qt.callLater(view.follow) }
    }

    delegate: CardItem {
      required property var modelData
      required property int index
      width: strip.cardWidth
      height: view.height
      readonly property var info: strip.resolve(modelData.appId)
      iconSource: modelData.tab ? State.tabIcon(modelData, strip.tabIconDir, info.icon) : info.icon
      picture: modelData.tab ? State.tabPicture(modelData, strip.tabPictureDir) : ""
      // a browser tab (setting browser_tabs) is a card with the browser icon, its site as the caption, no picture and no buttons
      appName: modelData.tab ? State.tabCaption(modelData, qsTr("shown")) : info.name
      title: modelData.title
      minimized: modelData.minimized
      thumbnails: strip.thumbnails
      toplevel: modelData.tab ? null : strip.toplevelFor(modelData.address, modelData.appId)
      selected: index === strip.selected - 1
      actions: strip.actions && !modelData.tab
      hint: modelData.hint || ""
      playing: !modelData.tab && strip.playing[State.normalizeAddress(modelData.address)] === true
      onPicked: strip.picked(index + 1)
      onCloseRequested: strip.closeRequested(modelData.address)
      onMinimizeRequested: strip.minimizeRequested(modelData.address)
    }
  }
}

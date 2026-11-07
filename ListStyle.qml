import QtQuick
import qs.Commons
import qs.Ui
import "State.js" as State

// The list style: a vertical card of ListRow. It only draws what it is given; Service.qml owns the state.
BorderSurface {
  id: card

  property var entries: []
  property int selected: 1
  property real screenHeight: 1080
  property bool actions: true

  signal picked(int index)
  signal closeRequested(string address)
  signal minimizeRequested(string address)

  // Where each visible row is, in window coordinates (the live tests click on these; nothing else uses them).
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
  // Outline width in pixels, 0 for none; the owner decides (it follows Hyprland's window border by default).
  property int outline: Math.max(1, Style.space(2))
  // Resolve an app id to { icon, name }: supplied by the owner so this file needs no desktop-entry knowledge.
  property var resolve: function (appId) { return { icon: "", name: appId } }

  readonly property int rowHeight: Style.space(46)
  readonly property int tabHeight: Style.space(32)   // a browser tab row (TabRow), compact under its window
  readonly property int rows: State.visibleRows(card.screenHeight, card.rowHeight, 9)
  readonly property int pad: Style.space(10)

  width: Style.space(560) + borderLeft + borderRight + 2 * pad
  height: State.listHeight(card.entries, card.rowHeight, card.tabHeight, card.rows) + 2 * pad + borderTop + borderBottom
  color: Util.alpha(Color.background, 0.97)
  borderSpec: card.outline > 0 ? Border.surfaceSpec("popups", "border", Color.popups.border, card.outline) : Border.none()
  radius: Style.cornerRadius

  ListView {
    id: view
    anchors.fill: parent
    anchors.topMargin: card.borderTop + card.pad
    anchors.bottomMargin: card.borderBottom + card.pad
    anchors.leftMargin: card.borderLeft + card.pad
    anchors.rightMargin: card.borderRight + card.pad
    clip: true
    interactive: false
    model: card.entries
    // The highlight comes straight from `selected`, not from currentIndex: a ListView resets currentIndex to 0 whenever its model is
    // replaced (every state file change replaces it), which left the highlight on row 1.
    function follow() { if (card.selected >= 1) positionViewAtIndex(card.selected - 1, ListView.Contain) }
    onCountChanged: Qt.callLater(follow)
    Connections {
      target: card
      function onSelectedChanged() { Qt.callLater(view.follow) }
    }

    delegate: Item {
      id: slot
      required property var modelData
      required property int index
      width: view.width
      height: slot.modelData.tab ? card.tabHeight : card.rowHeight
      readonly property var info: card.resolve(slot.modelData.appId)
      readonly property bool isSelected: slot.index === card.selected - 1

      Loader {
        anchors.fill: parent
        sourceComponent: slot.modelData.tab ? tabRow : windowRow
      }
      Component {
        id: windowRow
        ListRow {
          iconSource: slot.info.icon
          appName: slot.info.name
          title: slot.modelData.title
          minimized: slot.modelData.minimized
          selected: slot.isSelected
          actions: card.actions
          hint: slot.modelData.hint || ""
          onPicked: card.picked(slot.index + 1)
          onCloseRequested: card.closeRequested(slot.modelData.address)
          onMinimizeRequested: card.minimizeRequested(slot.modelData.address)
        }
      }
      Component {
        id: tabRow
        TabRow {
          iconSource: slot.info.icon
          title: slot.modelData.title
          caption: State.tabCaption(slot.modelData, qsTr("shown"))
          active: slot.modelData.active === true
          selected: slot.isSelected
          onPicked: card.picked(slot.index + 1)
        }
      }
    }
  }
}

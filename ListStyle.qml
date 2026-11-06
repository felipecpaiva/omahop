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
  // Resolve an app id to { icon, name }: supplied by the owner so this file needs no desktop-entry knowledge.
  property var resolve: function (appId) { return { icon: "", name: appId } }

  readonly property int rowHeight: Style.space(46)
  readonly property int rows: State.visibleRows(card.screenHeight, card.rowHeight, 9)
  readonly property int pad: Style.space(10)

  width: Style.space(560) + borderLeft + borderRight + 2 * pad
  height: Math.min(card.entries.length, card.rows) * card.rowHeight + 2 * pad + borderTop + borderBottom
  color: Util.alpha(Color.background, 0.97)
  borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
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
    currentIndex: card.selected - 1
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    delegate: ListRow {
      required property var modelData
      required property int index
      width: view.width
      height: card.rowHeight
      readonly property var info: card.resolve(modelData.appId)
      iconSource: info.icon
      appName: info.name
      title: modelData.title
      minimized: modelData.minimized
      selected: index === view.currentIndex
    }
  }
}

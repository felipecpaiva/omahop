import QtQuick
import qs.Commons

// A thin line under the search that runs from full to empty while the list lingers (setting search_linger_seconds). It restarts whenever the
// state's linger revision changes (each key); Lua owns the real deadline, this only shows it.
Item {
  id: line

  property int duration: 0
  property int rev: 0
  property real progress: 1

  implicitHeight: Math.max(1, Style.space(2))

  function restart() {
    if (line.duration > 0) countdown.restart()
  }
  onRevChanged: line.restart()
  onDurationChanged: line.restart()

  NumberAnimation {
    id: countdown
    target: line
    property: "progress"
    from: 1
    to: 0
    duration: line.duration
  }

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    height: parent.height
    width: parent.width * line.progress
    radius: height / 2
    color: Color.accent
  }
}

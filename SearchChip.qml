import QtQuick
import qs.Commons
import qs.Ui

// The line above the list while the user is typing: what they typed, or a note that nothing matches. It shows only when there is a query.
BorderSurface {
  id: chip

  property string query: ""
  property bool empty: false
  property int outline: Math.max(1, Style.space(2))

  visible: chip.query !== ""
  width: label.implicitWidth + 2 * Style.space(14) + borderLeft + borderRight
  height: label.implicitHeight + 2 * Style.space(8) + borderTop + borderBottom
  color: Util.alpha(Color.background, 0.97)
  borderSpec: chip.outline > 0 ? Border.surfaceSpec("popups", "border", Color.popups.border, chip.outline) : Border.none()
  radius: Style.cornerRadius

  Text {
    id: label
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: chip.empty ? chip.query + "  (no window matches)" : chip.query
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.bold: !chip.empty
  }
}

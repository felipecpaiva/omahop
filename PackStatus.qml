import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// The pack editor's status: the last result or refusal, the question an import or a replacing export waits on, and the typed path field
// shown when the file picker could not open. Draws PackEditor.js state; the page acts on the signals.
ColumnLayout {
  id: status

  property var editor: ({})
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily

  signal confirmed(bool replace)
  signal cancelled()
  signal pathGiven(string path)

  readonly property var ask: status.editor.phase === "confirm" ? status.editor.confirm : null
  readonly property var summary: status.ask && status.ask.summary ? status.ask.summary : null

  spacing: Style.spacing.xs
  visible: !!status.editor.message || !!status.ask || !!status.editor.manualPath

  Text {
    visible: !!status.editor.message
    Layout.fillWidth: true
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    text: status.editor.message || ""
    color: status.editor.error ? Color.urgent : status.foreground
    font.family: status.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    visible: !!status.ask
    Layout.fillWidth: true
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    text: !status.ask ? "" : status.ask.kind === "export"
      ? "The zip is already there. Replace it?"
      : "Install " + status.summary.name + " by " + status.summary.author + " (" + status.summary.license + "), " + status.summary.icons
        + " icons, into " + status.summary.target + "?" + (status.ask.replace ? " A pack of that name is installed and will be replaced." : "")
    color: status.foreground
    font.family: status.fontFamily
    font.pixelSize: Style.font.caption
  }
  RowLayout {
    visible: !!status.ask
    spacing: Style.spacing.xs
    Button {
      text: status.ask && status.ask.replace ? "Replace" : "Install"
      bordered: true
      foreground: status.foreground
      accent: status.accent
      fontFamily: status.fontFamily
      onClicked: status.confirmed(status.ask.replace)
    }
    Button {
      text: "Cancel"
      foreground: status.foreground
      accent: status.accent
      fontFamily: status.fontFamily
      onClicked: status.cancelled()
    }
  }

  RowLayout {
    visible: !!status.editor.manualPath
    Layout.fillWidth: true
    spacing: Style.spacing.xs
    TextField {
      id: pathField
      Layout.fillWidth: true
      placeholderText: "Full path of the file, starting with /"
      foreground: status.foreground
      accent: status.accent
      onAccepted: status.pathGiven(pathField.text)
    }
    Button {
      text: "Use this file"
      foreground: status.foreground
      accent: status.accent
      fontFamily: status.fontFamily
      onClicked: status.pathGiven(pathField.text)
    }
  }
}

import QtQuick
import qs.Commons
import qs.Ui

// The pack editor's top row: a button per installed pack, New pack, Import a zip, and Export for the chosen pack. Signals only.
Flow {
  id: chooser

  property var packs: []
  property string folder: ""
  property bool creating: false
  property bool busy: false
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily

  signal chosen(string name)
  signal createRequested()
  signal importRequested()
  signal exportRequested()

  spacing: Style.spacing.xs

  Repeater {
    model: chooser.packs
    Button {
      required property string modelData
      text: modelData
      bordered: modelData === chooser.folder && !chooser.creating
      foreground: chooser.foreground
      accent: chooser.accent
      fontFamily: chooser.fontFamily
      onClicked: chooser.chosen(modelData)
    }
  }
  Button {
    text: "New pack"
    bordered: chooser.creating
    foreground: chooser.foreground
    accent: chooser.accent
    fontFamily: chooser.fontFamily
    onClicked: chooser.createRequested()
  }
  Button {
    text: "Import a zip"
    enabled: !chooser.busy
    foreground: chooser.foreground
    accent: chooser.accent
    fontFamily: chooser.fontFamily
    onClicked: chooser.importRequested()
  }
  Button {
    visible: chooser.folder !== ""
    text: "Export to ~/" + chooser.folder + ".omahop-pack.zip"
    enabled: !chooser.busy
    foreground: chooser.foreground
    accent: chooser.accent
    fontFamily: chooser.fontFamily
    onClicked: chooser.exportRequested()
  }
}

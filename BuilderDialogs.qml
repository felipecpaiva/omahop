import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Builder.js" as Builder

// The builder's dialogs, one at a time, drawn over the page: the Save as pack form, the Saved state (Use it now, Close), the list of installed packs to open, and the three
// Replace/Cancel questions (the pack name is taken, discard the draft, open a pack over a draft with changes). It decides nothing: BuilderPage runs the commands on the signals.
Item {
  id: dialogs

  property string kind: ""   // "", "save", "saved", "packs", "replace", "discard", "force"
  property string subject: ""   // the pack name the question or the Saved state is about
  property var packs: []
  property string message: ""   // the last refusal, shown in the form
  property int count: 0   // icons in the draft
  property string baseTitle: ""
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily
  property string licence: Builder.LICENCES[0]

  signal saveRequested(string name, string author, string licence)
  signal closed()
  signal useNow()
  signal confirmed()
  signal packChosen(string name)

  visible: kind !== ""
  onKindChanged: if (kind === "save") { nameField.text = dialogs.subject !== "" ? dialogs.subject : Builder.DEFAULT_NAME; Qt.callLater(function () { nameField.forceActiveFocus(); nameField.selectAll() }) }
                 else if (kind !== "") Qt.callLater(function () { sink.forceActiveFocus() })

  function submit() { dialogs.saveRequested(nameField.text, authorField.text, dialogs.licence) }
  readonly property bool asking: kind === "replace" || kind === "discard" || kind === "force"

  Rectangle {
    anchors.fill: parent
    color: Color.menu.scrim
    MouseArea { anchors.fill: parent; onClicked: if (!dialogs.asking) dialogs.closed() }
  }

  // Keys for every dialog but the form (its fields have their own).
  Item {
    id: sink
    Keys.onPressed: function (event) {
      if (dialogs.asking) { event.accepted = ask.handleKey(event); return }
      if (event.key === Qt.Key_Escape) { dialogs.closed(); event.accepted = true }
      else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && dialogs.kind === "saved") { dialogs.useNow(); event.accepted = true }
    }
  }

  ConfirmDialog {
    id: ask
    anchors.fill: parent
    opened: dialogs.asking
    message: dialogs.kind === "replace" ? "A pack named " + dialogs.subject + " is already installed. Replace it with this draft?"
      : dialogs.kind === "force" ? "The draft has changes. Replace them with a copy of " + dialogs.subject + "?"
      : "Discard the draft? Its " + dialogs.count + " icons are lost."
    confirmText: dialogs.kind === "replace" ? "Replace" : dialogs.kind === "force" ? "Replace" : "Discard"
    cancelText: "Cancel"
    selectedIndex: 0
    foreground: dialogs.foreground
    background: Color.menu.background
    fontFamily: dialogs.fontFamily
    onCanceled: dialogs.closed()
    onConfirmed: dialogs.confirmed()
  }

  Rectangle {
    id: card
    visible: !dialogs.asking
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(32), Style.space(440))
    height: col.implicitHeight + Style.space(32)
    radius: Style.cornerRadius
    color: Color.menu.background
    border.width: 1
    border.color: dialogs.accent
    MouseArea { anchors.fill: parent }

    ColumnLayout {
      id: col
      anchors.fill: parent
      anchors.margins: Style.space(16)
      spacing: Style.spacing.sm

      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: dialogs.kind === "save" ? "Save as pack" : dialogs.kind === "saved" ? "Saved" : "Open a pack"
        color: dialogs.foreground
        font.family: dialogs.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      // ---- the form
      ColumnLayout {
        visible: dialogs.kind === "save"
        Layout.fillWidth: true
        spacing: Style.spacing.xs
        TextField {
          id: nameField
          Layout.fillWidth: true
          placeholderText: "Pack name"
          foreground: dialogs.foreground
          accent: dialogs.accent
          Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) { dialogs.closed(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { dialogs.submit(); event.accepted = true }
          }
        }
        TextField {
          id: authorField
          Layout.fillWidth: true
          placeholderText: "Author (your name, optional)"
          foreground: dialogs.foreground
          accent: dialogs.accent
          Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) { dialogs.closed(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { dialogs.submit(); event.accepted = true }
          }
        }
        Text { textFormat: Text.PlainText; text: "Licence"; color: Qt.darker(dialogs.foreground, 1.6); font.family: dialogs.fontFamily; font.pixelSize: Style.font.caption }
        Flow {
          Layout.fillWidth: true
          spacing: Style.spacing.xs
          Repeater {
            model: Builder.LICENCES
            Button {
              required property string modelData
              text: modelData
              bordered: dialogs.licence === modelData
              foreground: dialogs.foreground; accent: dialogs.accent; fontFamily: dialogs.fontFamily; fontSize: Style.font.caption
              onClicked: dialogs.licence = modelData
            }
          }
        }
        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "Icons copied from a theme keep that theme's own licence. Pick a licence you may give to icons you did not draw." + (dialogs.baseTitle !== "" ? " Based on: " + dialogs.baseTitle + "." : "")
          color: Qt.darker(dialogs.foreground, 1.6)
          font.family: dialogs.fontFamily
          font.pixelSize: Style.font.caption
        }
        Text {
          visible: dialogs.message !== ""
          Layout.fillWidth: true
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: dialogs.message
          color: Color.urgent
          font.family: dialogs.fontFamily
          font.pixelSize: Style.font.caption
        }
        RowLayout {
          spacing: Style.spacing.sm
          Button { text: "Save"; bordered: true; foreground: dialogs.foreground; accent: dialogs.accent; fontFamily: dialogs.fontFamily; onClicked: dialogs.submit() }
          Button { text: "Cancel"; foreground: dialogs.foreground; accent: dialogs.accent; fontFamily: dialogs.fontFamily; onClicked: dialogs.closed() }
        }
      }

      // ---- saved
      ColumnLayout {
        visible: dialogs.kind === "saved"
        Layout.fillWidth: true
        spacing: Style.spacing.sm
        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "The pack " + dialogs.subject + " is installed. The draft is empty again."
          color: dialogs.foreground
          font.family: dialogs.fontFamily
          font.pixelSize: Style.font.caption
        }
        RowLayout {
          spacing: Style.spacing.sm
          Button { text: "Use it now"; bordered: true; foreground: dialogs.foreground; accent: dialogs.accent; fontFamily: dialogs.fontFamily; onClicked: dialogs.useNow() }
          Button { text: "Close"; foreground: dialogs.foreground; accent: dialogs.accent; fontFamily: dialogs.fontFamily; onClicked: dialogs.closed() }
        }
      }

      // ---- installed packs
      ColumnLayout {
        visible: dialogs.kind === "packs"
        Layout.fillWidth: true
        spacing: Style.spacing.xs
        Text {
          Layout.fillWidth: true
          visible: dialogs.packs.length === 0
          textFormat: Text.PlainText
          text: "No installed packs yet."
          color: Qt.darker(dialogs.foreground, 1.6)
          font.family: dialogs.fontFamily
          font.pixelSize: Style.font.caption
        }
        ListView {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(contentHeight, Style.space(220))
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: dialogs.packs
          delegate: Button {
            required property string modelData
            width: ListView.view.width
            text: modelData
            foreground: dialogs.foreground; accent: dialogs.accent; fontFamily: dialogs.fontFamily
            onClicked: dialogs.packChosen(modelData)
          }
        }
        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "The pack is copied into the draft; the installed pack stays as it is until you save over it."
          color: Qt.darker(dialogs.foreground, 1.6)
          font.family: dialogs.fontFamily
          font.pixelSize: Style.font.caption
        }
        Button { text: "Cancel"; foreground: dialogs.foreground; accent: dialogs.accent; fontFamily: dialogs.fontFamily; onClicked: dialogs.closed() }
      }
    }
  }
}

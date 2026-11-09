import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Builder.js" as Builder

// The builder's Export and Import dialogs (D29, slice 3), drawn over the page. Export: choose an installed pack, the zip's path (typed, or its folder from the file chooser), Export.
// Import: a zip (typed or chosen), the checked summary (pack-import.sh --dry-run), then Install or Replace, or Edit as draft (nothing installed). It decides nothing and runs nothing:
// BuilderPage runs the commands on the signals. Esc closes.
Item {
  id: share

  property string kind: ""   // "", "export", "import"
  property var packs: []
  property string chosen: ""   // the pack to export (the first one when it is not in the list)
  property string dir: ""      // the folder the zip goes to by default
  property int count: 0        // icons in the draft
  property var summary: null   // the dry run's summary (Builder.parseSummary), or null
  property bool busy: false
  property string message: ""
  property bool failed: false
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily

  signal closed()
  signal pathEdited()
  signal packChosen(string name)
  signal chooseFolder()
  signal exportRequested(string name, string path)
  signal saveFirst()
  signal chooseZip()
  signal checkRequested(string path)
  signal installRequested(string path)
  signal editRequested(string path)

  readonly property string pack: share.packs.indexOf(share.chosen) >= 0 ? share.chosen : (share.packs.length > 0 ? share.packs[0] : "")
  visible: kind === "export" || kind === "import"

  function resetPath() { if (share.kind === "export") exportPath.text = share.pack !== "" ? Builder.defaultZipPath(share.dir, share.pack) : "" }
  function reset() { zipPath.text = ""; resetPath() }
  onKindChanged: if (kind === "export" || kind === "import") { share.reset(); Qt.callLater(function () { (share.kind === "export" ? exportPath : zipPath).forceActiveFocus() }) }
  onPackChanged: resetPath()
  onDirChanged: resetPath()
  function setZip(path) { zipPath.text = path }
  function startExport() { if (share.pack !== "" && !share.busy) share.exportRequested(share.pack, exportPath.text.trim()) }
  function check() { if (zipPath.text.trim() !== "" && !share.busy) share.checkRequested(zipPath.text.trim()) }

  Rectangle {
    anchors.fill: parent
    color: Color.menu.scrim
    MouseArea { anchors.fill: parent; onClicked: share.closed() }
  }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(parent.width - Style.space(32), Style.space(480))
    height: col.implicitHeight + Style.space(32)
    radius: Style.cornerRadius
    color: Color.menu.background
    border.width: 1
    border.color: share.accent
    MouseArea { anchors.fill: parent }

    ColumnLayout {
      id: col
      anchors.fill: parent
      anchors.margins: Style.space(16)
      spacing: Style.spacing.sm

      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: share.kind === "export" ? "Export a pack as a zip" : "Import a pack zip"
        color: share.foreground
        font.family: share.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      // ---- export
      ColumnLayout {
        visible: share.kind === "export"
        Layout.fillWidth: true
        spacing: Style.spacing.xs
        Text {
          Layout.fillWidth: true
          visible: share.packs.length === 0
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "No installed packs yet. Use Save as pack first."
          color: Qt.darker(share.foreground, 1.6)
          font.family: share.fontFamily
          font.pixelSize: Style.font.caption
        }
        Flow {
          Layout.fillWidth: true
          spacing: Style.spacing.xs
          Repeater {
            model: share.packs
            Button {
              required property string modelData
              text: modelData
              bordered: share.pack === modelData
              foreground: share.foreground; accent: share.accent; fontFamily: share.fontFamily; fontSize: Style.font.caption
              onClicked: share.packChosen(modelData)
            }
          }
        }
        RowLayout {
          visible: share.count > 0
          Layout.fillWidth: true
          spacing: Style.spacing.sm
          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: "The draft has " + share.count + (share.count === 1 ? " change" : " changes") + " that are in no pack yet. Only a saved pack is exported."
            color: share.foreground
            font.family: share.fontFamily
            font.pixelSize: Style.font.caption
          }
          Button { text: "Save first"; foreground: share.foreground; accent: share.accent; fontFamily: share.fontFamily; fontSize: Style.font.caption; onClicked: share.saveFirst() }
        }
        TextField {
          id: exportPath
          Layout.fillWidth: true
          placeholderText: "Full path of the zip to write"
          foreground: share.foreground
          accent: share.accent
          Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) { share.closed(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { share.startExport(); event.accepted = true }
          }
        }
        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "The zip holds the icons and pack.toml only (name, author, licence, description). Nothing about this computer goes in; a description that holds a path is refused."
          color: Qt.darker(share.foreground, 1.6)
          font.family: share.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      // ---- import
      ColumnLayout {
        visible: share.kind === "import"
        Layout.fillWidth: true
        spacing: Style.spacing.xs
        TextField {
          id: zipPath
          Layout.fillWidth: true
          placeholderText: "Full path of a pack zip, then Enter"
          foreground: share.foreground
          accent: share.accent
          onTextChanged: if (share.summary) share.pathEdited()   // an edited path drops the old summary
          Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) { share.closed(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { share.check(); event.accepted = true }
          }
        }
        RowLayout {
          spacing: Style.spacing.sm
          Button { text: "Choose zip..."; enabled: !share.busy; foreground: share.foreground; accent: share.accent; fontFamily: share.fontFamily; fontSize: Style.font.caption; onClicked: share.chooseZip() }
          Button { text: "Check"; bordered: share.summary === null; enabled: !share.busy && zipPath.text.trim() !== ""; foreground: share.foreground; accent: share.accent; fontFamily: share.fontFamily; fontSize: Style.font.caption; onClicked: share.check() }
        }
        GridLayout {
          visible: share.summary !== null
          Layout.fillWidth: true
          columns: 2
          columnSpacing: Style.spacing.sm
          rowSpacing: 2
          Repeater {
            model: share.summary ? [["Pack", share.summary.name], ["Author", share.summary.author], ["Licence", share.summary.licence], ["Icons", String(share.summary.icons)],
              ["Folder", share.summary.folder + (share.summary.installed ? " (already installed)" : "")]] : []
            delegate: Item {
              required property var modelData
              Layout.columnSpan: 2
              Layout.fillWidth: true
              implicitHeight: line.implicitHeight
              Text { id: line; width: parent.width; textFormat: Text.PlainText; elide: Text.ElideRight; text: modelData[0] + ": " + modelData[1]; color: share.foreground; font.family: share.fontFamily; font.pixelSize: Style.font.caption }
            }
          }
        }
        Text {
          visible: share.summary !== null
          Layout.fillWidth: true
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "Every icon passed the checks: plain PNG or SVG, no links, no scripts, sizes within the limits. A zip with one bad file is refused whole, with the reason."
          color: Qt.darker(share.foreground, 1.6)
          font.family: share.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        visible: share.message !== ""
        Layout.fillWidth: true
        textFormat: Text.PlainText
        wrapMode: Text.WrapAnywhere
        text: share.message
        color: share.failed ? Color.urgent : share.foreground
        font.family: share.fontFamily
        font.pixelSize: Style.font.caption
      }

      RowLayout {
        spacing: Style.spacing.sm
        Button { visible: share.kind === "export"; text: "Choose folder..."; enabled: !share.busy; foreground: share.foreground; accent: share.accent; fontFamily: share.fontFamily; onClicked: share.chooseFolder() }
        Button { visible: share.kind === "export"; text: "Export"; bordered: true; enabled: !share.busy && share.pack !== ""; foreground: share.foreground; accent: share.accent; fontFamily: share.fontFamily; onClicked: share.startExport() }
        Button { visible: share.kind === "import" && share.summary !== null; text: share.summary && share.summary.installed ? "Replace" : "Install"; bordered: true; enabled: !share.busy; foreground: share.foreground; accent: share.accent; fontFamily: share.fontFamily; onClicked: share.installRequested(zipPath.text.trim()) }
        Button { visible: share.kind === "import" && share.summary !== null; text: "Edit as draft"; enabled: !share.busy; foreground: share.foreground; accent: share.accent; fontFamily: share.fontFamily; onClicked: share.editRequested(zipPath.text.trim()) }
        Button { text: "Close"; foreground: share.foreground; accent: share.accent; fontFamily: share.fontFamily; onClicked: share.closed() }
      }
    }
  }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "PackEditor.js" as Editor
import "IconResolve.js" as IconResolve
import "ConfigIO.js" as ConfigIO
import "Paths.js" as Paths

// The icon pack editor, a page of the settings window (design: docs/research/pack-editor-spike.md). It writes no file itself: every change
// runs tools/pack-edit.sh, pack-export.sh or pack-import.sh, whose rules (pack-lib.sh) decide. PackEditor.js holds the logic: rows, the
// argument arrays and the state machine. Loaded only while shown, so nothing here runs otherwise.
ColumnLayout {
  id: page

  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily

  signal back()

  // The file chooser is a normal window; the settings window hides while it runs so the chooser is not under it.
  readonly property bool picking: page.editor.phase === "busy" && (page.editor.op === "pickImage" || page.editor.op === "pickZip")
  readonly property bool busy: page.editor.phase === "busy"

  readonly property var tools: ({
    edit: Paths.fromUrl(Qt.resolvedUrl("tools/pack-edit.sh")),
    exporter: Paths.fromUrl(Qt.resolvedUrl("tools/pack-export.sh")),
    importer: Paths.fromUrl(Qt.resolvedUrl("tools/pack-import.sh"))
  })
  readonly property string indexTool: Paths.fromUrl(Qt.resolvedUrl("tools/pack-index.sh"))
  readonly property string packsDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omahop/packs"
  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omahop"

  property var editor: Editor.initial()
  property var packs: []
  property string folder: ""        // the pack being edited, "" for none
  property bool creating: false
  property var meta: ({})
  property var packFiles: []
  property var packIndex: IconResolve.parseIndex("")
  property string filter: ""
  property var ctx: ({})            // the arguments of the running action
  property var lastPick: ({})       // {op, args} of the last picker run, for the typed path when the picker cannot open
  property string scannedFolder: ""  // the folder the icon scan in flight lists
  property int runId: 0
  property int doneId: 0

  readonly property var windows: Hyprland.toplevels.values.map(function (t) {
    var id = t.wayland ? String(t.wayland.appId || "") : String((t.lastIpcObject && t.lastIpcObject["class"]) || "")
    var e = DesktopEntries.heuristicLookup(id)
    return { appId: id, name: e ? e.name : id, icon: e ? e.icon : "" }
  })
  readonly property var entries: DesktopEntries.applications.values.map(function (e) {
    return { id: e.id, name: e.name, icon: e.icon, startupClass: e.startupClass, noDisplay: e.noDisplay }
  })
  readonly property var rows: page.folder === "" ? [] : Editor.appRows(page.windows, page.entries, page.packFiles,
    function (key, icon) { return IconResolve.packPick(page.packIndex, key, icon) }, page.filter)

  spacing: Style.spacing.sm

  Component.onCompleted: page.refresh()

  function run(op, args) {
    var built = Editor.command(page.tools, op, args)
    if (built.error) { page.editor = Editor.refuse(page.editor, built.error); return }
    if (page.busy) return
    if (op === "pickImage" || op === "pickZip") page.lastPick = { op: op, args: args }
    page.editor = Editor.begin(page.editor, op)
    page.ctx = args
    page.runId += 1
    runner.op = op
    runner.command = built.argv
    runner.running = true
  }

  function settle(next) {
    page.editor = next
    var fx = next.effect
    if (!fx) return
    if (fx.run) { Qt.callLater(page.run, fx.run, fx.args); return }
    if (fx.select) { page.folder = fx.select; page.creating = false }
    if (fx.changed) changedFile.setText(String(Date.now()) + "\n")
    page.refresh()
  }

  // A command that could not start (no omarchy, no bash) never sends exited: settle it as exit 127 once both signals had their turn.
  function settleUnstarted(id) {
    if (page.doneId === id || !page.busy) return
    page.doneId = id
    page.settle(Editor.finish(page.editor, runner.op, 127, "", "could not start " + runner.command[0], page.ctx))
  }

  function choose(name) {
    page.folder = name
    page.creating = false
    filterField.text = ""
    page.refresh()
  }

  function refresh() {
    if (!packsProc.running) packsProc.running = true
    page.packFiles = []
    page.packIndex = IconResolve.parseIndex("")
    page.meta = ({})
    if (page.folder === "") return
    page.scanIcons()
    metaFile.reload()
  }

  function scanIcons() {
    if (iconsProc.running || page.folder === "") return
    page.scannedFolder = page.folder
    iconsProc.running = true
  }

  function pickedPath(path) {
    var pick = page.lastPick
    var args = Object.assign({}, pick.args || {}, { path: String(path).trim() })
    page.run(pick.op === "pickZip" ? "importCheck" : "add", args)
  }

  Process {
    id: runner
    property string op: ""
    stdout: StdioCollector { id: runOut }
    stderr: StdioCollector { id: runErr }
    onExited: function (code) {
      page.doneId = page.runId
      page.settle(Editor.finish(page.editor, runner.op, code, runOut.text, runErr.text, page.ctx))
    }
    onRunningChanged: if (!running) Qt.callLater(page.settleUnstarted, page.runId)
  }
  Process {
    id: packsProc
    command: ["bash", page.tools.edit, "list"]
    stdout: StdioCollector { onStreamFinished: page.packs = Editor.lines(text) }
  }
  Process {
    id: iconsProc
    command: ["bash", page.indexTool, page.scannedFolder]
    onRunningChanged: if (!running && page.folder !== page.scannedFolder) page.scanIcons()
    stdout: StdioCollector {
      onStreamFinished: {
        if (page.scannedFolder !== page.folder) return
        page.packFiles = Editor.lines(text)
        page.packIndex = IconResolve.parseIndex(text)
      }
    }
  }
  FileView {
    id: metaFile
    path: page.folder === "" ? "" : page.packsDir + "/" + page.folder + "/pack.toml"
    printErrors: false
    onLoaded: page.meta = ConfigIO.parse(text()).top
    onLoadFailed: page.meta = ({})
  }
  // Tells the switcher (Service.qml watches this file) to rescan the chosen pack.
  FileView { id: changedFile; path: page.runtimeDir + "/pack-changed"; atomicWrites: true; printErrors: false }

  RowLayout {
    Layout.fillWidth: true
    Button { text: "Back"; foreground: page.foreground; accent: page.accent; fontFamily: page.fontFamily; onClicked: page.back() }
    Text {
      Layout.fillWidth: true
      textFormat: Text.PlainText
      text: "Icon packs"
      color: page.foreground
      font.family: page.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }
  }

  Text {
    Layout.fillWidth: true
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    text: "Pick a pack to edit or make a new one. Every image is checked with the same rules as a shared pack. To use a pack, type its folder name in Icon pack."
    color: Qt.darker(page.foreground, 1.6)
    font.family: page.fontFamily
    font.pixelSize: Style.font.caption
  }

  PackChooser {
    Layout.fillWidth: true
    packs: page.packs
    folder: page.folder
    creating: page.creating
    busy: page.busy
    foreground: page.foreground
    accent: page.accent
    fontFamily: page.fontFamily
    onChosen: function (name) { page.choose(name) }
    onCreateRequested: { page.creating = true; page.folder = ""; page.refresh() }
    onImportRequested: page.run("pickZip", {})
    onExportRequested: page.run("export", { folder: page.folder })
  }

  PackStatus {
    Layout.fillWidth: true
    editor: page.editor
    foreground: page.foreground
    accent: page.accent
    fontFamily: page.fontFamily
    onCancelled: page.editor = Editor.cancel(page.editor)
    onPathGiven: function (path) { page.pickedPath(path) }
    onConfirmed: function (replace) {
      var ask = page.editor.confirm
      page.editor = Editor.cancel(page.editor)
      if (ask.kind === "import") page.run("importInstall", { path: ask.path, replace: replace })
      else page.run("export", { folder: page.folder, replace: true })
    }
  }

  PackMetaForm {
    visible: page.creating || page.folder !== ""
    Layout.fillWidth: true
    values: page.meta
    creating: page.creating
    busy: page.busy
    foreground: page.foreground
    accent: page.accent
    fontFamily: page.fontFamily
    onSubmitted: function (name, author, license, description) {
      var fields = { folder: page.folder, name: name, author: author, license: license, description: description }
      page.run(page.creating ? "init" : "meta", fields)
    }
  }

  TextField {
    id: filterField
    visible: page.folder !== ""
    Layout.fillWidth: true
    placeholderText: "Filter apps"
    foreground: page.foreground
    accent: page.accent
    onTextChanged: page.filter = text
  }

  // Hundreds of installed apps: a ListView, so only the visible rows exist.
  ListView {
    visible: page.folder !== ""
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: Style.space(132)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: page.rows
    delegate: PackAppRow {
      required property var modelData
      width: ListView.view.width
      app: modelData
      busy: page.busy
      foreground: page.foreground
      accent: page.accent
      fontFamily: page.fontFamily
      onChooseImage: page.run("pickImage", { folder: page.folder, appId: modelData.key })
      onRemoveIcon: page.run("remove", { folder: page.folder, file: modelData.packFile })
    }
  }

  Item { visible: page.folder === ""; Layout.fillHeight: true }
}

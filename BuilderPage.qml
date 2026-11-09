import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Builder.js" as Builder
import "PackEditor.js" as Editor
import "IconPicker.js" as Picker
import "IconResolve.js" as IconResolve
import "Paths.js" as Paths

// The icon builder, a page of the settings window (D29, docs/research/theme-picker.md). Choose an app, find an icon for it in every installed theme or in a file, see it in the switcher's
// own row and card, undo or reset. The draft is a private folder in the cache (tools/draft-edit.sh owns every rule); nothing here writes a file, and Escape or Back leaves the draft as it is
// (Save as pack, Export and Import are the next slices). Pure logic: Builder.js. Loaded only while shown.
ColumnLayout {
  id: page

  property var store: null
  property var byId: ({})
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily

  signal back()

  // The file chooser is a normal window; the settings window hides while it runs so the chooser is not under it.
  readonly property bool picking: page.editor.phase === "busy" && page.editor.op === "pick"
  readonly property bool busy: page.editor.phase === "busy"

  readonly property var tools: ({
    draft: Paths.fromUrl(Qt.resolvedUrl("tools/draft-edit.sh")),
    find: Paths.fromUrl(Qt.resolvedUrl("tools/icon-find.sh")),
    preview: Paths.fromUrl(Qt.resolvedUrl("tools/icon-preview.sh")),
    pick: Paths.fromUrl(Qt.resolvedUrl("tools/pack-edit.sh"))
  })
  readonly property string themesTool: Paths.fromUrl(Qt.resolvedUrl("tools/icon-themes.sh"))

  property var editor: Builder.initial()
  property var ctx: ({})
  property int runId: 0
  property int doneId: 0
  property var draft: []                 // [{stem, file, path}] the draft holds
  property var draftIndex: IconResolve.parseIndex("")
  property int rev: 0                    // counts draft reloads, so a replaced file (same name) is read again
  property string filterText: ""
  property int cursor: 0
  property string zone: "apps"           // "apps" or "icons": where the arrow keys go
  property string tab: "themes"          // "themes" or "file"
  property string query: ""
  property var results: []
  property int resultCursor: 0
  property string note: "Type at least 2 letters to search every installed theme."
  property var findCache: ({})           // query to [{theme, name, path}], while the page lives
  property string pendingQuery: ""
  property bool baseOpen: false
  property var themes: []
  property int baseCursor: 0
  property var nowPath: ({})             // app key to the file the base theme gives it

  readonly property var windows: Hyprland.toplevels.values.map(function (t) {
    var id = t.wayland ? String(t.wayland.appId || "") : String((t.lastIpcObject && t.lastIpcObject["class"]) || "")
    var e = DesktopEntries.heuristicLookup(id)
    return { appId: id, name: e ? e.name : id, icon: e ? e.icon : "" }
  })
  readonly property var entries: DesktopEntries.applications.values.map(function (e) {
    return { id: e.id, name: e.name, icon: e.icon, startupClass: e.startupClass, noDisplay: e.noDisplay }
  })
  readonly property var rows: Builder.decorate(Editor.appRows(page.windows, page.entries, page.draft.map(function (d) { return d.path }),
    function (key, icon) { return IconResolve.packPick(page.draftIndex, key, icon) }, page.filterText))
  readonly property var selected: page.rows.length > 0 ? page.rows[Math.min(page.cursor, page.rows.length - 1)] : null
  readonly property string selectedKey: page.selected ? page.selected.key : ""
  readonly property var setting: page.byId["top.icon_theme"]
  readonly property string baseValue: page.store && page.setting ? String(page.store.value(page.setting)) : ""
  readonly property var baseChoices: Picker.choices(Picker.KINDS[0], page.themes)
  readonly property string baseTitle: page.baseChoices[Picker.indexOfValue(page.baseChoices, page.baseValue)].title
  readonly property string nowFile: page.selected && page.nowPath[page.selected.key] ? page.nowPath[page.selected.key] : ""
  readonly property string newFile: page.selected && page.selected.packPath ? page.selected.packPath : ""

  spacing: Style.spacing.sm

  Component.onCompleted: { page.refreshDraft(); themesProc.running = true; filterField.forceActiveFocus() }
  onSelectedKeyChanged: { page.startSearch(); page.lookupNow() }
  onBaseValueChanged: { page.nowPath = ({}); page.lookupNow() }

  // ---- data
  function refreshDraft() { if (!lister.running) lister.running = true }

  function lookupNow() {
    var row = page.selected
    if (!row || nowProc.running) return
    var names = Builder.nowNames(IconResolve.candidates(row.key, row.icon))
    var built = Builder.command(page.tools, "now", { theme: page.baseValue, names: names })
    if (built.error) return
    nowProc.key = row.key
    nowProc.names = names
    nowProc.command = built.argv
    nowProc.running = true
  }

  // The search text starts from the chosen app's own icon name, so the first results are already about it.
  function startSearch() {
    var text = page.selected ? Builder.suggestQuery(page.selected.key, page.selected.icon) : ""
    searchField.text = text
    page.query = text
    page.findNow()
  }

  function findNow() {
    var q = page.query
    page.resultCursor = 0
    if (q.length < 2) { page.results = []; page.note = "Type at least 2 letters to search every installed theme."; return }
    if (page.findCache[q] !== undefined) { page.showFound(q, page.findCache[q]); return }
    page.pendingQuery = q
    page.note = "Searching..."
    page.results = []
    if (!finder.running) page.nextFind()
  }

  function nextFind() {
    var q = page.pendingQuery
    var built = Builder.command(page.tools, "find", { query: q })
    page.pendingQuery = ""
    if (built.error || q === "") return
    finder.query = q
    finder.command = built.argv
    finder.running = true
  }

  function showFound(q, list) {
    if (q !== page.query) return
    // nothing under the full name (google-chrome, org.gnome.nautilus): try its last part once (chrome, nautilus); the box shows what was searched
    var cut = Math.max(q.lastIndexOf("-"), q.lastIndexOf("."))
    if (list.length === 0 && cut > 0 && q.length - cut - 1 >= 2) { searchField.text = q.slice(cut + 1); return }
    page.results = list
    page.resultCursor = 0
    page.note = list.length === 0 ? "No icon named like \"" + q + "\" in any theme. Try a shorter name." : ""
  }

  // ---- actions
  function run(op, args) {
    var built = Builder.command(page.tools, op, args)
    if (built.error) { page.editor = Builder.refuse(page.editor, built.error); return }
    if (page.busy) return
    page.editor = Builder.begin(page.editor, op)
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
    if (fx.run) Qt.callLater(page.run, fx.run, fx.args)
    else if (fx.refresh) page.refreshDraft()
  }

  // A command that could not start never sends exited: settle it as exit 127 once both signals had their turn.
  function settleUnstarted(id) {
    if (page.doneId === id || !page.busy) return
    page.doneId = id
    page.settle(Builder.finish(page.editor, runner.op, 127, "", "could not start " + runner.command[0], page.ctx))
  }

  function apply(i) {
    if (!page.selected || i < 0 || i >= page.results.length) return
    page.run("add", { appId: page.selected.key, path: page.results[i].path })
  }

  function useTyped() {
    var path = pathField.text.trim()
    if (!page.selected || path === "") return
    page.run("add", { appId: page.selected.key, path: path })
    pathField.text = ""
  }

  function chooseBase(value) {
    if (!page.setting) return
    if (value === "") page.store.resetValue(page.setting)
    else page.store.setValue(page.setting, value)
    page.baseOpen = false
    page.focusZone()
  }

  function setZone(z) { page.zone = z; page.focusZone() }
  function focusZone() {
    if (page.zone === "apps" || page.baseOpen) filterField.forceActiveFocus()
    else if (page.tab === "file") pathField.forceActiveFocus()
    else searchField.forceActiveFocus()
  }

  function moveApp(key) {
    var to = Picker.move(page.cursor, key, page.rows.length)
    if (to >= 0) page.cursor = to
  }

  function onKey(event) {
    var names = {}
    names[Qt.Key_Up] = "Up"; names[Qt.Key_Down] = "Down"; names[Qt.Key_Left] = "Left"; names[Qt.Key_Right] = "Right"
    names[Qt.Key_PageUp] = "PageUp"; names[Qt.Key_PageDown] = "PageDown"; names[Qt.Key_Home] = "Home"; names[Qt.Key_End] = "End"
    names[Qt.Key_Return] = "Return"; names[Qt.Key_Enter] = "Return"; names[Qt.Key_Escape] = "Escape"; names[Qt.Key_Tab] = "Tab"; names[Qt.Key_Backtab] = "Backtab"
    names[Qt.Key_Z] = "z"; names[Qt.Key_R] = "r"
    var a = Builder.action(names[event.key] || "", (event.modifiers & Qt.ControlModifier) !== 0, { zone: page.zone, baseOpen: page.baseOpen })
    if (a.act === "none") return
    event.accepted = true
    if (a.act === "back") page.back()
    else if (a.act === "closeBase") { page.baseOpen = false; page.focusZone() }
    else if (a.act === "undo") page.run("undo", {})
    else if (a.act === "resetApp") { if (page.selected && page.selected.changed) page.run("reset", { appId: page.selected.key }) }
    else if (a.act === "zone") page.setZone(page.zone === "apps" ? "icons" : "apps")
    else if (a.act === "appMove") page.moveApp(a.key)
    else if (a.act === "baseMove") { var b = Picker.move(page.baseCursor, a.key, page.baseChoices.length); if (b >= 0) page.baseCursor = b }
    else if (a.act === "baseChoose") page.chooseBase(page.baseChoices[page.baseCursor].value)
    else if (a.act === "gridMove") { var g = Builder.gridMove(page.resultCursor, a.key, page.results.length, grid.columns); if (g >= 0) page.resultCursor = g }
    else if (a.act === "apply") { if (page.tab === "file") { if (pathField.text.trim() !== "") page.useTyped(); else page.run("pick", { appId: page.selected ? page.selected.key : "" }) } else page.apply(page.resultCursor) }
  }

  // ---- processes
  Process {
    id: runner
    property string op: ""
    stdout: StdioCollector { id: runOut }
    stderr: StdioCollector { id: runErr }
    onExited: function (code) {
      page.doneId = page.runId
      page.settle(Builder.finish(page.editor, runner.op, code, runOut.text, runErr.text, page.ctx))
    }
    onRunningChanged: if (!running) Qt.callLater(page.settleUnstarted, page.runId)
  }
  Process {
    id: lister
    command: ["bash", page.tools.draft, "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        page.draft = Builder.parseDraft(text)
        page.draftIndex = IconResolve.parseIndex(page.draft.map(function (d) { return d.path }).join("\n"))
        page.rev += 1
      }
    }
  }
  Process {
    id: finder
    property string query: ""
    stdout: StdioCollector {
      onStreamFinished: {
        var list = Builder.parseFind(text)
        var c = Object.assign({}, page.findCache)
        c[finder.query] = list
        page.findCache = c
        page.showFound(finder.query, list)
      }
    }
    onRunningChanged: if (!running && page.pendingQuery !== "") Qt.callLater(page.nextFind)
  }
  Process {
    id: nowProc
    property string key: ""
    property var names: []
    stdout: StdioCollector {
      onStreamFinished: {
        var c = Object.assign({}, page.nowPath)
        c[nowProc.key] = Builder.nowPick(nowProc.names, Picker.parsePreview(text))
        page.nowPath = c
      }
    }
    onRunningChanged: if (!running && page.selectedKey !== nowProc.key && page.nowPath[page.selectedKey] === undefined) Qt.callLater(page.lookupNow)
  }
  Process {
    id: themesProc
    command: ["bash", page.themesTool]
    stdout: StdioCollector { onStreamFinished: page.themes = Picker.parseThemes(text) }
  }
  Timer { id: findTimer; interval: 250; onTriggered: page.findNow() }

  // ---- header: back, title, base theme
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.sm
    Button { text: "Back"; foreground: page.foreground; accent: page.accent; fontFamily: page.fontFamily; onClicked: page.back() }
    Text {
      Layout.fillWidth: true
      textFormat: Text.PlainText
      text: "Icon builder"
      color: page.foreground
      font.family: page.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }
    Button {
      text: "Base theme: " + page.baseTitle
      bordered: page.baseOpen
      foreground: page.foreground
      accent: page.accent
      fontFamily: page.fontFamily
      onClicked: { page.baseOpen = !page.baseOpen; page.baseCursor = Picker.indexOfValue(page.baseChoices, page.baseValue); page.focusZone() }
    }
  }

  // ---- toolbar: undo, reset, and the next slices
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.sm
    Text {
      textFormat: Text.PlainText
      text: page.draft.length === 1 ? "Draft: 1 change" : "Draft: " + page.draft.length + " changes"
      color: page.foreground
      font.family: page.fontFamily
      font.pixelSize: Style.font.caption
    }
    Button { text: "Undo"; enabled: !page.busy && page.draft.length > 0; foreground: page.foreground; accent: page.accent; fontFamily: page.fontFamily; fontSize: Style.font.caption; onClicked: page.run("undo", {}) }
    Button {
      text: "Reset this app"
      enabled: !page.busy && page.selected !== null && page.selected.changed
      foreground: page.foreground; accent: page.accent; fontFamily: page.fontFamily; fontSize: Style.font.caption
      onClicked: page.run("reset", { appId: page.selected.key })
    }
    Item { Layout.fillWidth: true }
    Button { text: "Save as pack"; enabled: false; foreground: page.foreground; accent: page.accent; fontFamily: page.fontFamily; fontSize: Style.font.caption }
    Button { text: "Export"; enabled: false; foreground: page.foreground; accent: page.accent; fontFamily: page.fontFamily; fontSize: Style.font.caption }
    Button { text: "Import"; enabled: false; foreground: page.foreground; accent: page.accent; fontFamily: page.fontFamily; fontSize: Style.font.caption }
    Text {
      textFormat: Text.PlainText
      text: "next slice"
      color: Qt.darker(page.foreground, 1.6)
      font.family: page.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // ---- body: apps on the left, icons on the right
  RowLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: Style.space(150)
    spacing: Style.spacing.md

    ColumnLayout {
      Layout.preferredWidth: Style.space(210)
      Layout.maximumWidth: Style.space(210)
      Layout.fillHeight: true
      spacing: Style.spacing.xs
      TextField {
        id: filterField
        Layout.fillWidth: true
        placeholderText: "Filter apps"
        foreground: page.foreground
        accent: page.accent
        onTextChanged: { page.filterText = text; page.cursor = 0 }
        onActiveFocusChanged: if (activeFocus && !page.baseOpen && page.zone !== "apps") page.zone = "apps"
        Keys.onPressed: function (event) { page.onKey(event) }
      }
      BuilderAppList {
        Layout.fillWidth: true
        Layout.fillHeight: true
        rows: page.rows
        cursor: page.cursor
        rev: page.rev
        foreground: page.foreground
        accent: page.accent
        fontFamily: page.fontFamily
        onClicked: function (i) { page.cursor = i; page.setZone("apps") }
      }
    }

    // The base theme list replaces the right side while it is open.
    ListView {
      id: baseList
      visible: page.baseOpen
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      model: page.baseChoices
      currentIndex: page.baseCursor
      onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
      delegate: Rectangle {
        required property var modelData
        required property int index
        width: baseList.width
        height: Style.space(30)
        radius: Style.cornerRadius
        color: index === page.baseCursor ? Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.22) : "transparent"
        Text {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.spacing.sm
          textFormat: Text.PlainText
          text: (modelData.value === page.baseValue ? "✓ " : "") + modelData.title
          color: page.foreground
          font.family: page.fontFamily
          font.pixelSize: Style.font.body
        }
        MouseArea { anchors.fill: parent; onClicked: page.chooseBase(modelData.value) }
      }
    }

    ColumnLayout {
      visible: !page.baseOpen
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.spacing.xs

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.sm
        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: page.selected ? page.selected.name + "  (" + page.selected.key + ")" : "Choose an app on the left"
          color: page.foreground
          font.family: page.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }
        Text { textFormat: Text.PlainText; text: "Now"; color: Qt.darker(page.foreground, 1.6); font.family: page.fontFamily; font.pixelSize: Style.font.caption }
        Image {
          Layout.preferredWidth: Style.space(32); Layout.preferredHeight: Style.space(32)
          sourceSize.width: Style.space(32); sourceSize.height: Style.space(32)
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          source: page.nowFile !== "" ? "file://" + page.nowFile : (page.selected ? Quickshell.iconPath(page.selected.icon || page.selected.key || "", "application-x-executable") : "")
        }
        Text { textFormat: Text.PlainText; text: "New"; color: Qt.darker(page.foreground, 1.6); font.family: page.fontFamily; font.pixelSize: Style.font.caption }
        Item {
          Layout.preferredWidth: Style.space(32); Layout.preferredHeight: Style.space(32)
          Image {
            anchors.fill: parent
            visible: page.newFile !== ""
            sourceSize.width: Style.space(32); sourceSize.height: Style.space(32)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            source: page.newFile !== "" ? "file://" + page.newFile + "?v=" + page.rev : ""
          }
          Rectangle {
            anchors.centerIn: parent
            visible: page.newFile === ""
            width: parent.width * 0.7; height: width; radius: width / 4
            color: "transparent"; border.width: 1
            border.color: Qt.rgba(page.foreground.r, page.foreground.g, page.foreground.b, 0.3)
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.sm
        Button { text: "Themes"; bordered: page.tab === "themes"; foreground: page.foreground; accent: page.accent; fontFamily: page.fontFamily; fontSize: Style.font.caption; onClicked: { page.tab = "themes"; page.setZone("icons") } }
        Button { text: "A file"; bordered: page.tab === "file"; foreground: page.foreground; accent: page.accent; fontFamily: page.fontFamily; fontSize: Style.font.caption; onClicked: { page.tab = "file"; page.setZone("icons") } }
        TextField {
          id: searchField
          visible: page.tab === "themes"
          Layout.fillWidth: true
          placeholderText: "Search icons by name in all themes"
          foreground: page.foreground
          accent: page.accent
          onTextChanged: { page.query = text.trim().toLowerCase(); findTimer.restart() }
          onActiveFocusChanged: if (activeFocus && !page.baseOpen) page.zone = "icons"
          Keys.onPressed: function (event) { page.onKey(event) }
        }
        TextField {
          id: pathField
          visible: page.tab === "file"
          Layout.fillWidth: true
          placeholderText: "Full path of a PNG or SVG, then Enter"
          foreground: page.foreground
          accent: page.accent
          onActiveFocusChanged: if (activeFocus && !page.baseOpen) page.zone = "icons"
          Keys.onPressed: function (event) { page.onKey(event) }
        }
      }

      BuilderIconGrid {
        id: grid
        visible: page.tab === "themes"
        Layout.fillWidth: true
        Layout.fillHeight: true
        results: page.results
        cursor: page.resultCursor
        note: page.note
        foreground: page.foreground
        accent: page.accent
        fontFamily: page.fontFamily
        onClicked: function (i) { page.resultCursor = i; page.setZone("icons") }
        onActivated: function (i) { page.resultCursor = i; page.apply(i) }
      }

      ColumnLayout {
        visible: page.tab === "file"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.spacing.sm
        Button {
          text: "Choose file..."
          bordered: true
          enabled: !page.busy && page.selected !== null
          foreground: page.foreground; accent: page.accent; fontFamily: page.fontFamily
          onClicked: page.run("pick", { appId: page.selected.key })
        }
        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "A PNG or a plain SVG, checked with the same rules as a shared pack. The file is copied into the draft."
          color: Qt.darker(page.foreground, 1.6)
          font.family: page.fontFamily
          font.pixelSize: Style.font.caption
        }
        Item { Layout.fillHeight: true }
      }

      RowLayout {
        visible: page.tab === "themes"
        Layout.fillWidth: true
        Button {
          text: "Use this icon"
          bordered: true
          enabled: !page.busy && page.selected !== null && page.results.length > 0
          foreground: page.foreground; accent: page.accent; fontFamily: page.fontFamily; fontSize: Style.font.caption
          onClicked: page.apply(page.resultCursor)
        }
        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: page.results.length > 0 && page.resultCursor < page.results.length ? "Copies " + page.results[page.resultCursor].name + " from " + page.results[page.resultCursor].theme + " into the draft" : ""
          color: Qt.darker(page.foreground, 1.6)
          font.family: page.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  // ---- the real look
  BuilderPreview {
    Layout.fillWidth: true
    rows: Builder.previewRows(page.rows, page.cursor, 3)
    rev: page.rev
    nowPath: page.nowPath
    foreground: page.foreground
  }

  Text {
    Layout.fillWidth: true
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    text: page.editor.message !== "" ? page.editor.message : "Theme icons keep their theme's licence. The draft lives in your cache folder until Save as pack exists (next slice)."
    color: page.editor.error ? Color.urgent : Qt.darker(page.foreground, 1.6)
    font.family: page.fontFamily
    font.pixelSize: Style.font.caption
  }
  Text {
    Layout.fillWidth: true
    textFormat: Text.PlainText
    text: "Up and Down apps, Tab icons, Enter use, Ctrl+Z undo, Ctrl+R reset app, Esc back"
    color: Qt.darker(page.foreground, 1.6)
    font.family: page.fontFamily
    font.pixelSize: Style.font.caption
  }
}

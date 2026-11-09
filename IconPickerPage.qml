import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "IconPicker.js" as Picker
import "IconResolve.js" as IconResolve
import "Paths.js" as Paths

// The icon theme and icon pack picker, a page of the settings window (decision D28, docs/research/theme-picker.md). One card per choice, each showing the same
// sample apps. Up and Down move and the preview shows the highlighted choice at once, but nothing is written until Enter (or Choose); Escape goes back and writes nothing.
// Data comes from scripts (tools/icon-themes.sh, pack-edit.sh list, icon-preview.sh, pack-index.sh) and the sample apps from spec.json; the pure logic is IconPicker.js.
// Icons are looked up only for the cards on screen, one script at a time, and kept in `cache` while the page lives. Loaded only while shown.
ColumnLayout {
  id: page

  property var store: null
  property var byId: ({})
  property string settingKey: "icon_theme"   // the setting that opened the page, picks the Theme or Pack tab
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily

  signal back()
  signal packEditorRequested()
  signal builderRequested()

  property var kind: Picker.kindFor(page.settingKey)
  property var found: []              // themes or packs the scan listed for the tab
  property string filterText: ""
  property int cursor: 0
  property var cache: ({})            // "<kind>:<value>" to {app id: icon file}
  property var queue: []              // [{kind, value}] waiting for a lookup
  property var running: null          // the lookup in flight

  readonly property var sampleIds: (page.store && page.store.spec.sample_apps) || []
  readonly property var setting: page.byId["top." + page.kind.setting]
  readonly property string savedValue: page.store && page.setting ? String(page.store.value(page.setting)) : ""
  readonly property var shown: Picker.filter(Picker.choices(page.kind, page.found), page.filterText)
  readonly property var highlighted: page.shown.length > 0 ? page.shown[Math.min(page.cursor, page.shown.length - 1)] : null

  readonly property string themesTool: Paths.fromUrl(Qt.resolvedUrl("tools/icon-themes.sh"))
  readonly property string previewTool: Paths.fromUrl(Qt.resolvedUrl("tools/icon-preview.sh"))
  readonly property string packEditTool: Paths.fromUrl(Qt.resolvedUrl("tools/pack-edit.sh"))
  readonly property string packIndexTool: Paths.fromUrl(Qt.resolvedUrl("tools/pack-index.sh"))

  spacing: Style.spacing.sm

  Component.onCompleted: { page.scan(); filterField.forceActiveFocus() }
  onKindChanged: { page.filterText = ""; filterField.text = ""; page.scan() }

  function cacheKey(value) { return page.kind.id + ":" + value }

  function scan() {
    page.found = []
    page.cursor = 0
    scanner.command = page.kind.id === "pack" ? ["bash", page.packEditTool, "list"] : ["bash", page.themesTool]
    scanner.kindId = page.kind.id
    scanner.running = false
    scanner.running = true
  }

  // The sample icons of a choice, one file per sample app ("" when it has none), or the empty row while the lookup is not done.
  function iconsFor(value) {
    var map = page.cache[page.cacheKey(value)] || {}
    return page.sampleIds.map(function (id) { return map[id] || "" })
  }

  // A card asks for its icons when it is created, which only happens for the cards on screen. The "no pack" card has none to look up.
  function request(value) {
    var key = page.cacheKey(value)
    if (page.kind.id === "pack" && value === "") return
    if (page.cache[key] !== undefined || (page.running && page.running.key === key) || page.queue.some(function (q) { return q.key === key })) return
    page.queue = page.queue.concat([{ key: key, kind: page.kind.id, value: value }])
    page.next()
  }

  function next() {
    if (lookup.running || page.queue.length === 0) return
    page.running = page.queue[0]
    page.queue = page.queue.slice(1)
    var r = page.running
    lookup.command = r.kind === "pack" ? ["bash", page.packIndexTool, r.value] : ["bash", page.previewTool, r.value === "" ? "-" : r.value].concat(page.sampleIds)
    lookup.running = true
  }

  function finished(text) {
    var r = page.running
    page.running = null
    if (!r) return
    var map
    if (r.kind === "pack") {
      var index = IconResolve.parseIndex(text)
      map = {}
      page.sampleIds.forEach(function (id) { var p = IconResolve.packPick(index, id, ""); if (p !== "") map[id] = p })
    } else {
      map = Picker.parsePreview(text)
    }
    var c = Object.assign({}, page.cache)
    c[r.key] = map
    page.cache = c
    Qt.callLater(page.next)
  }

  function commit() {
    if (!page.highlighted || !page.setting) return
    if (page.highlighted.value === "") page.store.resetValue(page.setting)
    else page.store.setValue(page.setting, page.highlighted.value)
    page.back()
  }

  function setCursor(i) {
    page.cursor = i
    list.positionViewAtIndex(i, ListView.Contain)
  }

  function onKey(event) {
    var names = {}
    names[Qt.Key_Up] = "Up"; names[Qt.Key_Down] = "Down"; names[Qt.Key_PageUp] = "PageUp"; names[Qt.Key_PageDown] = "PageDown"
    names[Qt.Key_Home] = "Home"; names[Qt.Key_End] = "End"
    var to = Picker.move(page.cursor, names[event.key] || "", page.shown.length)
    if (to >= 0) { page.setCursor(to); event.accepted = true; return }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { page.commit(); event.accepted = true }
    else if (event.key === Qt.Key_Escape) { page.back(); event.accepted = true }
  }

  Process {
    id: scanner
    property string kindId: ""
    stdout: StdioCollector {
      onStreamFinished: {
        if (scanner.kindId !== page.kind.id) return
        page.found = page.kind.id === "pack"
          ? text.split("\n").filter(function (l) { return l.trim() !== "" }).map(function (l) { return { value: l.trim(), title: l.trim() } })
          : Picker.parseThemes(text)
        page.setCursor(Picker.indexOfValue(Picker.choices(page.kind, page.found), page.savedValue))
      }
    }
  }
  Process {
    id: lookup
    stdout: StdioCollector { onStreamFinished: page.finished(text) }
    onRunningChanged: if (!running && page.running) Qt.callLater(function () { if (!lookup.running && page.running) page.finished("") })
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.sm
    Button { text: "Back"; foreground: page.foreground; accent: page.accent; fontFamily: page.fontFamily; onClicked: page.back() }
    Repeater {
      model: Picker.KINDS
      Button {
        required property var modelData
        text: modelData.title
        bordered: modelData.id === page.kind.id
        foreground: page.foreground
        accent: page.accent
        fontFamily: page.fontFamily
        onClicked: page.settingKey = modelData.setting
      }
    }
    TextField {
      id: filterField
      Layout.fillWidth: true
      placeholderText: "Filter by name"
      foreground: page.foreground
      accent: page.accent
      onTextChanged: { page.filterText = text; page.cursor = 0 }
      Keys.onPressed: function (event) { page.onKey(event) }
    }
  }

  // The highlighted choice, larger. This is the live preview: it follows the arrow keys and writes nothing.
  IconChoiceCard {
    Layout.fillWidth: true
    visible: page.highlighted !== null
    interactive: false
    title: page.highlighted ? page.highlighted.title : ""
    help: "Preview"
    icons: page.highlighted ? page.iconsFor(page.highlighted.value) : []
    iconSize: Style.space(48)
    foreground: page.foreground
    accent: page.accent
    fontFamily: page.fontFamily
  }

  ListView {
    id: list
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    spacing: Style.spacing.xs
    boundsBehavior: Flickable.StopAtBounds
    model: page.shown
    delegate: IconChoiceCard {
      required property var modelData
      required property int index
      width: list.width
      title: modelData.title
      help: modelData.help
      icons: page.iconsFor(modelData.value)
      highlighted: index === page.cursor
      saved: modelData.value === page.savedValue
      foreground: page.foreground
      accent: page.accent
      fontFamily: page.fontFamily
      Component.onCompleted: page.request(modelData.value)
      onClicked: { page.cursor = index; filterField.forceActiveFocus() }
      onActivated: { page.cursor = index; page.commit() }
    }
    Text {
      anchors.centerIn: parent
      visible: page.shown.length === 0
      textFormat: Text.PlainText
      text: "Nothing matches"
      color: Qt.darker(page.foreground, 1.6)
      font.family: page.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  Text {
    Layout.fillWidth: true
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    text: page.kind.id === "pack"
      ? "A pack puts its own icons in front of the theme; an app it has no icon for keeps its usual one (shown as an empty outline)."
      : "An app a theme has no icon for gets one from the others."
    color: Qt.darker(page.foreground, 1.6)
    font.family: page.fontFamily
    font.pixelSize: Style.font.caption
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.sm
    Button {
      text: "Choose"
      bordered: true
      enabled: page.highlighted !== null
      foreground: page.foreground
      accent: page.accent
      fontFamily: page.fontFamily
      onClicked: page.commit()
    }
    Button {
      visible: page.kind.id === "pack"
      text: "Make or edit icon packs"
      foreground: page.foreground
      accent: page.accent
      fontFamily: page.fontFamily
      onClicked: page.packEditorRequested()
    }
    Button {
      text: "Customize icons"
      foreground: page.foreground
      accent: page.accent
      fontFamily: page.fontFamily
      onClicked: page.builderRequested()
    }
    Item { Layout.fillWidth: true }
    Text {
      textFormat: Text.PlainText
      text: "Up and Down preview, Enter chooses, Esc goes back"
      color: Qt.darker(page.foreground, 1.6)
      font.family: page.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}

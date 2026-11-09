import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "ConfigIO.js" as ConfigIO

// omahop settings: a side list of categories and one category's settings at a time (sub headings, dependents nested under their switch and hidden while it is off,
// rare ones folded under "Show advanced"), all built from spec.json (so a new setting needs no panel code). Every change is saved after a short pause,
// there is no Save button, and the next Alt+Tab uses it. Layout, tokens and lifecycle follow the other third-party panels (omagnet's, Omaland's).
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string page: ""   // "" for the settings list, or the editor page a setting asked for ("icons", the picker; "packs", the pack editor; "builder", the icon builder)
  property string pageKey: "icon_theme"   // the setting that opened the picker, so it starts on the right tab

  // Categories with something to show, the chosen one (the first until a click), and which categories have their advanced settings open.
  property string category: ""
  property var advancedOpen: ({})
  readonly property var categories: settings.spec.groups.filter(function (g) { return g.settings.some(function (s) { return !s.hidden }) })
  readonly property var current: categories.find(function (g) { return g.id === root.category }) || categories[0] || null
  readonly property var byId: ConfigIO.indexById(ConfigIO.flatSettings(settings.spec))
  readonly property int advancedCount: current ? current.settings.filter(function (s) { return s.advanced && !s.hidden }).length : 0

  function isShown(s) {
    return ConfigIO.visible(s, root.byId, function (x) { return settings.value(x) }, !!root.advancedOpen[root.current ? root.current.id : ""])
  }
  function subgroupShown(title) {
    return root.current.settings.some(function (s) { return s.subgroup === title && root.isShown(s) })
  }

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property color scrim: Color.menu.scrim
  property string fontFamily: Style.font.menuFamily

  function open(payloadJson) {
    root.page = ""
    root.opened = true
    settings.reload()
    devPage.reload()
    Qt.callLater(function () { content.forceActiveFocus() })
  }

  function close() {
    if (root.opened && settings.pending) settings.saveNow() // never drop a pending edit
    root.opened = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.felipecpaiva.omahop")
    else close()
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  SettingsStore { id: settings }

  // Dev and test only: write a setting key (icon_theme or icon_pack), or "builder", into $XDG_RUNTIME_DIR/omahop/open-page and the next open lands on that picker page
  // (a screenshot needs no keys). The file is emptied once read. Nothing else reads it; docs/settings.md, "Opening a page without clicks".
  FileView {
    id: devPage
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omahop/open-page"
    printErrors: false
    onLoaded: {
      var key = text().trim()
      if (key === "" || !root.opened) return // the load at start up is not an open
      root.pageKey = key
      root.page = key === "builder" ? "builder" : "icons"
      setText("")
    }
  }

  PanelWindow {
    id: window
    // Hidden while the pack editor's or the builder's file chooser is open: the chooser is a normal window and would open under this overlay.
    visible: root.opened && !(editorLoader.item && editorLoader.item.picking) && !(builderLoader.item && builderLoader.item.picking)
    onVisibleChanged: if (visible) Qt.callLater(function () { content.forceActiveFocus() })
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omahop-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: root.scrim
      MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(Style.space(780), window.width - Style.gapsOut * 4)
      height: Math.min(Style.space(640), window.height - Style.gapsOut * 4)
      radius: Style.cornerRadius
      color: root.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))

      MouseArea { anchors.fill: parent; onClicked: {} }

      // Ancestor of every field, so Escape from inside a text field still closes the panel.
      Item {
        id: content
        anchors.fill: parent
        // BorderSurface's padding does not move children that are anchored to it: keep clear of the border and the card's own padding by hand.
        anchors.topMargin: card.borderTop + Style.spacing.panelPadding
        anchors.bottomMargin: card.borderBottom + Style.spacing.panelPadding
        anchors.leftMargin: card.borderLeft + Style.spacing.panelPadding
        anchors.rightMargin: card.borderRight + Style.spacing.panelPadding
        focus: true
        Keys.onEscapePressed: root.dismiss()

        ColumnLayout {
          anchors.fill: parent
          spacing: Style.spacing.sm

          RowLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              textFormat: Text.PlainText
              text: "omahop"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              textFormat: Text.PlainText
              text: settings.status
              color: settings.failed ? Color.urgent : Qt.darker(root.foreground, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Button {
              text: "Close"
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.dismiss()
            }
          }

          Loader {
            id: editorLoader
            active: root.page === "packs"
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: PackEditorPage {
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onBack: { root.page = ""; content.forceActiveFocus() }
            }
          }

          Loader {
            active: root.page === "icons"
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: IconPickerPage {
              store: settings
              byId: root.byId
              settingKey: root.pageKey
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onBack: { root.page = ""; content.forceActiveFocus() }
              onPackEditorRequested: root.page = "packs"
              onBuilderRequested: root.page = "builder"
            }
          }

          Loader {
            id: builderLoader
            active: root.page === "builder"
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: BuilderPage {
              store: settings
              byId: root.byId
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onBack: { root.page = "icons"; content.forceActiveFocus() }
            }
          }

          RowLayout {
            visible: root.page === ""
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.spacing.md

            // Categories: one per spec group, so a new group needs no panel code.
            ColumnLayout {
              Layout.alignment: Qt.AlignTop
              Layout.preferredWidth: Style.space(150)
              Layout.minimumWidth: Style.space(150)
              Layout.maximumWidth: Style.space(150)
              spacing: Style.spacing.xs
              Repeater {
                model: root.categories
                Button {
                  required property var modelData
                  Layout.fillWidth: true
                  text: modelData.title
                  bordered: root.current && modelData.id === root.current.id
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.fontFamily
                  onClicked: root.category = modelData.id
                }
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.preferredWidth: 1
              spacing: Style.spacing.sm

              Flickable {
                id: scroller
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: column.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                  id: column
                  width: scroller.width
                  spacing: Style.spacing.sm

                  // One entry per setting of the chosen category, in spec order. The model only changes with the category; each row shows or hides itself.
                  Repeater {
                    model: root.current ? root.current.settings : []
                    ColumnLayout {
                      id: item
                      required property var modelData
                      required property int index
                      readonly property bool shown: root.isShown(modelData)
                      readonly property bool firstOfSubgroup: index === 0 || root.current.settings[index - 1].subgroup !== modelData.subgroup
                      Layout.fillWidth: true
                      spacing: Style.spacing.sm

                      PanelSectionHeader {
                        visible: item.firstOfSubgroup && root.subgroupShown(modelData.subgroup)
                        text: modelData.subgroup
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                      }
                      SettingRow {
                        visible: item.shown
                        Layout.leftMargin: modelData.depth * Style.space(16)
                        setting: modelData
                        store: settings
                        foreground: root.foreground
                        accent: root.accent
                        fontFamily: root.fontFamily
                        onEditorRequested: function (editor, key) { root.pageKey = key; root.page = editor }
                      }
                    }
                  }

                  Button {
                    visible: root.advancedCount > 0
                    text: root.advancedOpen[root.current.id] ? "Hide advanced settings" : "Show advanced settings (" + root.advancedCount + ")"
                    foreground: root.foreground
                    accent: root.accent
                    fontFamily: root.fontFamily
                    onClicked: {
                      var o = Object.assign({}, root.advancedOpen)
                      o[root.current.id] = !o[root.current.id]
                      root.advancedOpen = o
                    }
                  }
                }
              }

              ColumnLayout {
                visible: settings.needsReload
                Layout.fillWidth: true
                spacing: Style.spacing.xs
                PanelSeparator { foreground: root.foreground; Layout.fillWidth: true }
                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                  text: "A change you made applies after Hyprland reloads."
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Button {
                  text: "Reload Hyprland now"
                  bordered: true
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.fontFamily
                  onClicked: settings.reloadHyprland()
                }
              }
            }
          }
        }
      }
    }
  }
}

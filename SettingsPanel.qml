import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// omahop settings: one scrolling page, built from spec.json (so a new setting needs no panel code). Every change is saved after a short pause,
// there is no Save button, and the next Alt+Tab uses it. Layout, tokens and lifecycle follow the other third-party panels (omagnet's, Omaland's).
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string page: ""   // "" for the settings list, or the editor page a setting asked for ("packs")

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property color scrim: Color.menu.scrim
  property string fontFamily: Style.font.menuFamily

  function open(payloadJson) {
    root.page = ""
    root.opened = true
    settings.reload()
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

  PanelWindow {
    id: window
    // Hidden while the pack editor's file chooser is open: the chooser is a normal window and would open under this overlay.
    visible: root.opened && !(editorLoader.item && editorLoader.item.picking)
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
      width: Math.min(Style.space(560), window.width - Style.gapsOut * 4)
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
              onBack: root.page = ""
            }
          }

          Flickable {
            id: scroller
            visible: root.page === ""
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: column.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: column
              width: scroller.width
              spacing: Style.spacing.md

              Repeater {
                model: settings.spec.groups
                ColumnLayout {
                  id: group
                  required property var modelData
                  Layout.fillWidth: true
                  spacing: Style.spacing.sm
                  // A group with nothing to show (its settings are still hidden) takes no room.
                  readonly property var shown: modelData.settings.filter(function (s) { return !s.hidden })
                  visible: shown.length > 0

                  PanelSeparator { foreground: root.foreground; Layout.fillWidth: true }
                  PanelSectionHeader { text: group.modelData.title; foreground: root.foreground; fontFamily: root.fontFamily }

                  Repeater {
                    model: group.shown
                    SettingRow {
                      required property var modelData
                      setting: modelData
                      store: settings
                      foreground: root.foreground
                      accent: root.accent
                      fontFamily: root.fontFamily
                      onEditorRequested: function (editor) { root.page = editor }
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

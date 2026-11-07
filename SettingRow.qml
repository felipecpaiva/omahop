import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// One setting, drawn from its spec entry: a label, the control that fits its type, a help line, and a reset link when the file overrides the default.
ColumnLayout {
  id: row

  property var setting: ({})
  property var store: null
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily

  readonly property var current: row.store ? row.store.value(row.setting) : row.setting.default
  readonly property var overridden: row.store ? row.store.override(row.setting) : undefined

  // A value as the row words it: the display name of a choice, on or off for a switch, else the value itself.
  function shown(v) {
    if (row.setting.names && row.setting.names[v] !== undefined) return row.setting.names[v]
    if (typeof v === "boolean") return v ? "on" : "off"
    return v === "" ? "empty" : String(v)
  }

  Layout.fillWidth: true
  spacing: Style.spacing.xs

  Toggle {
    visible: row.setting.type === "bool"
    Layout.fillWidth: true
    label: row.setting.label || ""
    checked: row.current === true
    foreground: row.foreground
    accent: row.accent
    fontFamily: row.fontFamily
    onClicked: row.store.setValue(row.setting, !(row.current === true))
  }

  // Everything that is not a switch has its label above the control.
  Text {
    visible: row.setting.type !== "bool"
    Layout.fillWidth: true
    textFormat: Text.PlainText
    text: row.setting.label || ""
    color: row.foreground
    font.family: row.fontFamily
    font.pixelSize: Style.font.body
    font.bold: true
    elide: Text.ElideRight
  }

  Flow {
    visible: row.setting.type === "enum"
    Layout.fillWidth: true
    spacing: Style.spacing.xs
    Repeater {
      model: row.setting.type === "enum" && row.store ? row.store.choices(row.setting) : []
      Button {
        required property string modelData
        text: row.shown(modelData)
        bordered: modelData === row.current
        foreground: row.foreground
        accent: row.accent
        fontFamily: row.fontFamily
        onClicked: row.store.setValue(row.setting, modelData)
      }
    }
  }

  RowLayout {
    visible: row.setting.type === "int"
    spacing: Style.spacing.sm
    NumberField {
      value: row.setting.type === "int" ? row.current : 0
      from: row.setting.min !== undefined ? row.setting.min : 0
      to: row.setting.max !== undefined ? row.setting.max : 100000
      foreground: row.foreground
      accent: row.accent
      fontFamily: row.fontFamily
      onModified: function (v) { row.store.setValue(row.setting, v) }
    }
    Text {
      visible: !!row.setting.unit
      textFormat: Text.PlainText
      text: row.setting.unit || ""
      color: Qt.darker(row.foreground, 1.6)
      font.family: row.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  TextField {
    visible: row.setting.type === "text"
    Layout.fillWidth: true
    text: row.setting.type === "text" ? String(row.current) : ""
    foreground: row.foreground
    accent: row.accent
    onEditingFinished: if (text !== String(row.current)) row.store.setValue(row.setting, text)
  }

  Text {
    visible: !!row.setting.help
    Layout.fillWidth: true
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    text: row.setting.help || ""
    color: Qt.darker(row.foreground, 1.6)
    font.family: row.fontFamily
    font.pixelSize: Style.font.caption
  }

  // The chosen profile replaces this value: say so, since the control above shows the base value.
  Text {
    visible: row.overridden !== undefined
    Layout.fillWidth: true
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    text: row.overridden === undefined ? "" : "Profile " + row.store.resolved.profile + " sets this to " + row.shown(row.overridden) + "."
    color: row.accent
    font.family: row.fontFamily
    font.pixelSize: Style.font.caption
  }

  Button {
    visible: row.store && row.store.isSet(row.setting)
    text: "Reset to default"
    foreground: row.foreground
    accent: row.accent
    fontFamily: row.fontFamily
    fontSize: Style.font.caption
    onClicked: row.store.resetValue(row.setting)
  }
}

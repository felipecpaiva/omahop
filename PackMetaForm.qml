import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// The four pack.toml fields of the pack editor. Filled from `values` (the parsed pack.toml) whenever they change; `submitted` hands the
// typed text to the page, which runs tools/pack-edit.sh (init or meta), where the rules are.
ColumnLayout {
  id: form

  property var values: ({})
  property bool creating: false
  property bool busy: false
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily

  signal submitted(string name, string author, string license, string description)

  spacing: Style.spacing.xs

  function fill() {
    nameField.text = form.creating ? "" : String(form.values.name || "")
    authorField.text = form.creating ? "" : String(form.values.author || "")
    licenseField.text = form.creating ? "" : String(form.values.license || "")
    descriptionField.text = form.creating ? "" : String(form.values.description || "")
  }
  onValuesChanged: form.fill()
  onCreatingChanged: form.fill()

  GridLayout {
    Layout.fillWidth: true
    columns: 2
    columnSpacing: Style.spacing.sm
    rowSpacing: Style.spacing.xs
    TextField { id: nameField; Layout.fillWidth: true; placeholderText: "Name"; foreground: form.foreground; accent: form.accent }
    TextField { id: authorField; Layout.fillWidth: true; placeholderText: "Author"; foreground: form.foreground; accent: form.accent }
    TextField { id: licenseField; Layout.fillWidth: true; placeholderText: "Licence, such as CC0-1.0"; foreground: form.foreground; accent: form.accent }
    TextField { id: descriptionField; Layout.fillWidth: true; placeholderText: "Description (optional)"; foreground: form.foreground; accent: form.accent }
  }

  Button {
    text: form.creating ? "Make the pack" : "Save details"
    bordered: true
    enabled: !form.busy
    foreground: form.foreground
    accent: form.accent
    fontFamily: form.fontFamily
    onClicked: form.submitted(nameField.text, authorField.text, licenseField.text, descriptionField.text)
  }
}

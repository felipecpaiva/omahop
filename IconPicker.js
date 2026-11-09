.pragma library
// The icon picker's pure logic (tests/icon_picker.test.mjs): the list of choices, the filter, arrow key movement and reading the scripts' output.
// What exists comes from tools/icon-themes.sh, tools/pack-edit.sh list and tools/icon-preview.sh; nothing here knows a theme by name.

// The pages the picker has, one per setting that asks for it (spec field editor = "icons"). A new kind of choice is a new line here and a new scan command in the page.
const KINDS = [
  { id: "theme", setting: "icon_theme", title: "Theme", none: "Automatic", noneHelp: "Whichever theme the scan finds first (today's behaviour)" },
  { id: "pack", setting: "icon_pack", title: "Pack", none: "No pack", noneHelp: "Use no icon pack" }
]

function kindFor(settingKey) { return KINDS.find((k) => k.setting === settingKey) || KINDS[0] }

// "folder<TAB>Name" lines to {value, title}.
function parseThemes(text) {
  const out = []
  for (const line of String(text || "").split("\n")) {
    if (line.trim() === "") continue
    const [value, ...rest] = line.split("\t")
    out.push({ value: value, title: rest.join("\t").trim() || value })
  }
  return out
}

// "id<TAB>path" lines to {id: path}. No prototype, so an id such as "constructor" is just a miss.
function parsePreview(text) {
  const map = Object.create(null)
  for (const line of String(text || "").split("\n")) {
    const tab = line.indexOf("\t")
    if (tab > 0) map[line.slice(0, tab)] = line.slice(tab + 1).trim()
  }
  return map
}

// The cards of a kind: the "none" card first (empty value), then the found choices.
function choices(kind, found) {
  return [{ value: "", title: kind.none, help: kind.noneHelp }].concat(found.map((c) => ({ value: c.value, title: c.title, help: c.value === c.title ? "" : c.value })))
}

// Case blind substring over the title and the folder name. The "none" card stays unless the text says otherwise.
function filter(list, text) {
  const q = String(text || "").trim().toLowerCase()
  if (q === "") return list
  return list.filter((c) => c.title.toLowerCase().includes(q) || c.value.toLowerCase().includes(q))
}

function indexOfValue(list, value) {
  const i = list.findIndex((c) => c.value === value)
  return i < 0 ? 0 : i
}

// The new highlighted row for a key, or -1 when the key is not a movement key. Moves stop at the ends.
function move(index, key, count) {
  if (count <= 0) return -1
  const last = count - 1
  const steps = { Up: index - 1, Down: index + 1, PageUp: index - 4, PageDown: index + 4, Home: 0, End: last }
  return key in steps ? Math.max(0, Math.min(last, steps[key])) : -1
}

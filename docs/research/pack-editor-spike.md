# Icon pack editor: design

Date 2026-11-08, against omahop v1.4.0. Step 3 of `packs-spike.md`: make, edit, export and import icon packs from the settings window,
without touching files by hand. Steps 1 (hand-made packs, v1.3) and 2 (zip export and import, v1.4) are the base; the editor adds no new
format and no new validation rule.

## What exists on this machine (checked)

- **File picker:** `omarchy file select --title T --extensions "png svg"` (`/usr/share/omarchy/bin/omarchy-file-select`). It asks the
  xdg-desktop-portal FileChooser, prints the picked file as a **plain path** (one per line, not a `file://` URI, unlike what
  `packs-spike.md` assumed), exits 1 when nothing was picked and 2 when the chooser failed. No Omarchy plugin installed here calls it from
  QML yet; the shell's own panels run commands through `Quickshell.Io.Process` and read the exit code and a `StdioCollector` in `onExited`,
  which is the pattern used here.
- **Apps:** the panel can read `DesktopEntries.applications` (id, name, icon, `startupClass`, `noDisplay`) and `Hyprland.toplevels`
  (the Wayland app id) itself. The service's system icon index lives in another component (`Service.qml`), which the panel cannot reach,
  so the panel shows system icons with `Quickshell.iconPath` and pack icons from `tools/pack-index.sh`.
- **Ui kit:** `Button`, `TextField`, `FilterInput`, `PanelSectionHeader`, `PanelSeparator` in `qs.Ui`, already used by the panel.

## Flow

One more page of the one settings window, not a second window and nothing in the bar.

1. The **Icon pack** row (group Look) gets a button `Make or edit icon packs`. It comes from the spec (`editor = "packs"` on `icon_pack` in
   `lua/config.lua`, passed through `tools/gen-spec.lua`), so the panel stays spec driven. The button swaps the settings list for the
   editor page; `Back` swaps it back. The page is loaded only while shown, so nothing runs otherwise.
2. **Pick or create a pack.** A button per installed pack folder (`pack-edit.sh list`) and `New pack`. Creating asks for the display name,
   author, licence and description; the folder name is derived from the display name with the importer's rule (now one function,
   `pack_folder_name` in `pack-lib.sh`), so exporting and importing a pack lands in the same folder.
3. **Metadata.** Name, author, licence, description fields, filled from the pack's `pack.toml` (read with `ConfigIO.parse`, the same flat
   format), `Save` runs `pack-edit.sh meta`. Other keys and comments in the file are kept.
4. **Apps.** A filter field and a list (a `ListView`, so hundreds of installed apps cost only the visible rows): open windows first, then
   installed desktop entries by name, then pack icons that match no listed app (so they can still be removed). Each row shows the icon in
   use (the pack's, else the system's), the app name and its id, `Choose image` and, when the pack has one, `Remove`.
5. **Choose image.** Runs `omarchy file select` through `pack-edit.sh pick image` (exit 2 when the command is missing, so a missing chooser
   looks like a failed one and never like a process that could not start). While the chooser is open the settings window hides (it is an overlay layer with the
   keyboard, the chooser is a normal window that would open under it) and comes back when the chooser ends. Exit 1 does nothing; exit 2 or a
   missing command shows a path field (`Image file`) with an `Add` button instead. Either way the path goes to `pack-edit.sh add`.
6. **Export** writes `~/<folder>.omahop-pack.zip` with `pack-export.sh`. If the file exists the page says so and offers `Replace`.
7. **Import** picks a `.zip` the same way, runs `pack-import.sh --dry-run`, shows the summary (name, author, licence, icon count, where it
   goes, whether a pack of that name is installed) and `Install` (or `Replace`), which reruns it with `--yes` (and `--replace`).
8. Every result and refusal is shown in one status line under the pack buttons; the scripts' own reasons are shown as they are.

## Writer and validation

All writes go through one new script, `tools/pack-edit.sh`, positional arguments only (no flags, so no value can be read as one):

| Command | Does |
|---|---|
| `list` | prints the installed pack folders (not hidden, a valid pack name) |
| `stem <app id>` | prints the icon file stem for an app, or fails (the test compares it with the JS mirror) |
| `init <name> <author> <license> [description]` | makes `packs/<folder>/pack.toml` and `icons/`, prints the folder |
| `meta <folder> <name> <author> <license> [description]` | rewrites those four keys, keeps every other line |
| `add <folder> <app id> <image>` | copies the image in as `icons/<stem>.png` or `.svg`, prints the file name |
| `remove <folder> <icon file>` | deletes that one icon (a link itself, never its target) |
| `pick image\|zip` | runs Omarchy's file chooser for that type; exit 2 when it is not installed |

Rules, all from `pack-lib.sh`, none rewritten in QML or JS:

- The folder must pass `pack_name_ok`, exist, be a real folder (not a link: a linked pack is edited where it lives) and pass `pack_check`.
  Writes go only under `packs/<folder>/`; temporary files are hidden names inside that folder, so the final `mv` is one rename on the same disk.
- `add`: the image must be a full path to a regular file within the PNG cap; it is copied with a byte cap into a hidden staging pack inside
  the pack folder, named `<stem>.png` when it has the PNG signature, else `<stem>.svg`, and that staging pack must pass `pack_check_strict`
  (the exact rule export and import use: name, size, PNG header and size, plain SVG). Only then it is moved into `icons/`, and any other
  file for the same app (the other extension, another case) is removed so one app has one file.
- The stem: the app id in lower case with runs of spaces turned into one `-`, which must then be a valid icon file name. That is a form the
  resolver already tries, so the file is found. An id that cannot be a file name (non-ASCII, `/`, `:`) is refused, not rewritten.
- `init` and `meta`: name, author, licence must not be empty; no value may hold `"` or a control character (the format cannot hold them) or
  be longer than the 500 character limit; the result must pass `pack_check` before it replaces `pack.toml`.
- Export and import are the v1.4 scripts unchanged except `pack-import.sh --dry-run` (every check, the summary, no install).
- No network anywhere. The editor writes nothing outside `packs/<folder>/`, except the export zip in `~` and the import (the importer's own
  staging under `~/.cache/omahop` and its rename into `packs/`).

## Pure logic: `PackEditor.js`

A `.pragma library` file with Node tests (`tests/pack_editor.test.mjs`): `iconStem` (the same rule as `pack-edit.sh stem`, checked against
it on hostile inputs by `tests/pack_edit.test.sh`), `appRows` (merge, order, dedupe, filter, the pack file in use through an injected
`IconResolve.packPick`, orphan pack files), `parseImportSummary`, the editor state machine (`idle`, `busy`, `confirm`; one action at a
time; what each exit code means), and `argv` (every command as an argument array for `Process`, never a shell line; refuses a value that
is not a string, holds a NUL or newline, a folder starting with `-`, or a file path that is not absolute).

## Refreshing the switcher

The panel and the service are separate components. After an edit or import that changes the chosen pack, the panel writes
`$XDG_RUNTIME_DIR/omahop/pack-changed`; `Service.qml` watches that file and rescans the pack (the cheap pack scan, never the system scan)
and clears its icon cache. Qt still keeps a replaced picture with the same file name until a shell restart (known since v1.3); the editor's
own preview loads with `cache: false`.

## Not built (from `packs-spike.md`)

- No `mine` override layer and no "imported packs are read only": every installed, non-linked pack is editable; there is one pack layer.
- No `aliases`, no `preview.png`, no image conversion with `magick` (a picture must already be PNG or SVG), no drag and drop.
- No delete pack button (deleting a folder is one `rm -r` the user can do; a misclick here would lose work).

## Risks

1. The picker over a layer-shell panel: hiding the panel while the chooser runs is untested in a live session (hand check 1).
2. `FileView` watching a runtime file that may not exist yet: the service writes it once at load so the watch has a file.
3. QML is only syntax-checked here (`qmllint`); every click path is a hand check in `validation-checklist.md`.

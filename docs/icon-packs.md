# Icon packs

An icon pack gives apps in the switcher, the cards and the peek strip your own icons. Packs are folders you make in the settings window
([The editor](#the-editor)) or by hand, copy from someone (a git clone works), or receive as one zip and install with the importer
(see [Share a pack as one zip](#share-a-pack-as-one-zip)).

Off by default: nothing changes until you set `icon_pack`.

## Use a pack

1. Put the pack folder in `~/.config/omahop/packs/` (or `$XDG_CONFIG_HOME/omahop/packs/`). The folder may also be a link to a folder kept elsewhere.
2. Press the **Choose a pack** button under Icon pack in the settings window (group Look): a picker shows each pack with the same sample apps, Enter chooses (see settings.md, Icon picker). Or type the folder name in the box below it, or `icon_pack = "my-pack"` in `config.toml`.

The pack is read at once. Icons the pack has come first; every other app keeps the icon it had (from `icon_theme` and the installed themes).
Empty `icon_pack` uses no pack.

The folder is read when the setting changes and when the shell starts. After adding, removing or replacing files in a pack, restart the shell
(`omarchy restart shell`) or set the pack to empty and back. A replaced file with the same name may keep showing the old picture until a shell
restart, because Qt keeps images by file name.

## Folder layout

```
~/.config/omahop/packs/my-pack/
  pack.toml          required
  icons/             required, flat (folders inside it are ignored)
    firefox.svg
    kitty.png
    com.mitchellh.ghostty.svg
  LICENSE            recommended: the licence of the icons
```

### pack.toml

The same flat format as `config.toml`: `key = "text"` lines and `#` comments, no sections.

```toml
name = "My pack"
author = "Your name"
license = "CC0-1.0"              # an SPDX id, or a sentence
description = "Optional, one line"
```

`name`, `author` and `license` are required and must not be empty. Other keys, numbers and `true`/`false` are allowed and ignored (room for
later versions). Each text is at most 500 characters, the file at most 16 KB. Quotes inside a text are not possible.

A pack.toml that is missing, too big, has a line that is not `key = value`, or lacks a required key: the **whole pack is not used**, the switcher
keeps the system icons, and the shell log says why. Read the notes with
`strings $(ls -t $XDG_RUNTIME_DIR/quickshell/by-id/*/log.qslog | head -1) | grep "omahop icon pack"`.

### Icon file names

The file name, without `.png` or `.svg`, is the app it is for. omahop tries, in order, the window class (app id) as it is, in lower case, with
spaces turned into hyphens, the last part of a reverse-DNS id (`com.mitchellh.ghostty` also tries `ghostty`), then the icon name from the
app's desktop entry. Case never matters: `Kitty.png` serves `kitty`.

To find a window's class: `hyprctl clients | grep class`.

Allowed names: letters, digits, `.`, `_`, `+`, `-`, starting with a letter or digit, ending in `.png` or `.svg` (lower case), at most 200
characters. Hidden files (a leading dot) are skipped.

A link inside `icons/` that points to another file in the same pack is allowed, so one picture can serve several apps
(`ln -s firefox.svg zen.svg`). The link's name is the app.

### Size advice

- Prefer SVG: it is sharp at every size, usually 2 to 30 KB.
- A PNG should be square, 128 or 256 px. The list draws icons small; bigger only costs memory.
- Limits: PNG at most 2 MB and 4096 px on a side, SVG at most 256 KB, at most 2000 icons.

## What is refused

Packs are made by other people, so every file is checked before omahop uses it (`tools/pack-index.sh`). A refused file is skipped with a note in
the log; the rest of the pack still works.

- A pack name with anything but letters, digits, `.`, `-`, `_` (no `/`, no `..`): the whole setting is ignored.
- A file or link that leads outside the pack folder, or a link to nothing.
- Any extension but `.png` and `.svg`, and a name outside the rules above.
- A file larger than the limits, a PNG whose header is not a PNG or claims a picture too large, a `.png` that is really something else.
- An SVG that is not plain: `<script>`, `<foreignObject>`, `<iframe>`, `<embed>`, `<object>`, event attributes (`onload=`), a `DOCTYPE` or
  entity, or any `href` or `url()` that is not an in-file `#id` or embedded `data:image/png|jpeg|webp;base64` data. Inkscape: save as
  **Plain SVG** and remove any linked image.

Nothing in a pack is ever run.

## Example

`docs/examples/packs/omahop-sample/` is a tiny pack made for omahop (CC0, plain shapes, no app logos): a green circle for firefox and a blue
square for kitty. To try it:

```bash
mkdir -p ~/.config/omahop/packs
cp -r docs/examples/packs/omahop-sample ~/.config/omahop/packs/
```

then set Icon pack to `omahop-sample`.

## The editor

Open the settings window, find **Icon pack** (group Look) and press **Make or edit icon packs**. The settings list gives way to the editor;
**Back** returns. Nothing is added to the bar or the desktop, and nothing runs while the page is closed.

- **Choose a pack** by its folder name, or **New pack**: type the name, author, licence and an optional description, then **Make the pack**.
  The folder is the name in lower case with other characters as dashes (`My Pack!` becomes `my-pack`), the same rule the importer uses.
- **Details**: change the four fields and **Save details**. Other lines in `pack.toml` (comments, extra keys) are kept. A value cannot hold a
  double quote or a line break and is at most 500 characters.
- **Apps**: open windows first, then installed apps, then icons in the pack that no listed app uses. Each row shows the icon it gets now and
  whether it is the pack's or the system's. **Filter apps** narrows the list.
- **Choose image** opens Omarchy's file chooser (`omarchy file select`); the settings window steps aside while it is open and comes back after.
  The picture must be a PNG or a plain SVG within the [limits](#size-advice); it is checked with the same rules as a shared pack before it is
  copied into `icons/` as `<app id>.png` or `.svg` (the type is read from the file, not its name). An older picture for the same app is replaced.
  If the chooser cannot open, a field asks for the file's full path instead.
- **Remove** deletes the pack's picture for that app (a link inside the pack is removed, never the file it points to).
- **Export** writes `~/<folder>.omahop-pack.zip`; if that file exists the page asks before replacing it.
- **Import a zip** opens the chooser for a `.zip`, checks it (every rule in the table below), shows name, author, licence, icon count and
  where it goes, and installs only after **Install** (or **Replace**, when a pack of that name is installed).

Every result and every refusal is shown under the pack buttons, with the reason the check gave. The editor tells the switcher to rescan the
chosen Icon pack, so a change should show at the next Alt+Tab (not yet checked in a live session; if not, set Icon pack empty and back); a picture replaced under the same file name may still show the old one until
`omarchy restart shell`. A pack folder that is a link to a folder kept elsewhere (a git clone) can be exported, not edited: edit it where it lives.

The editor writes nothing itself. Every change runs `tools/pack-edit.sh`, which also works by hand:

```bash
bash $OMAHOP/tools/pack-edit.sh init "My pack" "Your name" CC0-1.0 "One line"   # prints the folder, my-pack
bash $OMAHOP/tools/pack-edit.sh add my-pack firefox ~/Pictures/fox.svg           # prints firefox.svg
bash $OMAHOP/tools/pack-edit.sh remove my-pack firefox.svg
bash $OMAHOP/tools/pack-edit.sh meta my-pack "My pack" "Your name" MIT
bash $OMAHOP/tools/pack-edit.sh list
```

It only writes inside `~/.config/omahop/packs/<folder>/`, through a hidden temporary name and one rename, and refuses anything else with a reason.

## Share a pack as one zip

The commands live in the plugin folder, `~/.config/omarchy/plugins/io.github.felipecpaiva.omahop/` (below as `$OMAHOP`). The editor runs
the same two commands; these are for the terminal.

To send a pack:

```bash
bash $OMAHOP/tools/pack-export.sh my-pack            # writes ~/my-pack.omahop-pack.zip
bash $OMAHOP/tools/pack-export.sh my-pack out.zip    # or a path of your choice; an existing file is kept unless --force
```

Then send the zip any way you like (chat, mail, a release on a git host). omahop uploads nothing.

To receive one:

```bash
bash $OMAHOP/tools/pack-import.sh ~/Downloads/my-pack.omahop-pack.zip
```

The importer checks the zip, shows the pack name, author, licence, icon count and the files it will add, and asks before installing. `--yes`
skips the question, `--dry-run` checks everything and shows the summary without installing, `--replace` replaces an installed pack of the same name (without it an installed pack is never touched). It installs into
`~/.config/omahop/packs/<folder>/`, where the folder is the pack.toml `name` in lower case with every run of other characters turned into one
`-` (`"omahop sample"` becomes `omahop-sample`), then says what to type in Icon pack. Importing never sets Icon pack by itself.

What export does: the pack must pass every rule pack-index uses, strictly (a file pack-index would skip, such as a stray `.DS_Store`, stops
the export and is named, so you share no junk). The zip holds `pack.toml` and `icons/` only (not `LICENSE` or other files, so put the licence
in pack.toml); a link inside `icons/` becomes a plain copy. Entries are sorted and carry one fixed time, owner and mode, so the same pack always
gives the same zip, byte for byte.

What import refuses, and why. The whole zip is refused at the first problem and nothing is left behind:

| Refused | Why |
|---|---|
| Not a zip (checked by its first bytes), larger than 50 MB, or unreadable | Only the format export writes is read |
| A name starting with `/`, or with a `..` part | It would write outside the pack (zip slip) |
| A link, device or other special entry | A link can point anywhere on your disk |
| A hidden name (a part starting with a dot) | Nothing in a pack should be invisible |
| Any folder but `icons/`, any file but `pack.toml` and `icons/<app>.png` or `.svg` | A pack is data only, so it cannot smuggle a script beside the icons |
| Two names that differ only in case | They collide on some disks and in omahop's case-blind lookup |
| More than 2002 entries (2000 icons, pack.toml, the folder) | Bounds the work |
| A file over its limit (PNG 2 MB, SVG 256 KB, pack.toml 16 KB), more than 100 MB in all, or more than 100 times the zip's own size | Zip bombs: a tiny zip that unpacks to gigabytes |
| No pack.toml, or one that breaks the [pack.toml](#packtoml) rules, or whose name has no letter or digit | The pack must say what it is and who made it |
| Any icon that pack-index would skip (see [What is refused](#what-is-refused)) | The same rules as a pack you copy by hand, applied to every file |

All of this is decided from the zip's listing before anything is unpacked. Then the importer unpacks each allowed entry itself, by its checked
name, with a byte cap (so a listing that lies about sizes gets no further), into a fresh folder under `~/.cache/omahop/`, runs the pack-index
rules on it, and only after your yes copies it next to the packs and renames it into place in one step. Nothing from the zip is ever run, and
no root is needed. It needs `bsdtar`, which every Arch system has (pacman depends on it).

**Safety note.** A pack is only images and one text file, and the importer holds it to that. Still, never unzip a pack from a stranger by
hand: `unzip` and file managers follow paths and links in the archive. Use the importer, which checks everything first.

## Sharing and licences

App logos are trademarks and often copyrighted art. A pack author needs the right to share every icon in it: original art, or art under a
licence that allows sharing. Put the licence in `pack.toml` and a `LICENSE` file. omahop ships no third-party icons; the sample pack is original.

A pack folder can live in its own git repository; others clone it into `~/.config/omahop/packs/`.

## Icons in the Omarchy app grid, bar and menu (optional)

Off by default. The setting **Use these icons in the Omarchy app grid, bar and menu** (`icons_in_launcher`, group Look, Show advanced, needs an
`icon_theme` or an `icon_pack`, not changed by a profile) extends your icon choice beyond omahop:

- **Changes:** the app grid (Super + Alt + Space), the app icons on the bar, and the app rows of the Omarchy menu.
- **Does not change:** the menu's own round glyph icons (Apps, Learn, System and so on); they are font glyphs, not files.
- **How:** omahop owns one folder, `~/.local/share/icons/omahop-launcher/` (`apps/<Icon= name>.svg`, one symlink per desktop entry, pointing at the file
  omahop picked for it: pack first, then theme, the same rules as the switcher, plus a `.omahop` marker file). Omarchy's icon index reads that
  folder before the system ones. No Omarchy file, desktop entry or system icon theme is touched. Other programs that read
  `~/.local/share/icons` may notice the folder (it has no `index.theme`, so it is not offered as a theme).
- **Off:** turning the setting off, or emptying both the theme and the pack, deletes the folder, but only when the marker file is in it. A folder of
  that name without the marker is never changed (the script refuses and logs a note).
- **Limits (version one):** SVG icons only. A PNG from a pack or theme loses to a system SVG of the same name in Omarchy's index, so such an
  app is left out. A picture already drawn may keep its old icon until the grid is opened again or the shell restarts (Qt keeps images by file).
  Built for the Omarchy shell that has `AppLibrary` (4.5 and later).

The links are rebuilt (after a short wait) when the setting, the theme, the pack or the installed apps change. `tools/icon-overlay.sh on|refresh|off`
does the file work and checks every name and file again; `Service.qml` chooses the files; `lua/omahop.lua` only removes a leftover folder at load.
Test: `tests/icon_overlay.test.sh` (a temporary HOME). Research and live test: `research/launcher-icons.md`, decision D30.

## How it works

The rules live once, in `tools/pack-lib.sh`, sourced by the indexer, the exporter, the importer and the editor's writer `tools/pack-edit.sh`. `tools/pack-index.sh <name>` lists the pack's good icon files, one path per line; `Service.qml` runs it when `icon_pack` changes (a separate scan
from the slow system one in `tools/icon-index.sh`) and passes the result to `IconResolve.resolve` as a layer before the system index. The
resolver takes a list of layers, so a later per-app override folder can sit in front of the pack without changing it. Tests:
`tests/icon_resolve.test.mjs` (pack wins, misses fall through, case, names that look like paths), `tests/pack_index.test.sh` (the sample
pack, then links out, traversal names, huge and wrong-type files, hostile SVGs, and bad pack.toml files) and `tests/pack_zip.test.sh` (hostile
zips built in the test, an export and import round trip in a temporary HOME, and a mutation check on the zip-slip and link rules), `tests/pack_edit.test.sh` (the editor's writer with hostile names, app ids, images and
text, each changing nothing) and `tests/pack_editor.test.mjs` (the editor page's logic: rows, commands, states). Design:
`research/pack-editor-spike.md`.

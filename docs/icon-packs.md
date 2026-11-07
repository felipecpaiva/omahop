# Icon packs

An icon pack gives apps in the switcher, the cards and the peek strip your own icons. Step 1 (this version): packs are folders you make by
hand or copy from someone (a git clone works). There is no import, export or editor yet; those come later (`research/packs-spike.md`).

Off by default: nothing changes until you set `icon_pack`.

## Use a pack

1. Put the pack folder in `~/.config/omahop/packs/` (or `$XDG_CONFIG_HOME/omahop/packs/`). The folder may also be a link to a folder kept elsewhere.
2. Set **Icon pack** in the settings window (group Look) to the folder name, or `icon_pack = "my-pack"` in `config.toml`.

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

## Sharing and licences

App logos are trademarks and often copyrighted art. A pack author needs the right to share every icon in it: original art, or art under a
licence that allows sharing. Put the licence in `pack.toml` and a `LICENSE` file. omahop ships no third-party icons; the sample pack is original.

A pack folder can live in its own git repository; others clone it into `~/.config/omahop/packs/`.

## How it works

`tools/pack-index.sh <name>` lists the pack's good icon files, one path per line; `Service.qml` runs it when `icon_pack` changes (a separate scan
from the slow system one in `tools/icon-index.sh`) and passes the result to `IconResolve.resolve` as a layer before the system index. The
resolver takes a list of layers, so a later per-app override folder can sit in front of the pack without changing it. Tests:
`tests/icon_resolve.test.mjs` (pack wins, misses fall through, case, names that look like paths) and `tests/pack_index.test.sh` (the sample
pack, then links out, traversal names, huge and wrong-type files, hostile SVGs, and bad pack.toml files).

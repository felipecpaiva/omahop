# Icon packs: design spike and verdict

Spike date 2026-11-07, against omahop v1.0.0. Question: can a user pick or build an icon pack in the settings window, override app icons, and share it as one file? Prototypes (run with `node`, no desktop touched): `docs/research/spike-packs/` (`PackResolve.js`, `PackValidate.js`, their tests, `make_zips.py` for hostile fixture zips).

## Verdict

**GO, in three shippable steps.** The resolver change is tiny (IconResolve is already the single choke point), the format can be plain files with no new parser, and the only risky part (importing a stranger's zip) is bounded by a data-only allow list that I prototyped and tested against 12 hostile archives. Ship the small milestone first (v1.1, about 9 hours), then import/export, then the editor. Do not ship the editor before import validation exists.

Recommended format: a **simple pack folder** (`pack.toml` plus a flat `icons/` folder, file name = app id), shared as one `.zip`. Not a freedesktop theme (section 1 explains). A freedesktop theme can still be used, as `icon_theme`, with one line of shell (see "Free find" below).

## 1. Prior art and the format decision

Evidence gathered:

- **freedesktop icon theme spec** (fetched 2026-11-07): `index.theme` needs `Name`, `Comment`, `Directories`; every directory needs its own section with `Size`, `Type` (Fixed, Scalable, Threshold), `Scale`; `Inherits` chains to a parent, then `hicolor`; lookup is by icon NAME and size; formats PNG, SVG, XPM. The spec says nothing about window class matching.
- **Packaging in the wild**: Papirus installs by copying the theme folder to `~/.local/share/icons` (their script with `DESTDIR`), and packages (Arch, PPA) ship the same tree; manual installs may need `gtk-update-icon-cache` or a re-login. Yaru here (`/usr/share/icons/Yaru-purple/index.theme`) shows the shape: a `Directories=` line listing over 70 folders (16x16/apps ... 256x256@2x/apps), `Inherits=Yaru,hicolor`, one section per folder. A hand-made one is tedious and a missing section silently hides icons.
- **Omarchy themes** are git repos cloned into `~/.config/omarchy/themes/<name>` by `omarchy theme install <git-url>`; a theme may carry `icons.theme` (a one-line name of an installed GTK icon theme, here `Yaru-purple`), it does not carry icons. So there is no Omarchy precedent for bundling icons, and the sharing norm is a git repo.
- **Other desktops**: KDE and GNOME treat an icon theme as a tarball of the freedesktop layout dropped into `~/.local/share/icons` (KDE adds a "Get New Stuff" store, GNOME relies on distro packages and Tweaks). macOS and Windows icon changers (LiteIcon, Candybar, IconPackager) are per-app replacement files, usually `.icns`/`.ico` renamed by bundle id or exe, packaged as one archive. That is the per-app model, the one users understand for "make Firefox look like this".

| Criterion | Freedesktop theme (index.theme + apps/) | Simple pack (pack.toml + icons/) |
|---|---|---|
| Hand-building | Needs `Directories`, a section per size folder, size metadata, ideally an icon cache. Easy to get subtly wrong | `icons/<appid>.png`. Drop a file, done. `pack.toml` is 4 lines |
| One-zip sharing | Works, but nested size folders; no manifest for author or licence beyond `Comment` | One flat folder, manifest has author, licence, version |
| Other tools can use it | Yes (GTK, Qt, launchers). The one real advantage | No, only omahop. Mitigated: the flat `icons/` folder is a valid single-size `apps/` dir if a user wants to wrap it |
| Size | Many sizes per icon (Papirus is tens of MB) | One image per app, SVG preferred (about 5 to 30 KB), a 200-icon pack is a few MB |
| Security surface | Many files, nested dirs, symlinks are common in real themes (Papirus uses them heavily). Validating "no symlinks" rejects most real themes | Flat, allow-listed names, easy to reject anything else |
| Match by window class | Not expressible: name only. Our case is the window class (`StartupWMClass`, Wine/Steam classes, `Foo Bar`) differing from the icon name | File name is the class or app id (case-insensitive, same `candidates()` forms as today), plus an `aliases` string for odd ones |
| Light and dark | A second theme, or `Inherits` | Optional later: `<id>.dark.svg` next to `<id>.svg` |
| SVG vs PNG | Both, by size dir | Both, no size dir: SVG scales, PNG should be 128 px or larger |
| Spec to implement | Size matching and inheritance (reimplementing GTK) | None: a file lookup |

**Decision: simple pack.** The deciding criteria are hand-buildability, class matching (the freedesktop name-only model cannot say "this Wine window gets that icon"), and a safe import. The loss is interop with other tools, which the user did not ask for. Interop is cheap to keep: a pack's `icons/` folder can be copied into a theme's `apps/` folder as is.

**Free find, independent of packs.** `tools/icon-index.sh` scans every theme under `~/.icons`, `~/.local/share/icons` and `$XDG_DATA_DIRS/icons`, sorts the paths `sort -rV` and keeps the first file per icon name. So today the winning icon comes from whichever theme sorts first, not from the theme the user picked (Omarchy's `icons.theme`, Papirus, Tela). A user who installs Papirus gets no way to select it. A setting `icon_theme` that puts that theme's folder first in the scan (about 10 lines of shell plus a settings enum fed by a folder listing) gives "pick an icon pack" for every existing Linux theme with zero new format. It is the best value item in this spike and part of milestone 1.

## 2. Lookup order, storage, cache

Order (first hit wins), implemented by `PackResolve.js`'s `resolve(system, [mine, pack], appId, entryIcon)`:

1. **mine**: the user's own overrides, the pack `~/.config/omahop/packs/mine/`. The editor and "set icon for this app" write here. Always on top, so a per-app override beats any chosen pack and survives switching packs. Off when the folder is absent.
2. **active pack**: `icon_pack` (default `""` = none), folder `~/.config/omahop/packs/<id>/` (`$XDG_CONFIG_HOME` honoured, same base as `config.toml`).
3. **system index**: today's `IconResolve.resolve` (entry icon, app id forms, absolute path, generic fallback).

Inside a pack the names tried are: alias for the app id, then the app id forms (`appId`, lower case, spaces to hyphens, last dot part of a reverse-DNS id), then the desktop entry's icon NAME (so a pack made against icon names works too). A pack never follows an absolute path from a desktop entry (that is the system layer's job). All matches are case-insensitive, like the system index.

Why per-app overrides are a pack, not config.toml lines: `ConfigIO.js` keys are `[A-Za-z0-9_]+`, so `com.mitchellh.ghostty` or `google-chrome` cannot be a key, and a flat config should not grow one line per app. Files in `mine/icons/` need no new parser, are exported as a pack for free, and removal is a file delete.

Cache (`Service.qml` `resolved`): keyed by app id, filled only once the index is ready. Changes: (a) an object `{path, fallback}` instead of a path (`lookup()` returns `{icon, fallback, name}`); (b) clear `resolved` whenever the pack index is rebuilt (setting `icon_pack` changed, editor wrote a file, import finished). The system scan (2.2 s here, 8354 icon files) is NOT rerun for a pack change: pack scans are separate. Stale pixels: Qt caches images by URL, so replacing `mine/icons/x.png` in place shows the old image; the editor writes a new revision in the URL (simplest fix: `cache: false` on the row `IconImage` for pack icons only, they are small; alternative: write `x-<n>.png` and delete the old file).

Config additions (all in the `lua/config.lua` spec, so the panel gets them for free, defaults stated):

```toml
icon_pack = ""        # "" = system icons only, otherwise a folder name under packs/
icon_theme = ""       # "" = automatic (today's behaviour), else a freedesktop theme name to prefer
```

Lua does not need to read them (icons are QML-only); the spec still holds them so the file and panel stay one source of truth. gen-spec needs one new rule: an enum whose values come from a folder listing at runtime (`dynamic = "packs"`), see section 3.

## 3. Settings window UI (QML)

Rules applied: no new widget or icon outside the settings window, nothing on by default, one window, plain words, theme tokens only.

What the shell offers (checked on this machine):

- Quickshell 0.3.2, Qt 6.12. `QtQuick.Dialogs` exists (`/usr/lib/qt6/qml/QtQuick/Dialogs`), but a QML `FileDialog` needs a platform dialog helper or the QML fallback with QtQuick.Controls styling that does not follow the Omarchy theme, and this repo has never loaded it. Untested in the shell, so treated as a risk, not a plan.
- **`omarchy file select --title T --extensions "png svg"`** (`/usr/share/omarchy/bin/omarchy-file-select`) opens the desktop file chooser through the xdg-desktop-portal `FileChooser.OpenFile` call (`xdg-desktop-portal-gtk` and `-hyprland` are installed), prints `file://` URIs, exit 1 = nothing picked, exit 2 = chooser failed. It also takes `--directory` and `--multiple`. omahop already runs helpers with `Quickshell.Io.Process` (`icon-index.sh`, `hyprctl`), so this is a plain `Process` with `command: ["omarchy","file","select",...]`. **Recommended picker**: Omarchy's own, themed, portal-native. Fall back to a typed path text field when the command is missing (non-Omarchy install).
- **Drag and drop** (`DropArea`) works on a layer-shell `PanelWindow` only if the source app can drop onto layer surfaces, which varies; treat it as a later nicety, not the core path.
- Running windows: the service already has the toplevel list (app ids). Installed apps: `DesktopEntries.applications` (lazy, touch early, see gotchas).

Minimal editor, a section "Icon pack" at the end of the existing settings page (one more spec group, not a new window):

1. Row "Icon pack": a button group, `None`, each pack found under `packs/` (names from `pack.toml`), `Mine`. Choosing sets `icon_pack`. Extra buttons: `Import pack...`, `Export pack...`.
2. Row "Change an app's icon": a `SearchableDropdown` (Ui component already in the shell: `/usr/share/omarchy/shell/Ui/SearchableDropdown.qml`) listing open windows first, then installed apps, showing the current icon (the resolved one, small) next to each name.
3. On a pick: a preview strip (current icon, new icon, both at the list's real size), buttons `Choose image...` (runs `omarchy file select`), `Remove override` (deletes the file in `mine/`), `Reset all` (confirm via the shell's `ConfirmDialog`, then delete `mine/icons/*`).
4. Live preview is free: the settings panel and the switcher share `Service`, so changing `resolved` re-renders any open list.

Image handling on `Choose image`, done by a small shell script `tools/pack-add.sh <appid> <file>` run with `Process`:

- Check magic bytes and size with the same rules as import (png or svg only, caps in section 4). Anything else (jpg, webp, ico) is converted with `magick` **if present** (`magick in.webp -resize 256x256\> -strip out.png`; ImageMagick 7.1.2 and librsvg are installed here) and the user is told otherwise ("Use a PNG or SVG"). No dependency is added; Qt can read webp natively, but a pack stays PNG or SVG so it is portable.
- PNG larger than 512 px is shrunk with `magick` if present, else kept (cap 1024 px, 4 Mpx).
- Name: `mine/icons/<id-lowercase>.<ext>`, where `<id>` is the app id sanitised to `[a-z0-9._-]`, the same key the resolver will look for. Existing file with the other extension is removed so there is never a pair.
- Write through a temp name then `mv` (atomic, a half-written file is never picked up).

Editing a pack other than `mine`: not allowed in the UI. A downloaded pack is read-only; `Export` always exports a chosen pack, and `Duplicate to Mine` (copy icons into `mine/`) is the way to start from someone's pack. This removes a whole class of "I broke the imported pack" support problems.

## 4. Export and import as one zip

**Tool**: `bsdtar` (libarchive), because it is a dependency of `pacman`, so it is on every Arch and Omarchy machine; `zip` and `unzip` here are only pulled in by `gnome-shell` and `luarocks` (`pacman -Qi`) and cannot be relied on. Verified here: `bsdtar --format zip -cf out.zip pack.toml icons` writes a normal zip (`unzip -Zl` reads it), and `bsdtar -xf` already refuses an entry containing `..` (`Path contains '..'`), though the validator must not rely on that.

**Export**: `cd packs/<id> && bsdtar --format zip --no-xattrs -cf <target>.zip pack.toml icons preview.png LICENSE README.md` (missing optional files omitted). The target path comes from `omarchy file select --directory` plus `<id>-<version>.zip`. If `preview.png` is absent, export generates one (a grid of the pack's first 12 icons) only if `magick` is present; otherwise none. Zip, not tar: it opens on every OS and in every file manager, which matters for sharing with non-Linux friends and for chat apps.

**Pack layout** (all of it, nothing else is allowed):

```
my-pack/
  pack.toml          required
  icons/
    firefox.png      file stem = app id or window class, case-insensitive
    kitty.svg
    com.mitchellh.ghostty.svg
  preview.png        optional, 4 Mpx max
  LICENSE            optional (LICENSE.txt also accepted)
  README.md          optional (README.txt also accepted); shown as text, never rendered as markup
```

**pack.toml** (the flat TOML subset `ConfigIO.js` and `lua/config.lua` already parse, so no new parser; `aliases` is a comma-separated string, the same shortcut `config.lua` already uses for lists):

```toml
schema = 1
id = "tokyo-glyphs"
name = "Tokyo Glyphs"
version = "1.2"
author = "Example Person"
licence = "CC-BY-4.0"
description = "Flat monochrome icons for the usual developer apps."
aliases = "Steam App 440=team-fortress, zen=firefox, Kitty=terminal"
```

`aliases` maps a window class or app id (left, case-insensitive) to another file stem in the same pack (right). This is how one icon serves several classes, and how a Wine window (`steam_app_440`) is matched. Limit: ConfigIO strings have no escapes, so no `"` in an alias (a real limit, noted for the docs: `shortcut: comma and equals sign are the separators, upgrade to a [aliases] section if a class needs them`).

**Import validation algorithm** (`PackValidate.js` implements steps 1 to 6 and 8; a shell/QML wrapper does the I/O). Import never executes anything and never lets the zip choose a path.

1. **Archive gate**: file size at most 50 MB, regular file (not a symlink), opens as a zip (`bsdtar -tvf` exits 0). Run every bsdtar/extract call under `timeout 20` and `ulimit -f 4096` (bash counts 1 KiB blocks, so a 4 MB cap per written file) in a subshell.
2. **Listing** (`bsdtar -tvf`, parsed by `parseBsdtar`; `unzip -Zl` is parsed by `parseListing` for the test harness). Reject the whole pack on the first failure, listing every entry error so the dialog can say why:
   - entries at most 2100;
   - each name: non-empty, at most 200 chars, not absolute (`/`, `~`, `C:`), no backslash, no control character, no `.` or `..` or empty segment, no hidden file (leading dot) (`badPath`);
   - kind must be regular file (`-`), except the single directory `icons/`; any symlink, hard link, device, fifo is rejected;
   - names compared lower-case: a duplicate is rejected (collision on case-insensitive disks and in our own case-insensitive matching);
   - allow list: top level `pack.toml`, `preview.png`, `LICENSE`, `LICENSE.txt`, `README.md`, `README.txt`; or `icons/<name>.png|svg` exactly one level deep. Everything else (scripts, `.desktop`, `.so`, nested folders, other extensions) rejects the pack, not just that file, so a pack cannot smuggle a payload next to valid icons;
   - declared sizes: any file at most 2 MB, SVG at most 256 KB, total at most 100 MB, and (only for listings that show a compressed size) ratio at most 100 to 1 per file above 1 KB;
   - `pack.toml` present.
3. **Stage**: extract into a fresh directory `packs/.staging-<random>/` created with `mktemp -d` on the same filesystem (so the final `mv` is atomic), with `bsdtar -xf <zip> -C <staging> --no-same-owner --no-same-permissions`, never `-P`.
4. **Re-check on disk** (the listing can lie about sizes; the disk cannot): walk staging with `find -printf '%y %s %P\n'`; every entry must be type `f` (or the `icons` dir), no `l`; total bytes at most 100 MB; any entry or name not in the listing rejects. Counting real bytes is the zip-bomb defence for archives that declare small sizes.
5. **Manifest**: parse `pack.toml` with `ConfigIO.parse` (a bad line is reported, not ignored). `validateManifest`: `schema` must be 1 (a higher number means "needs a newer omahop", offered as a message, not guessed), `id` matches `^[a-z0-9][a-z0-9-]{0,39}$`, `name` 1 to 60 chars, `author`, `licence`, `description`, `version` each at most 200 chars, `aliases` at most 20000 chars. The folder is named from `id`, never from the zip file name or any path in the zip.
6. **Content**: for every `icons/*` file check magic bytes and structure (`validateBytes`): PNG signature, `IHDR` first, width and height at most 4096 and at most 4 Mpx (stops a 1 MB file that decodes to hundreds of MB); SVG must start with `<svg` (after an optional XML declaration and comments), no `<!ENTITY` or `<!DOCTYPE [`, no `<script>`, `<foreignObject>`, `<iframe>`, `<embed>`, `<object>`, no `on...=` attribute, every `href` either `#fragment` or `data:image/(png|jpeg|webp);base64,`, every `url(` pointing to `#fragment`. An SVG fails the pack if it breaks any rule: SVG is a document format that can name files and URLs, which a PNG cannot. Qt's SVG renderer is the "tiny" profile and does not run scripts, but defence in depth is cheap and keeps an `<image href="file:///...">` probe from ever reaching the loader. File extension must match content (a `.png` that is really an SVG is rejected). Aliases whose right side names no file in `icons/` are dropped with a warning, not an error.
7. **Collision**: if `packs/<id>/` exists, ask: replace (only if the new `version` is higher or the user confirms), keep both (installs as `<id>-2`, and the pack keeps working because `icon_pack` is the folder name), or cancel. `mine` is a reserved id and is rejected on import.
8. **Commit**: `mv` staging to `packs/<id>` (atomic rename; if replacing, rename the old folder aside first, delete it after the move succeeds). On any failure, delete staging and leave everything as it was. Staging folders older than a day are removed on the next import.
9. **After install**: the pack is inert until chosen. Importing never changes `icon_pack` by itself. The dialog shows name, author, licence, icon count and the preview before the user presses "Use this pack".

Why zip bombs are covered: entry count, per-file and total size caps (declared and real), the on-disk re-check, `ulimit -f` per file, `timeout`, and the image dimension cap so a small PNG cannot expand at decode time. A ratio rule is kept where the tool reports it (`unzip -Zl` does, `bsdtar -tvf` does not); the real backstop is the real-bytes check.

**Test cases** (unit, Node; all pass in the spike, see `validate.test.js`): good pack accepted; `../` traversal; absolute path; backslash path; hidden file; symlink; script file; nested folder; case-insensitive duplicate; missing `pack.toml`; 1.9 MB of zeros named `.png` (ratio rule); 2200 entries; 60000x1 PNG; wrong magic bytes; SVG with script, external `href` (file and https), `xlink:href`, event handler, entity or DOCTYPE subset, external `url()`; legitimate in-document `<use href="#a">` and `fill="url(#g)"` accepted; XML declaration and comments before `<svg`; manifest with schema 2, bad id (`../x`), empty name; all `badPath` forms. Also verified: the same checks through the real `bsdtar -tvf` listing for the symlink, script, duplicate, many-files and traversal archives. A real fixture finding: Python and some GUI zippers write entries with no Unix type bits (`unzip -Zl` prints `?rw-------`), so the parser treats `?` plus a trailing slash as a directory and `?` otherwise as a file; symlinks are only trusted to be caught when the type bits exist, which is why step 4 re-checks the extracted tree with `find -printf %y`.

Still to add in the build batch (not prototyped): the shell wrapper tests (real extraction into a temp dir, asserting nothing lands outside it), a Windows-zipper fixture (`?`/DOS permission strings), and a hard-link archive.

## 5. Sharing UX and licensing

- **Now: file only.** `Export pack...` writes `<id>-<version>.zip`; users post it wherever they like (a gist, a forum, a repo release, chat). Import is `Import pack...` plus a file pick. Nothing is uploaded by omahop, there is no account and no network code, which is also why the import path only ever needs to be a local-file validator. Mirroring Omarchy's norm (themes are git repos), the README documents that a pack folder can live in a git repo and be cloned into `packs/`.
- **Later, only if packs appear in the wild** (3-uses rule from the roadmap): a documented `omahop-packs` index repo, a plain list of `{name, author, licence, url, sha256}` rows via pull request, with the preview images in the repo. The install flow stays "download zip, then the same Import". Not proposed for now, and no hosting service is touched.
- **Licensing and trademarks** (README and `Export` dialog text): app logos are trademarks and often copyrighted art. A pack author is responsible for the right to share every icon. The README says: set `licence` in `pack.toml` (SPDX id, for example `CC-BY-4.0` for original art, or `Various`/`All rights reserved by their owners` for logo packs), do not include icons you are not allowed to redistribute, a pack of original or permissively licensed art is the safe kind, omahop's MIT licence covers the code only and omahop ships no third-party icons in the repo. `Export` refuses when `licence` or `author` is empty and says why. Importing shows the licence line before activation. omahop's own sample pack (shipped for docs and tests) must be original art made for it.
- No telemetry, no phone-home check for updates.

## 6. Scale and performance

Measured or computed here:

- System scan: `tools/icon-index.sh` takes 2.2 s for 8354 icon files (already async at service start, results cached for the session). Unchanged by packs.
- Pack scan: one `find <pack>/icons -type f` (or `ls`) for a 1000-icon pack is a few milliseconds of process time (same order as `ls`), run async with `Process` when `icon_pack` changes or after import or editing, never while the switcher is closed. The parsed index is a plain object, built with `parseIndex`; 1000 resolves against a 1000-icon pack took 5 ms total in the prototype (about 5 microseconds each), so the lookup cost is immaterial next to window listing.
- Memory: an index entry is a path string, about 100 bytes, so 1000 icons are about 100 KB. Decoded pixels are the real cost: rows should load with `sourceSize` equal to the row icon size so a 256 px PNG is not held at full size, and only visible rows exist (the list is a `ListView`, standard rules apply). Existing delegates use `IconImage` without an explicit `sourceSize`; add one when the pack batch touches them (a small separate fix, likely also a win today).
- Stale cache: cleared by the service on every pack change or edit (section 2). Pack folder watched? No: no file watchers, no timers while closed. The index is rebuilt on explicit actions (setting change, import, editor write) and when the settings panel opens (one cheap `find`), so a hand-dropped file appears the next time the panel is opened.
- Missing or broken icon: `resolve` returns `{path, fallback}` where `fallback` is the system result (never empty when the generic icon exists). The row uses the pack path first; on `Image.Error` or an empty decode it switches to `fallback` (`onStatusChanged`). Deleted-while-running files take the same path. The import validation makes this rare (magic bytes and dimensions are checked), the runtime fallback makes it harmless. No checkerboard and no blank slot: worst case is the system icon the user had before.
- A pack with an alias loop is impossible (alias targets are file stems, never further aliases: one hop).

## 7. Effort and milestones

Estimates are build hours for an engineer who knows the repo, including tests and docs in the same batch, per the definition of done.

| Part | Hours | Notes |
|---|---|---|
| Format spec + `PackResolve` into `IconResolve.js` + Node tests | 3 | prototype exists and passes; port it, fold into the existing `icon_resolve.test.mjs`, add `{path, fallback}` to `Service.lookup()` |
| Settings: `icon_pack` and `icon_theme` rows, dynamic enum in gen-spec, pack scan process, cache clear | 4 | gen-spec (`tools/gen-spec.lua`) gets `dynamic` values; panel reads folder names |
| `icon_theme` preference in `icon-index.sh` | 1 | about 10 lines of shell, shellcheck |
| Editor: app dropdown, picker via `omarchy file select`, preview, remove, reset, `tools/pack-add.sh` | 8 | biggest UI part; picker fallback text field; live hand check in `validation-checklist.md` |
| Export and import (validator port, `tools/pack-import.sh`, staging, collision dialog, export, preview) | 8 | validator logic already prototyped; shell wrapper and dialog are the work |
| Tests beyond unit: shell wrapper against real zips, a live panel step | 3 | extend `tests/live_panel.py` with an import of the good fixture |
| Docs and README: format, licence text, sample original pack, batch log, release highlight | 3 | tag needs a highlight (`docs/releases/README.md`) |
| **Total** | **30** | |

**Smallest shippable first milestone (v1.1, about 9 hours):** no editor, no zip.
- `icon_pack` setting (a folder name under `~/.config/omahop/packs/`), `mine` always layered on top, the `PackResolve` order, runtime fallback, cache clear.
- Pack folders made by hand or copied from a git clone (`pack.toml` plus `icons/`), so people can already share via git.
- `icon_theme` setting for existing freedesktop themes (the free find).
- Settings page: one group with the two pickers. "Reset" for `icon_pack`.
- Docs: format spec, licence note, one sample pack.
This is alone shippable, off by default (`icon_pack = ""`), adds nothing to the bar, and does not touch the import risk.
Milestone 2 (about 8 hours): export and import with the validator. Milestone 3 (about 8 hours): the editor, which writes into `mine` and reuses the milestone-1 resolver.

Order matters: import before editor, because the editor mostly needs `tools/pack-add.sh`'s image checks, and the validator's byte checks are shared.

## Risks

1. **Hostile or sloppy zips.** The main new attack surface in a plugin that otherwise never reads untrusted input. Mitigation: allow list (pack fails, not just the file), on-disk re-check, caps, no code path that executes content. Residual: SVG parser bugs in Qt on a crafted but rule-abiding SVG. Option to cut the risk further: PNG only for imported packs (SVG only in `mine`), at the cost of resolution independence. Decide before milestone 2.
2. **Trademark and copyright of logos in shared packs.** The project is MIT and public; a pack that redistributes someone's logo is the author's problem, but omahop's README and Export dialog must not invite it, and the repo must never contain third-party icons. Mitigation in section 5.
3. **Picker dependency.** `omarchy file select` needs the Omarchy CLI and a working portal (GTK or Hyprland portal) in the user's session; the QML `FileDialog` route is unverified in this shell. Mitigation: typed-path fallback, and a first live check of the picker from the settings panel (needs a desktop session, not done in this spike because the user is at the machine).
4. Smaller: Qt image cache serves a replaced file's old pixels (use `cache: false` or revision names); ConfigIO strings cannot hold a quote, so aliases are limited; dynamic enum in gen-spec is the one structural change to the settings generator; icon lookup by window class stays heuristic for odd apps, which `aliases` and per-app overrides cover.

## What was not verified

No desktop interaction: the file chooser, the settings panel layout, and `Image` fallback on real error were not exercised (the user is at the machine). `QtQuick.Dialogs.FileDialog` under Quickshell untested. Zip fixtures from Windows or macOS tools were not available; only Info-ZIP, Python and bsdtar archives were tested. The statement that Qt's SVG loader would not fetch external files is from prior knowledge, not tested, which is why the validator rejects external references anyway.

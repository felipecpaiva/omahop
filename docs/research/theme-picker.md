# Theme and icon pack pickers: how others do it

Research for a friendlier Icon theme and Icon pack setting (decision D28). Date: 2026-11-09. Method: web search (snippets, not full pages) plus a read of Omarchy's own shell source on this machine. Anything not confirmed is marked **unverified**.

## How it works today

- `icon_theme` and `icon_pack` are plain text settings (`lua/config.lua`, group Look, sub heading Icons, both `advanced`). The user types a folder name. No list, no preview, no check that the name exists.
- Theme: `tools/icon-index.sh <theme>` scans every theme under `~/.icons`, `~/.local/share/icons` and `$XDG_DATA_DIRS/icons`, puts the chosen theme and its `Inherits=` parents first, and keeps the first file per icon name. Empty means "whichever theme the scan finds first". About 29 folders in `/usr/share/icons` on the dev machine (Adwaita, Yaru in many colours, breeze, hicolor and more), so a few dozen choices, some of them cursor or fallback folders.
- Pack: a folder `~/.config/omahop/packs/<name>/` with `pack.toml` and `icons/`, indexed by `tools/pack-index.sh`; layered in front of the theme (`IconResolve.js`). Choices are the folders found there, usually zero to five.
- A change applies at once: `Service.qml` watches both values, rescans, clears the resolved cache. The pack editor already is a separate page (`PackEditorPage.qml`, opened by the `editor = "packs"` button that `SettingRow.qml` draws).

## What others do

| App | Browse | Preview | Apply | Search or filter | Source |
|---|---|---|---|---|---|
| GNOME Tweaks, Icons | One dropdown of installed themes | None in the list (unverified: none at all) | Immediate on selection | No | [Pop!_OS docs](https://pop-os.github.io/docs/customize-pop/gnome-tweaks-extensions/gnome-tweaks-appearance.html), [bytexd](https://bytexd.com/how-to-install-gnome-themes/); dropdown sort bug [gnome-tweaks #487](https://gitlab.gnome.org/GNOME/gnome-tweaks/-/issues/487) |
| GNOME Settings, Appearance | Not found for icon themes (style thumbnails, wallpaper grid) | Thumbnails for wallpapers | Immediate | Not verified | [gnome-desktop #222](https://gitlab.gnome.org/GNOME/gnome-desktop/-/issues/222). Icon theme picker: **unverified**, current GNOME may have none |
| KDE System Settings, Icons | List of themes with a preview area, "Get New Icons" button for downloads | A row of sample icons per theme; known bug: preview not recoloured by accent ([bug 456652](https://bugs.kde.org/show_bug.cgi?id=456652)) | Apply button | Not verified | [KDE docs commit](https://mail.kde.org/pipermail/kde-doc-english/2021-April/022360.html), [Trinity docs](https://git.trinitydesktop.org/cgit/tdebase/tree/doc/kcontrol/icons/index.docbook). Exact grid or list layout: **unverified** |
| macOS Appearance | Three big tiles (Light, Dark, Auto), accent colour dots | Tile is the preview | Immediate | No | [Apple guide](https://support.apple.com/en-au/guide/mac-help/mchl52e1c2d2). Tile art details: **unverified** |
| Windows 11 Themes | Grid of theme thumbnails under "Current theme" | Thumbnail is the preview | Click a thumbnail, immediate | No (store link for more) | [How-To Geek](https://www.howtogeek.com/753967/how-to-change-themes-on-windows-11/), [Elevenforum](https://www.elevenforum.com/t/change-theme-in-windows-11.945/post-23176) |
| Kvantum Manager | Tabs; list of themes | A Preview button shows a sample widget window | Explicit "Use this theme" | No | [Lubuntu manual](https://manual.lubuntu.me/master/_sources/2/2.4/2.4.10/Kvantum-Manager.rst.txt) |
| nwg-look | Dropdowns per setting | None (unverified) | Apply writes gsettings | No | [README](https://www.github.com/nwg-piotr/nwg-look) |
| rofi-theme-selector | Text list inside rofi | Enter previews, Alt+a applies to config; no live preview on arrow keys (per docs) | Explicit | rofi filter | [man page](https://man.archlinux.org/man/rofi-theme-selector.1.en). wofi: nothing found |
| Nova and Lawnchair | Nova: Settings, Looks and feel, Icon Theme, a list of installed packs; Lawnchair: Theme, Icon pack. Per app icon picker shows the pack's icons | Per app picker is a grid of the pack's icons; the list has no sample row (unverified) | Tap a pack, applies | Pack icon picker has search (unverified) | [How-To Geek](https://www.howtogeek.com/250094/how-to-change-androids-icon-theme-with-nova-launcher/), [Lawnchair docs](https://docs.lawnchair.app/core-features/theming-and-icons) |
| VS Code, File Icon Theme | Quick pick list (command palette style) | Live: arrow keys apply each theme as you move | Enter keeps it; Esc restoring the old one: **unverified** for icon themes | Type to filter | [VS Code docs mirror](https://vscode-docs-arc.readthedocs.io/en/latest/getstarted/themes/), [File Icon Theme guide](https://code.visualstudio.com/api/extension-guides/file-icon-theme) |
| Firefox themes | Grid of cards in Add-ons manager | Hover preview existed, appears removed (**unverified**) | Enable button | Search in the store | [Mozilla discourse](https://discourse.mozilla.org/t/themes-page-preview-no-longer-working/23792) |
| Papirus preview tools | Not found | Not found | | | **Not verified**, no source |
| Omarchy Style, Theme | Menu: Super+Alt+Space, Style, Theme (shortcut names differ by version: [manual](https://learn.omacom.io/2/the-omarchy-manual/52/themes), [Starry Hope](https://www.starryhope.com/linux/omarchy-first-keys/)) | Each theme ships a `preview.png` thumbnail | Enter applies the theme | Filter box in the image picker | Local source below |

Omarchy's own UI, read from `/usr/share/omarchy/shell`: the `menu` plugin is a text list; the `image-picker` plugin is a horizontal strip of preview cards (the selected one wide), Left and Right to move, Enter to choose, Escape to cancel, Delete to remove, a filter input, previews decoded only for cards near the selection and released after the picker closes (`PreviewHold.qml`). The Ui kit has `Button`, `ButtonGroup`, `Dropdown`, `SearchableDropdown`, `FilterInput`, `SizedImage`, `ConfirmDialog`. So a card strip with arrow keys, Enter, Esc and a filter is the house style.

## Patterns that matter

1. A picture beats a name. Windows, macOS, KDE and Omarchy all show what you get before you commit; plain dropdowns (GNOME Tweaks, Nova list) are the weakest.
2. Icons are best previewed as the same few sample icons repeated per choice, so choices can be compared side by side (KDE's row).
3. Keyboard live preview (VS Code) is the friendliest for a keyboard tool, and fits a switcher.
4. Preview and commit are separate: browse freely, Enter commits, Escape leaves the old value untouched.
5. Explicit "get more" (KDE, Windows) is a store; omahop has no store, so the page links to the pack docs and the Import button instead.

## Recommendation

A separate page of the one settings window with a card list (one card per choice, a row of the same sample app icons in each), live preview on arrow keys, Enter to choose, Escape to go back, a filter box. Details and mockup in D28 and ROADMAP ("Icon theme and pack picker").

## Could not verify

Current GNOME Settings icon picker, KDE's exact layout, Papirus tools, wofi pickers, Firefox hover preview, VS Code Escape revert for icon themes. None changes the recommendation.

## Proposed design (D28)

```
+--------------------------------------------------------------+
| < Back to settings        Icons:  [ Theme ] [ Pack ]         |
| Filter: [ papi_________ ]                                    |
+--------------------------------------------------------------+
|  Preview of the highlighted choice (larger icons)            |
|   [fx] [term] [files] [code] [music] [chat] [mail] [calc]    |
+--------------------------------------------------------------+
|  (o) Automatic (today's behaviour)                           |
|  ( ) Adwaita      [fx][term][files][code][music][chat]       |
| >( ) Papirus      [fx][term][files][code][music][chat]  <--  |
|  ( ) Yaru-blue    [fx][term][files][code][music][chat]       |
|  Pack tab: also "No pack", then each pack folder,            |
|  and a button "Make or edit icon packs" (existing editor)    |
+--------------------------------------------------------------+
| Up/Down move, preview live | Enter choose | Esc back (no change)|
+--------------------------------------------------------------+
```

- Opens from a button on the Icon theme and Icon pack rows (spec field `editor = "icons"`); the rows show the current value as text. Back returns to the settings list at the same category.
- Mouse: click a card to preview, double click or the Choose button to commit, wheel scrolls. Keyboard: Up, Down, Home, End, Enter, Escape, typing goes to the filter.
- Data, not code: themes from a scan script (folder name, `Name=` from `index.theme`, drop folders with no app icons); packs from the packs folder (name and author from `pack.toml`); sample app ids from one list in `lua/config.lua`, passed through spec.json. Adding a theme or pack, or changing the sample apps, needs no QML edit.
- Cost: icon lookups run per visible card only (`tools/icon-preview.sh <theme> <id>...`), results cached by theme and id, in the spirit of Omarchy's `PreviewHold`.
- Nothing new in the shell: the page lives inside the settings window, like the pack editor. Typed names stay as the fallback in the advanced text row.
- Files: `lua/config.lua`, `tools/gen-spec.lua`, spec.json, `tools/icon-themes.sh`, `tools/icon-preview.sh` (plus shell tests), `IconPickerPage.qml`, `IconChoiceCard.qml`, `SettingsPanel.qml`, `SettingRow.qml`, `docs/settings.md`, `docs/icon-packs.md`. Effort: medium.

## Builder style UIs (added 2026-11-09, for D29)

Question: how do tools let a person override single app icons, search icons, and share the result? Method: web search (snippets) and two page fetches. Findings are what the sources say; anything else is marked **unverified**.

| Tool | Per app override | Source of the new icon | Reset | Share | Source |
|---|---|---|---|---|---|
| Nova Launcher | Long press the app, Edit, tap its icon | An installed icon pack's icons or a gallery app | Not in the sources (unverified) | Packs are separate apps | [Android Central](https://www.androidcentral.com/how-make-custom-icon-android), [SlashGear](https://www.slashgear.com/stories/how-to-make-custom-app-icons-on-android-phones) |
| Lawnchair | Docs have a "Per-icon customization" heading; steps not retrieved (**unverified**). Whole pack: Home settings, General, Icon style | Installed icon packs | Unverified | Lawnicons is a standalone pack | [Lawnchair docs](https://docs.lawnchair.app/core-features/theming-and-icons), [Android Police](https://www.androidpolice.com/lawnicons-v2-icon-pack/) |
| Icon Pack Studio (Smart Launcher team) | Edit one icon from the launcher's Edit, or pick the app inside the studio; start from an existing style or a new one | A file under Logo, Design; shape, colour, effects; can import and tweak installed packs (v2 and later) | Not described on the page read | Exports a separate installable app when the launcher cannot read packs directly | [docs](https://docs.smartlauncher.net/other-products/iconpackstudiofaq/documentation/edit-individual-icons), [Android Central](https://www.androidcentral.com/icon-pack-studio), [SourceForge listing](https://sourceforge.net/app/icon-pack-studio/android/) |
| macOS Get Info | Select the app, Get Info, click the small icon | Paste an image (Command V) or drag an image file onto the icon | Select the custom icon and press Delete or Cut; known failure reports on a system volume icon | None built in (an icon is stored in resource data or a hidden file) | [9to5Mac](https://9to5mac.com/2021/11/08/change-mac-icons/), [iDownloadBlog](https://www.idownloadblog.com/2023/01/19/how-to-change-app-icons-mac/), [Apple Community](https://origin-discussions2-us-dr-prz.apple.com/thread/256136487) |
| KDE Plasma menu editor | Right click an app in the menu, Edit Application, click its icon | An icon chooser over installed themes, or a file | Not in the sources | The change is a per-user desktop entry. Known gaps: system-wide launchers once could not be edited (reported resolved), and the new icon may not show in every place | [KDE bug 429613](https://bugs.kde.org/show_bug.cgi?id=429613), [bug 505884](https://bugs.kde.org/show_bug.cgi?id=505884), [Manjaro forum](https://forum.manjaro.org/t/change-app-icons-in-kde/37195) |
| Stream Deck | Per key: pick from the Icon Library or Set from File | Installed packs (Marketplace) or a file | Unverified | A pack is a `.sdIconPack` folder compiled to one `.streamDeckIconPack` file that a double click installs. Installed library export from the app: **not found** | [Elgato packaging docs](https://docs.elgato.com/en/stream-deck/icon-packs/packaging) (snippet only, the page returned 404 when fetched), [StreamSpell guide](https://www.streamspell.com/post/how-to-install-stream-deck-icon-packs-and-stream-deck-profiles), [Elgato explorer](https://www.elgato.com/explorer/products/stream-deck/customize-stream-deck-with-icons) |
| Steam | Right click a game, Manage, Set custom artwork; a 2025 beta added a Customization tab in properties | A file; community art from SteamGridDB, applied by hand or by a helper such as SGDBoop | Unverified | Community site, not a pack file | [Digital Trends](https://digitaltrends.com/?p=3639024), [GamingOnLinux](https://gamingonlinux.com/2025/08/valve-makes-steam-library-customisation-a-little-easier-in-the-latest-steam-beta) |
| kAppIcon (Linux, per app launcher icons without root) | One app at a time | Files or theme icons (details **unverified**) | Unverified | Unverified | post on a Lemmy instance (title only) |

### What it means for omahop

1. The unit is the app, with the current icon shown next to the candidate. Everyone starts from the list of apps, not a list of themes.
2. Two sources in one chooser: an installed set (themes here) searched by name, and a file. Every tool above has both.
3. Reset is per app and obvious (macOS Delete). omahop adds undo of the last step too, because a keyboard tool has no second chance.
4. Sharing is one file you double click or import (Stream Deck, Icon Pack Studio export). omahop already has that: the zip.
5. Start from something (Icon Pack Studio, tweak an installed pack): the builder starts from the chosen base theme and may open an existing pack as its draft.
6. Drag and drop appears in macOS only. Whether a Quickshell overlay window receives file drops on Hyprland is **unverified**; the file chooser (already built) is the dependable route and drop is a later nicety.

### Could not verify

GNOME and ChromeOS icon editors (no per-app icon override found in two searches; GNOME Tweaks only switches whole themes and ChromeOS none found, both **unverified**), Windows shortcut Properties, Change Icon (not covered by the search), Lawnchair's per-icon steps, Stream Deck pack manifest details (docs page 404), Steam artwork picker internals, reset behaviour in Nova and Icon Pack Studio.

## Builder design (D29)

One settings window, three pages, one direction: **settings list, Picker, Builder**. The existing pack editor stays the plain file tool (make, meta, one image per app, export, import) and is linked from the builder as "Pack files".

### How the pages connect

1. Picker (D28, slice 1): choose Theme (the base) or Pack, live preview, Enter. A **Customize icons** button on the picker opens the builder.
2. Builder: the base theme is shown at the top and can be changed (it writes `icon_theme` like the picker). Optional start: **Open a pack as a draft** (a copy of an installed pack goes into the draft).
3. Override single apps, preview in place, undo or reset each.
4. **Save as pack** (name, author, licence, then the pack exists in `~/.config/omahop/packs/<folder>/`) with an optional **Use it now** (sets `icon_pack`). **Export** (zip) and **Import** (zip becomes a draft or an installed pack) reuse the editor's buttons.

### Builder mockup

```
+------------------------------------------------------------------------+
| < Back     Icon builder          Base theme: [ Papirus  v ]            |
| Draft: 3 changes   [Undo] [Reset all]       [Save as pack] [Export]    |
+----------------------+-------------------------------------------------+
| Filter apps [fire__] | Firefox   (class: firefox)                      |
|----------------------| Now: [theme icon]    New: [draft icon]          |
|  [ic] Firefox   *    |                                                 |
|> [ic] Kitty     *    | Choose from:  ( ) Themes   ( ) A file           |
|  [ic] Ghostty        | Search icons: [ fox____ ]   all themes          |
|  [ic] Files          | +------+ +------+ +------+ +------+ +------+    |
|  [ic] Code           | | fox  | | fox  | | fox  | | fire | | fire |    |
|  Open windows first  | | Papi | | Yaru | | Adwa | | Papi | | Mint |    |
|  * = changed         | +------+ +------+ +------+ +------+ +------+    |
|                      | [Choose file...]  [Reset this app] [Undo]       |
+----------------------+-------------------------------------------------+
| Preview in the real switcher                                           |
|  list row:  [icon] Firefox - Docs    cards: [icon][icon][icon][icon]   |
+------------------------------------------------------------------------+
| Up/Down apps | Tab to icons | Enter use | Delete reset | Esc back      |
+------------------------------------------------------------------------+
```

### Data flow

- **Apps:** the same rows `PackEditor.js appRows` already builds (open windows, desktop entries, stems by `iconStem`). Reused, plus a `changed` flag.
- **Draft:** `~/.cache/omahop/draft/icons/<stem>.png|svg` plus `draft.json` (base theme, `based_on` pack, undo stack: stem, previous file or none). Cache folder, so no half made pack is ever listed, indexed or exported. Nothing private goes in: only icon files and stems. Lost cache means a lost draft, which the page says; Save is the durable step.
- **Search across themes:** new `tools/icon-find.sh <query> [limit]`, built on the scan code of `icon-index.sh`, but keeping every theme's match (not the first), png or svg only, scalable and larger sizes first, capped (200), output `theme<TAB>name<TAB>path`. Run per query with a short delay after typing, results cached by query. Same cost rule as D28: only the visible cards decode images.
- **Choose a result or a file:** both call `pack-edit.sh`'s image check. New commands, still positional: `draft-add <stem> <image>` (strict check, stem rule, writes into the draft), `draft-remove <stem>`, `draft-undo`, `draft-save <name> <author> <licence> [description]` (init, copies, `pack_check_strict`, removes the draft). They share `pack-lib.sh`, so a draft file passes exactly what export accepts.
- **Preview in the real look:** the builder draws the real list row and card delegates with an icon source override map `{stem: draft file}` in front of the usual resolve, so no scan and no service change is needed while editing. Only Save and Use makes `Service.qml` read the pack.

### Format and compatibility

- Pack format unchanged: `pack.toml` (name, author, licence required) plus flat `icons/<stem>.png|svg`. Optional extra text key `based_on = "Papirus"` is ignored by older versions (the format allows other keys). No new file, no section, nothing a v1.5 importer would refuse.
- A theme icon is copied, never referenced, so the pack works on a machine without that theme. Each copy goes through the same size and SVG rules; a theme icon that fails them (script, huge, xpm, symbolic recolour needs) is shown as "not usable" in the grid, not silently dropped.
- Licence: theme icons have their own licences and app logos are trademarks. The Save dialog pre fills the licence field empty and shows "Icons copied from <theme> keep that theme's licence; set the licence of the pack accordingly". Export refuses an empty licence (already true).

### Export and import safety

Unchanged and reused: export holds `pack.toml` and `icons/` only, sorted and fixed in time, owner and mode; import decides from the zip listing before unpacking (no `/` start, no `..`, no links or specials, no hidden names, only `icons/` and `pack.toml`, case collisions, 2002 entries, 50 MB zip, 100 MB unpacked, 100 times ratio, per file limits, pack-index rules on every file), unpacks with a byte cap into a fresh cache folder, installs after a yes with one rename, never sets `icon_pack` itself. Private data: the zip contains only the draft's icon files and four metadata lines; no paths, user name, app list or window titles. The builder never reads window titles for the list (class and name only) and never logs them. Slice 3 adds one test that an export from a draft built in a temp HOME contains no home path string.

### Flexibility and scalability

- Sources are data: another icon source (a second folder, a downloaded set) is one more line in `icon-find.sh`'s search list, no QML change.
- A `ListView` for apps and a lazy `GridView` for results keep hundreds of apps and thousands of icons cheap; the search cap bounds the work.
- One app per stem, same as the editor; `many apps share one icon` stays the editor's symlink rule (export already turns a link into a copy).

### Files to change

`lua/config.lua` (editor "builder" on the picker, sample app list), `tools/gen-spec.lua` and spec.json, new `tools/icon-find.sh`, `tools/pack-edit.sh` and `pack-lib.sh` (draft commands), new `IconBuilderPage.qml`, `BuilderAppList.qml`, `IconSearchGrid.qml`, `BuilderPreview.qml`, `IconBuilder.js` (state, undo, argument arrays, like `PackEditor.js`), `SettingsPanel.qml` (page switch), `SettingRow.qml`, docs `settings.md`, `icon-packs.md`, `architecture.md`, `validation-checklist.md`. Tests: `tests/icon_find.test.sh`, `tests/pack_draft.test.sh` (hostile stems, files, a theme icon that fails the strict check, undo round trip, save then export then import in a temp HOME, a mutation check), `tests/icon_builder.test.mjs`.

### Slices

| Slice | Ships | Effort |
|---|---|---|
| 1 Picker (D28) | Theme and pack cards, live preview, filter, Customize button present but opens the existing pack editor | Medium (about 2 days) |
| 2a Builder read and search | Apps list, theme search across themes, choose a file, preview in the real row and card, draft with undo and reset, no save yet | Medium to large (about 3 days) |
| 2b Save | `draft-save`, Save as pack, Use it now, `based_on`, open a pack as a draft | Small to medium (about 1.5 days) |
| 3 Export and import glue | Export and Import buttons inside the builder (the zip tools exist since v1.5), import into a draft, the no home path export test, docs | Small (about 1 day) |

Order: 1, 2a, 2b, 3. Each slice is releasable; slice 1 alone already replaces typed names with pictures.

### Open questions

1. Copy or reference a theme icon? Recommend copy (self contained, one validator); a reference form can come later behind a new key if packs become large.
2. Draft in cache or a hidden pack folder? Recommend cache, so a pack folder always passes `pack-index`.
3. Drag and drop in slice 2? Recommend no: unverified on Hyprland overlay windows; test later and add only if a drop arrives.
4. Name the pack first or at Save? Recommend at Save, and a default name `my-icons`.
5. Edit an installed pack in place? Recommend the builder opens a copy as a draft and Save asks to replace; the editor remains for in place edits.
6. Include apps that are not open? Recommend yes (installed apps below open windows), as the editor does.

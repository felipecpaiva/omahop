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

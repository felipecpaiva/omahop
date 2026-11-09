# Launcher icons: can the icon theme and pack also apply to Super + Space?

Question (Felipe, 2026-11-09): an extra opt in setting that applies the user's icon theme and pack to Omarchy's launcher.
Machine: Omarchy 4.5, Quickshell build of Omarchy, Hyprland Lua config. Read only research; one scratch test (see How verified).

## Answer in short

- Super + Space is **not an app launcher and not Walker** (Walker is not installed). It opens the **Omarchy menu** (`menu = "root"`), a Quickshell
  plugin `omarchy.menu`. Its Apps submenu, and the separate app grid on **Super + Alt + Space** (`omarchy.dock apps`), list desktop entries.
  Both ask one shared function for every icon: `AppLibrary.iconSource(icon)`.
- That function picks icons from a **file index of icon folders first**, and only then from the Qt icon theme. The index is built by a `find`
  that lists `~/.icons` and `~/.local/share/icons` before the system folders. So a folder we create under `~/.local/share/icons` wins, with no
  patch to any Omarchy file and no setting in the shell to point at.
- Recommended: option a, in a changed form. Generate a small folder `~/.local/share/icons/omahop-launcher/apps/` of **symlinks** named by each
  desktop entry's `Icon=` value, pointing at the file omahop's own resolver chose (pack first, then theme). Remove the folder to restore.

## 1. What Super + Space is

- `/usr/share/omarchy/default/hypr/bindings/utilities.lua:1`: `o.bind("SUPER + SPACE", "Omarchy menu", { menu = "root" })`.
- Line 2: `SUPER + ALT + SPACE` is "Apps", `omarchy-shell omarchy.dock apps` (the grid, `shell/plugins/dock/AppGrid.qml`).
- `~/.config/hypr/bindings.lua` only has a comment about the bind; nothing overrides it on this machine.
- `shell/plugins/menu/manifest.json`: id `omarchy.menu`, kinds menu and bar-widget. Apps rows are built in `Menu.qml` (`mergeAppRows`, about line 367)
  from `appLibrary.sortedEntries("")`, so they come from `DesktopEntries` and carry `appIcon = entry.icon`.
- Not verified: whether typing at the root of the menu searches apps directly (needs keyboard input to the shell, forbidden here). It does not
  change the icon path, since every app row uses the same code.

## 2. How icons are loaded

`/usr/share/omarchy/shell/services/AppLibrary.qml`, `iconSource(icon)` (lines 57 to 69), in order:

1. empty value: the generic `application-x-executable` icon;
2. a `file://` or `image://` value, or an absolute path: used as is;
3. **`iconIndex[name]`**: a name to file map ("prefer the context limited app/device index" says the comment);
4. `Quickshell.iconPath(name, true)`: the Qt icon theme lookup;
5. the generic icon.

The index (`iconIndexScanCommand`, lines 18 to 33): `find` over `$HOME/.icons`, `$HOME/.local/share/icons`, then each `$XDG_DATA_DIRS/icons`,
keeping files whose path has `/apps/` or `/devices/` and ends `.svg` or `.png`; **all SVG lines are printed before all PNG lines**, and the first
hit per file name (without extension) wins. It runs when the menu or grid opens (`refreshIcons()`), and when the app list changes (750 ms debounce).
It ignores which theme is active: it is "first file called that name" over every installed theme.

Where the Qt theme comes from (only step 4): `QT_QPA_PLATFORMTHEME=gtk3`, so Qt follows the GTK setting, here
`gsettings get org.gnome.desktop.interface icon-theme` = `Yaru-grey`. No `qt6ct.conf`, no `QT_ICON_THEME`, no gtk settings.ini on this machine.

Config exposed by Omarchy for icons: none found. `~/.config/omarchy/shell.json` has only per widget `iconStyle` (bar glyph style, unrelated); no
launcher icon theme or override key. Plugins get `PluginAppLibraryApi` (`services/PluginAppLibraryApi.qml`), whose `iconSource` is a function the
shell injects; a plugin can read it, not replace it. No hook to change what the stock menu or grid show.

## 3. Options

| | a) overlay icon folder (symlinks) | b) override desktop entries | c) system icon theme | d) launcher hook or plugin |
|---|---|---|---|---|
| Works for the launcher | Yes, by the index (step 3), tested layout | Yes (absolute `Icon=` is step 2) | Only step 4, and the index (step 3) answers first for any name it holds, so often no visible change | No hook exists; would mean our own menu |
| Blast radius | Only apps in omahop's overlay folder; other programs reading `~/.local/share/icons` could see the names too | Every program that lists apps (all launchers, GTK file dialogs, "open with") | Every GTK and Qt program | Own code only |
| Reversible | Delete the folder (and rescan) | Delete copies, but a copy of a system entry goes stale after package updates (the copy shadows the new one) | One gsettings value; must remember the old | n/a |
| Effort | Small to medium: one script, one setting | Medium, and risky | Tiny, wrong tool | Large, duplicates Omarchy's menu |
| Survives Omarchy update | Yes: relies on the documented search order of user icon folders and on Qt/freedesktop rules, not on shell code. If a future shell drops the `$HOME/.local/share/icons` scan, the folder is still a valid freedesktop theme location (see below) | Partly (staleness) | Yes | Breaks often |
| Pack stems match `Icon=` names | Not directly; we map (below) | Same mapping needed | No (themes are not packs) | n/a |

Detail on a):

- A pack file is named by the window class (`kitty.png`, `com.mitchellh.ghostty.svg`); the launcher only knows `entry.icon`, the `Icon=` value.
  The generator must, per desktop entry, find the pack file with the same candidate names omahop already uses for a window
  (`IconResolve.packPick(pack, appId, entryIcon)`: the desktop id, `StartupWMClass` if any, lower case, hyphenated, last part of a reverse DNS
  id, then the `Icon=` name) and write a link called `<Icon= name>.<ext>`. For `icon_theme` without a pack, use the normal resolver result.
  Only entries where the resolved file differs from what the system would show need a link (skip when the pack and theme have nothing).
  `Icon=` values that are absolute paths cannot be overridden by a name (step 2 returns them untouched); skip them and list them in the log.
- **Format trap, tested:** the SVG first rule means a pack **PNG** loses to a system **SVG** of the same name (kitty), and an SVG wins. So
  PNG packs would work only for apps with no system SVG. Fixes to test before building: write the overlay file as an SVG wrapper holding the PNG
  (`<image href="data:image/png;base64,...">`), or convert. Not tested here, so unverified that Qt renders it.
- The index uses `find` without `-L`: symlinks are listed (tested) and Qt follows them when it loads the file. A dangling link is also listed,
  so the generator must check the target exists.
- Qt keeps images by URL: after a link points at a new file the old picture can stay until the shell restarts (same note as in `icon-packs.md`).
  Giving each generation a new link name is not possible (the name is the `Icon=` value); the setting should say "restart the shell to see
  changes" or the script can touch nothing and rely on the restart, as packs do today.
- The folder only needs `apps/` for the index. To also serve step 4 and other programs it would need an `index.theme`; we do **not** want that
  (it would make the folder a theme other programs might pick). Leave `index.theme` out so the folder is invisible to theme lists.
  Not tested: whether the missing `index.theme` upsets the Qt icon cache on startup (Qt ignores folders with no `index.theme` for theme lookup).

b) is rejected: copies shadow system entries, go stale, affect every launcher, and can hide updated `Exec=` lines. c) is rejected: it changes
other programs, and does not even reliably change the launcher because of the index. d) is not available.

## 4. Reusing pack matching

Yes, with one change of input. `IconResolve.js` is pure and tested in Node; the generator should be a script (shell plus the same logic, or Lua
`lua/` side since the settings and config are read there) that feeds it each desktop entry (`id`, `StartupWMClass`, `Icon`) instead of a window.
Rules stay equal to the switcher's: case never matters, pack before theme, an app with no pack icon keeps its usual one. One parity test on a
fixture of desktop entries keeps the launcher and the switcher choosing the same file. Not reused: the absolute-path rules (the pack index never
returns them).

## 5. Recommendation

Option a, symlink overlay, built **after the builder** (D29), because the picker and builder are what make a pack or theme worth sharing.

Setting (in `lua/config.lua`, carried to `spec.json` by `tools/gen-spec.lua`):

- key `icons_in_launcher`, type bool, default `false`;
- group `Look`, subgroup `Icons`, `advanced = true`, shown after Icon pack; label "Icons in the Omarchy menu";
- depends on the icon settings: only meaningful when `icon_theme` or `icon_pack` is non empty, so the row says "needs an icon theme or pack"
  and does nothing otherwise (no overlay is written when both are empty);
- not overridable per profile (it changes files outside omahop, so it is `base_only` like the privacy settings);
- help text must name what changes (Super + Space apps list and Super + Alt + Space grid), that it writes
  `~/.local/share/icons/omahop-launcher`, and that other programs reading that folder may notice.

Restore on turn off (and when the setting is on but both icon settings are emptied): delete `~/.local/share/icons/omahop-launcher` entirely,
and only that folder. Safety rules for the code: (1) never write outside that one folder, (2) create it only with a marker file `.omahop`
inside, and delete only a folder that has the marker, (3) never touch `index.theme`, desktop entries, gsettings or Omarchy files,
(4) regenerate on setting change, on shell start, and when the app list changes (reuse the shell's debounce idea, not its code), (5) if the
generator fails, remove the overlay rather than leave a half built one. The first run records nothing else to restore, since the original is
simply "the folder does not exist", which is why this is the cheapest option to undo. Add a startup check: setting off but folder with marker
present (crash, manual edit) gets removed.

Effort: small to medium (one script plus tests with fake desktop entries and a temp `HOME`, one bool row, docs). Risk: low for files (one
owned folder), medium for behaviour (PNG versus SVG ordering, the Qt image cache after a change, a future Omarchy changing the index scan).

## 5b. Real test on this machine (2026-11-09, Felipe approved)

Result: **works.** Steps: made `~/.local/share/icons/omahop-test/apps/` with three plain SVG files named `kitty.svg`, `btop.svg`, `chromium.svg`
(solid magenta, green, orange squares with a T). `~/.local/share/icons` did not exist before. No setting, no env, no gsettings, no file under
`/usr` or `~/.config` was changed. Opened the app grid with `omarchy-shell omarchy.dock apps` (the same menu code as the Apps list behind
Super + Space; no keyboard input to any window), waited 2.5 s, took `grim`. In the grid **btop shows the green T and Chromium the orange T**
instead of their normal icons, live, with no shell restart: the grid's own icon rescan on open found the folder.
Screenshot (cropped to the grid, nothing else on screen): `img/launcher-icons-test.png`.

Findings from the test:
- The kitty entry is not on the first page of the grid (alphabetical, the screenshot ends at "Image Viewer"), so the kitty test icon was not seen
  in the grid. It did show on the **top bar**: the workspace item for the kitty window showed the magenta test icon too. So the overlay also
  changes the bar's app icons (anything using `appLibrary.iconSource`), not only the two launcher views. Say so in the setting's help.
- A surface that already drew its icon keeps the old picture until the next rescan, and the bar kept the test icon for a moment after the folder
  was deleted, until the grid was opened again (which rescans). This matches the stale image note above.
- Opening the grid a second time with the same command closes it (it toggles), which is how the test grid was closed without a key.

Restore proof: deleted the test folder (`rm -r ~/.local/share/icons/omahop-test`, then `rmdir ~/.local/share/icons`, which this test had created);
`ls ~/.local/share/icons` then answers "No such file or directory", exactly as before. Reopened the grid: btop and Chromium show their normal
icons again. `git status` of the repo shows only the new screenshot folder. Nothing else was backed up because nothing else was touched.

## 5c. Second live test: the small vertical menu (Super + Space itself)

Open without keys: `omarchy-menu summon root` (wrapper of `omarchy-shell shell summon omarchy.menu '{"menu":"root"}'`), close with `omarchy-menu close`.
Same reversible test: `omahop-test/apps/` with `aether.svg`, `btop.svg`, `chatgpt.svg` (magenta, green, orange T), deleted afterwards
(`ls ~/.local/share/icons` answers "No such file or directory", as before the test).

- **The root menu rows have no app icons at all.** They are glyph icons from the font (Apps, Learn, Appearance, Trigger, Setup, Install,
  Remove, Update, About, System), set in `/usr/share/omarchy/default/omarchy/omarchy-menu.jsonc` (`"icon":"..."`) and drawn as text
  (`Menu.qml` around line 1516, `iconText`, `visible: row.hasIcon && !row.isApp`). Nothing there reads an icon file, so nothing to change.
  Screenshot: `img/menu-root-test.png`.
- **The root "Apps" row opens the grid.** Its action is `omarchy-shell omarchy.dock apps` (jsonc line 24), so `omarchy-menu summon apps` and
  Enter on that row both open the same app grid as Super + Alt + Space, and the grid showed the test icons (Aether magenta, btop green,
  ChatGPT orange): `img/menu-apps-test.png`.
- **The vertical list with app icons exists only as the menu's app rows** (`Menu.qml` `mergeAppRows`, rows with `parent: "apps"`, `appIcon`).
  They are drawn at `Menu.qml:1532 to 1541` with `source: ... root.appLibrary.iconSource(row.appIcon)`, the same function the grid and bar use, so the
  overlay applies to them by the same rule (source proof, not seen on screen). It was not possible to bring that list on screen without
  keyboard input here: route `apps` runs the grid action instead, and the rows would most likely only show when text is typed at the root.
  Not verified: when exactly those rows are visible.
- Bar: yes, changed. The workspace item for the kitty window drew the test icon in the first test (section 5b) and again here (still showing a
  `T` tile during the aether/btop/chatgpt test, because it had not been rescanned); it returned to normal after a grid reopen.

## 6. Not verified

- Symlinks in the real shell: the real test (5b) used plain files, the scratch test (How verified) showed `find` lists symlinks; a link served by
  the running shell is the first hand check once built (`validation-checklist.md`). The kitty icon in the grid (it was off the first page).
- The PNG in SVG wrapper idea; the effect of a missing `index.theme` on Qt; the root menu typed search.
- Other machines: Omarchy older than the version with `AppLibrary` (the 4.0.6 Z13 note) may use a different launcher; the feature must detect
  `AppLibrary` before offering the setting, or say it is for Omarchy 4.5 and later.

## Open question

Should the first version cover SVG pack icons only (works with no extra step) and say so, or wait for a tested PNG route?
Recommended answer: ship SVG first with the limit stated in the help, and add PNG only after the wrapper idea is tested, because a pack made by
the builder from theme icons is mostly SVG anyway.

## How verified

- `grep` of `~/.config/hypr`, `/usr/share/omarchy/default/hypr/bindings/*.lua`; `which walker` (absent).
- Read `shell/services/AppLibrary.qml`, `PluginAppLibraryApi.qml`, `plugins/menu/Menu.qml`, `plugins/menu/manifest.json`, `plugins/dock/AppGrid.qml`, `Dock.qml`.
- `env`, `gsettings get org.gnome.desktop.interface icon-theme`, absence of qt6ct and gtk settings files, `~/.config/omarchy/shell.json`.
- Real test: section 5b.
- Scratch test in the session scratchpad (a fake `HOME`, never the real one): the stock scan command was run with
  `~/.local/share/icons/omahop-launcher/apps/` holding a symlink `firefox.svg` and a symlink `kitty.png`. Result: the symlinked SVG was listed
  and won for its name; the symlinked `kitty.png` lost to the system `hicolor/scalable/apps/kitty.svg`. This confirmed the layout is scanned
  (symlinks included, no `index.theme` needed) and the SVG before PNG rule.

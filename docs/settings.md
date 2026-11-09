# omahop settings model

Design, not built. Rule from Felipe (2026-11-06): nothing about scope or window choice is hard-coded; each is a setting, the
default is the narrow one (floating desktops, active monitor). All settings follow [engineering-standards.md](engineering-standards.md).

## Two separate questions

1. **Trigger scope**: on which workspaces does omahop take over Alt+Tab? Out of scope, stock Alt+Tab runs unchanged.
2. **Window set**: which windows does the list show, once omahop is open?

They are independent. Mixing them is allowed.

| Setting | Values | Default | Meaning |
|---|---|---|---|
| `scope` | `floating`, `all` | `floating` | Trigger scope (question 1) |
| `windows.workspaces` | `current`, `floating`, `all` | `floating` | `current`: only the workspace you are on. `floating`: every workspace that is in floating mode. `all`: every workspace, tiling too |
| `windows.monitors` | `active`, `all` | `active` | `active`: only the monitor with focus. `all`: windows on every monitor |
| `windows.minimized` | `back`, `hide` | `back` | Minimized windows listed last, or not listed |
| `windows.specials` | `hide`, `show` | `hide` | Scratchpad and console special workspaces |
| `windows.ignore` | list of app id or title patterns | empty | Never listed |
| `border` | auto, on, off | auto | The list card's outline. `auto` follows Hyprland's `general:border_size` (no outline when window borders are off); `on` and `off` force it |
| `search_fuzzy` | on, off | on | Typed search also matches initials (`gc`: Google Chrome) and letters in order inside a word (`chrm`: chrome, 3+ letters), after the plain matches. Accents are always ignored (`acao` finds `ação`) |
| `search_linger_seconds` | 0, or 1 to 60 (seconds) | 0 | 0: releasing Alt picks, as always. 1 to 60: with a search typed, releasing Alt no longer picks; the list stays open this long after the last key and holds the keyboard (from the first typed letter), so any character can be typed. Return picks, Escape clears then closes, a click outside the card closes, the timeout closes without picking. Inert when `takeover` is off. Out of range falls back to 0 |
| `action_keys` | text, `key=action` pairs | empty | Keys that act on the selected row while the list is up and the query is empty, for example `q=close, m=minimize`. A key is one letter or digit (navigation keys cannot be used). Actions: `close`, `minimize` (the table of actions is data in the glue, `M.actions`, so more can be added without touching the parser). Once a letter is typed, every key types. A key a hint also uses (`hints` = numbers claims 1 to 9, apps claims the `hint_keys` letters) is dropped and reported in the log as `config: action_keys: ...`. The acted-on row leaves the list at once and the selection moves to the next row; an empty list ends the session. Needs `search` on (same key binding path) |
| `icon_theme` | text (a theme folder name), with a picker button (D28) | empty | Prefer this installed icon theme (and the themes it inherits) when picking app icons, for example `Papirus`. Empty (shown as Automatic) keeps the old behaviour (the first theme the scan finds). An app the theme lacks still gets an icon from the others. A name with anything but letters, digits, dot, dash or underscore is ignored. The index is rebuilt when the value changes |
| `modifier` | `alt`, `ctrl` | `alt` | The key held for the switch (trigger, keys while the list is up, release to pick). Read at load, so a change needs a Hyprland reload. `alt` replaces Omarchy's Alt+Tab and runs it itself out of scope. `super` and `ctrl` bind Tab only when the bind snapshot shows it and its Shift variant free (Super+Tab is Omarchy's next workspace, so stock bindings leave it unbound, with a note in the log), and out of scope hand the key back to the app. Session keys follow the same free-chord rule (most Super letters are Omarchy's). `same_app_key` must start with the same modifier. An unknown value falls back to `alt` and is logged. Values come from one table, `lua/modifier.lua`. Shift is out of scope (it means reverse) |
| `icon_pack` | text (a pack folder name), with a picker button (D28) | empty | A hand-made icon pack in `~/.config/omahop/packs/<name>/` (`pack.toml` plus `icons/`, format in [icon-packs.md](icon-packs.md)). Its icons come before the theme and the system ones; an app the pack lacks keeps its usual icon. Same name rule as `icon_theme` (letters, digits, dot, dash, underscore, else ignored). A bad `pack.toml` refuses the whole pack, a bad file is skipped; both leave a note in the shell log. Read again when the value changes. The button opens the same picker on its Pack tab; the pack editor is reached from there (see icon-packs.md, The editor) |
| `icons_in_launcher` | on, off | off | Use the icon theme and pack in the Omarchy app grid (Super + Alt + Space), on the bar and in the menu's app rows too (not the menu's own glyph icons). Group Look, advanced, needs `icon_theme` or `icon_pack` (does nothing with neither), not changed by a profile. omahop owns `~/.local/share/icons/omahop-launcher/` (links named by each app's `Icon=` value, plus a `.omahop` marker); off, or both icon settings empty, deletes it, only with the marker. SVG icons only: a PNG that loses to a system SVG is left out. Other programs reading that folder may notice. See [icon-packs.md](icon-packs.md) |
| `browser_tabs` | on, off | off | Search browser tabs (v1.4, group Browser tabs). Off: omahop creates no file for tabs and reads none. On: omahop creates `$XDG_RUNTIME_DIR/omahop/tabs.enabled` (folder mode 700, files 600) and the separate helper of the `omahop-tabs` extension starts writing the tab list there; while a search is typed, each matching tab is a row under its browser window and Return opens it. Turning it off in the settings window removes at once (and, as a fallback, the next Alt+Tab or Hyprland reload does it) the flag, the ignore file and every tab file. The file contract: [file-contract.md](file-contract.md) |
| `browser_tabs_ignore` | text, site names comma separated | empty | Sites whose tabs are never listed, for example `bank.example.com`. A plain name covers its subdomains (`example.com` also hides `mail.example.com`); a glob (`*`, `?`, `[...]`, as Python fnmatch) must match the whole site name (`*.corp.example` hides `a.corp.example`, not `corp.example`). Tabs with no site (`data:`, `file:`) are never hidden. Same rules as the helper. Written to `tabs.ignore` (one name per line) for the helper, which drops those tabs before writing; omahop drops them again when it reads (defence in depth). Names may hold letters, digits, dot, dash and the glob characters only; anything else is skipped and logged |
| `browser_tab_previews` | on, off | off | Page pictures on found tab cards (v1.6, group Browser tabs, cards style, needs `browser_tabs`). A second opt in: this setting and the extension's own options page (Enable page pictures, which asks Chrome for the broad permission). Neither alone does anything. omahop makes `$XDG_RUNTIME_DIR/omahop/tabs.pictures` only while both this and `browser_tabs` are on and removes it, with every picture, when either goes off. Pictures of tabs you have looked at are updated while you browse (every 12 s while a tab is shown, and when the switcher opens: omahop asks `shown`). Never for sites on the ignore list. Not changed by a profile. |
| `browser_tab_previews_draw` | on, off | off | Also draw pictures of tabs you have not opened (D26, group Browser tabs, needs `browser_tab_previews`, which needs `browser_tabs`). Chrome cannot photograph a tab you never looked at; with this on the extension draws pictures of tabs you have not opened quietly in the background after they load, so they are ready when you search (approximate: images from some websites may be blank, video first frame), by running a small script inside that page, locally, within a resource budget (one at a time, at most one a second (fewer after a slow page) and 60 an hour, no very heavy pages). When the switcher opens omahop asks for drawings of the first 6 background tabs of each host that have no picture, and at search time for the rest (once per session); the card says "approximate". A tab card that has no picture says why in a small label (for example "Chrome page", "too heavy to draw", "drawing soon"; see the README). Chrome's own pages and the new tab page cannot get a picture. Never for sites on the ignore list. omahop makes `tabs.draw` only while all three settings are on. Not changed by a profile. |
| `audio_marker` | on, off | off | A small speaker (the Nerd Font glyph Omarchy's audio panel uses, as text) after the app name in rows and cards whose app is playing sound (group Look). Sampled once when the list opens: `tools/audio-sample.sh` runs `pactl -f json list sink-inputs` and `ps -e -o pid=,ppid=`; nothing runs while the list is closed or the setting is off. A stream counts only when it is neither corked (paused) nor muted. Matched to windows by process id up the parent chain (16 steps), then by app binary or name against the window class. A browser marks all its windows. Only the overlay reads it (`ConfigReader`); the Lua side and the state file do not carry it. D21, `research/audio-spike.md` |
| `swipe_trigger` | on, off | off | Touchpad swipe trigger (v1.5, group Touchpad swipe): a swipe left or right with `swipe_fingers` fingers opens the list on the first row of travel (right: the previous window, left: the last), each further row moves the selection, lifting picks. Lifting on the window the swipe started from, a swipe Hyprland cancels, or 10 s with no movement closes without switching. Does nothing where omahop is not active (scope, passthrough) or while a keyboard session is open. Touchpads only: a touchscreen swipe never reaches a plugin. Needs `takeover` on and a Hyprland reload to turn on; turning it off applies at once. Design: [research/swipe-spike.md](research/swipe-spike.md) |
| `swipe_fingers` | 3, 4 | 4 | Fingers for the swipe trigger. Read at load (Hyprland reload). A swipe already in the Hyprland config on the same fingers and axis keeps working and Hyprland reports omahop's as a config error; `lua tools/gesture-map.lua` lists the swipes in use. Omarchy's example config uses 3 fingers left and right for workspaces. Out of range falls back to 4 |
| `swipe_distance` | 20 to 600 (px) | 100 | Finger travel per row. Applies at once |
| `takeover` | on, off | on | Take over Alt+Tab at all. Off leaves a user's own Alt+Tab bind alone (a user can also set `_G.omahop_takeover = false` before omahop loads) |
| `keys.repeat_delay_ms`, `keys.repeat_ms` | numbers | 250, 40 | Hold-Tab repeat, polled by omahop (no Hyprland `repeating` bind, so stock behaviour on tiling workspaces is untouched) |

A window is listed when its workspace matches `windows.workspaces` AND its monitor matches `windows.monitors`, then the
minimized, specials and ignore rules apply. Order is most recently used first; the first Tab picks the previous window.

## Combinations

| `scope` | `windows.workspaces` | `windows.monitors` | Behaviour |
|---|---|---|---|
| floating | floating | active | **Default.** On a floating desktop you see only floating windows on this monitor. Tiling desktops are untouched |
| floating | floating | all | Same, plus floating windows on the other monitors |
| floating | current | active | Only this desktop, this monitor: the smallest list |
| floating | all | any | Triggers only on floating desktops but the list also shows tiled windows. Allowed for power users; choosing one switches desktop (and monitor if needed) |
| all | floating | any | omahop runs everywhere but only ever lists floating-desktop windows. On a tiling desktop the list may hold windows from other desktops, so picking one moves you there |
| all | current | active | omahop everywhere, each desktop shows only itself. Closest to a classic per-desktop switcher |
| all | all | all | Everything everywhere: the Windows-style switcher of core PR 16548 |

Edge rules:
- Empty list (for example `current` on an empty desktop): do nothing, no overlay, no error.
- One window: Alt+Tab does nothing visible.
- Picking a window on another workspace or monitor focuses it and switches there. Same rule everywhere, no special cases.
- If `scope = floating` and the current desktop is tiling, omahop is out of the picture: the stock bind runs, `windows.*` is not read.

## Thumbnail exclusions

`thumbnail_exclude` (top level, group Look) is a comma separated list of window classes, case-insensitive, whole classes only. A listed window is never captured: cards and the peek popup show its app icon, in every `thumbnails` mode, and no capture object is created for it. The list style has no pictures and ignores it. Only the overlay reads it (live, through `ConfigReader`, parsed by `State.thumbnailExcludeSet`); the Lua side and the state file do not carry it.

## Profiles (v1.5, D19, design in `research/profiles-spike.md`)

A profile is a named set of settings that replaces some of the base ones. It lives in the same file as a
`[profiles.<name>]` table (top-level keys) plus `[profiles.<name>.windows]` and `[profiles.<name>.keys]` for the nested
sections. The top-level setting `profile` chooses one; empty (the default) uses the base settings as they are.

```toml
profile = "work"           # "" = none

[profiles.work]
style = "cards"
thumbnails = "snapshot"

[profiles.work.windows]
ignore = "steam, discord"

[profiles.gaming]
style = "list"
passthrough_fullscreen = true
```

| Rule | Detail |
|---|---|
| Name | Letters, digits and underscores (`[A-Za-z0-9_]+`); a table name with anything else is an unreadable line |
| Layering | For each setting: the profile's value if it is valid, else the base value, else the default. A bad profile value keeps the base value and is logged (`config: profiles.work.style = 5`) |
| Not overridable | `takeover`, `modifier`, `same_app_key` (read only at load), `browser_tabs`, `browser_tabs_ignore` (privacy: one place decides), `profile` (no chains). A profile key naming one is logged as `not overridable in a profile, ignored`. The rule is spec metadata (`reload`, `hidden`, `base_only`; `C.overridable`), written to `spec.json` as `overridable` |
| Unknown profile | `profile = "ghost"` with no such table: logged, the base settings are used |
| Unknown keys | Ignored inside a profile, as in the base; so is the hidden `schema` |
| When it applies | The next Alt+Tab (Lua reads the file at each session start); the overlay's live readers (peek strip, icons, thumbnail exclusions) at once |
| Settings window | One row, General > Profile: None plus the profiles in the file. Rows keep showing and editing the base value; a row the active profile replaces gets a caption, "Profile work sets this to Cards with thumbnails." Writing a profile's values is done in the file for now |

One rule, two implementations: `C.resolve` in `lua/config.lua` (the switcher) and `ConfigIO.resolve` in `ConfigIO.js`
(the overlay's `ConfigReader` and the settings window). `tests/config_io.test.mjs` runs both on the fixtures in
`tests/fixtures/profiles/` and compares every value and every log line.

Later (not built): choosing a profile automatically by workspace, monitor count or app; per-shortcut profiles (a profile
bound to its own chord, the older BetterCmdTab idea); editing a profile's values in the settings window.

## Config file

`~/.config/omahop/config.toml`, `schema = 1`, unknown keys kept, bad values fall back to the default and are logged.
The settings app reads and writes the same file; hand edits apply live.

## Tests this model needs

- Pure: a table test over every row above with fake windows on several workspaces and monitors, checks the listed set and order.
- Glue: scope guard calls the stock handler on an out-of-scope desktop.
- Live (real monitors only): default settings on a tiling desktop equal stock Alt+Tab.

## Icon picker (D28, slice 1)

Both icon rows (group Look, sub heading Icons) show a button labelled with the current value ("Choose a theme: Automatic"). It opens a page of the same settings window with a Theme and a Pack tab. Each choice is a card showing the same sample apps (`sample_apps` in `lua/config.lua`, carried to the panel by spec.json), so choices compare side by side; an app a choice has no icon for is an empty outline. Up, Down, PageUp, PageDown, Home and End move and the larger preview row follows at once, but nothing is written until Enter or Choose; Escape (or Back) returns and writes nothing. Typing filters by name. Automatic (theme) or No pack (pack) is the first card and clears the setting. A click selects, a double click chooses. The typed text boxes stay under the buttons as the fallback for a name the scan does not list. Customize icons is shown disabled ("coming next") until the builder (D29) exists; the Pack tab links to the pack editor.

Choices come from `tools/icon-themes.sh` (folder and `Name=` of every installed theme that has app icons; hicolor, default, `Hidden=true` and cursor-only or empty themes are left out) and `tools/pack-edit.sh list`. Icons come from `tools/icon-preview.sh <theme|-> <app id>...` (one run per theme, only for cards on screen, cached while the page is open) or `tools/pack-index.sh`. A new theme or pack appears with no code change.

### Opening a page without clicks (dev and test only)

Write `icon_theme` or `icon_pack` into `$XDG_RUNTIME_DIR/omahop/open-page`, then open the settings window (`omarchy-shell shell toggle io.github.felipecpaiva.omahop`): it lands on that picker page. The file is emptied once read. Used for screenshots, where no keyboard input is allowed.

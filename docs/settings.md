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
| `icon_theme` | text (a theme folder name) | empty | Prefer this installed icon theme (and the themes it inherits) when picking app icons, for example `Papirus`. Empty keeps the old behaviour (the first theme the scan finds). An app the theme lacks still gets an icon from the others. A name with anything but letters, digits, dot, dash or underscore is ignored. The index is rebuilt when the value changes |
| `modifier` | `alt`, `ctrl` | `alt` | The key held for the switch (trigger, keys while the list is up, release to pick). Read at load, so a change needs a Hyprland reload. `alt` replaces Omarchy's Alt+Tab and runs it itself out of scope. `super` and `ctrl` bind Tab only when the bind snapshot shows it and its Shift variant free (Super+Tab is Omarchy's next workspace, so stock bindings leave it unbound, with a note in the log), and out of scope hand the key back to the app. Session keys follow the same free-chord rule (most Super letters are Omarchy's). `same_app_key` must start with the same modifier. An unknown value falls back to `alt` and is logged. Values come from one table, `lua/modifier.lua`. Shift is out of scope (it means reverse) |
| `icon_pack` | text (a pack folder name) | empty | A hand-made icon pack in `~/.config/omahop/packs/<name>/` (`pack.toml` plus `icons/`, format in [icon-packs.md](icon-packs.md)). Its icons come before the theme and the system ones; an app the pack lacks keeps its usual icon. Same name rule as `icon_theme` (letters, digits, dot, dash, underscore, else ignored). A bad `pack.toml` refuses the whole pack, a bad file is skipped; both leave a note in the shell log. Read again when the value changes |
| `browser_tabs` | on, off | off | Search browser tabs (v1.4, group Browser tabs). Off: omahop creates no file for tabs and reads none. On: omahop creates `$XDG_RUNTIME_DIR/omahop/tabs.enabled` (folder mode 700, files 600) and the separate helper of the `omahop-tabs` extension starts writing the tab list there; while a search is typed, each matching tab is a row under its browser window and Return opens it. Turning it off in the settings window removes at once (and, as a fallback, the next Alt+Tab or Hyprland reload does it) the flag, the ignore file and every tab file. The file contract: [file-contract.md](file-contract.md) |
| `browser_tabs_ignore` | text, site names comma separated | empty | Sites whose tabs are never listed, for example `bank.example.com`. A plain name covers its subdomains (`example.com` also hides `mail.example.com`); a glob (`*`, `?`, `[...]`, as Python fnmatch) must match the whole site name (`*.corp.example` hides `a.corp.example`, not `corp.example`). Tabs with no site (`data:`, `file:`) are never hidden. Same rules as the helper. Written to `tabs.ignore` (one name per line) for the helper, which drops those tabs before writing; omahop drops them again when it reads (defence in depth). Names may hold letters, digits, dot, dash and the glob characters only; anything else is skipped and logged |
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

## Later: profiles (idea from BetterCmdTab, B-ids in its reference)

A profile is a named set of the settings above bound to its own shortcut, for example `Alt+Tab` = floating, active monitor,
and `Alt+Backtick` = all windows, all monitors. The settings model is a flat table now so that profiles can wrap it later
without a schema change: `profiles.<name>.windows.*` overrides the global values.

## Config file

`~/.config/omahop/config.toml`, `schema = 1`, unknown keys kept, bad values fall back to the default and are logged.
The settings app reads and writes the same file; hand edits apply live.

## Tests this model needs

- Pure: a table test over every row above with fake windows on several workspaces and monitors, checks the listed set and order.
- Glue: scope guard calls the stock handler on an out-of-scope desktop.
- Live (real monitors only): default settings on a tiling desktop equal stock Alt+Tab.

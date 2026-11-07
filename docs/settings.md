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
| `icon_theme` | text (a theme folder name) | empty | Prefer this installed icon theme (and the themes it inherits) when picking app icons, for example `Papirus`. Empty keeps the old behaviour (the first theme the scan finds). An app the theme lacks still gets an icon from the others. A name with anything but letters, digits, dot, dash or underscore is ignored. The index is rebuilt when the value changes |
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

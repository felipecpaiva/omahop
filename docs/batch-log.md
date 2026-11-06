# omahop batch log

2026-11-06: research and design docs written. No code yet.

## Batch 1 (2026-11-06): Lua core, pure modules and glue

Built: `lua/config.lua`, `scope.lua`, `windows.lua`, `mru.lua`, `session.lua` (pure, each with a `test_*.lua`), `omahop.lua` (Hyprland glue, tested against a fake `hl`
in `test_glue.lua`). Live test `tests/live.py` (16 checks, real keys through `/dev/uinput` on a spare workspace with three coloured windows): quick tap flips to the previous window
and raises it, hold Alt plus Tab picks, Shift+Tab, Escape cancels, Alt+arrows, hold Tab repeats, tiling workspace keeps stock Alt+Tab. All pass.
Found on the way: `send_shortcut` echo (fixed with `send_key_state`), minimized windows carry `omarchy-minimized-from-<id>` (so their origin workspace is known and the window filter uses it).
Not done: the overlay (the state file is written, nothing draws it yet), settings app, install line in `hyprland.lua`, hand checks.

## Batch 2 (2026-11-06): overlay (list style), manifest, README

Built: `State.js` (state file parser, Node-tested in `tests/state.test.mjs`), `ListRow.qml`, `ListStyle.qml`, `Service.qml` (watches the state file, draws with the shell's `OverlayWindow`, never takes keyboard or pointer),
`manifest.json` (kind `service`, validates). The first live screenshot showed the card in the Omarchy theme with the selected row highlighted; the layer appeared within 60 ms of the reveal and went away on release.
Not yet verified after the first screenshot: it was taken while the theme picker overlay (which the shell opens after a restart) held the keyboard, so list order and pick in that picture are not trustworthy.
Fixes after seeing it: subtitle contrast (was `Color.muted`, too dim on the card), generic icon instead of the missing-image checkerboard. `qmllint` cannot resolve the shell's `qs.*` imports, so it only checks syntax.
Left for v0.1: a clean overlay screenshot with the picker closed, hand checks, tag.

## v0.1 status (2026-11-06, end of session)

Feature complete for the v0.1 row of the release plan: Alt+Tab override with scope and window-set settings, MRU, tap flips, reveal delay, Alt/Tab polling, repeat, Esc/Enter/arrows, list overlay in the Omarchy theme, config file, stock fallback on tiling workspaces.
Verified: all unit and glue tests, the state parser, plugin validation, QML syntax, 16 live checks with real keys (run before the overlay plugin was enabled), and the overlay itself with a synthetic state file (icons, names, titles, dimmed minimized row, elided long title, highlight on the selected row, scrolling with 12 entries). A bug found that way: ListView resets `currentIndex` on every model replacement, so the highlight now comes from `selected` directly.
NOT verified end to end: the live test with the overlay plugin enabled (key events were declined by the user at the end of the session, so none were sent), state-file watch latency (S3), minimized restore and two monitors on real hardware, non-Qt apps for the Alt-menu fix.
To close v0.1: run `bash tests/run-all.sh` (live part drives the keyboard, hands off for about a minute), tick `docs/validation-checklist.md`, then tag `v0.1.0`.

## v0.1 live run with the overlay (2026-11-06)

With the plugin enabled and the install line in `hyprland.lua`, `bash tests/run-all.sh` passed everything: unit, glue, scrub, state parser, plugin validation, QML syntax, and 18 live checks with real keys
(the 16 from before plus: the overlay layer is on screen while revealed, and gone after cancel). No test windows left, the temporary config removed, the original workspace restored.
Still on Felipe's hand-check list: non-Qt apps for the Alt-menu fix, two monitors, minimized restore on real windows, theme change, the real keyboard feel.

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

## Border follows Hyprland (2026-11-06)

Felipe removed window borders (`general:border_size = 0`); the list card still drew an outline. Now the card reads the border size (at load, on config reload, each time a session opens) and `border = auto` follows it (0 means no outline); `on` and `off` override. Checked with a synthetic state on the real shell: auto with border size 0 shows no outline, `on` shows it. Unit tests: `State.borderWidth` (Node), `border` in config (Lua).

## v0.1.0 tagged (2026-11-06)

Felipe tried it on his machine (look fine, performance fine after the state-write fix and `reveal_delay_ms = 0`, outline now follows his Hyprland border setting) and asked for the tag. Next goal: v0.2 (cards with thumbnails, search, settings app, multi-monitor overlay), see `docs/ROADMAP.md`.

## Batch 3 (2026-11-06, branch v0.2): live config and the config writer

Built: the spec table in `lua/config.lua` now carries labels, help, names per value, units, groups and order (one definition); `tools/gen-spec.lua` writes `spec.json` for the settings panel and `--check` fails the run when the committed file drifts;
`omahop.lua` re-reads the config file when a session is about to start (text compare, nothing parsed when unchanged), so edits apply to the next Alt+Tab without a reload (`takeover` still needs one: it decides whether the binds exist);
`ConfigIO.js` edits one line at a time and keeps comments, order, unknown keys and sections byte for byte (`set`, `unset`, `get`, `parse`), Node-tested including a cross-check that Lua and JavaScript parse the same text the same way.
Bug found by that cross-check: the Lua parser cut a line at ` #` even inside quotes (`ignore = "steam, #hash"` was dropped); fixed with a quote-aware comment strip in both languages.
Verified: all unit tests, `run-all.sh` with the live part (18 checks) on this branch.

## Batch 4 (2026-11-06, branch v0.2): settings window

Built: `SettingsStore.qml` (reads spec.json and the config file, edits one line per change through ConfigIO, saves after 450 ms with atomic writes), `SettingRow.qml` (one setting drawn from its spec entry: switch, buttons, number field or text field, help line, reset link),
`SettingsPanel.qml` (scrolling page with groups, "Reload Hyprland now" when a reload-only setting changed), `omahop.desktop` (launcher entry the service installs and removes, only if it carries our marker), `Paths.js`, manifest kinds `service` and `panel`.
Verified on the real shell: the window opens from `omarchy-shell shell toggle`, a virtual mouse click on a button writes `scope = "all"` and then `scope = "floating"` to the same line, comments and other keys untouched (`tests/live_panel.py`, positions measured for a 1280x800 logical screen, SKIPs elsewhere).
Bugs found: a QML name clash (`store: store` inside the row component refers to its own property, so every control did nothing; the panel's store is now `settings`); BorderSurface padding does not move anchored children (margins added by hand).
Not yet by hand: number field, text field, reset link, the reload button (on the checklist).

## Batch 5 (2026-11-06, branch v0.2): cards style with thumbnails

Spike S2 first (`research/spikes.md`): thumbnails show real content for a covered window and a minimized one; live capture costs CPU (about 20% of Hyprland for 30 views), snapshots cost almost nothing, so `snapshot` stays the default.
Built: `CardItem.qml` (picture or icon, app icon, name and title), `CardsStyle.qml` (horizontal strip, scrolls to keep the picked card in view, cards outside the strip are not built so no capture runs for them), `Service.qml` picks the style with a Loader and maps a Hyprland window address to its Wayland toplevel,
`State.js` (`normalizeAddress`, `visibleCards`, Node-tested), settings `style` and `thumbnails` now shown in the panel. Cards are keyboard-only in v0.2.
Verified on the real shell with real windows: `tests/live_cards.py` counts the three test colours in a screenshot (covered, minimized and top window each have a thumbnail; with thumbnails = off none).
Bugs found: a Loader property named `scale` clashes with Item.scale (renamed `fitScale`); the first test counted the test windows themselves (they are moved out of the photographed area now); minimized cards are dimmed so a colour threshold must be loose.
Left: many-windows scroll and live mode by hand (checklist), the unplugged-monitor check (L6), a better highlight picture for the release.

## Batch 6 (2026-11-06, branch v0.2): type to search

Spike D14 first: `io.popen("hyprctl binds")` from the glue blocked the whole compositor for 5 seconds (Hyprland waits for itself), so the bind snapshot is taken by a detached `hl.exec_cmd` into a file; 38 binds register in under 10 ms.
Built: `lua/search.lua` (pure: every word must appear in the app display name, class or title; apps that start with the first word rank first; Node-free Lua tests), `Session:resize`, the glue (typing chords only while a session is open and only for chords the snapshot shows free, exact unbind at the end, first Escape clears the query, empty result keeps the session open and activates nothing, `query=` in the state file, a `search` setting),
overlay (`SearchChip.qml` above the list, the names file the overlay writes so Lua can search by display name such as "Files").
Verified: unit and glue tests (including a user's own ALT+X left alone), `State.js` tests, and live with real keys: typing 'alp' picks alpha although the default pick is bravo, backspace, Escape clears first, no match leaves focus alone.
Left: hand checks (display-name search, own shortcuts), tuning ranking after real use.

## Batch 7 (2026-11-06, branch v0.2): release material and checks

Core PRs 16548, 16219 and 16479 are all still open (read-only check), so D9 stands. Highlight pictures made from the real overlay on a spare workspace with public content only (`branding/tools/highlight.py v0.2.0`): cards, list, search.
First attempt showed the home folder in a file-manager window: those pictures were deleted before any commit and the demo now opens a system folder (the check is: look at every highlight picture before committing it). `docs/releases/v0.2.0.md` written (image links point at the `v0.2` branch until it is merged to main).
Left for Felipe before the tag: hand checks (`docs/validation-checklist.md`, v0.2 sections), picking a logo concept, plugging in a second monitor for the multi-monitor and unplug checks, and the decision to merge `v0.2` into main.

## Brand round two and feature GIFs (2026-11-06, branch v0.2)

Felipe rejected the first logo concepts (orange, unrelated to omagnet). The brief now has a "Family" section: omagnet's graphite tile, white-lilac mark, electric violet for the one element that moved, the three grey motion ticks, rounded geometry and the violet-o wordmark are kept, only the idea differs.
Three new concepts from Codex in that family (`v1-stackhop`, `v2-tilehop`, `v3-ohop`), board rebuilt. My read: v1 is the clearest (windows, one hopping out), v3 the closest to omagnet in feel and the cleanest at 16 px, v2 reads like headphones at small sizes. Felipe picks.
GIFs: `branding/tools/demo.py` (adapted from omagnet's recorder, `gifkit.py` copied) records switch, cards, search and settings on the spare workspace. Bugs found while recording: top-level config keys written after the `[windows]` header are read as window settings and ignored (cards and search scenes showed the list); a Nautilus background service hands new windows to itself so the demo window never appeared on the spare workspace (replaced by a third terminal). Frames checked on contact sheets: only demo windows, wallpaper and the overlay.

## Logo: v2-tilehop chosen, three colour variations (2026-11-06)

Felipe liked v2-tilehop and wants a colour scheme of its own, not omagnet's violet. `branding/tools/recolor.py` made three palettes from the same vector (Tide blue, Coral rose red, Citrus golden yellow), contrast computed (all above the bar), PNGs exported, board `branding/board-v2-tilehop.png`.
Honest note: the arch can read as headphones at small sizes; the ticks blur at 16 px (omagnet has an `icon-small` without ticks for that, to be made with the full kit).

## Brand kit built: v2-tilehop in Citrus (2026-11-06)

Felipe picked the yellow variation. `branding/tools/kit.py` (own script, structure learned from omagnet's logo.py, kit.py, social.py and sheet.py, palette parameterised) writes the logo set, the small icon without ticks, wordmark with the letters h and p added in the same stroke style, lockups, eight social images, the marketplace preview (lockup beside the real settings window, cropped to the card) and the brand sheet (all 8 colour pairs computed). README has the banner (dark and light) and the switch GIF at the top.
Manual step left: upload `branding/social/github-social-preview.png` as the repository social preview on GitHub.

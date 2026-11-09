# omahop roadmap

Method, same as omagnet: small batches. Each row has plan, implementation, test, validation. No row is done until its test
passes and the real shell shows it. Live tests drive the real keyboard through `/dev/uinput`; tell Felipe, keep hands off.
Agents on cheaper models do mechanical work, a strong model judges. Agent reports are data, the orchestrator re-runs tests.

Every row must meet [engineering-standards.md](engineering-standards.md): flexibility, scalability, code standards per language.

## Release plan (features arrive gradually, each release is usable alone)

| Release | Goal | Contents |
|---|---|---|
| **v0.1** basic (RELEASED 2026-11-06, tag v0.1.0) | A working list switcher you can use daily | Phase 0 spikes. Phase 1 rows A1 to A6: Alt+Tab override, `scope` (floating default, `all`), window set filter (A2b), MRU, first Tab picks previous window, tap vs hold with 100 ms reveal, Esc/Enter/arrows, vertical list with icon, app name and title, live theme. Settings by hand-edited `config.toml` (no app yet). No thumbnails. Must handle the rivals' known failures: raise the focused floating window (`bring_to_top`), skip ghost windows (Wine, Proton, no real toplevel), both Alt keys by scan code, no pointer warp. |
| v0.2 (RELEASED 2026-11-06, tag v0.2.0; plan in `v0.2-plan.md`) | Looks and settings app | Type-to-search in the list (moved up from v0.4, rivals have it), Phase 2 cards style with thumbnails (B1 to B3), `thumbnails` setting, Phase 3 settings panel (C1 to C3), multi-monitor overlay (B5) |
| v0.3 (RELEASED 2026-11-06, tag v0.3.0; plan in `v0.3-plan.md`) | Pointer, quick actions, peek strip | Phase 4 hover previews (needs D8), minimized and special windows (B4), quick actions close and minimize (B6) |
| v0.4 (RELEASED 2026-11-07, tag v0.4.0; plan in `v0.4-plan.md`) | Power features | Profiles, letter hints, per-app rules, ignore-when-fullscreen (BetterCmdTab ideas, see its reference) |
| v1.0 (RELEASED 2026-11-07, tag v1.0.0; plan in `v1.0-plan.md`) | Release polish | Requirements and privacy in the README, launch material in `docs/launch/`. submitted to the marketplace (issue 14254) |
| v1.1 (RELEASED 2026-11-07, tag v1.1.0; plan in `v1.1-plan.md`) | Search and icons | accent and fuzzy search, `icon_theme`, `thumbnail_exclude` |
| v1.2 (RELEASED 2026-11-07, tag v1.2.0, was planned as v1.1b; design in `research/linger-spike.md`) | Keep the list open while searching | `search_linger_seconds` (default 0): the overlay holds the keyboard while lingering, any character can be typed, Return picks, timeout and click outside cancel. Unit, glue, Node and live tests pass with one monitor; two monitors not measured |
| v1.3 (RELEASED 2026-11-07, tag v1.3.0, v1.3.1 drops Super; plan in `v1.1-plan.md`) | Keys and icon packs | `modifier` (alt, ctrl; Super is not offered, Omarchy owns it), `action_keys` (quit and minimize by key), `icon_pack` (hand-made packs, format in `icon-packs.md`) |
| v1.4 (RELEASED 2026-11-08, tag v1.4.0; design in `research/tabs-spike.md`, D17 and D18) | Browser tabs and pack zips | omahop side of tab search (`browser_tabs`, off by default; the extension lives in the private repo `omahop-tabs`, not published yet) and `tools/pack-export.sh` / `tools/pack-import.sh` |
| v1.5 (RELEASED 2026-11-08, tag v1.5.0; designs in `research/profiles-spike.md`, `swipe-spike.md`, `audio-spike.md`, `pack-editor-spike.md`, D19 to D22) | Profiles, audio marker, swipe, pack editor | `profile` with `[profiles.<name>]` tables, `audio_marker`, `swipe_trigger` (touchpad only), the icon pack editor page. Real touchpad, real sound and the editor clicks are hand checks |
| v1.6 (BUILT 2026-11-09, screenshot checked; decision D24, research `research/settings-layout.md`) | Settings window layout | Done: side list of seven categories, sub headings, dependents nested and hidden while their switch is off, advanced settings folded, driven by `subgroup`, `advanced` and `depends` in `lua/config.lua` and spec.json, no search box (justified in D24). `tests/live_panel.py` coordinates need re-measuring. Original plan: the settings page was one long scroll of nine groups (General, Windows, Look, Keys, Peek strip, App rules, Shortcuts, Browser tabs, Touchpad swipe) and grows with each release. Sort it: a side list of categories or tabs so one category shows at a time, sub sections inside a category (for example Look: Style, Icons, Sound marker), the advanced and rare settings folded away, and a search box over all settings. Built from `spec.json` groups (add a sub section field in `lua/config.lua`, regenerate the spec, keep the drift check). Same one window, same pack editor page, no new widgets. Needs a live screenshot check at each size |
| v1.6b (step 1 BUILT 2026-11-08, live check done; step 2 BUILT 2026-11-08 omahop side, live check pending, D25; Felipe 2026-11-08) | Tab previews | Step 1 done in code: site icon (favicon) per tab, through the extension's local `_favicon` address (permission `favicon`, no network), written by the helper to `tabicons/` while `browser_tabs` is on, never for ignored sites. Step 3 (D26, omahop side BUILT 2026-11-08, real browser check pending): the final design for tabs that are not shown. Pictures come two ways: shot (exact, the extension photographs the shown tab after load, every 12 s while shown and when omahop asks at session start) and drawn (approximate, opt in `browser_tab_previews_draw`: html2canvas in a hidden tab, asked for at search time, marked approximate on the card). No tab switching. Step 2, decided: a picture of the page as an OPTIONAL setting, off by default, that the user turns on after install. Chrome only photographs the tab you see, so the picture is taken when you leave a tab, kept in memory and in the private runtime folder only, and needs `optional_host_permissions` (`<all_urls>`) that the extension asks for only when the user clicks the enable button on its own page. The extension page on paiva.gg explains why, so the user decides |
| v1.6c (BUILT as a draft PR 2026-11-08: felipecpaiva/Paiva.gg#30, branch feat/omahop-pages; Felipe 2026-11-08) | Project pages on paiva.gg | A page for omahop at `paiva.gg/omahop` (what it is, gifs, install, settings, privacy) and a page for the Chrome extension (what it does, why it works through a local helper, what each permission is for, what is optional, how to install, how to remove). They are the project pages the store listing and the README link to. Static files, nothing private, built in the repo so they can be reviewed before anything goes live. Lives in the paiva.gg repo (routes `/[locale]/omahop` and `/[locale]/omahop/tabs`). Needs from Felipe: review the copy and merge (merging deploys) |
| v1.7 (PLANNED, not started; decision D23) | Dock extension | Replace our own peek strip with an extension of the stock Omarchy dock (`/usr/share/omarchy/shell/plugins/dock/`, shown on floating workspaces). Keep the stock dock as it is and add only what we need: hover previews, the windows of an app, quick actions. Step 1 is a spike (`research/dock-spike.md`): upstream hover hook PR, clone of the dock plugin, or a layer over it; pick one by what survives Omarchy updates. All off by default (D11). Then `peek` is retired or kept as a fallback |

Rule: v0.1 stays small on purpose. A feature not in the v0.1 row waits, but the settings model (`settings.md`) and the
Lua/QML contract are built so that later features add values and views without rewriting the key handling.

## Phase 0: spikes (answer before design is final)

| ID | Question | Pass when |
|---|---|---|
| S1 | Does `hl.bind` with repeating fire Tab again while Alt is held? | **DONE: yes** (`research/spikes.md`) |
| S2 | Cost and behaviour of thumbnails: 10 live views, minimized, special, occluded, frame rate | Numbers in `research/`, default for `thumbnails` chosen |
| S3 (PARTLY DONE: 42 ms per shell IPC call; file-watch latency still to measure) | Lua to shell IPC: state file plus which IPC call opens/updates/closes an overlay from a plugin, latency per Tab | Overlay opens within 50 ms of Alt+Tab |
| S4 | Can an in-shell overlay window be focusless and still receive hover? | Hover works, keys stay in Lua |
| S5 | Read core PR #16548 diff: key handling, IPC, what we can copy by idea | Notes in `research/` |

| S6 (DONE: no detection; settings switch plus `_G.omahop_takeover`) | Load order: does the guarded load of `omahop.lua` run before or after the user's own `bindings.lua`? `hl.unbind("ALT + TAB")` removes every bind on that chord. Is a "do not take Alt+Tab" escape hatch needed? | Order documented, setting decided |
| S7 | Competitor traps: floating focus without raise, ghost windows, Alt scan codes 64 and 108, bind lifecycle on monitor hotplug (see `competitive-analysis.md`) | Each has a test or a documented answer |
| S8 (DONE: focus alone does not raise; `alter_zorder top` does) | Raise on Hyprland 0.56.2: does a focus dispatch raise a floating window, a maximized one, a fullscreen one? Which of `bring_to_top`, `alter_zorder`, lowering others works? (core issues 16241, 16973, 17724; PR 16412) | Table of cases and the working call in `research/` |
| S9 (DONE: only polling `hl.is_key_down` is reliable) | Cross-check Alt release: our polling versus the submap release bind `release, submap_universal, transparent, non_consuming`, both Alt keys | One method chosen, tested |

## Phase 1: switcher core, list style (no thumbnails)

| ID | Feature | Source ids |
|---|---|---|
| A1 (DONE batch 1-2) | Override Alt+Tab and Alt+Shift+Tab, guarded Lua load | C-baseline |
| A2 (DONE batch 1-2) | Scope guard: floating default, `all` option, stock behaviour out of scope | D4 |
| A2b (DONE batch 1-2) | Window set filter: `windows.workspaces` (current, floating, all), `windows.monitors` (active, all), minimized, specials, ignore; table test over every combination | `settings.md` |
| A3 (DONE batch 1-2) | MRU list from focus events, first Tab picks previous window | C-UX |
| A4 (DONE batch 1-2) | Alt hold/release commit, Esc cancel, Enter, arrows, Tab repeat | S1 |
| A5 (DONE batch 1-2) | Vertical list overlay: icon, app name, title, theme colours | C1.. |
| A6 (DONE batch 1-2) | Show delay (quick tap flips with no overlay) | C-UX |

## Phase 2: cards style and thumbnails

B1 cards strip, B2 `ScreencopyView` thumbnails, B3 `thumbnails` setting (live, snapshot, off), B4 minimized and special windows,
B5 multi-monitor (overlay per screen, list scope), B6 window quick actions (close, minimize).

## Phase 3: settings app

C1 settings panel in the shell (style, scope, thumbnails, show delay, list scope, include minimized, ignore list),
C2 config file `~/.config/omahop/config.toml` with a parser tested under Lua 5.5, C3 live apply.

## Phase 4: hover previews (needs D8)

D1 hover panel per app icon, D2 preview with title and window controls, D3 delay and position settings.

## Phase 5: release

E1 `tests/scrub.sh` clean, E2 offline and live suites green, E3 branding kit, E4 `v0.1.0`, E5 marketplace submission (only with Felipe's go).

## Tests

- `tests/run-all.sh`: pure (MRU, scope, config), glue (fake `hl`), scrub, then live.
- Scope test: on a tiling workspace, Alt+Tab result equals stock for every run.
- Never create headless monitors in live tests.

## v1.5: touchpad swipe trigger (branch v1.5-swipe)

Spike and design: `research/swipe-spike.md` (GO for the touchpad, NO-GO for the touchscreen), decision D20. Settings `swipe_trigger` (off),
`swipe_fingers` (4), `swipe_distance` (100 px). Files: `lua/swipe.lua` (pure, `lua/test_swipe.lua`), `lua/omahop.lua` (`open_session`,
`swipe_start`, `swipe_update`, `swipe_finish`, `bind_swipe`), `lua/config.lua`, `spec.json`, `tools/gesture-map.lua` (`--check` in run-all).
Tests: pure and fake `hl` glue in `run-all.sh --no-live`; the real touchpad is a hand check (`validation-checklist.md`, v1.5). Status: built,
hand checks pending.

## After 1.0 (ideas, not scheduled)

- **Audio marker per browser window** (from the v1.5 spike): today every window of a browser playing sound gets the speaker, because one process plays all tabs. The tabs API has an `audible` flag per tab; the `omahop-tabs` extension could write it, and omahop could then mark only the window that holds the audible tab.

- **Choose the trigger key and bring Super back** (Felipe, 2026-11-08): Super is not off limits, only its conflicts with Omarchy are. `docs/omarchy-key-map.md` (made by `tools/key-map.py`) maps which chords are taken. A `trigger_key` setting would make the pair (held key, trigger key) free to choose, checked against the live binds, so Super + a free key becomes possible without touching Omarchy's Super+Tab.
- **Icon theme and pack picker** (Felipe, 2026-11-09, PLANNED, proposed decision D28, research `research/theme-picker.md`). Icon theme and Icon pack are typed folder names today. Replace them with a separate page of the settings window: cards with sample app icons per choice, live preview on arrow keys, Enter chooses, Escape returns, filter box, choices read from the installed themes and the packs folder. Medium effort. Files: `lua/config.lua` (editor field, sample app list), `tools/gen-spec.lua` and spec.json (pass the sample list), new `tools/icon-themes.sh` and `tools/icon-preview.sh` (with shell tests), new `IconPickerPage.qml` and `IconChoiceCard.qml`, `SettingsPanel.qml` (page switch), `SettingRow.qml` (button, current value shown), docs `settings.md` and `icon-packs.md`.
- **Icon builder** (Felipe, 2026-11-09, PLANNED, proposed decision D29, design in `research/theme-picker.md`, section Builder design). Build an icon pack by clicking: see the apps, pick each one's icon from a search across all installed themes or from a file, preview in the real switcher row and card, undo or reset per app, Save as pack, Export or Import as a zip. Pack format unchanged. Builds on the picker. Slices: 1 picker (medium), 2a builder with search, draft and undo (medium to large), 2b Save as pack and Use it now (small to medium), 3 export and import glue plus a privacy test (small). New: `tools/icon-find.sh`, draft commands in `pack-edit.sh`, `IconBuilderPage.qml` and parts, `IconBuilder.js`; tests `icon_find`, `pack_draft`, `icon_builder`.
- **Reference icon pack** (Felipe, 2026-11-09, BUILT, shared test fixture for the picker and the builder). `packs/omahop-reference/`, 132 SVG icons from `tools/refpack/apps.tsv` through `gen.sh`, in the active Omarchy theme colours; documented in `icon-packs.md`, test `tests/refpack.test.sh`. Not enabled anywhere by default. Follows the running Omarchy theme (BUILT 2026-11-09): generic pack.toml keys `follows_theme` and `generator` (built-in generators only), regenerated into `~/.cache/omahop/themed-packs/` on a theme change, distinct hues per category, shade fallback for greyscale themes; test `tests/refpack_theme.test.sh`.
- **Icons in the Omarchy menu** (Felipe, 2026-11-09, PLANNED, proposed decision D30, research `research/launcher-icons.md`). Opt in setting `icons_in_launcher` (off) that also shows the chosen icon theme and pack in Super + Space (Apps list) and Super + Alt + Space (app grid), by writing an owned symlink folder `~/.local/share/icons/omahop-launcher/apps/` that the shell's icon index prefers; off deletes it. Slice after the builder (small to medium). New: a generator script with tests on fake desktop entries and a temp HOME, one row in `lua/config.lua` and spec.json, docs. Hand check on the real shell.
- **Icon packs** (Felipe, 2026-11-07): choose or build an icon pack in the settings window and override app icons. `IconResolve.js` is the one place icons are chosen, so a pack is one more layer in front of the system index. A pack is a folder with a small name-to-icon map (author, licence, version, preview) plus images. An editor in the settings window to make one (pick an app, pick an image), and export or import as one zip that holds data only: reject paths outside the pack and any file that is not an image or the map. Off by default, no new icons added. Step 1 (hand-made pack folders) shipped in v1.3; step 2 (zip export and import) in v1.4; step 3, the editor, is built on branch v1.5-pack-editor (D22). Not built from the spike: a `mine` override layer, aliases, preview images, image conversion.
- **Keep the list open while you search** (Felipe, 2026-11-07). Today the list closes when Alt is released. After you type, you should be able to let go of every key and keep searching without holding Alt. Proposed setting: `search_linger_seconds` (0 = off, which is today's behaviour; a number of seconds keeps the list open after Alt is released once a query has started). Design notes:
  - The countdown restarts on every key, so it only closes when you stop. Return picks the selected window, Escape cancels (first Escape clears the query), a click on a row picks it.
  - When the time runs out the list cancels, it does not pick: a wrong pick is worse than a closed list.
  - With Alt up, the typed keys must reach the list. Today the session binds only `ALT + key` chords. A linger session would also bind the bare letters, digits, Backspace, Return and Escape, again only while the list is open and only for chords that are free in the bind snapshot; the alternative is to give the overlay keyboard focus for those seconds. Pick one in a short spike before building (the bare-key binds would steal keys from the app for a few seconds, the focus route needs the layer-shell keyboard mode to work on every compositor setup).
  - No new widget: the remaining time can show as a thin line under the search chip. It is a setting in the settings window under "Look" or "General", with the default stated.
  - Tests: pure (timer logic, query rules), glue (fake `hl`), live (type, release all keys, wait less than the time, keep typing, press Return).
- **Search browser tabs** (Felipe, 2026-11-07; chosen route: a small browser extension). **Status 2026-11-08: v1.4 in progress**, spike GO (`research/tabs-spike.md`), omahop side built (D17, `file-contract.md`); the extension and helper live in the separate `omahop-tabs` repository, not here. Tab rows show while a search is typed. Today search sees only each window's title, which for a browser is the tab you are looking at, so a tab behind another tab cannot be found. Plan:
  - **Extension:** a small extension for Chromium browsers (Chrome, Chromium, Brave, Edge), later Firefox. It lists every tab (id, window, title, address, icon) and can activate a tab on request. It has no network access of its own and sends nothing anywhere except to the local omahop helper.
  - **Link to omahop:** the browser's native messaging, with a tiny helper program installed by the user that writes the tab list to a file under `$XDG_RUNTIME_DIR/omahop` and reads "activate tab N" requests. No open port, no start flag for the browser. The helper's manifest names only our extension id, so no other extension can talk to it.
  - **In omahop:** an opt-in setting (off by default, in the settings window) "Browser tabs". When on, each tab is a row or card under its window, search matches tab title and address, and Return focuses that window and activates that tab. Window matching: the browser window title carries the active tab, so match by window id sent by the extension and Hyprland's pid or class, and verify before building.
  - **Privacy:** tab titles and addresses are private. They stay in memory and the runtime folder (gone at logout), are never logged, and the README states it. The extension asks only for the `tabs` permission. A per-site ignore list belongs in the settings (banking pages etc).
  - **Rules kept:** nothing extra installed or running unless the user turns it on; no new widget by default; the extension and helper ship in this repository, separate from the plugin, with their own install and removal notes.
  - **Why not the debug port:** it needs a Chrome start flag and the open port gives any local program control of the browser; rejected as the default. It could still be a documented advanced option.
  - **First step:** a short spike on one browser: can the extension tell us which tab is active in which window, and can the helper switch tabs when the window is not focused?

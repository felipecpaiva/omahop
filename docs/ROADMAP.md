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
| v1.3 (IN PROGRESS, part B on branch v1.3-action-keys) | Keys for quick actions | `action_keys` (default empty): quit and minimize the selected window by key while the list is open |
| v1.2 (RELEASED 2026-11-07, tag v1.2.0, was planned as v1.1b; design in `research/linger-spike.md`) | Keep the list open while searching | `search_linger_seconds` (default 0): the overlay holds the keyboard while lingering, any character can be typed, Return picks, timeout and click outside cancel. Unit, glue, Node and live tests pass with one monitor; two monitors not measured |
| v1.3 (in progress; plan in `v1.1-plan.md`) | Modifier, keys | Part A built on a branch: `modifier` (`alt` default, `super`, `ctrl`; table in `lua/modifier.lua`, D16). Pure, config and glue tests pass; no live run yet, hand checks in `validation-checklist.md`. Still to come: quit and minimize by key, icon packs step 1 |

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

## After 1.0 (ideas, not scheduled)

- **Icon packs** (Felipe, 2026-11-07): choose or build an icon pack in the settings window and override app icons. `IconResolve.js` is the one place icons are chosen, so a pack is one more layer in front of the system index. A pack is a folder with a small name-to-icon map (author, licence, version, preview) plus images. An editor in the settings window to make one (pick an app, pick an image), and export or import as one zip that holds data only: reject paths outside the pack and any file that is not an image or the map. Off by default, no new icons added.
- **Keep the list open while you search** (Felipe, 2026-11-07). Today the list closes when Alt is released. After you type, you should be able to let go of every key and keep searching without holding Alt. Proposed setting: `search_linger_seconds` (0 = off, which is today's behaviour; a number of seconds keeps the list open after Alt is released once a query has started). Design notes:
  - The countdown restarts on every key, so it only closes when you stop. Return picks the selected window, Escape cancels (first Escape clears the query), a click on a row picks it.
  - When the time runs out the list cancels, it does not pick: a wrong pick is worse than a closed list.
  - With Alt up, the typed keys must reach the list. Today the session binds only `ALT + key` chords. A linger session would also bind the bare letters, digits, Backspace, Return and Escape, again only while the list is open and only for chords that are free in the bind snapshot; the alternative is to give the overlay keyboard focus for those seconds. Pick one in a short spike before building (the bare-key binds would steal keys from the app for a few seconds, the focus route needs the layer-shell keyboard mode to work on every compositor setup).
  - No new widget: the remaining time can show as a thin line under the search chip. It is a setting in the settings window under "Look" or "General", with the default stated.
  - Tests: pure (timer logic, query rules), glue (fake `hl`), live (type, release all keys, wait less than the time, keep typing, press Return).
- **Search browser tabs** (Felipe, 2026-11-07; chosen route: a small browser extension). Today search sees only each window's title, which for a browser is the tab you are looking at, so a tab behind another tab cannot be found. Plan:
  - **Extension:** a small extension for Chromium browsers (Chrome, Chromium, Brave, Edge), later Firefox. It lists every tab (id, window, title, address, icon) and can activate a tab on request. It has no network access of its own and sends nothing anywhere except to the local omahop helper.
  - **Link to omahop:** the browser's native messaging, with a tiny helper program installed by the user that writes the tab list to a file under `$XDG_RUNTIME_DIR/omahop` and reads "activate tab N" requests. No open port, no start flag for the browser. The helper's manifest names only our extension id, so no other extension can talk to it.
  - **In omahop:** an opt-in setting (off by default, in the settings window) "Browser tabs". When on, each tab is a row or card under its window, search matches tab title and address, and Return focuses that window and activates that tab. Window matching: the browser window title carries the active tab, so match by window id sent by the extension and Hyprland's pid or class, and verify before building.
  - **Privacy:** tab titles and addresses are private. They stay in memory and the runtime folder (gone at logout), are never logged, and the README states it. The extension asks only for the `tabs` permission. A per-site ignore list belongs in the settings (banking pages etc).
  - **Rules kept:** nothing extra installed or running unless the user turns it on; no new widget by default; the extension and helper ship in this repository, separate from the plugin, with their own install and removal notes.
  - **Why not the debug port:** it needs a Chrome start flag and the open port gives any local program control of the browser; rejected as the default. It could still be a documented advanced option.
  - **First step:** a short spike on one browser: can the extension tell us which tab is active in which window, and can the helper switch tabs when the window is not focused?

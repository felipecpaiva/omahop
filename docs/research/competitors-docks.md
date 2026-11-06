# Competitors: docks, taskbars and hover previews (omahop research)

Date of research: 2026-11-06. Public read only (gh API, raw GitHub files, local read of /usr/share/omarchy/shell/plugins/dock/). Nothing was run or installed.

Scope note. The brief says `catalog.json`; the marketplace repo has no such file, the listing is `registry.json` (13.8 MB, 6327 sources). Registry id `macos.dock` resolves to **ifubaraboye/omarchy-dock** (pluginIds in its security baseline). A near-identical code base is **hari45wavin/omarchy-mac-dock** (same file names and sizes, e.g. IconPickerPanel.qml 28789 B in both; neither is a GitHub fork, so which one is the origin is UNVERIFIED). Both are covered in one column, MACD. Last-commit dates come from the commits API where I fetched it, else from `pushed_at` (marked "pushed").

Column key: CORE = Omarchy stock dock (local copy plus upstream issues), ROSA = rosakodu/omarchy-dock (`rosakodu.dock`), OMAD = thepathless/omadock, MACD = macos.dock (ifubaraboye + hari45wavin), NICK = nick-friedrich/hyprland-dock, JOEY = joeyvigil/omarchy-taskbar, MARC = marcho78/omarchy-taskbar, HOGA = hogar1977/top-bar-dock, SPAC = tornikegomareli/omarchy-spaces (`tornikegomareli.spaces`).

Scoring caveat. These are docks, taskbars and a bar widget, not switchers. A row about the Alt+Tab switcher (F1 to F16) is mostly NO for them by design. Cells are YES / PARTIAL / NO / UNKNOWN. Evidence for each YES or PARTIAL is in the per-project sections below.

## 1. Coverage matrix

| Key | Feature | CORE | ROSA | OMAD | MACD | NICK | JOEY | MARC | HOGA | SPAC |
|---|---|---|---|---|---|---|---|---|---|---|
| F1 | hold-Alt switcher, release commits | NO | NO | NO | PARTIAL | NO | NO | NO | NO | NO |
| F2 | quick tap goes to previous window (MRU) | NO | NO | NO | UNKNOWN | NO | NO | NO | NO | NO |
| F3 | reveal delay (no flash on quick tap) | NO | NO | NO | UNKNOWN | NO | NO | NO | NO | NO |
| F4 | vertical list (icon, app name, title) | NO | NO | NO | NO | NO | NO | YES | NO | NO |
| F5 | horizontal cards style | NO | NO | PARTIAL | PARTIAL | NO | NO | PARTIAL | PARTIAL | NO |
| F6 | live window thumbnails | NO | NO | PARTIAL | YES | NO | NO | YES | YES | YES |
| F7 | thumbnail cost control (snapshot or off) | NO | NO | YES | PARTIAL | NO | NO | YES | PARTIAL | YES |
| F8 | keyboard nav (Tab, arrows, Esc, Enter) | PARTIAL | PARTIAL | PARTIAL | YES | NO | NO | NO | NO | UNKNOWN |
| F9 | mouse hover and click on entries | YES | YES | YES | YES | YES | YES | YES | YES | YES |
| F10 | type-to-search | PARTIAL | NO | NO | NO | PARTIAL | PARTIAL | NO | NO | NO |
| F11 | quick actions (close, minimize, quit) | YES | PARTIAL | YES | YES | PARTIAL | NO | YES | YES | UNKNOWN |
| F12 | floating-workspace-only scope | YES | PARTIAL | UNKNOWN | NO | NO | NO | NO | NO | NO |
| F13 | workspace filter (current / floating / all) | NO | UNKNOWN | UNKNOWN | NO | NO | NO | YES | UNKNOWN | NO |
| F14 | monitor filter (active / all) | UNKNOWN | UNKNOWN | YES | NO | UNKNOWN | UNKNOWN | YES | UNKNOWN | UNKNOWN |
| F15 | minimized / special-workspace windows | PARTIAL | YES | YES | PARTIAL | UNKNOWN | UNKNOWN | YES | PARTIAL | UNKNOWN |
| F16 | multi-monitor overlay | UNKNOWN | PARTIAL | YES | NO | PARTIAL | UNKNOWN | NO | UNKNOWN | NO |
| F17 | hover preview over dock/bar app icon | NO | PARTIAL | YES | YES | NO | PARTIAL | YES | YES | PARTIAL |
| F18 | provides its own dock or taskbar | YES | YES | YES | YES | YES | YES | YES | YES | PARTIAL |
| F19 | overview / expose grid | NO | NO | NO | NO | NO | NO | NO | NO | PARTIAL |
| F20 | follows Omarchy theme live | YES | YES | YES | YES | UNKNOWN | UNKNOWN | UNKNOWN | YES | YES |
| F21 | settings app (GUI) | NO | PARTIAL | YES | YES | NO | PARTIAL | YES | PARTIAL | YES |
| F22 | config file | YES | YES | PARTIAL | YES | YES | YES | PARTIAL | PARTIAL | YES |
| F23 | profiles (shortcuts with different settings) | NO | NO | PARTIAL | NO | NO | NO | NO | NO | NO |
| F24 | letter or number hints to jump | NO | NO | NO | NO | NO | NO | NO | NO | NO |
| F25 | per-app ignore and rules | UNKNOWN | UNKNOWN | PARTIAL | NO | NO | NO | NO | UNKNOWN | UNKNOWN |
| F26 | media or other widgets | NO | YES | PARTIAL | PARTIAL | NO | NO | NO | NO | YES |
| F27 | stock Alt+Tab fallback when out of scope | NO | NO | NO | NO | NO | NO | NO | NO | NO |
| F28 | performance controls | NO | UNKNOWN | YES | UNKNOWN | NO | NO | PARTIAL | PARTIAL | PARTIAL |
| F29 | automated tests present | PARTIAL | YES | YES | PARTIAL | NO | NO | NO | NO | YES |
| F30 | marketplace packaging | YES | YES | YES | YES | YES | YES | YES | YES | YES |

Reading the matrix. Nobody covers F1 to F3 as a real switcher; the closest is MACD (an app-level HUD). F24 (hints) and F27 (stock fallback) are empty for the whole group. F6, F17 and F7 are where this group is crowded.

## 2. The D8 question: how hover previews work and where the hover target lives

| Project | Hover target | Preview surface | Delay (show / hide) | Capture mode |
|---|---|---|---|---|
| MACD | its own dock icon (`Dock.qml` `requestPreviewForApp`) | separate full-screen `PanelWindow`, layer Overlay, input `mask: Region { item: previewContainer }` (`WindowPreviewPanel.qml`) | 220 ms / 320 ms grace (`previewDelayTimer`, `previewGraceTimer`) | `ScreencopyView live: true`, cached image or icon fallback |
| OMAD | its own dock icon | its own `PopupWindow` per tooltip, empty input mask (`components/TooltipWindow.qml`) | fade in, 200 ms linger on leave (README s11) | one still frame per card, at most 6 buffers (`WindowCardStack.qml` header comment) |
| HOGA | chip inside the stock Omarchy bar (bar-widget API) | card anchored to the chip (`top-bar-dock.qml` `previewAnchor`) | `previewDelay` 350 ms, a manifest setting | `ScreencopyView live: previewCard.open` |
| MARC | chip or dropdown row inside the bar | panel (`TaskbarPanel.qml`) | `previewShowTimer` (value not read) | `live: root.opened && row.showThumb` |
| SPAC | workspace pill in the bar | popup card anchored to the pill (`Spaces.qml:640-715`) | 380 ms show, 200 ms hide, 2500 ms for keyboard `peek` | `ScreencopyView live: cfg.previewLive`, `constraintSize` 2x the thumb |
| ROSA | its own dock icon | window title list, no thumbnails | not read | none |
| CORE | none | none (no `ScreencopyView` in the 5 local files) | n/a | n/a |

Findings for D8.

1. **Nobody puts a hover layer over the stock Omarchy dock.** Every project that previews either owns the icon strip (MACD, OMAD, ROSA, NICK, JOEY) or lives in the bar (HOGA, MARC, SPAC). So option 3 (hover layer over stock dock) has no precedent in the marketplace.
2. **The stock dock exposes no hook.** Upstream PR omacom/omarchy#16609 says it outright: "a plugin can't reach the dock, and a cloned dock gets neither the dock config nor the app library". That PR adds only a `menu` plugin takeover of the apps button; the payload carries the dock rect and the apps button rect, not per-app icon rects. So a hover layer would have to guess icon positions. UNVERIFIED whether the dock's icon rects can be derived reliably from `dock.size` and the app order.
3. **The dock is moving.** Open upstream PRs #17538 and #17575 (show dock on all layouts), #17339 (blink on reload), #17539 (app grid polish), issue #17644 (minimized windows not shown on the dock in 4.5.0-2). A layer that depends on dock geometry would be chasing a moving target. ROSA already hit this class of break: its #55 is a ReferenceError after a core refactor.
4. **Two proven surface patterns for own-strip.** Full-screen overlay with an input mask (MACD) is simple but costs VRAM; OMAD measured it: popup windows per tooltip cut dock VRAM "from 194 MiB to 26 MiB" (README s11). If omahop ever owns a strip, use per-tooltip popups.
5. **Cheapest honest path for omahop.** Keep F17 out of the first releases, ship the switcher. If F17 comes, either contribute a small upstream hook (an IPC or signal giving the hovered app id and its rect) or ship a hover popup that only reacts to an IPC call. This is a recommendation, not something I verified upstream would accept.

## 3. Per-project sections

### 3.1 CORE: Omarchy stock dock (`omarchy.dock`)
- Repo omacom/omarchy: 46375 stars, MIT, pushed 2026-11-06, 6237 open issues (whole monorepo, not dock-only). Local copy: manifest `omarchy.dock` v1.0.0, kind `service`, 5 files, 1765 lines.
- Evidence. F9 hover and click: `DockWindow.qml:331-341` (`hoverEnabled`, `containsMouse`), `AppGrid.qml:375`. F11: `Dock.qml:192` `toplevel.activate()`, `Dock.qml:219` `toplevel.close()`. F12: `DockWindow.qml` and `Dock.qml:280 isFloating(workspaceId)`; issue #16967 confirms visibility is tied to floating layout. F15 PARTIAL: `DockModel.js:35-48` knows `special:minimized` and sorts minimized windows after active ones; yet issue #17644 reports they do not show in 4.5.0-2. F8/F10 PARTIAL: `AppGrid.qml` has a search and a selection tile (#17539 text), but it lists apps, not windows. F18/F20/F22: part of Omarchy, `dock` section in `shell.json` (#17538 text). F29 PARTIAL: upstream PRs cite `test/shell.d/dock-test.sh` and `app-grid-test.sh`; not in the installed copy.
- Praise: nothing dock-specific read; 4.5 notes call minimize "to the dock" (#17644 body quotes it).
- Complaints (newest or most commented, all from the 7 given issues): #16967 want dock on all workspaces (0 comments); #17644 minimized windows missing (0); #17539 app grid polish PR (1); #17538 dock styling and all layouts PR (1); #17575 `dock.showOn all` PR (1); #17339 dock blinks on Hyprland reloads (1); #16609 launcher takeover PR (1). Also #16548 (Windows-style Alt+Tab with live thumbnails, MRU, all workspaces) is OPEN with 2 comments; it is the direct competitor to omahop itself.
- Licence MIT, copyable into MIT.
- HIGHLIGHTS. 1) Floating-scope awareness that matches Omarchy exactly. 2) Minimize-to-`special:minimized` model with restore to the workspace in front. 3) Zero-config, ships with the OS.
- GAPS vs omahop plan. No previews, no switcher, no hook for plugins, app grid not a window list.
- IMPLICATION. No course change for the switcher; but D8 option 1 (upstream hook) depends on a core that is changing weekly.

### 3.2 ROSA: rosakodu/omarchy-dock (`rosakodu.dock`)
- 54 stars, MIT, last commit 2026-11-06 (API), 18 open issues, listed 2026-08-15.
- Evidence. F9/F11 PARTIAL: README controls table (left click focus or restore, right click minimize, middle click new instance; no close verb found). F8 PARTIAL: README "Cycle Duplicates ... Arrow Keys", Enter, Tab, Escape. F15: right-click minimize to a special workspace, `scripts/dock-minimize.py`, `tests/test_dock_minimize.py`. F17 PARTIAL: README "Hover on App with 2+ windows lists windows by title and workspace", no `ScreencopyView` anywhere in the tree. F16: "draws a dock on every connected monitor". F12 PARTIAL: BarWidget "workspace targeting" (README, behaviour not read). F20: README "100% Native Theme Sync" (`Color.accent`). F21 PARTIAL: `BarWidget.qml` settings card. F22: README config section, `DockSettings.js`. F26: README "Integrated Dock Widgets" (weather, volume, bluetooth). F29: `tests/` with QML and Python tiers, `TEST_INFRA.md`.
- Praise: README claims (app stacks, wiggle edit mode, notification badges). Issue #22 thanks the author (a user asking how to pin closed apps).
- Complaints: #22 pinning apps that are not open (11 comments, a how-to); #21 mouse centred on left-click focus; #26 Chrome web app icons never resolve because the code reads `entry.exec` but Quickshell exposes `execString`; #56 want dock edge independent of bar; #55 ReferenceError, `minimizeRefreshTimer` moved; #54 dock does not follow the shell type scale.
- HIGHLIGHTS. 1) Feature breadth (folders, widgets, badges, edit mode). 2) Real test suite with Python plus QML tiers. 3) Multi-window handling: wheel-cycle duplicates and a title picker.
- GAPS vs omahop plan. No thumbnails, no Alt switcher, no search, no hold semantics.
- IMPLICATION. No change; its #21 (focus warps the mouse) and #26 (`execString`) are traps to test in omahop.

### 3.3 OMAD: thepathless/omadock
- 48 stars, MIT, last commit 2026-11-01, 1 open issue.
- Evidence. F6 PARTIAL and F7 YES: `components/WindowCardStack.qml` header (single frame per card, 6 buffers max, "closed tooltip holds no buffers") and README s"Window previews in tooltips" ("captured into GPU memory only while the tooltip is open, never written to disk. Turn them off in Settings"). F17: same README section, plus group tooltips. F5 PARTIAL: card stack in tooltip. F8 PARTIAL: `DockKeys.js` and README "Keybindings & IPC" (details not read). F11: `components/DockContextMenu.qml`, restore or close on minimized tiles. F14/F16: README "one dock per monitor, each showing its own monitor's windows". F15: README s2 "Minimized Preview Tiles" (`special:minimized`). F21: `components/SettingsPanel.qml`, `SettingsSearch.js`. F22 PARTIAL: saved settings and presets (storage format not read). F23 PARTIAL: `DockPresets.js` presets are look profiles, not shortcut profiles. F25 PARTIAL: per-app name fields and app groups (README s Labels). F26 PARTIAL: clock, drives, badges. F28: `tests/bench/` plus README "strictly 0.00% background CPU". F29: README "300 Node.js unit tests, 149 Python checks, sixteen sandboxed live Wayland integration suites"; `tests/{unit,live,bench,static}`.
- Praise: README claims (wave magnification, sponsors page); stars are modest.
- Complaints: only 1 open issue (not read in depth). Its own README notes crash lessons: `DockOutput.js` guards captures because "Hyprland aborts on a capture of a vanished output".
- HIGHLIGHTS. 1) Preview cost discipline (still frames, buffer cap, off switch, VRAM numbers). 2) Test culture: unit, live Wayland and benchmark harnesses. 3) Tooltip surface design: own popup, empty mask, no re-dwell between icons.
- GAPS vs omahop plan. No Alt switcher at all, no MRU, no search.
- IMPLICATION. Best template for omahop's F7 and its test plan (a live-Wayland suite exists and is MIT). No change of course; copy the idea of capped buffers and the output-awake guard.

### 3.4 MACD: macos.dock (ifubaraboye/omarchy-dock, and hari45wavin/omarchy-mac-dock)
- ifubaraboye: 16 stars, MIT, last commit 2026-10-27, 0 open (4 closed seen). hari45wavin: 1 star, MIT, last commit 2026-11-03, 8 open (all feature requests dated 2026-10-20). ifubaraboye listed 2026-08-18.
- Evidence. F1 PARTIAL, F8 YES, F9: `AltTabPanel.qml` header: Alt release activates, Escape cancels, Enter activates, arrows move, "hover to select, click to activate"; keys at lines 193-221. It is an app-level HUD opened by `omarchy-shell -q omarchy-mac-dock altTabNext` (README), with `p.open(running, 1)` selecting the second entry; the running list order (MRU or not) is not read, so F2 UNKNOWN; reveal delay not read, F3 UNKNOWN. F4/F5: flat row of equal icons, no titles, no cards (`AltTabPanel.qml` header). F6: `WindowPreview.qml` `ScreencopyView live: true`. F7 PARTIAL: cached image fallback and icon fallback (ifubaraboye `WindowPreview.qml:84-100`), but live capture is always on. F11: README context menu (Bring to Front, Minimize, Maximize, Quit) and the hover x on previews. F17: `Dock.qml:569-620` timers 220/320 ms. F20: `Commons.Color`. F21: `DockSettings.qml` (34 KB). F22: `~/.config/omarchy/mac-dock.json`. F29 PARTIAL: ifubaraboye has `tests/DockModel.test.js` (27 KB), IconResolver and helper tests; hari45wavin has none.
- Praise: README claims (magnification, launch bounce, icon picker from macosicons.com).
- Complaints: ifubaraboye #24 (closed) config reload from the plugin crashes Hyprland with SIGABRT when another plugin's `.so` is broken; #13 dock surfaces unmap and do not recover after monitor reconnect or sleep; #20 inotifywait watcher outlives the shell; #19 wrong icon (name-substring collision). hari45wavin open: #5 live hover thumbnails (already shipped, stale), #6 multi-monitor, #8 vertical dock, #4 drag reorder, #10 audio.
- Gotchas worth stealing. Hyprland delivers the Alt release as an unmapped keysym (Qt key 0); match scan code 64 or 108 (`AltTabPanel.qml:221-230`). It toggles `cursor.no_warps` around focus to avoid cursor warps (`Dock.qml:~630`).
- HIGHLIGHTS. 1) Only project with an Alt-release HUD. 2) Preview card with per-window close and activate without cursor warp. 3) Full icon picker and customizer.
- GAPS vs omahop plan. App-level not window-level, no titles, no MRU/reveal-delay evidence, no search, no workspace/monitor filter, no scope.
- IMPLICATION. Confirms demand for Alt+Tab on a dock plugin but its switcher is thin; omahop's F1 to F3 plus F4 stays a real differentiator. Avoid its config-reload approach (#24).

### 3.5 NICK: nick-friedrich/hyprland-dock
- 11 stars, MIT, pushed 2026-08-23, 0 open issues (1 closed: autohide).
- Evidence. F9/F11 PARTIAL/YES: README "Right-click actions to launch, close, pin, or unpin". F10 PARTIAL: README "Fuzzy application search for adding dock items" (apps, not windows). F16 PARTIAL: README "Multi-monitor support". F22: README "Live JSON configuration reload", `config/dock.json`. F18, F30: `manifest.json` kind `overlay`, listed in registry. No tests directory in the tree, no `ScreencopyView`.
- Praise: README claims only.
- Complaints: none open.
- HIGHLIGHTS. 1) Light footprint. 2) Live JSON reload. 3) Installer with no sudo.
- GAPS vs omahop plan. No previews, no switcher, no settings GUI, no tests.
- IMPLICATION. None; not a competitor on our keys.

### 3.6 JOEY: joeyvigil/omarchy-taskbar (`io.github.joeyvigil.taskbar`)
- 6 stars, MIT, pushed 2026-09-29, 0 open (1 closed: show all opened apps).
- Evidence. F9: README interaction table. F17 PARTIAL: "Hover: App name, plus window count" (no thumbnail). F10 PARTIAL: searchable app list for pinning (`bin/taskbar-pick`). F21 PARTIAL: pin, unpin from the bar, "No config file editing". F22: README Settings, stored inline in `shell.json` (`docs/configuration.md`). F18: pinned icons in the Omarchy bar. Click on a focused icon cycles to that app's next window (not MRU). No tests.
- Praise: README claims only.
- Complaints: closed #4 asked for running apps to show automatically (since fixed via `showRunningApps`).
- HIGHLIGHTS. 1) Pin from the bar itself. 2) Web-app identity matching. 3) Plain bar-widget packaging.
- GAPS vs omahop plan. No previews, no Alt switcher, no close action.
- IMPLICATION. None.

### 3.7 MARC: marcho78/omarchy-taskbar (`marcho78.taskbar`)
- 0 stars, MIT, pushed 2026-09-14, 0 issues.
- Evidence. F4/F6: README "Dropdown: ... a vertical list of all windows, each with a live thumbnail ... a visual window switcher" (`TaskbarPanel.qml:72-105`). F5 PARTIAL: Tabs style chips. F7: `TaskbarPanel.qml:99-100` `live: root.opened && row.showThumb`, plus "turn previews off, or resize them". F13/F14: README "Show windows from: Current workspace (default), This monitor, or All workspaces". F15: `special:taskbar-min`, origin workspace remembered (`Taskbar.qml:40-95`). F11: x and middle-click close, click focused chip to minimize. F17: hover chip shows live thumbnail (`Taskbar.qml:144-159`). F21: right-click options menu. F22 PARTIAL: `omarchy bar set` into `shell.json`. F28 PARTIAL: previews off or sized, collapse to icons past N windows. Scroll cycles focus (README "a quick alternative to Alt-Tab"); `cycleNext` and `cyclePrev` IPC, so there is no keyboard nav of a list (F8 NO). No tests.
- Praise: README claims only; zero stars.
- Complaints: none.
- HIGHLIGHTS. 1) Vertical thumbnail list as a switcher, the closest to omahop's F4 plus F6. 2) Scope option (workspace, monitor, all) is the closest to F13 and F14. 3) Security stance (absolute argv, no files, PlainText labels).
- GAPS vs omahop plan. No Alt-hold behaviour, no keyboard list nav, no MRU, no tests, no multi-monitor overlay.
- IMPLICATION. Validates the vertical-list-with-thumbnails look and the scope filter; its scope names are worth borrowing. No change of course.

### 3.8 HOGA: hogar1977/top-bar-dock (`io.github.hogar1977.top-bar-dock`)
- 2 stars, MIT with "Portions Copyright anelcelik, OmaHarbor" (the OmaHarbor licence was not checked, so copy only after checking it), pushed 2026-09-29, 0 issues.
- Evidence. F6/F17: README "hover shows live thumbnail previews", `top-bar-dock.qml:533,657` `ScreencopyView`; multi-tile grid per app (README "Improvements over OmaHarbor" 2). F5 PARTIAL: preview tile grid. F7 PARTIAL: `live: previewCard.open`, `previewDelay` default 350 ms in `manifest.json:22-36` (hover delay, not Alt reveal delay). F11: README right-click actions (new instance, pin, maximize, minimize, close, close all). F15 PARTIAL: "dim minimized windows" (README). F20: README "inherits your theme automatically". F21/F22 PARTIAL: manifest `schema` (maxTitleLength, previewDelay) rendered by the bar's settings panel. F28 PARTIAL: `previewDelay`. No tests (only `test/fixtures.md`).
- Praise: README claims (web-app and Steam identity engine).
- Complaints: none.
- HIGHLIGHTS. 1) Preview inside the stock bar with no own surface. 2) Window grouping per app with a tile grid. 3) Identity scoring for web apps and Steam games.
- GAPS vs omahop plan. No switcher, no keyboard, no tests, no scope filter.
- IMPLICATION. Shows a hover preview can live in a bar widget; relevant only if omahop chooses a bar anchor for D8.

### 3.9 SPAC: tornikegomareli/omarchy-spaces (`tornikegomareli.spaces`)
- 222 stars (highest of the plugin group), MIT, last commit 2026-10-26, 9 open issues.
- Evidence. F6/F17 PARTIAL: README "Hover another workspace to see it live, laid out the way it is on screen. Click a window in the preview to jump to it." `Spaces.qml:1447-1453`: `ScreencopyView captureSource: thumb.win.toplevel; live: root.cfg.previewLive; constraintSize: 2x thumb size`. F7: `previewLive` setting plus `constraintSize` (capture size capped to the thumb). F19 PARTIAL: workspace-level layout preview, not an all-windows grid. F9: click a window in the preview. F18 PARTIAL: per-workspace app icons in the bar. F20: `Color`, `Util.alpha` tokens. F21: `SpacesSettings.qml`, sections "App icons, Windows, Appearance, Workspaces, Previews, Behaviour" (README). F22: `~/.config/omarchy/shell.json`. F26: agent badges for Claude Code, Cursor, opencode (`hooks/`). F29: `tests/model.test.js` (34 KB), QML tests, hook tests. F24 NO: but `peek(id)` opens a preview from a key or script (`Spaces.qml:~700`), a useful pattern.
- Praise: 222 stars; README claim that previews follow monitor orientation and shrink to fit. No issue thanks found.
- Complaints (open, by comments): #2 per-monitor workspaces on multiple displays (1 comment); #41 show layout of the active workspace; #38 opt out of the plugin moving the pointer on click; #37 hide native spaces from the bar; #36 denser icon spacing.
- HIGHLIGHTS. 1) Best-liked preview in the group (live, anchored, sized to the monitor). 2) Complete settings app with seven sections. 3) Serious model tests (`Model.js` with 34 KB of tests).
- GAPS vs omahop plan. Not an Alt switcher; no MRU, no keyboard list, no search, no quick actions found.
- IMPLICATION. The social proof is for previews that fit a bar and have a settings GUI, not for window switching. Its complaint #38 (pointer moves on click) matches omahop's no-warp need.

## 4. What this group tells omahop

1. Nobody ships the hold-Alt, release-commits, MRU switcher with a reveal delay (F1 to F3). MACD is the only attempt and it is app-level. This is open ground, but the core PR #16548 is the real competitor.
2. Hover previews (F17) are a crowded feature: 5 of 9 columns have them. Do not make it the headline; D8 stays open and low priority.
3. D8: no project hovers over the stock dock, and the dock has no hook (#16609). Own strip or bar anchor are the only proven patterns; for omahop a hover layer over the stock dock is the riskiest option.
4. The vertical thumbnail list exists in MARC and the scope filter exists there too; omahop's F4 plus F13/F14 are validated but not unique.
5. Cost control (F7) is solved well by OMAD (still frames, buffer cap, off switch) and SPAC (`previewLive`, `constraintSize`). Copy the idea, MIT allows it.
6. Settings GUI plus theme-live (F20, F21) are table stakes: OMAD, MACD, SPAC and MARC all have one.
7. Crash lessons to design in: Alt release arrives as scan code 64/108 (MACD), captures on a vanished output abort Hyprland (OMAD), never trigger a config reload (MACD #24), surfaces must survive monitor reconnect (MACD #13), do not warp the pointer (ROSA #21, SPAC #38).
8. F24 (hints) and F27 (stock fallback) are empty everywhere: low evidence of demand, keep them late in the roadmap.
9. Course shift needed? No, with one change: keep F17 below the switcher in the roadmap and do not depend on dock geometry.
10. Unverified here: whether the stock dock's icon rects can be derived, what MACD's switcher orders by, and the OMAD, ROSA open-issue contents beyond titles.

# Competitor research: overview / expose / window-gallery group

Research date 2026-11-06. Public read only (gh api, raw READMEs, source trees). Nothing installed or run.
Marketplace catalog note: `catalog.json` does not exist in `omacom/omarchy-plugin-marketplace`; the catalog is `registry.json` (13 MB, `sources[]` list of repos). All 9 Omarchy plugins below were found there (addedAt Aug-Sep 2026).

Legend: Y = YES, P = PARTIAL, N = NO, U = UNKNOWN. N means absent from README, docs and the files I read (not a full source audit). U means I could not tell.
Stars/issues are as of 2026-11-06. "Last commit" is the default-branch head. Issue counts are real issues, PRs counted separately.

Columns: EXP kristofferR/omarchy-expose, MIR sanjyay/Mirador, STG zzwong/omarchy-stage, BEY harel/omarchy-birdseye, PAN aastrand/omarchy-panorama, FWP falser101/falser-window-preview, WMN nahuelvara/omarchy-windows-menu, MOO itsmoorgrove/omarchy-overview, GAL LosokosG/omarchy-window-gallery ("Better Alt-Tab", added because it is the closest competitor), HSH H3rmt/hyprshell, E4 end-4/dots-hyprland, CAE caelestia-dots/shell.

## 1. Coverage matrix

| Key | EXP | MIR | STG | BEY | PAN | FWP | WMN | MOO | GAL | HSH | E4 | CAE |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F1 hold-Alt, release commits | N | Y | Y | N | N | N | N | N | P | Y | N | N |
| F2 quick tap = previous (MRU) | N | N | N | N | N | N | N | N | Y | Y | N | N |
| F3 reveal delay | N | U | N | N | N | N | N | N | U | U | N | N |
| F4 vertical list | N | N | N | N | N | N | P | N | N | U | N | N |
| F5 horizontal cards | N | P | P | N | N | N | N | N | P | P | N | N |
| F6 live thumbnails | Y | Y | Y | P | Y | P | P | Y | P | N | Y | P |
| F7 thumbnail cost control | P | P | U | P | P | P | P | Y | Y | N | P | U |
| F8 keyboard nav | Y | Y | Y | Y | Y | Y | N | Y | Y | P | U | U |
| F9 mouse hover+click | Y | Y | Y | Y | Y | P | P | Y | P | Y | Y | N |
| F10 type-to-search | Y | N | N | Y | N | Y | N | Y | Y | P | P | N |
| F11 quick actions | P | P | P | P | N | P | N | P | N | P | P | N |
| F12 floating-only scope | N | N | N | N | N | N | N | N | N | N | N | N |
| F13 workspace filter | Y | N | N | N | Y | P | N | N | U | Y | N | N |
| F14 monitor filter | Y | N | P | N | P | U | N | P | U | Y | P | N |
| F15 minimized/special | U | Y | N | U | U | Y | P | Y | U | U | U | P |
| F16 multi-monitor overlay | Y | P | N | Y | P | U | N | Y | U | N | P | N |
| F17 hover preview on dock/bar icon | N | N | N | N | N | N | P | N | N | N | Y | N |
| F18 own dock/taskbar | N | N | N | N | N | N | P | N | N | N | Y | P |
| F19 overview/expose grid | Y | Y | Y | Y | Y | Y | P | Y | P | Y | Y | N |
| F20 follows Omarchy theme | Y | U | Y | Y | Y | P | U | U | Y | P | P | P |
| F21 settings GUI | Y | N | N | P | Y | P | N | Y | N | Y | Y | Y |
| F22 config file | P | Y | Y | Y | P | P | N | P | N | Y | Y | Y |
| F23 profiles | N | P | N | N | P | N | N | N | N | P | N | N |
| F24 letter/number hints | N | P | P | N | N | P | N | P | N | N | N | N |
| F25 per-app ignore/rules | U | N | N | N | P | N | N | N | N | P | N | N |
| F26 media/other widgets | N | N | P | N | N | N | N | N | P | Y | Y | Y |
| F27 stock Alt+Tab fallback | N | N | N | N | N | N | N | N | N | N | N | N |
| F28 performance controls | P | P | U | P | P | N | N | Y | Y | P | U | U |
| F29 automated tests | Y | Y | Y | N | N | N | N | P | N | P | N | U |
| F30 marketplace packaging | Y | Y | Y | Y | Y | Y | Y | Y | Y | N | N | N |

Row notes (evidence for every Y/P is in the per-project sections):
- F27 is N for everyone: no project hands Alt+Tab back to stock when out of scope. MIR and GAL both document the opposite (removing the plugin leaves the stock bind unbound or needs a manual remove step).
- F12 is N for everyone: nobody scopes to floating workspaces. That is omahop's unique axis.

## 2. Per-project sections

### EXP kristofferR/omarchy-expose (MIT, may be copied into MIT with notice)
Stars 43. Last commit 2026-10-26. Open: 1 issue, 6 PRs. Marketplace listed (addedAt 2026-08-23). Forked from BEY.
Evidence: https://github.com/kristofferR/omarchy-expose (README, `manifest.json`, `tests/`, `Overview.qml`, `WindowCard.qml`: `live: card.controller.opened && card.inLayout`).
- Praise: README claims live cards, Quick Look (Space), search, Tab toggles all/current workspace, hot corner, "adds no packages, services, or daemons". Only open issue (#37) is a thank-you: "careful, well-tested plugin", forked into Panorama.
- Complaints: none open. Setup friction: you must edit `input.lua` to stop workspace swipes moving the desktop behind it.
- Matrix evidence: F8/F9 Controls table; F10 "Just start typing"; F13 Tab scope + "Opens with" setting; F14 "This display / All displays"; F16 "Every display blurs and dims"; F21 built-in Settings panel + 1-6 section keys; F22 inline entry in `~/.config/omarchy/shell.json`; F29 `tests/tst_*.qml`, `tests/check-*`; F28 only partial (live only while open, blur 0-20, animation controls).
HIGHLIGHTS
1. Most polished settings and IPC surface in the group (settings panel plus `omarchy-shell expose <key> <value>` for every option).
2. Per-monitor and workspace-scope handling, including the activation delay on the hot corner.
3. Quality bar: QML tests, theme tests, blur-lock check, PR model check in CI.
GAPS vs omahop plan: no Alt-hold switcher, no MRU, no list style, no floating scope, no hover over a dock. It is a toggle overlay, not a switcher.
IMPLICATION: No course change. Copy its ideas for the settings panel and the test layout; the grid expose is a different product.

### MIR sanjyay/Mirador (MIT)
Stars 40. Last commit 2026-10-21. Open: 0 issues, 18 PRs (all by the owner, a public roadmap). Marketplace listed (2026-08-10). v2.4.0.
Evidence: https://github.com/sanjyay/Mirador (README bindings block, `CompactCycleView.qml`, `CarouselCycleView.qml`, `WorkspaceOverview.qml`, `settings.example.json`, `docs/architecture.md`, `tests/`).
- Praise: README claims spatial previews, drag to move windows between workspaces, carousel, rapid-tap commit "deterministically even on instant taps (0ms hold)", named and special workspace cycling.
- Complaints: no open issues. The 18 PRs signal what the author sees as missing: window search (#55), close buttons (#62), recently-used cycling (#61), previews on every monitor (#59), settings panel (#68), setup diagnostics (#65). Install needs a very long Lua block with many `hl.unbind` calls; uninstall warning admits it leaves `SUPER+TAB` unbound.
- Matrix evidence: F1 `ALT + TAB` binding "release Alt to select"; F5 carousel; F7 `liveCaptureEnabled` flag; F15 scratchpad cycling (2.3.2 notes); F23 per-binding JSON payload (`cycleUI`, `modifier`, `keybindMode`).
HIGHLIGHTS
1. Hold-modifier cycle that handles instant taps (the exact race omahop's reveal delay must solve). It detects modifier release by polling `hyprctl repl` (see `modifierCheckQuery`).
2. Several cycle UIs (`compact`, `carousel`, `full`) selectable per binding, close to omahop's list vs cards styles.
3. Fast feature cadence plus tests for geometry, physics and security of titles.
GAPS vs omahop plan: cycles workspaces, not a window MRU; no search; no floating scope; no theme claim; no fallback to stock keys.
IMPLICATION: Watch closely, no course change. It proves hold-release plus a compact cycle UI is feasible in a plugin and shows its 18 PRs are the competitor roadmap (MRU, search, close). If it merges window MRU it becomes a direct competitor.

### STG zzwong/omarchy-stage (MIT)
Stars 10. Last commit 2026-10-19. Open: 1 issue, 0 PRs. Marketplace listed (2026-08-27).
Evidence: https://github.com/zzwong/omarchy-stage (README, `docs/configuration.md` "Hold-to-cycle", `Stage.qml`: skips `ws.id <= 0`, `tests/*.test.cjs`).
- Praise: "Mission Control for Omarchy"; media-control pills under the carousel; CHANGELOG, lint CI, marketplace badge.
- Complaints: #7 install timed out (`omarchy-shell is not responding`); maintainer pointed to upstream Omarchy issue about plugin rebuild exceeding the 2 s IPC timeout. Not a Stage bug, but every plugin hits it.
- Matrix evidence: F1 `keybindMode: "cycle"` (hold Super, release jumps, disarms after 10 s idle); F5 `style: cards`; F24 `1-9` jump to workspace; F26 media pills; F15 N because special workspaces skipped.
HIGHLIGHTS
1. Hold-to-cycle with a documented safety (disarm after 10 s, editing or dragging disarms).
2. Window actions: drag to move, X to close, Shift+arrow swap tiled windows, Ctrl-Shift move to neighbour workspace.
3. Small clean config (`style`, `view`, `badgeStyle`, `keybindMode`) re-read on each open.
GAPS vs omahop plan: workspace-level, focused monitor only, no search, no MRU, no list.
IMPLICATION: No course change. Borrow the "disarm after idle" guard for hold-release logic.

### BEY harel/omarchy-birdseye (MIT)
Stars 3. Last commit 2026-09-03. Open: 0. Marketplace listed (2026-08-22). Original of EXP.
Evidence: https://github.com/harel/omarchy-birdseye (README, `Overview.qml`: `live: false`, `config.example.json`). 9 files, no tests.
- Praise: README feature list (thumbnails on every monitor, type-to-filter, two-click close confirmation, theme fallback when capture fails).
- Complaints: none filed. README itself notes workspace shows an em-dash for short-lived or duplicate title/class windows (matches windows by `hyprctl clients -j`).
HIGHLIGHTS
1. Two-click auto-expiring close confirmation (1.6 s), a good quick-action safety pattern.
2. Config minimal: `backgroundMode` (workspace snapshot or wallpaper) and `blurStrength`.
3. Grid on every connected monitor.
GAPS vs omahop plan: everything switcher-related; no tests; snapshots only.
IMPLICATION: No course change. Reuse the confirm-to-close pattern for F11.

### PAN aastrand/omarchy-panorama (MIT)
Stars 0. Last commit 2026-09-02. Open: 1 issue, 1 PR. Marketplace listed (2026-08-22). README says it forks EXP ideas; the EXP thank-you issue links a different repo (igouss/omarchy-panorama), so there are two "Panorama" projects (unverified which is which).
Evidence: https://github.com/aastrand/omarchy-panorama (README, `Overlay.qml`, `SettingsCard.qml`, `WindowTile.qml`: `live: root.overlayOpen && captureSource !== null`).
- Praise: README claims "two QML files", no network, no binaries, no files written, hides tray and helper windows, `all` vs `current` scope passed on the bind.
- Complaints: #1 tiles follow model order (focus history), not screen position, so side-by-side windows look swapped.
HIGHLIGHTS
1. Scope as a bind argument (`summon ... all|current`): cheap profile mechanism.
2. Auto-excludes helper and tray windows (a baseline for F25).
3. Tiny footprint with a separate settings view.
GAPS vs omahop plan: no switcher, no search, no tests.
IMPLICATION: No course change. The #1 complaint (layout order vs spatial order) is a reminder to sort list entries deliberately.

### FWP falser101/falser-window-preview (MIT)
Stars 2. Last commit 2026-09-07. Open: 1 issue, 1 PR. Marketplace listed (2026-09-01).
Evidence: https://github.com/falser101/falser-window-preview (README, `WindowCard.qml`: `live: false`, `WorkspaceStrip.qml`).
- Praise: "KDE Overview style"; workspace strip on top; special workspaces get their own chip; hot corner; type filter; Shift+Q close.
- Complaints: #3 Wayland fatal error ("Invalid argument") and GBM buffer teardown when another screencopy runs (hyprpicker or `omarchy-capture-text` screen freeze). Important: capture can break other tools or crash the shell.
HIGHLIGHTS
1. Special workspaces handled (scratchpad chip).
2. Workspace strip plus keys `1-9`, `Tab`, `PgUp/PgDn`.
3. Single-frame (non-live) capture.
GAPS vs omahop plan: current workspace only, no tests, no monitor logic.
IMPLICATION: No course change, but #3 is a risk flag: any capture-based thumbnail feature (F6) needs a safe "off" path (F7) because capture conflicts crash the plugin or shell.

### WMN nahuelvara/omarchy-windows-menu (MIT)
Stars 0. Last commit 2026-09-27. Open: 0. Marketplace listed (2026-09-04).
Evidence: https://github.com/nahuelvara/omarchy-windows-menu (README, `Panel.qml`, `bin/capture_toplevel.py`, `bin/capture-thumbnails.sh`).
- Praise: README claims fills the gap left by the stock workspace dots: every window grouped by workspace with thumbnails, no `hyprctl` shelling for the list, works with minimized windows.
- Complaints: none filed. Design cost: needs `python-pywayland` and `python-pillow`, spawns a capture process per window per open, writes screenshot files to `~/.cache`, and retries images for about 4 s.
HIGHLIGHTS
1. List style with thumbnail, app name and title (closest to omahop F4), with web-app name resolution from `.desktop` `Exec`.
2. Bar-widget entry point (opens as a dropdown from the bar).
3. Degrades cleanly to a text list when thumbnail deps are missing.
GAPS vs omahop plan: no keyboard nav, no hold-switch, no search, no tests; click-only.
IMPLICATION: No course change. Reuse its app-name and web-app title cleanup logic idea for the list rows; do not copy the external-process thumbnail design (heavy, leaves screenshots on disk).

### MOO itsmoorgrove/omarchy-overview (MIT)
Stars 2. Last commit 2026-10-06. Open: 0 issues, 1 PR. Marketplace listed (2026-08-29).
Evidence: https://github.com/itsmoorgrove/omarchy-overview (README, `SettingsSheet.qml`: previews `live` or `icons`, `bin/omarchy-overview-bindings-*`, `tests/settings.cjs`).
- Praise: README claims ships unbound, GUI settings, bar icon, drag to move, `/` filter, hardened bindings-file writer (`O_NOFOLLOW`, atomic rename).
- Complaints: none filed. Writes your `bindings.lua` when you press Apply (managed block), more invasive than the others.
HIGHLIGHTS
1. Live vs icons preview switch (a real F7).
2. In-app keybind picker that names the bind it will unbind first.
3. Security-hardened file access helpers.
GAPS vs omahop plan: no hold switcher, no MRU, tests minimal.
IMPLICATION: No course change. Copy the "live or icons" toggle and the conflict-naming keybind UI.

### GAL LosokosG/omarchy-window-gallery, "Better Alt-Tab" (MIT)
Stars 1. Last commit 2026-09-16. Open: 0. Marketplace listed. Not on your name list but it is the nearest direct competitor to omahop.
Evidence: https://github.com/LosokosG/omarchy-window-gallery (README "Usage", "Performance", `Gallery.qml`: `live: false`, `docs/design.md`).
- Praise: README claims Alt+Tab opens and steps; MRU order with selection starting on the previous window ("`ALT+TAB`, `Enter` is go back"); type to filter; `playing`/`fullscreen`/`tab` keywords; measured 19 captures cost about 12 KB, 23-57 ms; nothing running while closed; theme tokens only.
- Complaints: none filed. Writes its Alt+Tab bind into `bindings.lua` on first load; optional Firefox tab bridge needs an extension and native host.
HIGHLIGHTS
1. MRU with previous-window pre-selected (our F2) plus search.
2. Documented, measured performance and snapshot capture (`live: false`).
3. Browser tabs as entries (novel).
GAPS vs omahop plan: README does not say release commits (Enter or click); no reveal delay; no list style; no floating scope; no settings or config; no tests; no stock fallback.
IMPLICATION: Closest overlap on F1/F2/F6/F10. Differentiate on release-commit, floating scope, hover on dock icons and stock fallback; do not compete on gallery grids.

### HSH H3rmt/hyprshell (MIT, Rust; code may be copied into MIT with notice)
Stars 601. Last commit on release branch 2026-06-10 (other branches pushed up to 2026-11-06). Open: 23 issues, 21 PRs. Not Omarchy-aware (GTK4, own daemon, `config.ron`, own themes).
Evidence: https://github.com/H3rmt/hyprshell (README, `docs/CONFIGURE.md`, `crates/config-lib/src/structs.rs`: `Switch{modifier,key,filter_by_*,switch_workspaces,exclude_workspaces,kill_key}`, `.github/workflows/test.yml`).
- Praise: README claims switch mode sorted by recent access, launcher plugins, settings editor, hot-reload config, CLI check/explain, Nix module. 601 stars. Contributor sim590 is building live thumbnails as an external contribution.
- Complaints (top issues): #26 live thumbnails (16 comments, "help wanted", oldest and most requested); #477 live thumbnails with text filter and hint selection (13); #424 live window preview (8); #498 workspace switching fails on Hyprland 0.55; #346 cannot close overview with Escape or clicking outside. Newest: #533 Alt+Tab broke on Hyprland 0.57; #526 keybinds re-registered on every monitor hotplug without unbinding, so Alt+Tab advances N windows per press; #527 option to show the switcher on all monitors.
- Matrix evidence: F1/F2 "Switch ... sorted by their most recent access ... letting go closes it"; F13/F14 `filter_by_current_workspace`, `filter_by_current_monitor`; F21 `hyprshell config edit`; F23 separate `switch` and `overview` blocks; F25 `exclude_workspaces`, `same_class`; F26 launcher plugins (calc, web search, actions); F11 `kill_key`.
HIGHLIGHTS
1. The reference hold-Alt switcher: MRU, workspace and monitor filters, kill key, config reload without restart.
2. Config validation tooling (`config check`, `config explain`) and a GUI settings editor.
3. Launcher plugins plus clipboard history (a full shell, not just a switcher).
GAPS vs omahop plan: no live thumbnails today (its most requested feature), no floating scope, no Omarchy theme or marketplace packaging, no stock fallback, no multi-monitor overlay (#527). Its own daemon and bind lifecycle bugs (#526, #533) show fragility across Hyprland versions.
IMPLICATION: Validates the plan. Users want live thumbnails and hold-switcher together; hyprshell lacks the first and Omarchy plugins mostly lack the second. Re-register-binds-on-hotplug (#526) is a trap omahop must avoid.

### E4 end-4/dots-hyprland (GPL-3.0: ideas only, do not copy code)
Stars 16545. Last commit 2026-10-11. Open: 473 issues, 247 PRs. Full dotfiles (Quickshell "ii"), not a plugin.
Evidence: https://github.com/end-4/dots-hyprland, `dots/.config/quickshell/ii/modules/ii/overview/{Overview,OverviewWidget,OverviewWindow,SearchBar}.qml`, `.../dock/{Dock,DockApps,DockAppButton}.qml`, `.../modules/settings/*Config.qml`.
- Praise: 16.5k stars; overview with live `ScreencopyView` (`live: true`, only while overview open), drag windows between workspaces; dock with a hover preview popup (max 300x200) per app, close and activate buttons per window.
- Complaints: top issues are install packaging (#1061 Guix/Nix, 73 comments) and a Windows-style variant (#2342). Newest are Super-tap bugs: #3728 "Super tap opens search after any Super combo" and #3752 "Overview triggers after long press of super", both on Hyprland 0.57. This is the exact tap-vs-hold problem behind omahop's reveal delay.
- Matrix evidence: F17/F18 dock plus `previewPopup` in `DockApps.qml`; F19 `Overview.qml`; F21 `modules/settings/`; F22 `Config.qml`.
HIGHLIGHTS
1. The only project here with hover preview over a dock icon (F17), with window close inside the popup.
2. Live capture bound to open state (`captureSource` null when closed): cost control by design.
3. Whole-shell polish (settings app, theming, widgets).
GAPS vs omahop plan: no Alt switcher, no Omarchy integration, no tests found, GPL.
IMPLICATION: F17 is rare and valued; it supports keeping hover-over-dock in the plan, but the dock is a whole shell. Ideas only; reimplement independently.

### CAE caelestia-dots/shell (GPL-3.0: ideas only)
Stars 13263. Last commit 2026-11-02. Open: 153 issues, 139 PRs. Quickshell shell with C++ plugin.
Evidence: https://github.com/caelestia-dots/shell, `modules/windowinfo/Preview.qml` (`ScreencopyView` `live: true`), `modules/bar/components/workspaces/SpecialWorkspaces.qml`, `modules/nexus/` (settings), `modules/launcher/`.
- Praise: 13k stars; launcher, sidebar, lock, settings pages. I found no Alt-switcher or overview module.
- Complaints: top issues are greeter, wallpaper behaviours, calendar; newest are visual bugs (#2261 duplicated special workspace icons, #2263 visualiser gaps).
HIGHLIGHTS
1. Complete shell with GUI settings pages (`nexus`).
2. Live window preview panel for the active window (`windowinfo`).
3. Special workspace display in the bar.
GAPS vs omahop plan: no switcher or grid overview; not Omarchy.
IMPLICATION: No course change; irrelevant to switcher scope.

## 3. What this group tells omahop

1. Overview grids are crowded: 8 Omarchy overview plugins in 3 months, mostly 0-3 stars. Only EXP (43) and MIR (40) have traction; do not build another grid.
2. The wedge is the switcher: only HSH (not Omarchy) and MIR/STG (workspace-level) do hold-then-release; only GAL and HSH do MRU previous-window. Nobody combines hold-release + MRU + live thumbnails + Omarchy theme.
3. HSH's most-requested feature (#26, 16 comments) is live thumbnails; the Omarchy plugins deliver them but not the hold-switch. Keep both in the plan.
4. Nobody has floating-only scope (F12) or a stock Alt+Tab fallback (F27). Both are free differentiators, not validated demand.
5. Hover preview over a dock or bar icon (F17) exists only in end-4's own dock (GPL). Real but costly; treat as stretch.
6. Cost control is under-served: only MOO (live/icons) and GAL (snapshot, measured) offer it; FWP #3 shows capture can crash with other screencopy tools. Keep F7 as a hard requirement.
7. Tap-vs-hold bugs are live everywhere (E4 #3728/#3752, MIR instant-tap fix, HSH #526 hotplug binds); the reveal delay and bind lifecycle deserve tests.
8. Test culture is thin: only EXP, MIR, STG ship real tests. Tests are a cheap quality edge.
9. Licence: all Omarchy plugins and HSH are MIT (can be reused with notice); E4 and CAE are GPL-3.0 (ideas only).
10. Course change: none. Move MIR's 18 open PRs (window MRU, search, close) onto a watchlist; it is the competitor most likely to converge.

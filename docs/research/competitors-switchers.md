# Omarchy Alt+Tab switchers vs omahop plan

Research date 2026-11-06. Public read only (gh API, raw files). Nothing was run or installed.
Evidence is README text or source files in the repos named in each section (QML/JS read directly).
Marketplace: all 10 repos are listed in `omacom/omarchy-plugin-marketplace` `registry.json` (there is no `catalog.json`; the file is `registry.json`, `sources[].repo`). The listed `catalog` objects were not inspected for ids, so the id `vbrosseau.alttab` is taken from the c4software README.
Legend: Y = YES, P = PARTIAL, N = NO, ? = UNKNOWN (not verified).

Column key: CORE = omacom/omarchy PR #16548 (author rndaom); ALT = c4software/hyprland-alttab; ASW = Pablo-Merino/omarchy-altswitch; OMA = piyush97/omaswitch; SLC = m4rone/omarchy-slicetab; SWR = gabrielvincent/omarchy-switcharoo; XAD = xadacka/omarchy-window-switcher; LUW = luwojtaszek/omarchy-alt-tab; QS = ewweberlin/QuickSwitch; OMT = Codesmith28/omalt-tab; GAL = LosokosG/omarchy-window-gallery.

## 1. Coverage matrix

| Key | Feature | CORE | ALT | ASW | OMA | SLC | SWR | XAD | LUW | QS | OMT | GAL |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F1 | hold-Alt, release commits | Y | Y | Y | ? | Y | Y | N | Y | Y | Y | ? |
| F2 | quick tap = previous (MRU) | Y | ? | Y | Y | Y | ? | N | Y | Y | P | P |
| F3 | reveal delay | Y | ? | ? | ? | Y | ? | N | Y | Y | ? | ? |
| F4 | vertical list style | N | N | P | Y | N | N | P | Y | N | N | N |
| F5 | horizontal cards style | Y | Y | N | N | Y | P | N | N | Y | P | P |
| F6 | live thumbnails | Y | P | N | P | P | N | N | N | P | N | P |
| F7 | thumbnail cost control | N | Y | N | P | P | N | N | N | P | N | Y |
| F8 | keyboard nav | Y | Y | P | Y | P | Y | P | Y | Y | Y | Y |
| F9 | mouse hover and click | Y | Y | N | Y | P | Y | N | ? | Y | Y | Y |
| F10 | type-to-search | N | N | N | Y | N | N | Y | Y | N | N | Y |
| F11 | quick actions | P | P | N | N | N | Y | N | N | P | N | N |
| F12 | floating-workspace scope | N | N | N | N | N | N | N | N | N | N | N |
| F13 | workspace filter | N | N | N | N | P | Y | N | Y | N | N | N |
| F14 | monitor filter | N | N | N | N | N | Y | N | N | N | N | N |
| F15 | minimized / special | Y | N | N | ? | P | Y | ? | N | N | ? | ? |
| F16 | multi-monitor overlay | N | N | ? | ? | N | ? | ? | ? | ? | N | N |
| F17 | hover preview on dock icon | N | N | N | N | N | N | N | N | N | N | N |
| F18 | own dock / taskbar | N | N | N | N | N | N | N | N | N | N | N |
| F19 | overview / expose grid | N | N | N | N | N | P | N | N | N | P | P |
| F20 | follows Omarchy theme | Y | Y | Y | Y | ? | Y | Y | Y | Y | Y | Y |
| F21 | settings GUI | N | N | N | N | N | N | N | N | N | N | N |
| F22 | config file | N | Y | Y | ? | P | Y | N | Y | ? | ? | N |
| F23 | profiles (several shortcuts) | P | P | N | N | N | P | N | Y | N | N | N |
| F24 | letter / number hints | N | N | N | N | N | N | N | Y | N | Y | N |
| F25 | per-app ignore / rules | N | N | N | N | N | P | N | N | P | N | N |
| F26 | media / other widgets | N | P | N | N | N | N | N | N | N | N | Y |
| F27 | stock Alt+Tab fallback | N | N | N | N | P | N | N | N | P | N | N |
| F28 | performance controls | N | P | N | P | P | N | N | N | N | N | P |
| F29 | automated tests | Y | N | N | Y | N | Y | N | Y | N | Y | N |
| F30 | marketplace packaging | P | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y |

Row totals worth noting: nobody covers F12, F17, F18, F21 (omahop's whole floating angle, dock hover preview, own dock, settings GUI). Only OMT, GAL, SWR touch F19.
F16 note: every project that states where its overlay goes uses the focused monitor only (CORE PR text "The switcher on the focused monitor"; ALT `Service.qml` `Hyprland.focusedMonitor`; SLC `targetScreen`; GAL `targetScreen`; OMT `resolveActiveScreen`). Marked N for those, ? where unread.
F30 CORE = P: it ships a manifest (`shell/plugins/switcher/manifest.json`, id `omarchy.switcher`) but as a built-in, not a marketplace listing.

## 2. Per-project sections

### CORE: omacom/omarchy PR #16548 "Switch windows with Alt + Tab the way Windows does"
- Stars: omacom/omarchy 46,382 (fork rndaom/omarchy 0). Licence MIT (copyable into MIT). State OPEN, created 2026-10-25, updated 2026-11-02. Label enhancement. 12 commits, +1222 / -119, 80+ files (about 60 are i18n keybinding json).
- Files (evidence): `shell/plugins/switcher/Switcher.qml` (306 lines), `SwitcherModel.js` (342), `SwitcherOverlay.qml` (292), `manifest.json`, `default/hypr/window-switcher.lua` (66, the `o.window_switcher.activate` helper), `default/hypr/foreground-lock.lua` (83), `default/hypr/bindings/tiling.lua`, `test/shell.d/switcher-test.sh` (75), manual page `manual/07-hotkeys.md`. It removes the stacked `cycle_next` + `bring_to_top` binds and the "Reveal active window on top" entry.
- Key handling (from `SwitcherOverlay.qml` Keys.onPressed): Tab/Right next, Shift+Tab/Left previous, Up/Down row neighbour, Home/End, Enter/Return/Space commit, Escape cancel, Delete closes hovered window; Alt release commits (QML `Keys.onReleased` plus a `switcher.alt` global shortcut with `ignore_mods` and `non_consuming`). Three plugin global shortcuts: `switcher.next`, `switcher.previous`, `switcher.alt`. Overlay maps on the first Tab so the app does not see a bare Alt tap and open its menu bar.
- Features: quick tap flips two windows; 100 ms reveal; MRU from Hyprland focus events; live thumbnails (`ScreencopyView ... live: true`) with icon and title; covers all workspaces and monitors, minimized and scratchpad included; minimized goes to the back; picking a window brings it forward wherever it is (switch workspace, show scratchpad, restore minimized, dialog on top, `alter_zorder top`); `omarchy-shell omarchy.switcher open|next|previous` sticky mode for bindings with no Alt; theme via `Commons.Color.menu.*` tokens; lists only windows with a Wayland toplevel (drops Wine ghost windows); Proton fix that stops a game from stealing focus back (`focus_on_activate` off for a fullscreen XWayland window).
- Praise: no human comments yet; only 2 comments, both the greptile bot. PR body is the claim set: "the Windows switcher, run by the shell". Verified live on Hyprland 0.56.2 with two monitors, TF2 and Wizard101 under Proton.
- Complaints (bot review, 6 inline findings, unresolved at read time): P1 Alt+Tab stays put when a dialog is focused; P1 windowed X11 apps get locked by the foreground lock; P1 games reclaim focus after config reload; P2 minimized windows return too soon; P2 oversized layout can leave the screen; P2 unrelated removal of the `XF86Display` binding. Maintainer review not seen. Two other CORE PRs are related but not switchers: #11357 background switcher (open), #221 Telescope-style picker (closed).
- Missing: type-to-search, any filter (workspace, monitor, class), config file, settings, floating-only scope, tests only for model order and layout (no UI test), overlay on focused monitor only.
- HIGHLIGHTS: (1) Windows-exact behaviour: quick tap, 100 ms reveal, release commits, no overlay flash. (2) Raises windows correctly everywhere (`alter_zorder`, workspace switch, special and minimized restore) which the third-party plugins mostly skip. (3) Live thumbnails plus game/Proton focus handling.
- GAPS vs omahop plan: no floating-workspace scoping, no filters, no vertical list style, no search, no dock hover preview, no thumbnail cost option, no config. Scope is "all windows everywhere".
- IMPLICATION: This is the single biggest risk. If merged it becomes stock Alt+Tab with F1, F2, F3, F6, F8, F9, F15, F20 already done at first-party quality, so omahop must not compete on a plain switcher; it should either stay out of Alt+Tab entirely or be the opt-in layer on top (floating scope F12, filters F13/F14, vertical list F4, search F10, thumbnail cost F7) and reuse its `o.window_switcher.activate` raise logic. Check PR status before spending build time on F1-F3. Note the omahop plan's "F27 stock fallback when out of scope" becomes "fall back to the core switcher".

### ALT: c4software/hyprland-alttab (marketplace id vbrosseau.alttab)
- Stars 14. Last commit 2026-11-03. Open issues 0 (3 closed), 1 open PR (#10 highlight selected window on screen). Licence MIT. 23 releases. Created 2026-06-02. Rust and Python legacy implementations kept; the QML plugin lives in `omarchy-plugin/` (`Service.qml` 36 KB, `logic.js`, `alttab-bindings.lua`, `modules/NotificationBadges.qml`).
- README claims: layer-shell Overlay with exclusive keyboard focus; grouped by workspace (active first), recency by `focusHistoryID`; still-frame previews (`ScreencopyView ... live: false`, Service.qml:669-673) with icon badge and title; notification badge module; theme-aware; Tab/Right next, Shift+Tab/Left prev, Return, Escape, P toggles previews, Q closes window, release Alt/Super commits; hover selects, click activates; also Super+Tab. Config `~/.config/omarchy/alttab.json` (`previews`, `modules`). No Omarchy settings UI available to service plugins (README states why).
- Praise: README only. Closed issues are feature requests the author fixed fast (#1 preview request, #3 prev shortcut, #2 Super release bug).
- Complaints: none open. Closed #2 "Releasing SUPER doesn't commit after cycling backward".
- Gaps: no tests, no search, no reveal delay found, minimized and special workspaces excluded (`special:qconsole`, pinned windows), bindings are manual.
- HIGHLIGHTS: (1) Preview on/off toggle at runtime (P key), the only direct F7 answer in the group besides GAL. (2) Notification badges on windows. (3) Alt and Super both commit on release, and workspace-grouped list.
- GAPS vs omahop plan: no floating scope, no vertical list, no search, no filters, no tests, no quick-tap reveal delay evidence.
- IMPLICATION: No course change; steal the "P toggles previews" idea for F7 and the JSON-file hot reload for F22.

### ASW: Pablo-Merino/omarchy-altswitch
- Stars 26 (second highest in the group). Last commit 2026-08-30 (stale, about 10 weeks). Open issues 0, 4 open PRs (#6 settings fallback, #8 macOS icon bar, #9 Chromium webapp names, #10 Alt+arrow selection) all unmerged. Licence MIT. No releases.
- Files: `altswitch.lua` (state and keys, reads raw `input.keyboard.key` events), `AltSwitch.qml` (display only, no keyboard grab), `manifest.json`.
- README: Windows-style list, all workspaces and monitors, MRU, frozen snapshot at start, virtual selection (focus moves once on Alt release), Alt+Esc cancel, `omarchy-shell altswitch set showIcons false`. Special and scratchpad excluded. Self-hides after 10 s if Alt release is missed.
- Praise: the "snapshot then virtual selection" design is explained well. Stars only.
- Complaints (README "Known limitations"): keys not bound still reach the window underneath; no thumbnails. Author has not merged 4 PRs.
- HIGHLIGHTS: (1) The only plain vertical list with icons (F4). (2) Frozen order and virtual selection (no focus churn). (3) Tiny and dependency free.
- GAPS vs omahop plan: no thumbnails, no mouse, no search, no reveal delay found, no tests, special workspace excluded, abandoned-looking.
- IMPLICATION: No course change; confirms there is demand for a minimal vertical list (F4) and that core now makes the minimal version redundant.

### OMA: piyush97/omaswitch
- Stars 13. Last commit 2026-11-01. Open issues 2 (+1 PR #16 click preview to focus). 4 closed. Licence MIT. 4 releases, CI badge, CHANGELOG, CONTRIBUTING, `test_model.js` (19 KB), `Model.js`, `Switcher.qml` (35 KB), listed on omarchyplugins.com.
- README claims: "the Alt+Tab Omarchy was missing". Global MRU across all workspaces; live preview pane for the highlighted window (two alternating `ScreencopyView`, live); type to filter by title, app, workspace or on-device OCR text visible inside windows (tesseract) with match outlines; mouse click works; theme follows; no daemon. User must replace the binding by hand (README says most "doesn't open" reports are this).
- Praise: README names 5 contributors; closed issues show users asked for OCR (#8, #12) and the author shipped it. Write-up blog post exists.
- Complaints (issues): #13 stale ghost rows after quitting Spotify; a second commenter reports about 25 ghost rows after Battle.net under Wine/Proton ("Default IME", "Agent", ...). #14 under Omarchy 4.5 floating mode the app gets focus but is not raised (stays behind other windows). Closed: #2 other workspaces not reachable, #10 switcher resizes while cycling as previews load.
- Gaps: no release-to-commit verified in README (Enter or click), no close action, no thumbnails grid (single side pane), special/minimized unknown.
- HIGHLIGHTS: (1) Search inside window content by OCR (unique in the group). (2) Live preview pane with double buffering. (3) Best engineering hygiene of the third-party set: CI, tests, changelog, issue templates.
- GAPS vs omahop plan: no floating scope, no commit-on-release evidence, no raise logic (issue #14 is exactly omahop's floating case), no dock hover, no filters.
- IMPLICATION: Two lessons, no course change: floating windows need explicit z-raise (#14), and ghost Wine toplevels must be filtered (#13). OCR search is a differentiator omahop could skip or defer.

### SLC: m4rone/omarchy-slicetab
- Stars 2. Last commit 2026-08-25. Open issues 0. GitHub shows licence NOASSERTION but the LICENSE file is the standard MIT text (copyright m4rone), so MIT in practice. No tests, no releases.
- Claims: quick tap switches at native speed and draws nothing; hold Alt about 200 ms (4 ticks of a 50 ms in-compositor timer) and a carousel row appears with the selected window large and live (`ScreencopyView live: item.selected && root.opened && root.revealed`), others as slices; Escape (Alt+Escape bind) cancels back to the starting window; click a preview. Lists only the current workspace on purpose (screen-share privacy argument). Native `cycle_next()` and `bring_to_top()` still run first, so if the shell is slow or missing, Alt+Tab still works. Needs Hyprland 0.56 (`hl.is_key_down`).
- Praise: none external (2 stars). The privacy-scope argument is original.
- Complaints: README limits only: holding Tab does not repeat, polling can miss a very short Escape tap.
- HIGHLIGHTS: (1) Best-designed reveal delay and quick-tap path (F2, F3). (2) Native Alt+Tab keeps working underneath, the only true fallback (F27). (3) Live preview only for the selected slice (cost control).
- GAPS vs omahop plan: overlay takes no keyboard focus so no arrows/search/Enter; current workspace only with no option; no tests.
- IMPLICATION: Worth copying the "native action first, overlay on top" fallback and the polling-free alternative; the core PR's design replaces the polling need. No course change.

### SWR: gabrielvincent/omarchy-switcharoo
- Stars 3. Last commit 2026-10-31. Open issues 0 (1 open PR #1 releaseModifiers). Licence MIT. 1 release. Tests: `tests/tst_WindowModel.qml` (qmltestrunner). `Switcher.qml` 57 KB, `WindowModel.js`.
- README: MRU, vim keys (hjkl) and arrows, grid navigation with wrap, close client or all clients in a workspace (q, Delete, middle click), minimize client or workspace and a minimized-only view (persisted in `~/.local/state/switcharoo-minimized.json`), switch clients or workspaces (`switchMode`), filters `current_monitor`, `current_workspace`, `same_class` via `filterBy`, `excludeWorkspaces` regex, `itemsPerRow`, `maxVisibleRows`, summon payload overrides per bind, Omarchy theme colors/fonts/radius, `commitOnModifierRelease`. Settings live in `shell.json`. No `ScreencopyView` in source, so the "preview" is a schematic layout, not a live image.
- Praise: feature list and docs table. Stars low.
- Complaints: none open. Open PR #1 shows commit-on-release only for Alt by default.
- HIGHLIGHTS: (1) Richest configuration surface (filters, excludes, per-bind payloads) = closest to omahop F13/F14/F23/F25. (2) Minimize and restore flow plus workspace mode. (3) Real test file.
- GAPS vs omahop plan: no live thumbnails, no search, no quick-tap/reveal-delay evidence, no floating scope, no GUI.
- IMPLICATION: Closest analogue for omahop's filter model; reuse its `filterBy` vocabulary (current_monitor/current_workspace) so users get one mental model. No course change.

### XAD: xadacka/omarchy-window-switcher
- Stars 1. Last commit 2026-08-28. Open 0. Licence MIT. No tests. Files: `bin/omarchy-window-switcher` (shell + jq), `Service.qml`, `install.sh`.
- Not a hold-Alt switcher: a searchable list bound to `SUPER + GRAVE`, reusing Omarchy's `omarchy.menu` dmenu overlay. Type to filter, arrows, Enter, Esc. Nerd Font glyphs, not real icons (README explains the dmenu delegate cannot draw icons). Current window excluded. Service appends a line to the user's `bindings.lua`.
- Praise: none. Complaints (README caveats): two identical windows indistinguishable; removing the plugin leaves the binding behind; README says repo was private at writing.
- HIGHLIGHTS: (1) Zero custom UI, so lowest maintenance. (2) Type to filter. (3) Native look via the system menu.
- GAPS vs omahop plan: everything visual (no thumbnails, no icons, no Alt hold).
- IMPLICATION: None. Shows the cheapest possible path; omahop's UI is already beyond it.

### LUW: luwojtaszek/omarchy-alt-tab
- Stars 2. Last commit 2026-09-05. Open 0. Licence MIT. Tests: `tests/window-model.test.js`, `apply-binds.test.sh`, `test_theme_style.py`. Files `Switcher.qml` (27 KB), `Service.qml`, `WindowModel.js`, `apply-binds.sh` (17 KB).
- README: MRU; quick tap switches without the switcher ever appearing (`revealTimer`, 250 ms in `Switcher.qml:325`); type to filter latches sticky mode; two looks `two-line` (icon, title, key-hint footer) and `bare` (compact rows with `alt+<n>` jump numbers); `mode` all / sameclass / sameworkspace; modifier ALT or SUPER or none (picker); config `~/.config/omarchy/alt-tab.json` with `binds` array of combos and payloads; service registers binds dynamically and never edits the user's Hyprland config; strict validation, security notes. Raises with `bring_to_top` plus `alterzorder top` ("in a floating-heavy layout focuswindow alone is not enough", Switcher.qml:205). No thumbnails by design (icons only). Special and unassigned workspaces excluded.
- Praise: none external. Complaints: none open; README warns update needs `omarchy restart shell`.
- HIGHLIGHTS: (1) Best match to omahop's list-first design: vertical rows, reveal delay, type-to-search, jump numbers. (2) Config-file driven profiles with validation. (3) Dynamic bind registration with safe uninstall.
- GAPS vs omahop plan: no thumbnails, no dock hover, no minimized/special, no monitor filter, no mouse evidence.
- IMPLICATION: Closest competitor to omahop's vertical style; its design confirms the spec is right. Check its bind/payload schema before inventing ours. No course change.

### QS: ewweberlin/QuickSwitch
- Stars 4. Last commit 2026-10-26. Open issues 1 (#2 optional icon-only mode, author open to PR). Licence MIT. No tests. `Service.qml` 27 KB, `logic.js`, `task-switch-bindings.lua`.
- Claims: macOS style horizontal strip on SUPER+TAB; quick tap goes to previous without flashing, strip appears after a moment; MRU; hover highlight and click; SUPER+Q quits the highlighted app; still snapshots with icon badge (`captureFrame()` on a 90 ms timer until content settles, then frozen); never captures password managers, auth prompts or private browsing windows; special/scratchpad windows not listed; in-switcher keys live in a Hyprland submap `quickswitch` so other binds are untouched; falls back to "Next workspace" when the plugin is off. Donation link in README.
- Praise: 4 stars. Complaint: #2 asks for icon-only mode for privacy and lightness (a user wants F7).
- HIGHLIGHTS: (1) Privacy-aware capture exclusions. (2) Submap isolation so keys never leak. (3) Quit-app action.
- GAPS vs omahop plan: no config, no filters, no search, no tests, no special workspace.
- IMPLICATION: Issue #2 is user evidence that a thumbnail off switch (F7) is wanted; keep F7 in v1. No course change.

### OMT: Codesmith28/omalt-tab
- Stars 25. Last commit 2026-10-16. Open issues 0 (+1 PR #5 setup notification race). Licence Apache-2.0 (copyable into MIT only with attribution and notice; keep the Apache terms on copied files). Tests: 23 listed, `tests/test_navigation.js`, `test_overlay_lifecycle.js`, `test_window_model.js`, `test_icons.js`, `test_integration_scripts.js`. Makefile, install scripts, marketplace-update workflow. `AltTabOverlay.qml` 41 KB.
- Claims: spatial miniature desktop (one card per workspace with true-aspect window outlines, no live pixels); MRU cycling, release Alt commits, Enter/Space, Esc, click window or workspace; home-row jumps A..; to workspaces 1-10, 1-9 jump to a window; Hyprland group tabs rendered; two-row overflow above 6 workspaces; active-monitor placement; theme via `Color.menu`, `Color.accent`, `Style.font.*`; Unix socket plus shell IPC; z-raise via `alter_zorder` and `bring_to_top` with floating and maximized handling (`omalt.qml:305-345`); Unicode bidi spoof sanitization. Dev mode (stay open until Enter) via a `.dev` file.
- Praise: highest star count after ASW; README claims only (no issues).
- Complaints: none; the README is long and promotional. Install method "upcoming after plugin release".
- HIGHLIGHTS: (1) Workspace-centric spatial overview (F19 partial). (2) Numbered and home-row hints (F24). (3) Careful floating/maximized raise logic.
- GAPS vs omahop plan: no thumbnails, no search, no filters, no reveal delay evidence, no list style.
- IMPLICATION: Shows demand for a workspace overview, which omahop has as a non-goal or later goal; worth a roadmap note, not a pivot.

### GAL: LosokosG/omarchy-window-gallery ("Better Alt-Tab")
- Stars 1. Last commit 2026-09-16. Open 0. Licence MIT. 1 release. No automated tests (design doc `docs/design.md`). Files `Gallery.qml` (32 KB), `WindowList.js`, `Service.qml`, `bin/omarchy-window-gallery-keybind`, Firefox extension and native host in `browser/`.
- Claims: searchable grid of window previews on ALT+TAB; selection starts on the window you were just in; type filter plus keywords `playing`, `fullscreen`, `tab`; media and fullscreen windows grouped under headings, track title shown for playing tiles (Mpris); optional Firefox tab listing with thumbnails via extension and native messaging host; previews are `live: false`, released on close, measured 19 windows in 23-57 ms, about 0 memory; theme via `Color.menu.*` and `Style.*`; plugin writes a managed block into `bindings.lua` once.
- Praise: README documents measured performance; no external feedback. Complaints: none; Firefox only, tabs have no live preview.
- HIGHLIGHTS: (1) Documented snapshot-only preview cost with numbers (F7, F28). (2) Search plus media/fullscreen grouping widgets (F10, F26). (3) Browser tab integration.
- GAPS vs omahop plan: no release-to-commit evidence (Enter or click), no filters, no tests, no minimized/special.
- IMPLICATION: Their measurement is the evidence omahop needs: snapshot (non-live) thumbnails are cheap, so default omahop thumbnails to snapshot and make live opt-in.

## 3. What this group tells omahop

1. A first-party Alt+Tab (CORE PR #16548) is in flight with quick tap, 100 ms reveal, live thumbnails, all-window scope, minimized restore and theme. It is the plan most likely to make a generic omahop switcher redundant; confirm its status weekly.
2. Only SWR and LUW offer real filters (workspace, monitor, class) and per-bind profiles; nobody offers a floating-workspace scope (F12), a dock hover preview (F17), an own dock (F18) or a settings GUI (F21). Those are omahop's open ground.
3. Most-copied common core: MRU, release commits, theme tokens, `ScreencopyView`. Table stakes, not differentiators.
4. Floating raise is the recurring bug: OMA issue #14 (focus without z-raise in 4.5 floating mode); LUW, OMT, CORE solve it with `bring_to_top` and `alter_zorder`. Build this first for omahop.
5. Wine/Proton ghost toplevels (OMA #13, CORE commit 2) need filtering on `Wayland toplevel` presence.
6. Thumbnail cost: GAL measured snapshots as near free, QS #2 users want an icon-only mode, ALT toggles previews. Default to snapshot, offer live and off.
7. Search is demanded (OMA ships OCR, GAL, LUW, XAD have title search); CORE has none, so search is a safe differentiator for an opt-in plugin.
8. No project has more than 26 stars and open-issue counts are 0-2, so there is almost no user feedback to learn from; all praise is README self-claims.
9. Licences: all MIT except OMT (Apache-2.0) and SLC (MIT file, GitHub shows NOASSERTION); code can be copied into MIT with notices, OMT only with Apache attribution.
10. Course verdict: keep the plan but reposition. Do not build a plain Alt+Tab; ship floating scope, filters, vertical list, search and snapshot thumbnails as the layer core does not cover, and decide after PR #16548 resolves.

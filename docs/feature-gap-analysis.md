# omahop feature gap analysis (v1.0.0, 2026-11-07)

Everything mapped in the research docs, compared with what the code at tag v1.0.0 does. Research only: no product code changed.
Sources mapped: `contexts-reference/features.md` (C1 to C31), `bettercmdtab-reference/features.md` (B1 to B65, GPL, ideas only), `research/competitors-*.md`
(F1 to F30 and "highlights worth stealing"), `competitive-analysis.md`, `lessons-from-others.md` (L1 to L17), `research/community-code.md` (techniques),
`ROADMAP.md`, `v0.2` to `v0.4-plan.md`, `decisions.md`, `settings.md`, `architecture.md`.
DockDoor (D-ids) is not part of this pass.

Status words: BUILT, PARTLY, NOT BUILT, REJECTED BY RULE (our own principles or a decision), OUT OF SCOPE (no Linux or Omarchy equivalent, or another tool owns it).
Evidence is `file:line`, a setting name or a test. "Value" is for an Omarchy user on floating workspaces with several windows and monitors.
Effort S (under a day, one module), M (a batch, touches Lua, QML and the settings window), L (a release).
Fit rules checked per candidate: no new icons or widgets by default, one settings window, slim but complete, follows theme, flexibility, scalability and per-language standards, public repo with no private data.

Counts are at the end of section 1. Things I could not verify are in section 6.

## 1. Table

Columns: id, item, source, status, evidence, then for PARTLY and NOT BUILT: value, effort, fit and risk.

### 1a. Contexts (C1 to C31)

| Id | Item | Src | Status | Evidence | Value | Eff | Fit and risk |
|---|---|---|---|---|---|---|---|
| C1 | Vertical window list | Contexts | BUILT | `ListStyle.qml:45` (ListView), setting `style = list`, `tests/live.py:66` | | | |
| C2 | Row: icon, app name, title | Contexts | BUILT | `ListRow.qml`, `IconResolve.js`, `tests/icon_resolve.test.mjs` (207 desktop entries) | | | |
| C2b | Dock badge counts on rows | Contexts | NOT BUILT | grep `Notification\|badge` in QML: only the peek strip window count (`PeekStrip.qml:193`) | low | M | Notifications service exists (`Quickshell.Services.Notifications`), but a badge is a new glyph: opt-in only. See B44 |
| C3 | Hold-modifier switcher, release commits | Contexts | BUILT | `session.lua:66` tick, polling `hl.is_key_down` (`omahop.lua:253`), `live.py:56` | | | |
| C3b | Delay before the list shows | Contexts | BUILT | `reveal_delay_ms` (default 100), `live.py:47` quick tap shows no overlay | | | |
| C4 | First Tab picks the previous window | Contexts | BUILT | `mru.lua:44` first_pick, `live.py:47` | | | |
| C5 | MRU order | Contexts | BUILT | `omahop.lua:472` (window.active), `mru.lua:24`, `test_mru.lua`; seed from Hyprland history `omahop.lua:449` | | | |
| C6 | Same-app list (Cmd+backtick) | Contexts | BUILT | `same_app_key = "ALT + GRAVE"`, `omahop.lua:370`, `tests/live_sameapp.py:50` | | | |
| C7 | Several switchers with own settings | Contexts | PARTLY | one extra (same-app) only; generic profiles deferred in `v0.4-plan.md`, `settings.md` "Later: profiles" | high | L | Needs a settings window design for N profiles (a repeating group), or it breaks "one window" rule. Risk: bind lifecycle (L8) per profile |
| C8 | Sort by importance (minimized, hidden, special) | Contexts | BUILT | `windows.minimized` back/hide, `windows.specials` hide/show, `mru.lua:24` minimized last | | | |
| C9 | Filter by workspace and monitor | Contexts | BUILT | `windows.workspaces` current/floating/all, `windows.monitors`, `windows.lua:17`, `test_windows.lua`, `test_monitors.lua` (193 checks) | | | |
| C10 | Group by Space | Contexts | NOT BUILT | list is flat MRU (`omahop.lua:113`) | low | S | A section header is a new widget; MRU is the point of the product. Skip |
| C11 | Type-to-search, non-consecutive and acronym match | Contexts | PARTLY | words must be substrings (`search.lua:19`), starts-with ranking only; no subsequence, no acronym, no diacritic folding (`search.lua:7`) | high | S | Pure Lua, fits. Typing is ASCII only (`omahop.lua:193`), so folding "acao" to "ação" is the useful half. Risk: ranking surprises, keep tests realistic |
| C12 | Search from inside the list | Contexts | BUILT | `omahop.lua:246` typing binds, `live.py:95` "alp" | | | |
| C13 | Learned search shortcuts | Contexts | NOT BUILT | grep: no persistence of query to window | medium | M | Needs a state file and a reset control in the settings window. Risk: stale entries, privacy of typed queries (store class only, never titles) |
| C14 | Fast Search (modifier plus 1-2 letters, no panel) | Contexts | PARTLY | Alt+Tab, type, release goes to best match (`live.py:97`); no Tab-less entry | low | M | Needs binds that exist outside a session, which steals Alt+letter from apps. Poor fit |
| C15 | Number switcher | Contexts | BUILT | `hints = numbers`, `hints.lua:36`, `tests/live_hints.py:48` | | | |
| C16 | Keyboard navigation | Contexts | BUILT | Tab, Shift+Tab, Alt+arrows, Return, Esc (`omahop.lua:16`, `session.lua:57`); vim keys are B48, reorder is C31 | | | |
| C17 | Quick actions: close, minimize, quit, hide | Contexts | PARTLY | close: `Alt+Delete` (`omahop.lua:241`) and hover button; minimize: hover button only (`omahop.lua:284`); no quit, no hide; list stays open after close (`live_pointer.py:79`) | medium | S | Keys must avoid letters (they type). Quit = close all windows of the app. Minimize works on floating workspaces only (Omarchy script) |
| C18 | Sidebar | Contexts | PARTLY | opt-in peek strip, `peek = off/edge/always` (`PeekStrip.qml`, `tests/live_peek.py:71-114`); lists apps, hover shows windows, not a full window list | low | M | Already the right opt-in shape. Do not grow it |
| C19 | Resize windows to avoid the sidebar | Contexts | NOT BUILT | `PeekStrip.qml:24` `ExclusionMode.Ignore` | low | M | Moves user windows: against "stays out of the way" |
| C20 | Trackpad edge gesture | Contexts | NOT BUILT | grep `gesture`: none | low | L | Edge start position is not exposed; see B51 for the swipe variant that is now possible |
| C21 | Mouse: click, hover, wheel | Contexts | BUILT | hover never changes pick, click picks (`tests/live_pointer.py:60-66`); wheel scroll is the ListView's own (not tested) | | | |
| C22 | Multi-monitor: list on all displays | Contexts | PARTLY | list shows on the focused monitor only (`OverlayWindow.qml:44,56`, shell file, used by `Service.qml:208`); peek strip is per screen (`Service.qml:196`); window set via `windows.monitors` | medium | S | A `display` setting (focused, cursor, all) with a Variants over screens. Risk: one capture per screen, L6 |
| C23 | Ignore rules (app, title) | Contexts | BUILT | `windows.ignore`, `windows.ignore_titles`, `windows.lua:17-30`, `tests/live_rules.py:47` | | | |
| C24 | Pause shortcuts for chosen apps | Contexts | BUILT | `passthrough`, `passthrough_fullscreen`, `rules.lua:36`, `tests/live_rules.py:58,65` | | | |
| C25 | Windowless apps, Dock-icon action | Contexts | OUT OF SCOPE | Linux has no windowless-app list; Omarchy has launch-or-focus (`omarchy-launch-or-focus`) | | | |
| C26 | Themes | Contexts | BUILT | colours from `Color.*`, `Style.*` (`ListRow.qml:30`), setting `border` | | | |
| C27 | Accessibility permission, secure input | Contexts | OUT OF SCOPE | macOS only; Wayland has no secure input problem | | | |
| C28 | Speed | Contexts | BUILT | reveal delay, state file written only on change (`omahop.lua:146`), 0.7 ms to open (`docs/research/performance-v0.1.md`) | | | |
| C29 | Window tracking quirks, ghost windows | Contexts | BUILT | `windows.lua:20` (mapped), `omahop.lua:80` (hidden), `test_windows.lua:17` ghost fixture | | | |
| C30 | Preferences, updates, launch at login | Contexts | OUT OF SCOPE | settings window is built (`SettingsPanel.qml`); updates are `omarchy plugin update` | | | |
| C31 | Manual reorder, reserved slots | Contexts | NOT BUILT | none | low | M | Needs persisted order over MRU. Against MRU purity |

### 1b. BetterCmdTab (B1 to B65, ideas only)

| Id | Item | Status | Evidence | Value | Eff | Fit and risk |
|---|---|---|---|---|---|---|
| B1 | Tap vs hold with reveal delay | BUILT | `reveal_delay_ms`, `live.py:47,66` | | | |
| B2 | Layouts: list, icon grid, previews | PARTLY | list and cards (`style`); `thumbnails = off` gives icon cards (`live_cards.py:63`); no wrapping grid | low | M | Cards scroll in one row (`CardsStyle.qml:55`); a grid helps only with 20+ windows |
| B3 | Panel scale, list width | NOT BUILT | sizes come from `Style.*` | low | S | Against "follows Omarchy" |
| B4 | Grid column cap | NOT BUILT | n/a, no grid | low | S | Follows B2 |
| B5 | Display: cursor, active window, main | PARTLY | focused monitor only, no setting (`OverlayWindow.qml:44`); `hl.get_monitor_at_cursor` exists (stub) | medium | S | Same item as C22 |
| B6 | Warp pointer to target display | REJECTED BY RULE | L9: never move the pointer; grep `cursor.move` in code: none (tests only) | | | |
| B7 | Vertical position (center or top) | NOT BUILT | `Service.qml:218` anchors.centerIn | low | S | Cosmetic setting |
| B8 | Sort orders (alphabetical, launch, dock) | PARTLY | MRU plus `windows.first` only | low | S | MRU is the product; alphabetical helps nobody on floating |
| B9 | Initial selection middle | NOT BUILT | n/a with MRU | low | S | Only for stable sorts |
| B10 | Space scope visibleSpaces | PARTLY | current, floating, all (`windows.lua:7`); no "visible on any monitor" | medium | S | One new enum value. With several monitors this is the natural "what I can see" list |
| B11 | Instant space switch | NOT BUILT | none | low | S | Hyprland animation setting belongs to the user |
| B12 | Include and sink minimized, hidden | BUILT | `windows.minimized`, `windows.specials` | | | |
| B13 | Windowless apps | OUT OF SCOPE | no Wayland concept | | | |
| B14 | Apps only, one row per app | NOT BUILT | list is per window; peek strip groups per app (`PeekModel.js`) | low | S | A `group = app` value; same-app key covers most uses |
| B15 | Window shelf | NOT BUILT | none; peek card per app is similar | low | M | New surface |
| B16 | Down-arrow drill | NOT BUILT | none | low | M | Needs B14 first |
| B17 | Group per chosen app | NOT BUILT | none | low | S | Needs B14 |
| B18 | Tab drill, tabs as rows | NOT BUILT | roadmap "browser tab search" (other agents) | | | Context only |
| B19 | Recency tracking, unseen ranked by stacking | BUILT | `omahop.lua:449`, `:472`, `test_mru.lua` | | | |
| B20 | Cached enumeration, stable id | BUILT | one `hl.get_windows()` per session (`omahop.lua:114`), address as id | | | |
| B21 | Non-activating panel | BUILT | `Service.qml:211` `WlrKeyboardFocus.None`, `live_pointer.py:61` | | | |
| B22 | Survivor trigger if the UI fails | PARTLY | Lua owns the keys, so a switch still happens with no overlay if the shell plugin is down (design, `architecture.md`); no test with the plugin off | low | S | Add one live test; no feature |
| B23 | Stay open after release | NOT BUILT | roadmap "keep the list open while you search" (other agents) | | | Context only |
| B24 | Shift steps backwards, backtick reverses | PARTLY | Alt+Shift+Tab (`omahop.lua:476`, `live.py:61`); no Shift-tap while holding | low | S | Alt+arrows cover it |
| B25 | Same-app cycle | BUILT | see C6 | | | |
| B26 | Letter hints per row | PARTLY | numbers and app letters (`hints.lua:18`); no per-row typed letters | low | S | Would fight type-to-search |
| B27 | One-hand hints | NOT BUILT | none | low | S | Niche |
| B28 | Home-row single letters | NOT BUILT | none | low | S | Open upstream regression there too |
| B29 | Persistent app-to-letter map | BUILT | `hint_keys`, `hints.lua:8`, `live_hints.py:60` | | | |
| B30 | Hint exclusions | NOT BUILT | none | low | S | Niche |
| B31 | Fuzzy search: subsequence, fold case and diacritics | PARTLY | case folded only (`search.lua:7`); see C11 | high | S | Same item as C11. Note GPL: write from this description, do not copy |
| B32 | Search launches apps, recently closed | NOT BUILT | none | low | M | Omarchy's launcher does it (Super+Space). Do not duplicate |
| B33 | Search dismiss mode | NOT BUILT | roadmap "keep the list open" | | | Context only |
| B34 | Search browser tabs | NOT BUILT | roadmap "browser tab search" | | | Context only |
| B35 | Direct app hotkeys | OUT OF SCOPE | Omarchy 4.5 binds already focus-or-launch (`applications.lua:22`, `omarchy-launch-or-focus`) | | | |
| B36 | Scoped shortcuts | PARTLY | same-app only | high | L | Same item as C7 |
| B37 | Per-shortcut overrides | NOT BUILT | `settings.md` says the flat table was made so profiles can wrap it | high | L | Same item as C7 |
| B38 | Exclude current app per shortcut | NOT BUILT | first_pick skips the focused window only (`mru.lua:44`) | low | S | Part of profiles |
| B39 | Pinned apps first | BUILT | `windows.first`, `rules.lua:24`, `live_rules.py:52` | | | |
| B40 | Per-app rules: hide, ignore, group | PARTLY | ignore and pass-through built; no group rule | low | S | See B17 |
| B41 | Title exclusions | BUILT | `windows.ignore_titles`, `live_rules.py:47` | | | |
| B42 | Hide-all exclusions | NOT BUILT | no hide-all feature (B54) | low | S | n/a |
| B43 | Status glyphs (audio, hidden, minimized) | PARTLY | minimized rows dim (`ListRow.qml:24`); audio marker built in v1.5 (`audio_marker`, D21, pactl snapshot instead of the PipeWire service) | medium | M | Audio-playing marker via `Quickshell.Services.Pipewire` (installed). New glyph: opt-in, default off. Risk: matching a stream to a window by pid, wrong for browsers |
| B44 | Unread badges | NOT BUILT | none | low | M | Notification to window mapping is guesswork; new glyph |
| B45 | Handoff tile | OUT OF SCOPE | Apple only | | | |
| B46 | Hover action bar | PARTLY | close and minimize (`actions` setting, `ActionButton.qml`, `live_pointer.py:78`); no maximize, hide, quit, force quit | low | S | Maximize or quit buttons add clutter |
| B47 | In-panel action keys | PARTLY | `Alt+Delete` only | medium | S | See C17 |
| B48 | Vim navigation | NOT BUILT | letters type into search (`omahop.lua:246`) | low | S | Conflicts with search. Do not build |
| B49 | Layout-independent in-panel keys | NOT BUILT | typing uses keysym binds `ALT + A..Z` (`omahop.lua:193`); `input:resolve_binds_by_sym` is false here (read with hyprctl) | medium | M | Unverified on non-US layouts (see section 6). A user on AZERTY or Cyrillic may not be able to type. Check before 1.1 |
| B50 | Mouse behaviour (wheel, click outside, mouse-up) | PARTLY | hover, click built; no click-outside dismiss (mask is the card only, `Service.qml:214`); no mouse-up pick | low | S | Click outside is a free dismiss, but needs a full-screen input region, which steals clicks |
| B51 | Trackpad swipe trigger | NOT BUILT | grep `gesture`: none | medium | M | Stale reason: `hl.gesture({fingers, direction, action})` exists in Hyprland 0.56.2 stubs. Risk: collides with Omarchy workspace swipe; release-to-commit semantics unknown (unverified) |
| B52 | Commit sound or haptic | NOT BUILT | none | low | S | Against slim |
| B53 | Window tiling hotkeys | OUT OF SCOPE | sibling project omagnet | | | |
| B54 | Hide all, show all | OUT OF SCOPE | Omarchy has close-all; hide-all has no Hyprland meaning | | | |
| B55 | Appearance: material, opacity, radius | PARTLY | follows `Style` rounding, `border` setting only | low | S | More knobs fight "follows theme" |
| B56 | Selection colour | REJECTED BY RULE | follows accent (`ListRow.qml:30`), "no own palette" in `engineering-standards.md` | | | |
| B57 | Typography | REJECTED BY RULE | fonts from `Style.font` | | | |
| B58 | Motion: animations, fade | NOT BUILT | grep `Behavior\|animation`: none | low | S | No animations at all today, which is also the fastest |
| B59 | Live previews, cost control | BUILT | `thumbnails = snapshot/live/off`, `CardItem.qml`, `live_cards.py:59-63` | | | |
| B60 | Config file, live reload, clamp, schema | BUILT | `config.toml`, `config.lua` spec, `ConfigIO.js`, `live_panel.py:52` (comments survive), bad values fall back and are logged; no JSON schema (TOML plus `spec.json` for the panel) | | | |
| B61 | Export and import | NOT BUILT | a file copy does it | low | S | Skip |
| B62 | Hide from screen sharing | NOT BUILT | none | low | L | Layer-shell cannot exclude from capture |
| B63 | Settings window layout | BUILT | `SettingsPanel.qml`, `spec.json` groups | | | |
| B64 | Localization | NOT BUILT | grep `I18n\|qsTr`: none, English strings only; the shell ships `Commons/I18n.qml` | medium | M | Fits "follows Omarchy"; strings are in `config.lua` spec so one place. Risk: translation upkeep |
| B65 | Permission gates | OUT OF SCOPE | macOS only | | | |

### 1c. Feature keys F1 to F30 (competitor matrices)

| Id | Item | Status | Evidence | Value | Eff | Fit and risk |
|---|---|---|---|---|---|---|
| F1 | Hold Alt, release commits | BUILT | C3 | | | |
| F2 | Quick tap goes to previous | BUILT | C4 | | | |
| F3 | Reveal delay | BUILT | C3b | | | |
| F4 | Vertical list | BUILT | C1 | | | |
| F5 | Horizontal cards | BUILT | `CardsStyle.qml`, `style = cards` | | | |
| F6 | Live thumbnails | BUILT | B59 | | | |
| F7 | Thumbnail cost control | BUILT | B59, default snapshot | | | |
| F8 | Keyboard navigation | BUILT | C16 | | | |
| F9 | Mouse hover and click | BUILT | C21 | | | |
| F10 | Type-to-search | BUILT | `search = true`, `live.py:95`; quality is C11 | | | |
| F11 | Quick actions | PARTLY | C17 | medium | S | See C17 |
| F12 | Floating-only scope | BUILT | `scope`, `windows.workspaces = floating`, `scope.lua:18`, `live.py:125` | | | |
| F13 | Workspace filter | BUILT | C9 | | | |
| F14 | Monitor filter | BUILT | `windows.monitors`, `test_monitors.lua` | | | |
| F15 | Minimized and special windows | BUILT | `omahop.lua:58-72`, `:157-164`, `live_cards.py:60` | | | |
| F16 | Multi-monitor overlay | PARTLY | C22 | medium | S | See C22 |
| F17 | Hover preview over dock icon | PARTLY | decision D8: own opt-in peek strip, not the stock dock (core PRs 16219 and 16479 still open, `gh pr view` 2026-11-07) | low | L | Stock dock still has no hook (`Dock.qml` IPC is refresh and apps only) |
| F18 | Own dock or taskbar | PARTLY | peek strip, opt-in, no launch or pin | low | M | D11 allows opt-in only |
| F19 | Overview or expose grid | OUT OF SCOPE | `competitive-analysis.md`: eight plugins, do not build another grid | | | |
| F20 | Follows Omarchy theme | BUILT | C26, `ListRow.qml:30` | | | |
| F21 | Settings GUI | BUILT | `SettingsPanel.qml`, `live_panel.py:47` | | | |
| F22 | Config file | BUILT | B60 | | | |
| F23 | Profiles | PARTLY | C7 | high | L | See C7 |
| F24 | Letter or number hints | BUILT | B29, C15 | | | |
| F25 | Per-app ignore and rules | BUILT | C23, C24, B39 | | | |
| F26 | Media or other widgets | REJECTED BY RULE | "no new widgets by default" (D11) | | | |
| F27 | Stock Alt+Tab fallback | BUILT | `omahop.lua:395` stock, `scope.lua:18`, `live.py:125` | | | |
| F28 | Performance controls | BUILT | B59, `performance-v0.1.md` | | | |
| F29 | Automated tests | BUILT | `tests/run-all.sh`, offline suite re-run green for this report | | | |
| F30 | Marketplace packaging | PARTLY | `manifest.json`, `omarchy plugin validate` passes, `docs/launch/`; ROADMAP says submitted (issue 14254), `v1.0-plan.md` says nothing submitted: UNVERIFIED | | | Not a feature |

### 1d. Highlights worth stealing and community techniques

| Id | Item | Source | Status | Evidence | Value | Eff | Fit and risk |
|---|---|---|---|---|---|---|---|
| H1 | Snapshot order, virtual selection, focus moves once | altswitch | BUILT | `omahop.lua:440` snapshot, `:243` commit only on release | | | |
| H2 | Idle guard so a session cannot stick | stage, sparkrussell | BUILT | `session.lua:13` max 60 s | | | |
| H3 | Toggle previews at runtime (P key) | alttab | NOT BUILT | setting only | low | S | A letter key is taken by search |
| H4 | Notification badges on windows | alttab | NOT BUILT | none | low | M | See B44 |
| H5 | Two-click close confirmation | birdseye | NOT BUILT | `Alt+Delete` closes at once (`omahop.lua:241`) | low | S | Closing is a request, so low harm |
| H6 | Never capture sensitive windows | QuickSwitch | NOT BUILT | thumbnails exist for every listed window (`Service.qml:114`) | medium | S | Setting `thumbnails_exclude` (classes, title fragments) giving icon only. Fits rules, reuses `Rules.set` |
| H7 | Submap isolation of keys | QuickSwitch | REJECTED BY RULE | decision D5, `research/spikes.md` S9: polling is the only reliable release signal | | | |
| H8 | Quit-app action | QuickSwitch | NOT BUILT | none | medium | S | See C17 |
| H9 | Native action first, overlay on top | slicetab | BUILT | `omahop.lua:431-446` switch works without overlay; stock on out-of-scope (`:395`) | | | |
| H10 | MRU not rewritten during the session | x-mode | BUILT | focus changes only at commit (virtual selection) | | | |
| H11 | Stable id instead of address | rmacy | NOT BUILT | address used (`omahop.lua:158`) | low | S | Address reuse is rare, window is re-fetched at activate |
| H12 | Titles as plain text | rmacy, taskbar | BUILT | `textFormat: Text.PlainText` (`SearchChip.qml:23`, `SettingsPanel.qml:96`); row titles not re-checked, see section 6 | | | |
| H13 | Collision story with other switchers | manateelazycat | PARTLY | free-chord snapshot for session keys (`omahop.lua:180,230`); `Alt+Tab` itself is taken without checking other plugins; `takeover` setting | low | S | A startup log line naming the replaced bind |
| H14 | Same-app cycle | offGustavo | BUILT | C6 | | | |
| H15 | Raise fullscreen or maximized target by lowering others | PR 16412 | PARTLY | S8 table says focus plus `alter_zorder top` works for maximized and fullscreen here (`research/spikes.md`); core issue 16241 still OPEN; untested: other workspace, dialog, XWayland | medium | M | See L3 |
| H16 | Un-fullscreen others before focus | x-mode | NOT BUILT | not needed per S8 | low | S | Only if H15 fails |
| H17 | Minimize via special workspace, "focus mode" | jakubkozera | PARTLY | minimize via Omarchy script (`omahop.lua:284`); no minimize-others | low | S | Niche |
| H18 | Workspace-grouped list | alttab | NOT BUILT | see C10 | low | S | Skip |
| H19 | Jump numbers, per-bind profiles | luwojtaszek | PARTLY | numbers built, profiles are C7 | high | L | See C7 |
| H20 | Dynamic binds, safe uninstall | luwojtaszek | BUILT | `omahop.lua:226` unbinds exactly at session end; install is one line the user deletes (README) | | | |
| H21 | Degrade when capture is missing | omaswitch | BUILT | `Service.qml:113-121` null toplevel shows the icon | | | |
| H22 | Model files with tests | omaswitch, expose | BUILT | `State.js`, `PeekModel.js`, `IconResolve.js`, four Node tests | | | |
| H23 | Live Wayland test suite | omadock | BUILT | `tests/live_*.py`, nine scripts | | | |
| H24 | Search inside window content (OCR) | omaswitch | REJECTED BY RULE | needs tesseract: "nothing else to install" (README), slow, privacy | | | |
| H25 | Media and `playing` keywords | window-gallery | NOT BUILT | none | low | M | Mpris installed; a widget. Skip |
| H26 | Hot corner trigger | expose | OUT OF SCOPE | overview product | | | |
| H27 | Pointer never warps on card click | macos.dock, spaces | BUILT | no `cursor.move` in code, `live_pointer.py:44,91` | | | |
| H28 | Both Alt keys and the Meta modmask matrix | jburchel | PARTLY | polls Alt_L and Alt_R (`omahop.lua:255`); right Alt only in the fake-Hyprland test (`test_glue.lua:69`), no live test (`ralt` exists in `uinput_kbd.py:17`, unused) | medium | S | Add a live check |
| H29 | Modifier other than Alt (Super, Ctrl) | jburchel, luwojtaszek, issue 7838 | NOT BUILT | `"ALT + TAB"` hard-coded (`omahop.lua:474`), session chords `ALT +` (`:16`), `same_app_key` must start with ALT (`:373`) | high | M | Mac and Windows users ask for it. Super+Tab is the stock workspace cycle in Omarchy: needs `takeover`-style care |
| H30 | Summon by IPC without Alt (sticky) | core PR 16548 | NOT BUILT | grep: no IPC entry to open a session | low | M | Overlaps the "keep the list open" idea (other agents) |
| H31 | Hyprland group (tab) windows | OMT | NOT BUILT | `omahop.lua:80` drops `hidden` windows, which are the inactive tabs of a group; Omarchy binds `SUPER + G` for groups (`tiling.lua:86`) | medium | M | Inferred from code, not tested live. Tiling mostly, so low impact at default scope |

### 1e. Lessons that are requirements (L1 to L17)

| Id | Requirement | Status | Evidence | Value | Eff | Fit and risk |
|---|---|---|---|---|---|---|
| L1 | Alt tap must not open the app menu | PARTLY | F24 injection (`omahop.lua:385`); verified on Qt only (`README` known limits, `validation-checklist.md` GTK, Chromium, Electron unchecked) | high | S | Hand check, not a build. A miss would be a visible bug for browser users |
| L2 | Focus not refused by the overlay | BUILT | `Service.qml:211`, `live.py:56` pick lands | | | |
| L3 | Raise floating windows | PARTLY | `omahop.lua:166`, `live.py:48,57` (pixel check), S8; untested: other workspace, two monitors, dialog over owner, XWayland | medium | S | Extend `tests/spikes/s8_raise.py` |
| L4 | Skip ghost windows | BUILT | `windows.lua:20`, `test_windows.lua:17`; no live Wine or Proton run | | | |
| L5 | Both Alt keys | PARTLY | see H28 | medium | S | |
| L6 | No capture of a vanished output | PARTLY | no code guard; one manual unplug pass 2026-11-07 (`validation-checklist.md`), `test_monitors.lua` unplug model | medium | S | Capture is by toplevel, which the compositor drops. Keep the hand check on each release |
| L7 | Never reload config from the plugin | BUILT | no reload in Lua; the settings window runs `hyprctl reload` only on a user click for `takeover` and `same_app_key` (`SettingsStore.qml:60`). Tension with the lesson, by choice | | | |
| L8 | Bind lifecycle on hotplug | BUILT | `test_glue.lua:63-66` loading twice leaves the same binds; no real hotplug test | | | |
| L9 | No pointer warp | BUILT | H27 | | | |
| L10 | Tap versus hold is a tested state machine | BUILT | `session.lua`, `test_session.lua` | | | |
| L11 | List with 100 windows scrolls with selection | PARTLY | ListView with follow (`ListStyle.qml:45`, `CardsStyle.qml:62`); no test with 100 windows | medium | S | Add a model test and one live run |
| L12 | Minimized order and restore | BUILT | `mru.lua:24`, `test_mru.lua`, `live_cards.py:60` | | | |
| L13 | Dialog or owner windows | NOT BUILT | grep `dialog\|owner\|transient`: none | low | M | Dialogs list as separate rows. Define behaviour before code |
| L14 | Titles read from the window list | BUILT | `omahop.lua:114`, state file carries titles from `hl.get_windows` | | | |
| L15 | Thumbnail cost bounded | BUILT | B59 | | | |
| L16 | Fullscreen game takes focus back after a switch | NOT BUILT | grep `focus_on_activate`: none; core PR 16548 ships `foreground-lock.lua` for it | medium | M | Needs a Proton game to test. `passthrough_fullscreen` avoids the problem when switching away from a game, not toward one |
| L17 | Settings to narrow the list | BUILT | `spec.json`, 24 settings | | | |

### 1f. Counts

Counted from the status column of the tables above (176 rows; C2b and C3b are split-out rows).

| Status | Count |
|---|---|
| BUILT | 73 |
| PARTLY | 37 |
| NOT BUILT | 49 |
| REJECTED BY RULE | 6 |
| OUT OF SCOPE | 11 |

By table: Contexts 33 rows, BetterCmdTab 65, F-keys 30, highlights and techniques 31, lessons 17. Several rows point at the same underlying gap (for example C11 and B31, C7 and B36 and F23), so distinct gaps are fewer than the NOT BUILT and PARTLY counts.

## 2. NOT BUILT items by theme

| Theme | Items | Fits omahop? |
|---|---|---|
| Search and discovery | C11/B31 matching quality, C13 learned shortcuts, B32 launch from search, H24 OCR, H25 media keywords | Matching quality and learned shortcuts fit (pure Lua, no widget). Launch and OCR do not: another tool owns launching, OCR needs a package |
| Switching behaviour | H29 modifier choice, B10 visible-spaces scope, B8 sorts, B14 apps-only, B38, C10 grouping, H31 group tabs, L13 dialogs, L16 game focus | Modifier, visible-spaces, group tabs, game focus fit. Sorts and grouping fight MRU |
| Profiles | C7, B36 to B38, F23, H19 | Fits and was always planned; the cost is the settings window design (L) |
| Window actions | C17 and B47 quit and minimize keys, H5 confirm, H11 stable id, B46 extra buttons | Quit and minimize keys fit (S). Extra buttons add clutter |
| Appearance | B3, B7, B55, B58, B64 localization | Mostly fight "follows theme". Localization is the one worth a look |
| Privacy and safety | H6 thumbnail exclusions, B62, L6 | H6 fits (S). B62 impossible with layer-shell |
| Integrations (audio, media, notifications) | B43, B44, H4, H25, F26 | Opt-in audio marker only. Rest are new widgets |
| Input (gestures, layout) | B51 swipe, C20 edge gesture, B49 layout-independent keys, B48 vim | Swipe fits (now possible). B49 is a correctness risk to check. Vim conflicts with search |
| Display | C22 and B5 list on all or cursor monitor, B7 position | Display setting fits (S) |
| macOS-only | C25, C27, C30, B13, B35, B45, B53, B54, B65 | Out of scope, or Omarchy already covers it |

## 3. Ranked shortlist (top 10 to build next)

| # | Candidate | Why | Effort | Depends on |
|---|---|---|---|---|
| 1 | Search matching: fold diacritics, subsequence and acronym ranking (C11, B31) | Search is the daily path and today needs substrings; typing is ASCII only, so "acao" must find "ação" | S | `search.lua` and `test_search.lua` only |
| 2 | Modifier setting: Alt, Super or Ctrl (H29) | Open core issue 7838 and three rival plugins show demand; Mac and Windows habits | M | `session_keys` and bind code made modifier-aware, polling keys, a live test per modifier |
| 3 | Thumbnail exclusions (H6) | Cards snapshot every window, including password managers; one list setting gives icon-only for them | S | `Rules.set`, `CardItem.qml`, settings row |
| 4 | Extra shortcuts with their own window set (profiles: C7, B36 to B38) | The promised "Later: profiles"; "this workspace" and "all monitors" on a second chord | L | Settings window design for a repeating group; bind lifecycle test (L8) |
| 5 | Quit app and minimize by key (C17, B47, H8) | Closing three windows of one app, or hiding one, without the mouse | S | `session_keys` (non-letter chords), Omarchy minimize script |
| 6 | Overlay display choice: focused, cursor or all screens (C22, B5) | Multi-monitor users get the list where they look | S | `Variants` over screens in `Service.qml`, capture per screen |
| 7 | Fullscreen game focus bounce-back (L16) | Switching to a Proton game can lose focus again; core ships a lock for it | M | A Proton game on the test machine, a live test |
| 8 | Visible-workspaces scope (B10) | "Windows I can see on any monitor" is the natural multi-monitor list | S | One enum value in `windows.lua`, `test_monitors.lua` |
| 9 | Touchpad swipe trigger via `hl.gesture` (B51) | Tablet and laptop users without a keyboard; the old reason ("raw input") is stale | M | Test of what a gesture action fires on; Omarchy's own workspace swipe config |
| 10 | Audio-playing marker, opt-in (B43) | Find the window with the call or music; `Quickshell.Services.Pipewire` is installed | M | Stream to window match; default off (new glyph) |

Debt that should come before or with these (not features): the GTK, Chromium and Electron Alt-menu hand check (L1), right Alt live test (H28), 100-window test (L11), raise cases (L3), non-US keyboard check for typing (B49), group-tab windows (H31).

Would NOT build:
- Launching apps or reopening closed ones from search (B32, C25, B13): Omarchy's launcher and launch-or-focus own it; duplicates a bigger tool.
- OCR search (H24): needs a package, slow, reads window pixels.
- Overview grid, hot corner, own dock, window tiling, hide-all (F19, H26, B53, B54): other products or omagnet.
- Sound, haptics, colours, fonts, opacity, motion knobs (B52, B55 to B58): fight "follows theme" and slim.
- Vim keys, one-hand and home-row hints (B27, B28, B48): letters already type into search.
- Pointer warp (B6): breaks L9.
- Dock or Sidebar badges, Handoff (B44, B45): guesswork or Apple only.
- Manual reorder, group-by-workspace headers (C10, C31): fight MRU.
- Export and import (B61): copying one file does it.

## 4. Mapped as rejected or deferred: reasons that may be stale

| Item | Earlier reason | Where | Check on this system | Verdict |
|---|---|---|---|---|
| Trackpad gestures | "needs raw input", C20 "hard, skip" | `v0.4-plan.md`, `contexts-reference` | Hyprland 0.56.2 stubs: `hl.gesture(spec)` with `fingers`, `direction`, `action` (function or string) | Stale for swipe triggers. Edge-start two-finger scroll (C20) still impossible. What the action fires on is unverified |
| Audio badges | "anything that needs raw input" | `v0.4-plan.md` | Quickshell 0.3.2 ships `Services.Pipewire`, `Mpris`, `Notifications` | Stale. Feasible, still opt-in |
| Lone-modifier Fast Search | needs press and release of a modifier | `contexts-reference` C14 | D14 dynamic binds now type letters during a session (`live.py:95`) | Half stale: Alt+Tab, type, release works; a Tab-less entry still would steal Alt+letter |
| Hold and release needs `bindr` | C3 "binds cannot see modifier release" | `contexts-reference` | S9: polling `hl.is_key_down` works, binds miss it | Solved, not stale |
| Hover preview on the stock dock | no hook (D8) | `decisions.md` | `Dock.qml` IPC handler has only `refresh` and `apps`; PR 16609 (dock hook) OPEN, PRs 16219 and 16479 OPEN (gh, 2026-11-07) | Still valid |
| Plain switcher redundant if core merges | D9 | `decisions.md` | PR 16548 OPEN, last update 2026-11-02; `/usr/share/omarchy/shell/plugins` has no switcher; Omarchy 4.5.0-3, Hyprland 0.56.2, Quickshell 0.3.2 | Still valid, re-check before each release |
| Generic user profiles | would break the one-window rule | `v0.4-plan.md` | Settings window exists and groups are generated from `spec.json` | Reason weakened: needs a design, not a ban. Ranked #4 |
| Focus does not raise maximized or fullscreen | S8 table | `research/spikes.md` | `on_focus_under_fullscreen = 1` in `looknfeel.lua:113`; core issue 16241 and PR 16412 still OPEN | Conflict between S8 and the upstream bug: re-test with other workspace and XWayland before trusting |
| Dialogs and owners | "define in the design" | L13 | no handling in code | Open, never built |
| Fullscreen game bounce-back | "not v0.1" | L16 | not built | Open |
| Direct app hotkeys | n/a | B35 | Omarchy 4.5 binds use `focus = ...` and `omarchy-launch-or-focus` | Covered by the OS |
| Minimize from cards | floating workspaces only | `v0.3.0.md` | `omarchy-hyprland-window-minimize` exists; still floating only | Unchanged |
| Stock-dock icons from outside | geometry cannot be derived | `competitors-docks.md` | unchanged | Valid |

## 5. Already on the roadmap (context only, other agents are evaluating)

1. Keep the list open while you search (`search_linger_seconds`): related to B23, B33, H30.
2. Icon packs: no source item.
3. Browser tab search through an extension: related to B18, B34.

Not duplicated here.

## 6. Verification log and what I could not verify

Verified BUILT by reading code or tests (not by the docs): C3 and C3b (`session.lua:66`, `omahop.lua:253`, `live.py:47,56`), C4 (`mru.lua:44`), C6 (`omahop.lua:370`, `live_sameapp.py:50`),
C15 (`hints.lua:36`, `live_hints.py:48`), C23 and B41 (`windows.lua:17-30`, `live_rules.py:47`), C24 (`rules.lua:36`, `live_rules.py:58`), B21 (`Service.qml:211`),
B59 (`CardItem.qml`, `live_cards.py:59-63`), B60 (`config.lua`, `live_panel.py:52`), F27 (`omahop.lua:395`, `live.py:125`), L4 (`windows.lua:20`, `test_windows.lua:17`),
H2 (`session.lua:13`), H27 (grep: no `cursor.move` outside tests). The offline suite was re-run: `bash tests/run-all.sh --no-live` passes (unit, glue, 193 monitor checks, 207 icon entries, spec drift, plugin validate, qml syntax).

Verified NOT BUILT by grep over `*.lua`, `*.qml`, `*.js` (excluding tests): audio and media (`pipewire|mpris`, no hits), gestures (`gesture`, none), fuzzy and subsequence (none; `search.lua:19` is substring), notifications and badges (none), sound (`sound|canberra`, none), animation (`animation|Behavior`, none), quit or kill (none), pointer warp (none), group-tab handling (only the `hidden` drop at `omahop.lua:80`), localization (`I18n|qsTr`, none), dialog handling (none).

System checks (read only): `hyprctl version` 0.56.2, Omarchy 4.5.0-3, Quickshell 0.3.2, `/usr/share/hypr/stubs/hl.meta.lua` (gesture, `get_monitor_at_cursor`, `window.urgent` event), `/usr/share/omarchy/shell` (no switcher, dock IPC), `gh pr view` for 16548, 16219, 16479, 16609, 16412 (all OPEN).

Could not verify:
- Live tests were not run (they drive `/dev/uinput` on the real desktop; out of bounds for this task). Live claims rest on the test source and the batch log.
- Hand checks still unchecked in `validation-checklist.md`: GTK, Chromium and Electron Alt-menu, real keyboard feel, minimize from a card.
- Non-US keyboard layouts and accented characters for typing (B49): not tested, the system layout here is `us`.
- Whether `hl.gesture` actions fire at swipe start, update or end, and how they interact with Omarchy's workspace swipe.
- Grouped windows (H31): the `hidden` field behaviour is inferred from Hyprland semantics and the code, not observed.
- Marketplace submission state (ROADMAP and `v1.0-plan.md` disagree).
- Row titles as plain text in `ListRow.qml` and `CardItem.qml` (only two files confirmed).
- Wheel scrolling on the list and the 100-window scroll behaviour.
- Upstream issue states other than the PRs listed above (16241 checked open; 17724 is an issue, not a PR).

# Community code outside the covered projects (omahop research, 2026-11-06)

## Verdict (10 lines)

1. YES, others got there first. At least six public repos already ship Alt+Tab with live previews for Omarchy 4: sparkrussell, jburchel, jakubkozera, manateelazycat, rmacy (Mission Control 3.0.0), devmobasa.
2. Closest duplicate of the switcher half: **sparkrussell/omarchy-alt-tab-switcher** (hold-to-preview, MRU, ScreencopyView thumbnails, raises floating windows, written for Hyprland 0.56 Lua). omahop would not beat it on features alone.
3. Closest duplicate of the "Mac on floating workspaces" half: **timurguseynov/omarchy-x-mode** (floating, titlebars, snaps, dock, Command-Tab). It switches by APP icon with no thumbnails, and needs a hyprbars C++ plugin plus hyprpm.
4. Hover previews on a dock exist (hyprdrive, 0xJ1nn, already-covered docks). None does hover previews outside a dock.
5. Nobody found that is explicitly "floating-workspace-first" for the switcher: no switcher handles the Hyprland fullscreen/maximized-not-raised bug (omacom/omarchy #16241, #16973, #17724). That is omahop's real gap to own.
6. The Alt-release problem is SOLVED in public code (submap + global release bind with three flags). One repo (sroomberg) wrongly concludes it is impossible. Do not copy that.
7. Omarchy 4.5 now has a native floating workspace mode (hyprbars titlebars, `omarchy-floating-workspace`, Super+L cycles layouts). Hyprland itself has the stacking bug, so a plugin cannot fully fix click-through (#17724).
8. The ecosystem is huge: quantavil/awesome-omarchy-plugins indexes 2,600+ plugins; README lists ~194 lines matching switcher/overview/dock/snap terms. Expect more duplicates daily.
9. Unverified: I read source only and ran nothing on Hyprland. Behaviour claims below are from READMEs, comments and code, not live tests. Star counts are as of today.
10. Recommendation: treat omahop as "floating-mode correctness + cards/list in your theme", and study sparkrussell and jburchel before writing the key handling.

Licences: GitHub shows "other" for some, but their LICENSE files are MIT (checked x-mode, jburchel). Snippets below are short evidence only.

---

## Ranked finds

Format: repo, stars, last push, licence. All stars/dates from `gh` today.

### 1. sparkrussell/omarchy-alt-tab-switcher  (8 stars, 2026-10-26, MIT)
https://github.com/sparkrussell/omarchy-alt-tab-switcher
- **What**: hold-to-preview Alt+Tab with live thumbnails, MRU, mouse hover/pick, works across workspaces.
- **Stack**: a Lua module (`hypr/switcher.lua`) owns keys and selection; a Quickshell plugin (`Service.qml`) only renders. Switching still works if the plugin is off.
- **Window list**: `hl.get_windows()`, filter `mapped and not hidden`, sort by `focus_history_id`.
- **Hold/release**: enters a submap on Alt+Tab; commits on a global release bind for `ALT + Alt_L/Alt_R` (details in the snippet).
- **Previews**: Quickshell `ScreencopyView { captureSource: shown ? toplevelFor(address) : null }`, so capture only runs while the overlay is visible. Lua sends only window ADDRESSES to the overlay because socket2 truncates events at 1024 bytes; the overlay reads titles and classes from its own `Hyprland.toplevels`.
- **Raise**: `hl.dsp.focus({window="address:..."})` then `hl.dsp.window.bring_to_top()`.
- **Learn**: the whole protocol (below); 10 s idle timeout so the submap can never stay stuck; `window.close` handler refreshes entries; calling `Hyprland.refreshToplevels()` for windows opened since the last listing.
- **Traps noted in its comments**:
  - Hyprland refocuses the monitor's last window when a layer surface unmaps (LayerSurface.cpp onUnmap), which UNDOES the switch. Fix: remember the target and re-focus on the `layer.closed` event.
  - `hl.unbind` is not submap-aware; unbind Omarchy's ALT+TAB first.
  - HL.Timer has no `stop()`; use `set_enabled(false)`.
  - It ships no floating-specific raise fix (same dispatcher as stock, so it inherits #16241). Unverified: I did not test it.

Key technique (switcher.lua):
```lua
hl.define_submap(NAME, function() hl.bind("ALT + TAB", step_fwd, {repeating=true}) ... end)
-- three load-bearing flags (its comments cite Hyprland 0.56 KeybindManager.cpp):
for _, key in ipairs({ "ALT + Alt_L", "ALT + Alt_R" }) do
  hl.bind(key, function() if state.open then close(true) end end,
    { release=true, submap_universal=true, transparent=true, non_consuming=true })
end
```
Reason: a release bind matches the submap active when the key went DOWN (Alt goes down before the submap), `transparent` avoids shadowKeybinds, `non_consuming` lets apps see Alt go up.

### 2. jburchel/omarchy-alt-tab  (1 star, 2026-10-09, MIT)
https://github.com/jburchel/omarchy-alt-tab
- **What**: Alt+Tab, live previews, MRU, scope filter (all workspaces / current / current monitor), scratchpad windows optional, settings panel, tests (`tests/e2e.sh`, `bindings.test.lua`).
- **How**: Lua `snapshot()` serialises windows as `address@ws@monitor@pinned` into one string and sends it via `hl.dsp.event("omarchy-alt-tab:open;...")`; Quickshell parses it. Same submap+release design as #1, but binds release for EVERY modifier combination: `Alt_L, Alt_R, Meta_L, Meta_R` crossed with `{"", "ALT + ", "ALT + SHIFT + ", "SHIFT + "}`. Comment: "Meta_* is what Alt reports when Shift was already held" and "whether MOD is still in the modmask at release time varies".
- **Quick tap**: a `showDelay` timer (0-1000 ms) delays showing the overlay; a tap switches straight to the previous window with no flash. The overlay "never takes keyboard focus".
- **Focus**: `Quickshell.execDetached(["hyprctl","dispatch","hl.dsp.focus({ window = \"address:...\" })"])`. Always `submap reset` first, so the keyboard cannot stick.
- **Learn**: the Meta_L/Alt_R modmask matrix is the edge case omahop would otherwise find by bug report; plugin loads its Lua via `loadfile` from `bindings.lua`, a no-op if the plugin is removed (clean uninstall).
- **Trap**: user must edit `bindings.lua` by hand. Raise is focus only (no bring_to_top seen in Switcher.qml, unverified elsewhere).

### 3. timurguseynov/omarchy-x-mode  (9 stars, 2026-11-05, MIT)
https://github.com/timurguseynov/omarchy-x-mode
- **What**: a Mac-like pack for Omarchy: its own `xmode` workspace layout (floating), Mac titlebars, same-app tabs, Rectangle-style snaps, a right-edge dock, Command-Tab (Super+Tab), Mac text shortcuts. 148 KB of Lua plus Quickshell QML plus a **hyprbars-based C++ plugin** (needs `hyprpm update`, headers).
- **Switcher**: apps, not windows. A row of icons, no thumbnails (`Switcher.qml`, 166 lines). Lua writes a command file (`$XDG_RUNTIME_DIR/omarchy-switcher.cmd`: `show <active> <classes...>` / `hide`) and QML watches it. List is frozen when it opens and held while Super is down.
- **Own MRU**: tracks MRU per CLASS and records nothing while the switcher is held, because cycling rewrites Hyprland's `focus_history_id` and would scramble order. Good idea for omahop.
- **Hold/release**: a different technique from #1/#2, a raw key event hook (keycode 133/134 = Super_L/R). Unverified that this event fires for modifiers on 0.56, but the pack ships it.
- **Raise (key finding)**: its comment says a focus dispatch NEVER raises a floating window, `bring_to_top`/alter_zorder re-entered a tab drag and froze the compositor, so it calls `hyprbars.raise` through a plugin API on every `window.active`:
```lua
hl.on("window.active", function(w)
  if not raising and bars().raise and w.floating then
    raising = true; pcall(bars().raise, w); raising = false  -- guard re-entry
  end
end)
hl.on("input.keyboard.key", function(keycode, _, state)
  if switcher_active and state == 0 and (keycode == 133 or keycode == 134) then switcher_hide() end
end)
```
- **Fullscreen**: before focusing an app it un-fullscreens every other window (`leave_fullscreen_for`), because a fullscreen window "would take that focus straight back".
- **Trap / conflict**: its own `Switcher.qml pick()` comment says `window.active` raises the floating window, while the Lua comment says focus never raises. Contradiction in the same repo, so test raise on 0.56.2 yourself before trusting either.
- **Learn**: omahop must define behaviour when the workspace is in Omarchy's native floating mode, x-mode's `xmode`, or tiling. x-mode explicitly "hands the keys back to Omarchy" outside its own mode. It also supports Omarchy 4.0.x with its own state file, because workspace modes only arrived in 4.5.
- **Overlap risk**: highest. A user wanting "macOS on Omarchy" already gets Command-Tab, dock and snaps here. Not previews.

### 4. dragosol/hyprdrive-omarchy  (51 stars, 2026-11-04, BSD-3)
https://github.com/dragosol/hyprdrive-omarchy
- **What**: mission-control overview (tap Super), full dock with stacks, "Mosaic" layout, hot corner, settings panel, dock hover live window previews. No Alt+Tab found (grep of the README and sources, unverified in code).
- **How**: a C++ Hyprland plugin (65 .cpp files) with function hooks into compositor internals (`findFnOrThrow("shouldRenderWindow", ...)`, `createFunctionHook`). Previews are real compositor-rendered window textures, not screencopy.
- **Learn**: this is the high-quality, high-cost route. Price: README says after a Hyprland update the plugin "may refuse to load with `[he] Version mismatch`"; ships its own `hyprdrive update` command and pins "built against Hyprland 0.56.2".
- **Trap**: hooking private symbols breaks on every Hyprland bump. omahop's Lua + Quickshell route avoids this. Do not go this way.

### 5. jakubkozera/omarchy-window-switcher  (0 stars, 2026-10-30, MIT)
https://github.com/jakubkozera/omarchy-window-switcher
- **What**: Alt+Tab grid with live previews, type-to-filter (title/class/workspace), close button on a preview (Delete key), plus MINIMIZE (Hyprland has none) via a hidden `special:minimized` workspace and a bar widget showing minimized windows with hover preview. Minimized windows appear dimmed in the switcher and restore on select.
- **Learn**: minimize-as-special-workspace is the standard trick; "focus mode" (minimize all others on the workspace). Closing from the preview while still switching is a nice feature.
- **Trap**: unverified how it handles the release bind (not read in detail).

### 6. rmacy/omarchy-mission-control  (0 stars, 2026-08-31, MIT) and archived rmacy/omarchy-alt-tab
https://github.com/rmacy/omarchy-mission-control
- **What**: the Alt-Tab was merged into Mission Control 3.0.0 (standalone repo archived). Alt-Tab scope is the ACTIVE workspace of the focused monitor only.
- **How**: README says each space card "composes Hyprland's real window geometry with captured client surfaces, so tiled and floating windows appear where they actually live"; selected space live, inactive ones not.
- **Focus**: revalidates by Hyprland **stable ID** before focusing, then raises:
```lua
hl.dispatch(hl.dsp.focus({ window = "stableid:<id>" }))
hl.dispatch(hl.dsp.window.bring_to_top())
```
It runs this through `hyprctl eval`. Titles rendered as plain text; icon names accept theme identifiers only (paths/URLs rejected). Good security detail for omahop (titles are attacker-controlled).
- **Learn**: use stable IDs instead of addresses so a reused address can't focus the wrong window.

### 7. manateelazycat/omarchy-window-switcher  (8 stars, 2026-10-13, MIT)
https://github.com/manateelazycat/omarchy-window-switcher
- **What**: combo of "Orbit" window switching and "Overview Workspaces". Alt+Tab (windows, per workspace or per monitor) and Super+Tab (workspaces grid). Zero config: it registers shortcuts at RUNTIME and re-installs them after a Hyprland config reload.
- **Trap**: replaces Omarchy's built-in workspace bar widget while enabled, and conflicts with Orbit/Overview if installed separately ("two plugins compete for the same global shortcut"). Lesson: omahop needs a collision story with other switchers. At least a `hyprctl binds` check at startup.

### 8. sroomberg/omarchy-window-switcher  (0 stars, 2026-09-28, MIT)
https://github.com/sroomberg/omarchy-window-switcher
- **What**: a bash script (`hypr-cycle-window.sh`) + QML HUD. Cycles all workspaces, follows to the window's workspace, macOS-style HUD.
- **How**: calls `hyprctl clients -j`, sorts by `focusHistoryID`, caches icons from `.desktop` files, persists a session file in `~/.local/state/omarchy/window-switcher/`.
- **Alt release**: claims it "never fires" on physical hardware and instead ends sessions by a 3 second time-out. CONFLICTS with #1 and #2, which fix this with the three flags. This author likely lacked `submap_universal`/`transparent`. Unverified by me, but the time-out design is clearly the weaker approach.
- **Learn (bug class)**: it found the stale-session bug: a session with an address of a closed window must be discarded. Take as a test case.

### 9. 0xJ1nn/omarchy-dock  (0 stars, 2026-09-22, MIT)
https://github.com/0xJ1nn/omarchy-dock
- **What**: macOS-grade dock with hover previews on running apps (title + Minimize/Maximize/Close).
- **How for previews**: NOT screencopy. A `grim` region screenshot of "the hovered app's visible window" refreshed on a timer, written to `/tmp/dock-preview-<user>.png`.
- **Trap (important for floating mode)**: a region grab captures whatever is on top, so an occluded floating window shows the window covering it. It also falls back to states "minimized"/"elsewhere". Screencopy per toplevel (as in #1) avoids this. Hover popups have a 30 s hard cap because MouseArea exit does not fire when the pointer leaves through a layer boundary.

### 10. mjmanzini/omarchy-macos  (0 stars, 2026-10-02, MIT)
https://github.com/mjmanzini/omarchy-macos
- **What**: one-command macOS look and feel: hyprbars traffic lights, `nwg-dock-hyprland` dock, Hyprspace or hyprexpo for Mission Control (Ctrl+Up), Super+Tab cycles windows, Super+M minimise.
- **How**: glue of existing Hyprland plugins via `hyprpm`, with `lib/patch-plugins.py` to patch them. Older style (before Omarchy's plugin system).
- **Learn**: shows demand and the cheap route, but depends on hyprpm plugin headers matching the compositor (same fragility as #4).

### 11. hudrucan/omarchy-gridnet  (0 stars, 2026-11-05, MIT) and georgeantonopoulos/omarchy-snap, JeoCrypto/omarchy-snap-layouts
https://github.com/hudrucan/omarchy-gridnet
- **What**: snapping for Omarchy native floating workspaces: edge and corner previews that follow the accent colour, drag-away restores size, keeps a titlebar grip on-screen, respects panel reservations and gap. Has a Python integration test (`tests/integration.py`). Tested on Omarchy 4.5 rc3, Hyprland 0.56.2.
- **Relevance**: not a switcher, but same audience, and omahop's sibling omagnet overlaps it directly (snapping). Mention only.

### 12. offGustavo/hyprland-alt-tab  (9 stars, 2025-12-05, MIT)  (generic Hyprland, not Omarchy)
https://github.com/offGustavo/hyprland-alt-tab
- **What**: a shell script alt-tab with flags `--reverse`, `--visible` (visible on active monitors only), `--same` (same app class), smart fallback when a filter empties, session memory across quick presses, optional `dim_inactive` as a visual cue.
- **Learn**: `--same` (cycle one app's windows) is a useful feature that no Omarchy switcher listed here seems to provide (not checked everywhere). No preview, hyprctl-only; pre-Lua config era so the keys will not work unchanged.

### 13. Newstrife/omarchy-tweaks  (0 stars, 2026-08-28, no licence)
https://github.com/Newstrife/omarchy-tweaks
- Personal dotfile (Chinese README). Windows-style Alt+Tab replacement in `bindings.lua`: frozen snapshot list per session, MRU order, current workspace only, target window is MAXIMIZED, previous window's fullscreen state restored, session expires 1 s after last key via `hl.timer` (note: ms units). Only evidence that dotfile users reach for maximise-on-switch; it also walks into the #16241 bug family. No licence, so ideas only.

### 14. Other plugin names seen, not opened (verify before relying on)
- ewweberlin/QuickSwitch (4 stars, MIT): Hold Super, tap Tab, release to switch; ships `task-switch-bindings.lua`, `Service.qml`, `logic.js`. Not read in depth.
- m4rone/omarchy-slicetab, taisau/omarchy-bottom-launcher (Alt+Tab rising switcher), StavWasPlayZ/omarchy-jump-to (searchable window switcher, drill into app windows), stefansdev/omarchy-app-switcher, eddygarcas/omarchy-workspaces-preview, Woogy7/omarchy-workspace-switcher (Alt+Tab through workspace previews).

---

## Lists and tweak repos (window management content)

- **aorumbayev/awesome-omarchy** (711 stars, 2026-11-05, CC0): curated list. Not read in detail.
- **quantavil/awesome-omarchy-plugins** (1 star, 2026-11-01, CC0): auto-built index of 2,600+ plugins (`plugins.json`, `BY_UPDATED.md`). Best single file for duplicate checks: `grep -i` on `plugins.json`. I counted 194 README lines matching switcher/overview/dock/snap/float.
- Other lists: mirarr-app/awesome-omarchy, minimallyexceptional/awesome-omarchy, seyhunak/awesome-omarchy. Themes lists skipped.
- "omarchy-extras"/"omarchy-tweaks" repos found are personal dotfiles (Jabbslad, gstrand99, Newstrife, etc.). Only Newstrife touches window switching. None is a community "pack" except x-mode.
- **omacom/omarchy forks** (30 forks; top by stars: omarchy-mac 2065, omarchy-mx-mac 418, okimarchy 125, omnixy 91): the top ones are Apple Silicon / Mac-hardware ports (`omarchy-mx-mac` description: Arch Linux ARM / Asahi compatibility), not window-management changes. No fork with window-switching commits ahead found by star ranking. Unverified: I did not diff each fork.

## Upstream issues omahop must read (omacom/omarchy; basecamp/omarchy redirects)

| # | State | What | Why omahop cares |
|---|---|---|---|
| 16241 | open | Fullscreen window on a floating workspace is focused by Alt-Tab but never raised | Root cause is in Hyprland: focusing a floating window while another is fullscreen sets `allowedOverFullscreen` (FocusState.cpp); renderer draws those after the fullscreen window (Renderer.cpp); `bring_to_top` only reorders the stack. Proposed Omarchy fix (PR #16412): when the target is fullscreen/maximized, lower the other windows beneath it, top down, keeping pinned windows visible. A custom switcher should copy this logic. |
| 16973 | open | RC2: stacking breaks when switching back to a maximized window | Same bug, with "maximized". Alt+Tab on non-maximized floating windows works. |
| 17724 | open | Clicks on floating windows over a maximized window pass through to the maximized one | Input side of the same bug; "needs an upstream fix", so omahop cannot fully fix it. |
| 7838 | open | Proposal: Super+Tab for windows (macOS muscle memory) | Shows demand; omahop's modifier should be configurable (jburchel does Alt/Super/Ctrl). |
| 12117 | open | Alt+Tab does not follow adjacent windows in scrolling layout | Layout-awareness trap. |
| 12179 | open | Pinned pop-out window stays foreground across workspaces | Pinned windows must be handled specially (fix for #16241 keeps them visible). |
| 17078 | open | Shell and fcitx5 crash (E2BIG, message > 4096) on long window titles | Truncate titles before sending to the shell. |
| 15996 / 16974 / 17736 | open | Floating mode adds duplicate titlebars on CSD apps | Related to hyprbars, not omahop, but affects thumbnails (titlebar included or not). |
| 12546 | closed | Screenshot picker's unbind takes the user's own TAB/CTRL+TAB binds | `hl.unbind` collateral damage. Unbind only exact combos. |

## What omahop should take from this

1. Use the sparkrussell/jburchel input design: submap + global release binds with `release, submap_universal, transparent, non_consuming`; bind both Alt_L/Alt_R and Meta_L/Meta_R across modmask combos; always `submap("reset")` first; idle timeout as a stuck-keyboard guard.
2. Keep Lua as the owner of keys and state; the shell only renders. Send addresses (or stable IDs) not titles over `hl.dsp.event` (1024 byte socket2 limit; E2BIG in #17078).
3. Previews: Quickshell `ScreencopyView` bound only while the overlay is visible. Avoid `grim` region captures (wrong for occluded floating windows).
4. Raise: do not rely on `focus + bring_to_top` alone for fullscreen or maximized targets. Port the #16412 idea (lower the others) and test on 0.56.2. Treat x-mode's claim "focus never raises" as unverified until tested.
5. Add a quick-tap path (showDelay timer) and a window-close handler.
6. Keep an own per-session MRU if windows get focused during cycling (x-mode lesson).
7. Offer a modifier option (ALT/SUPER/CTRL) and a collision check with other switchers.
8. Differentiator candidates, none found in competitors above: floating-workspace awareness (detect Omarchy's workspace mode), the fullscreen/maximized raise fix, same-app cycling (`--same`), theme-matched card/list modes.
9. Avoid: C++ compositor plugins (hyprdrive, x-mode hyprbars) because of Hyprland version lock.

## Not done / unverified

- No live testing on Hyprland; all behaviour is from source and comments.
- Did not read: awesome-omarchy list contents beyond counts, QuickSwitch, jakubkozera release handling, jburchel's raise path in full, fork diffs.
- No gist or forum (Reddit, Discourse) search of non-Omarchy Hyprland scripts beyond `gh search repos`; WebSearch was not used.
- `gh search code` not used, so private-style dotfiles with a small star count may be missed.

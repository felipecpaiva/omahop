# omahop architecture

Status: design only, nothing is built yet (2026-11-06). Every claim marked UNVERIFIED needs a spike (see ROADMAP, phase 0).
Evidence lives in `docs/research/`. Feature lists are in `docs/dockdoor-reference/features.md` (D1 to D95) and
`docs/contexts-reference/features.md` (C1 to C31), `docs/bettercmdtab-reference/features.md` (B1 to B65, GPL-3.0, ideas only).

Competitors, community search and positioning: [competitive-analysis.md](competitive-analysis.md).

Principle: learn from others, do not copy ([lessons-from-others.md](lessons-from-others.md)).

Standing rules for all work: [engineering-standards.md](engineering-standards.md) (flexibility, scalability, code standards per language).

## What it is

A window switcher for Omarchy's floating workspace mode, with three faces:

1. **Cards switcher.** Hold Alt, press Tab: a horizontal strip of live window thumbnails with app icon and title (DockDoor style).
2. **List switcher.** Same trigger, but a vertical list: app icon, app name, window title (Contexts style).
3. **Hover previews.** Hover an app icon (dock) and a panel shows that app's windows with previews and quick actions (DockDoor style).

The user picks cards or list in the settings app. Everything follows the Omarchy theme live.

## Scope rule (setting, not a hard rule)

`scope` decides on which workspaces omahop takes over Alt+Tab:

| Value | Meaning |
|---|---|
| `floating` (default) | Only on floating workspaces. On tiling workspaces Alt+Tab behaves exactly as stock Omarchy. |
| `all` | Every workspace. |

The settings app exposes it. Design consequences:

- Stock Alt+Tab is bound in `/usr/share/omarchy/default/hypr/bindings/tiling.lua:57-60` as two binds per chord
  (`cycle_next` plus `bring_to_top` or `alter_zorder`). `hl.unbind("ALT + TAB")` removes both, so omahop's own handler must
  run the stock behaviour itself when the active workspace is out of scope. A test compares both paths against stock.
- Floating test: windows on a floating workspace carry the tag `omarchy-floating-workspace` (a maximized window loses it).
  The workspace mode is saved in `~/.local/state/omarchy/workspace-layouts/<id>.lua`
  (read with `omarchy-hyprland-workspace-layout-current`).
- With scope `floating`, a tiling workspace must see zero change: no overlay, no rebinding side effect, same focus result.

## Parts

```
 Hyprland Lua  (lua/omahop.lua, loaded from hyprland.lua by a guarded pcall, like omagnet)
   - overrides ALT+TAB and ALT+SHIFT+TAB
   - scope guard: out of scope -> run stock cycle_next + bring_to_top
   - keeps the MRU list (focus events)
   - Alt hold/release: polls hl.is_key_down("Alt_L"/"Alt_R") on chained one-shot timers (omagnet's super_down pattern); the keys come from the `modifier` setting's row in `lua/modifier.lua` (Control_L/R for Ctrl, D16)
   - key handling, as measured: the Tab bind is NOT `repeating` (stock Alt+Tab is not, and a repeating bind would rapid-cycle on a tiling workspace
     where the stock handler runs); during a session the same per-tick loop that polls Alt also polls `hl.is_key_down("Tab")`, and the first delay and repeat
     interval are settings. A release bind or a global shortcut cannot end the session: they miss the Alt release once another key was pressed (S9)
   - the Tab bind consumes the key, so the app under the overlay would see Alt down and Alt up and open its menu bar (L1); the handler injects a harmless
     key with `hl.dsp.send_shortcut` (F24) so the app sees a chord, not a tap
   - arrows, Esc (bind enabled only while the session is open), Enter
   - on release: focuses the chosen window
        |  small state file in $XDG_RUNTIME_DIR + a shell IPC call   (UNVERIFIED: exact IPC, spike S3)
        v
 Quickshell plugin  (repo root is the plugin, manifest.json at root, like omagnet)
   - overlay: one PanelWindow per screen, WlrLayer.Overlay, WlrKeyboardFocus.None (Lua owns the keys); the one exception is
     `search_linger_seconds` (D15): Exclusive while the state says grab=1, typed text sent back as set_query(seq, text)
   - cards or list view, ScreencopyView thumbnails, icons, theme from `import qs.Commons` (Color.*, Style.*)
   - hover panel (phase 4)
   - settings panel -> ~/.config/omahop/config.toml
```

Status: the split below is decided on evidence (D5, `research/spikes.md`). Why Lua owns the keys and QML only draws: the overlay must never take keyboard focus while Alt is held (focus changes would change the
window list order and fight the switch), and omagnet already proved the hold/release poll. Exception (D15, off by default): with `search_linger_seconds` on and a search typed, the overlay holds the keyboard from the first typed letter until the list closes; Lua writes `open=0` first and focuses the picked window from a short timer, because a focus call is ignored while a layer holds the keyboard. State file keys for it: `seq`, `grab`, `linger_ms`, `linger_rev`. The in-flight core PR
(omacom/omarchy#16548) and the marketplace plugin `omarchy-altswitch` split the work the same way (UNVERIFIED for the second).

## Browser tabs (v1.4, setting `browser_tabs`, off by default; D17)

```
 browser extension -> omahop-tabs helper -> $XDG_RUNTIME_DIR/omahop/tabs.<hostpid>.json   (separate repository, only while tabs.enabled exists)
 lua/omahop.lua: at the first typed letter of a session, `find` lists the folder, each fresh file is read and checked (lua/tabs.lua, lua/json.lua),
                 browser windows are matched to Hyprland windows (pid, then title and focus), and tab rows join the list after their window
 state file:     t <address> <class> <minimized> <active> <icon> <picture> <asleep 0|1> <nopic> <site> <title>   (QML draws TabRow in the list; a CardItem in cards with the site icon, or the page picture when browser_tab_previews is on, D25)
 Return on a tab row: hl.exec_cmd(tools/omahop-tabs-activate <hostpid> <tabId>)  -> FIFO tabs.<hostpid>.activate (non-blocking), then focus and raise
 pictures:        session start -> tools/omahop-tabs-request <dir> <hostpid> shown (every live host); a search -> `draw <ids>` (draw setting on, visible tabs
                  without a picture, 6 a host, once a session); for 6 s after a request the tick re-reads the tab files every 400 ms and updates the picture
                  field and the `nopic` reason code (files only, no hyprctl; a lasting reason, unlike queued and limit, ends the wait). A picture name ending in d is drawn: the card says "approximate" (D26)
 setting on/off:  tools/omahop-tabs-files <dir> on|off|pictures-on|pictures-off|draw-on|draw-off   (from Lua at load and config change, from Service.qml at once and at unload)
```

Off: no file is read and none is made. Idle cost is zero: no watcher, no timer, nothing read on a quick Alt+Tab. The file contract as consumed: [file-contract.md](file-contract.md).

## Window list

Full settings model and combinations: [settings.md](settings.md). The text below is the default.

Default: windows tagged `omarchy-floating-workspace` on the current monitor's workspace, in MRU order, minimized ones
(on `special:minimized`) at the back, no scratchpad or console specials. Settings: all workspaces, all monitors,
include minimized, include specials. First Tab selects the previous window (Contexts principle), so a quick tap flips
between two windows.

## Thumbnails

Verified 2026-11-06 on this machine by a probe and a reviewed screenshot (`docs/research/thumbnails-and-prior-art.md`): `ScreencopyView` with a `Toplevel` as
`captureSource` shows real content for windows on other workspaces, with no permission prompt. Compositor advertises
`hyprland_toplevel_export` v2 and `ext_image_copy_capture`.

Not verified: minimized and special-workspace windows, occluded windows, CPU with 10 live views, frame rate.
CPU for 5 live views was roughly 7 to 19 percent for the shell and 14 to 19 percent for Hyprland, no clean baseline.
Design answer: `thumbnails = live | snapshot | off`. Default decided after spike S2. Snapshot means capture once when the
overlay opens (or only the selected card live), which bounds the cost.

Icons: `DesktopEntries.heuristicLookup` or `byId`, then `.icon`, then `Quickshell.iconPath(icon)`. Call it without the
second argument (`true` returned empty here). Since batch 15 omahop indexes the icon folders itself (`tools/icon-index.sh`, `IconResolve.js`);
since v1.3 a hand-made icon pack (`icon_pack`, `tools/pack-index.sh`) is a layer in front of that index, see `icon-packs.md`. The settings
window's pack editor (`PackEditorPage.qml` and its parts, logic in `PackEditor.js`) writes only through `tools/pack-edit.sh` and tells the
service to rescan the pack through `$XDG_RUNTIME_DIR/omahop/pack-changed`. Touch `ToplevelManager` and `DesktopEntries` early; they are lazy.

## Hover previews

Blocked on a decision, see `decisions.md` D8 and D11 (no new icons by default, so an own dock strip can only be an opt-in setting). The stock dock (`/usr/share/omarchy/shell/plugins/dock/`, floating
workspaces only) has no plugin hooks and no previews. Options: (a) upstream PR adding a hover hook to the dock,
(b) omahop ships its own small dock strip, (c) a click-through hover-detection layer over the stock dock (fragile).
Phase 4, after the switcher is solid.

## Theme

Read live from `Color.*` and `Style.*` (`import qs.Commons`) inside the shell plugin. omagnet's separate `qs -p` overlay
reads colours once at start, so omahop draws inside the shell where theme changes apply at once.

## Licensing

MIT. DockDoor is GPL-3.0, end-4 and caelestia are GPL-3.0: take ideas and feature lists, never code.

## Known traps carried over (details in omagnet `docs/gotchas.md`)

- Hyprland Lua is 5.5: loop variables are read-only; run unit tests with `lua`, not `lua5.4`.
- `hyprctl` socket error in agent shells: pick the live signature under `/run/user/1000/hypr`.
- The theme picker overlay (`omarchy-image-selector`) opens on shell reloads, takes keyboard focus, and makes focus calls fail. Escape closes it.
- Never create virtual (headless) monitors on a dev machine: Omarchy keeps ten workspaces per monitor ever seen.
- Releasing the modifier before the other key leaves no release handler (omagnet stuck-drag bug): always poll the modifier.
- Hyprland runs the press handler just before a release handler: a stop sent right after a start needs a short wait.

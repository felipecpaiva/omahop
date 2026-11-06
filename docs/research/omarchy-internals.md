# Omarchy internals survey for an alt-tab switcher + hover previews plugin

Machine: Omarchy 4.5.0-3 (`omarchy-version`; /usr/share/omarchy/version file still says "4.0.0.alpha", ignore), Hyprland 0.56.2-4, Quickshell 0.3.2 (Omarchy build). Read-only survey.

## Summary (10 lines)
1. EASY: Alt+Tab is bound only in Omarchy's defaults (`/usr/share/omarchy/default/hypr/bindings/tiling.lua:57-60`); override from `~/.config/hypr/bindings.lua` with `hl.unbind` + `hl.bind`, or from a Lua file loaded like omagnet's (`hyprland.lua:39`).
2. EASY: hold/release is solvable the omagnet way: `hl.is_key_down("Alt_L"/"Alt_R")` polled by chained one-shot timers; Tab presses arrive as repeated bind events.
3. EASY: a focusless layer-shell overlay with live theme colours (`qs.Commons` `Color.*`, `Style.*`) is a known-good pattern (omagnet `lua/preview.qml`, Omarchy Dock/Osd).
4. EASY: window thumbnails exist: `ScreencopyView` + `Hyprland.toplevels` / `ToplevelManager` (used by `tornikegomareli.spaces`, installed here, `Spaces.qml:1447`).
5. EXISTING: a dock already ships: `omarchy.dock` (`shell/plugins/dock/`), shown only on floating workspaces; it has icons, pinning, running dots, minimize restore, but NO hover previews. There is also no per-app taskbar in the bar; the installed `tornikegomareli.spaces` widget shows app icons per workspace WITH hover previews (workspace-level).
6. NO switcher/overview exists in the shell (no Alt+Tab list, no expose). Only `omarchy.dock apps` (app grid).
7. NO version gap on this machine: `Commons.ShellIpc` exists (`/usr/share/omarchy/shell/Commons/ShellIpc.qml`). The Z13 4.0.6 note is outdated here; 4.5.0-3 is present.
8. CAUTION: a plugin cannot load Lua by itself; user must add one guarded `dofile` line (omagnet README does the same). Alt+Tab mid-bind: the Lua handler must fall back to stock behaviour on non-floating workspaces.
9. CAUTION: `hl.unbind` removes EVERY bind on that chord (all 4 Alt+Tab binds die together); `hl.timer` has no handle (chain oneshots); the shell caches failed QML compiles (restart shell after first install).
10. DECISION NEEDED: previews on the dock require patching/duplicating first-party `omarchy.dock` (not a plugin hook), so hover previews are best attached to our own overlay (or the Spaces-style bar widget) rather than the stock dock.

## 1. Where Alt+Tab is bound, and how to override

File: `/usr/share/omarchy/default/hypr/bindings/tiling.lua` (package file, do not edit).
```
57  o.bind("ALT + SHIFT + TAB", "Reveal active window on top", hl.dsp.window.alter_zorder({ mode = "bottom" }))
58  o.bind("ALT + TAB", "Focus on next window", hl.dsp.window.cycle_next())
59  o.bind("ALT + SHIFT + TAB", "Focus on previous window", hl.dsp.window.cycle_next({ next = false }))
60  o.bind("ALT + TAB", "Reveal active window on top", hl.dsp.window.bring_to_top())
```
(comment at 55-56: going backwards lowers the window it leaves; bring_to_top moves the active window to the end of the list cycle_next walks.) So each chord has TWO binds that both fire. Related binds in the same file: `SUPER + TAB` next workspace (36), `SUPER + SHIFT + TAB` (37), `SUPER + CTRL + TAB` (38), `CTRL + ALT + TAB` / `CTRL + ALT + SHIFT + TAB` focus monitor (62-63), `SUPER + ALT + TAB` group next (94-95). `utilities.lua:58-59` uses plain `TAB` / `CTRL + TAB` only during a slurp region selection (not conflicting).

`~/.config/hypr/hyprland.lua` loads defaults (`require("default.hypr.omarchy")`, line 11) then user files (`hypr.monitors`, `hypr.input`, `hypr.bindings`, `hypr.looknfeel`, `hypr.autostart`), then omagnet at lines 37-39:
```
pcall(dofile, os.getenv("HOME") .. "/Work/omagnet/lua/omagnet-snap.lua")
```
(`pcall` so a broken file never breaks the config; gotcha: pcall hides load errors, debug with `hyprctl eval 'dofile("<path>")'`.) A final block (line ~42) loads `hyprmoncfg-monitors.lua` last.

Override without touching core files (Hyprland Lua 0.56; helper in `/usr/share/omarchy/default/hypr/helpers.lua:138-170`):
- `hl.unbind("ALT + TAB")` and `hl.unbind("ALT + SHIFT + TAB")` (removes ALL binds on the chord, both of each pair), then `hl.bind("ALT + TAB", fn, opts)`. Omarchy's own `o.rebind(keys, desc, dispatcher, opts)` (helpers.lua:~160) does unbind+bind. `~/.config/hypr/bindings.lua` template explains: "Change an existing binding by unbinding it first, then binding the key again."
- `o.bind` is a thin wrapper over `hl.bind(keys, dispatcher, {description=...})`; a dispatcher may be a Lua function (`hl.bind(keys, function() ... end, opts)`), as omagnet does (`omagnet-snap.lua:628,667-671`).
- Key strings join modifiers with `+` ("ALT + SHIFT + TAB").
- To keep stock behaviour outside floating workspaces: bind with `{ auto_consuming = true }` and return `{ ok = false }` for non-floating windows (omagnet `:667-671`), which passes the key on to the app, but that would NOT run Omarchy's cycle_next (it is unbound). So in the handler, for non-floating context call `hl.dispatch(hl.dsp.window.cycle_next())` and `hl.dispatch(hl.dsp.window.bring_to_top())` yourself.
- Only unbind once per Lua state (omagnet gotcha: unbind of a shared chord is not undoable; guard with a global flag so reloads do not stack).
- Hold behaviour helper: `o.bind_hold` (helpers.lua:222-260) gives press/release pairs but is built for single keys (push-to-talk), not "modifier held"; use polling instead (section 5).

## 2. Bar widgets, taskbar, dock, switcher

`~/.config/omarchy/shell.json` (read): bar position top, transparent. Layout entries:
- left: `omarchy.menu`, `tornikegomareli.spaces` (settings: previews true, previewSize medium, previewLive false, showApps all, groupApps false, iconStyle color)
- centerBegin: `omarchy.indicators`; center: `google-calendar.clock`; centerEnd: `omarchy.weather`, `io.github.jcarcinogen.gaming-console`, `omarchy.system-update`
- right: `omarchy.keyboard-layout`, `felipe.tray`, `io.github.felipecpaiva.omagnet`, `omarchy.elsewhen`, `esemczak.theme-modes`, `omarchy.agents`, `omarchy.bluetooth`, `omarchy.network`, `omarchy.audio`, `omarchy.monitor`, `omarchy.power`
- `dock`: `{ "autohide": true, "pinned": ["google-chrome","Herdr"] }`; `plugins`: `bobbynicholas.omaland`, `io.github.felipecpaiva.omabarconfigurator`.
Installed third-party plugins (`~/.config/omarchy/plugins/`): bobbynicholas.omaland, crmne.hyprmoncfg, esemczak.theme-modes, felipe.tray, google-calendar.clock, io.github.felipecpaiva.omabarconfigurator, io.github.felipecpaiva.omagnet, io.github.jcarcinogen.gaming-console, jankeesvw.notification-center, tornikegomareli.spaces.

First-party bar widgets (`/usr/share/omarchy/shell/plugins/bar/widgets/`): ActiveWindow, Indicators, KeyboardLayout (+Model), Microphone, Spacer, SystemUpdate, Tray (+Model), Workspaces. Plus plugin-dir widgets: menu, audio, bluetooth, clock, elsewhen, monitor, network, power, tailscale, weather, agents, media (list in `/usr/share/omarchy/shell/plugins/README.md`).

Is there a per-app taskbar? Not in the bar itself (no taskbar widget; `ActiveWindow.qml` shows only the focused window). BUT:
- `omarchy.dock` (`/usr/share/omarchy/shell/plugins/dock/`: Dock.qml 403 lines, DockWindow.qml 641, AppGrid.qml 517, DockModel.js 190) is an app dock "shown on floating workspaces, hidden on tiled ones and behind a fullscreen window" (plugins/README.md "Dock"). Features: pinned + running apps, windows matched to desktop entries (`DesktopEntries.heuristicLookup`, Dock.qml:36-53), minimized windows (workspace `special:minimized`, bar `SUPER + M`, `omarchy-hyprland-window-minimize`), click brings forward (Dock.qml `bringForward` via `hyprctl dispatch hl.dsp.focus` + `alter_zorder top`), drag reorder, autohide, app grid (`omarchy-shell omarchy.dock apps`), config via `omarchy dock`. It has NO hover preview and NO window list popup (grep found no Screencopy in it). It is a first-party `service` plugin with no extension hooks.
- `tornikegomareli.spaces` (third-party bar widget, installed): workspace pills with per-app icons AND hover thumbnail previews of a workspace's windows using `ScreencopyView` (`Spaces.qml:1447-1456`, captureSource = toplevel, `live`, `constraintSize`). Good code to copy for thumbnails.

Existing window switcher / overview? None. No Alt+Tab UI, no expose/overview in the shell. Only the dock's `apps` grid and the `omarchy.menu`. (Spaces' previews are workspace-level.)

## 3. Plugin API

Manifest schema (checker: `/usr/share/omarchy/bin/omarchy-plugin-validate`, mirror of `shell/services/PluginRegistry.qml:48-90`):
- Required: `schemaVersion` (number 1), `id`, `name`, `version`, `kinds` (non-empty array), `entryPoints` (object). Id regex `^[A-Za-z0-9][A-Za-z0-9._-]*$`, no `omarchy.*` (reserved), no `..`.
- Optional: `author`, `description`, `license`, `keepLoaded` (true keeps overlay/panel loaded between summons; used by osd, image-picker, emojis, lock), `barWidget` {displayName, description, category, allowMultiple, defaultSection (left|centerBegin|center|centerEnd|tray|right), defaults, schema[] of {key,type bool|enum|int|string,label,options,min,max,default}} (see spaces manifest).
- Kinds and required entry points: `bar`->`bar`, `bar-widget`->`barWidget`, `menu`->`menu`, `overlay`->`overlay`, `panel`->`panel`, `service`->`service`. No symlinks allowed in the plugin folder; entry points relative, exist, no `..`.
- Examples: `omarchy.osd` kind panel keepLoaded; `omarchy.image-picker` kind overlay keepLoaded; `omarchy.dock` kind service (entry `Dock.qml`, root `Item` with `shell` and `manifest` props, builds `PanelWindow`s through `Variants { model: Quickshell.screens }`); omagnet `manifest.json`: kinds [panel, service, bar-widget] with `SettingsPanel.qml`, `Service.qml`, `BarWidget.qml`.
- Add a bar widget: kind `bar-widget` + `entryPoints.barWidget` + `barWidget` block; the user enables it in the bar layout (omagnet's id is listed in shell.json bar.right). Widget root is `BarWidget` from `qs.Ui` with `moduleName` = plugin id, gets `settings` and `bar`. omagnet hides itself with `visible:false` and zero size (no gap).
- Add a panel / settings page: kind `panel` (on-demand, toggle with `omarchy-shell shell toggle <id>`; also `summon <id> '<json>'`, `hide`). Panels use `qs.Ui` `Panel`/`KeyboardPanel`/`PanelController` etc. (files in `/usr/share/omarchy/shell/Ui/`).
- Layer-shell overlay: kind `overlay` (fullscreen picker-type, e.g. `Ui/OverlayWindow.qml`, `plugins/image-picker/ImagePicker.qml`) or a service/panel that owns a `PanelWindow` with `WlrLayershell.layer: WlrLayer.Overlay` (Dock, omagnet's separate `qs -p` process).
- Service plugins: `Service.qml` root `QtObject` with `omarchyPath`, `shell`, `manifest` props (omagnet Service.qml:10-14); the shell passes `shell.appLibrary`, `shell.shellConfig`, `shell.defaultsConfig` (Dock.qml:15-21). Mounted at startup.
- Install: `omarchy plugin add <git-url> --enable` clones into `~/.config/omarchy/plugins/<id>/`; also `omarchy-plugin-{list,enable,disable,remove,update,clone,catalog,validate}`. After the FIRST install of a new plugin, `omarchy restart shell` (shell caches failed compiles; omagnet gotchas.md). Third-party `__sourceDir` is stripped: use `Qt.resolvedUrl("file")` (omagnet Service.qml:17-19). Enabled plugins listed in shell.json `plugins[]` (bar widgets via bar layout).
- LIVE theme colours: singleton `Color` in `import qs.Commons` (`/usr/share/omarchy/shell/Commons/Color.qml`). Base: `Color.foreground`, `Color.background`, `Color.accent`, `Color.urgent`, `Color.muted`. Surface groups: `Color.bar.{background,text,active}`, `Color.popups.{background,text,border}`, `Color.tooltip.*`, `Color.menu.{background,text,border,scrim,selectedBackground,selectedText,selectedBorder}`, `Color.notifications.*`, `Color.imagePicker.{text,selectedBorder,unselectedBorder}`, `Color.lock.*`, `Color.polkit.*`. Watches `~/.local/state/omarchy/current/theme/colors.toml` (Color.qml:15-17,228) so it updates live on theme change. Also `Style` (`Commons/Style.qml`: `Style.space(n)`, `Style.cornerRadius`, `Style.gapsOut`, `Style.hoverFill`, `Style.selectedFill`, `Style.normalBorderColor`, `Style.hoverBorderColor`, `Style.selectedBorderColor`, `Style.controlFill()`, etc.) and `Util` (`Util.alpha(color, a)`, `Util.shellQuote`, `Util.execDetached`, `Util.fileUrl`). Third-party plugins import them as `import qs.Commons` / `import qs.Ui` (omagnet BarWidget.qml:1-5). Spaces shows `Color.accent`, `Util.alpha` usage.
- Run shell commands: `Quickshell.execDetached([...])` (omagnet Service.qml), `Process { command: [...] }` from `Quickshell.Io` (SettingsStore.qml), `Util.execDetached("cmd")`, `root.bar.run("omarchy-shell shell toggle <id>")` from a bar widget, `shell.execDetached/execArgv` (`services/PluginShellApi.qml:68-78`).
- ShellIpc: `ShellIpc { target: "omarchy.dock"; function refresh(): void {...} }` (`Commons/ShellIpc.qml`, an `IpcHandler` that also registers on the shell's own socket via `IpcRegistry`); called with `omarchy-shell <target> <method>` (Dock.qml:Util.execArgv usage in shell.qml:1623) or `qs ipc`. Lets Hyprland Lua tell the shell "show switcher / advance / commit" via `hl.exec_cmd("omarchy-shell io.me.switcher next")` (costs ~45ms for `qs ipc`, less through omarchy-shell socket; per shell.qml:1658 comment).
- Version gap: the memory note (Z13 on 4.0.6, `Commons.ShellIpc is not a type`) does NOT apply now: `omarchy-version` = 4.5.0-3 and `Commons/ShellIpc.qml` exists. Shell log (`/run/user/1000/quickshell/by-pid/<pid>/log.qslog`, huge) showed no ShellIpc errors in the grep tail I checked, though I did not read it fully. Verify on the target machine at install time; fall back to file-based IPC (omagnet style) if needed.
- Persist settings: omagnet uses its own flat file `~/.config/omagnet/config.toml` read by Lua and QML (`SettingsStore.qml`, `FileView` with `atomicWrites`, 450 ms save debounce, `hyprctl eval "_G.omagnet.reload_config()"` to apply). Alternative: bar-widget `barWidget.schema` stored by the shell in `shell.json` per entry (Spaces: `settings`). Plugin settings for service/panels have no automatic store; use a file.

## 4. omagnet drag-zone outline overlay (template)

File `~/Work/omagnet/lua/preview.qml` (separate process `qs -p lua/preview.qml`, not part of the shell):
- `ShellRoot { Variants { model: Quickshell.screens; PanelWindow { ... } } }` one window per monitor.
- Window flags: `anchors { top,bottom,left,right: true }`, `exclusionMode: ExclusionMode.Ignore`, `color: "transparent"`, `mask: Region {}` (click-through), `WlrLayershell.layer: WlrLayer.Overlay`, `WlrLayershell.keyboardFocus: WlrKeyboardFocus.None`, `WlrLayershell.namespace: "omagnet-preview"`. For a switcher that must be clickable: drop the empty `mask` or set a Region over the card strip only.
- Data in: three tiny files in `$XDG_RUNTIME_DIR` (`omagnet-preview`, `omagnet-style`, `omagnet-zones`) watched by `FileView { watchChanges: true; onFileChanged: reload() }`.
- Start/stop: Lua `qs(arg)` = `hl.exec_cmd('qs -p "<dir>/preview.qml" ' .. arg)`; kill is `qs -p ... kill` (`omagnet-snap.lua:365`); started on first drag, stopped after `M.kill_ms = 400` ms (kill right after start finds nothing registered, so a stop waits and a start during the wait reuses the process: `:367-386`). An idle Quickshell is ~230 MB, so on-demand process. For a switcher, prefer a resident `service`/`overlay` plugin inside omarchy-shell (no extra process, cheaper at ~45 ms IPC) and show/hide a window.
- Theme: preview.qml reads `~/.local/state/omarchy/current/theme/colors.toml` once at start for `accent` (known shortcut: no live change). In-shell plugins instead use `Color.accent` from `qs.Commons` (live). omagnet's Lua also reads `hl.get_config("general.col.active_border")` (returns colour objects, use `tostring`) to match the active border.
- Keyboard focus: none; Alt/Tab handled by Hyprland binds + polling, so the overlay never needs focus (and must not steal it from the chosen window).

## 5. Hold / release mechanic (omagnet)

`~/Work/omagnet/lua/omagnet-snap.lua`:
```lua
-- :414-425  (comment 410-413: modifiers are matched at release time, so poll SUPER on every tick)
local function super_down()
  local seen_nil = false
  for _, k in ipairs({ "Super_L", "Super_R" }) do
    local ok, r = pcall(hl.is_key_down, k)
    if not ok or r == nil then seen_nil = true elseif r then return true end
  end
  if seen_nil then return nil end
  return false
end
-- :428  chained one-shot timers (hl.timer repeat type has no stop handle; use a generation number)
hl.timer(function() tick(gen) end, { type = "oneshot", timeout = M.following and M.follow_ms or M.tick_ms })
-- :455-475 MOD_KEYS = { ALT = { "Alt_L", "Alt_R" }, ... } ; extras_down() uses hl.is_key_down per key, nil = "cannot tell"
```
Rules learned (gotchas.md end): `hl.is_key_down` takes X key names with case (`"Alt_L"`, `"Alt_R"`, `"Shift_L"`, `"Super_L"`, `"Control_R"`); `"ALT"`, `"code:42"`, `"mouse:272"` return nil; nil must be treated as "cannot tell"; in Lua `x and nil or false` is false, so return nil with an explicit `if`; release of a bind is matched at release time, so a release bind is NOT reliable when the modifier is released first: count two consecutive ticks with Alt up as the commit. A bind's press handler can run a few ms near release. Pattern for the switcher: on first ALT+TAB press -> start session (snapshot window list, show overlay via ShellIpc or file); further ALT+TAB (and ALT+SHIFT+TAB) presses advance index (key repeat produces repeated bind events with `repeating = true` option on hl.bind); a tick (~30 ms) calls `alt_down()`; two ticks without Alt -> commit (focus + bring_to_top the selected window) and hide. Escape cancel needs its own bind (`ALT + ESCAPE`) enabled only while the session is on (see `utilities.lua:46-105` for the "enable binds only while a layer is on screen, disable rather than unbind" pattern).

## 6. Floating mode in Omarchy

- Not a Hyprland layout; per-workspace "mode". Files: `/usr/share/omarchy/default/hypr/workspace-modes.lua` (header comment lines 1-17), `workspace-layouts.lua`. State per workspace: `~/.local/state/omarchy/workspace-layouts/<id>.lua` containing `o.workspace_mode({ workspace = "1", mode = "floating" })`, with `default.lua` for the default mode. Read the mode with `omarchy-hyprland-workspace-layout-current [id]` (prints dwindle|scrolling|floating) or by parsing that file (omagnet `workspace_is_floating`, `omagnet-snap.lua:74-82`). Toggle: `SUPER + L` (`omarchy-hyprland-workspace-layout-toggle`, back with `SUPER + ALT + L`; tiling.lua:14-15). Current machine has workspace 1 floating.
- Tags: every window on a floating workspace gets `omarchy-floating-workspace` (WORKSPACE_TAG, workspace-modes.lua:22,45-47; titlebars, shadows, opacity follow it); windows the mode floated itself also get `omarchy-mode-floated` (claimed, restored to tiled when mode ends), `omarchy-mode-opened`, and a window-rule prefix `omarchy-floating-open-`. A maximized window loses the `omarchy-floating-workspace` tag (omagnet gotcha) so use the saved-mode file for `fullscreen == 1`. Moved to a non-floating workspace -> tag removed at once.
- Placement on open (`place()`, workspace-modes.lua ~122-146): resize min(1100, 64% width) x min(760, 68% height), centre, cascade 24 px up to 5 steps; special workspaces and named workspaces (negative id) keep their state (`floating_workspace()` returns false for id < 1).
- Title bars: from the native `omarchy-hyprland-titlebars` plugin `/usr/lib/omarchy-hyprland-titlebars/titlebars.so` (workspace-modes.lua:26,446-460) loaded once something floats. The user's `~/.config/hypr/hyprland.lua` line ~32 sets `o.window(".*", { ["hyprbars:no_bar"] = true })` (no bar anywhere; exceptions below it). Minimize: `SUPER + M` moves a window to the special workspace `special:minimized` with tag `omarchy-minimized-from-<ws>` (`bin/omarchy-hyprland-window-minimize`), only on floating workspaces; the dock restores them.
- Dock `omarchy.dock refresh` is called by the layout commands to re-read modes (Dock.qml `ShellIpc`).
- What a switcher list should contain (recommendation, drawn from the above): windows with tag `omarchy-floating-workspace` on the focused monitor's visible workspace (what stock cycle_next sees); optionally all workspaces, and windows on `special:minimized` (shown dimmed, restored by moving to the current workspace as `Dock.bringForward` does, Dock.qml); skip scratchpad/qconsole specials and windows with `toplevel.parent` (dialogs; dock does the same). On non-floating workspaces keep stock Alt+Tab. Use the omagnet `is_floating` test (tag OR fullscreen==1 with floating saved mode) for the guard. Hyprland's own order for cycle_next is the window list order, not MRU; for MRU, track focus events (`hl.on("window.active", ...)` or Hyprland raw event `activewindowv2`) to build your own list.

## 7. Quickshell version and QML modules

Quickshell 0.3.2 (Omarchy build, rev 2b4501a). QML under `/usr/lib/qt6/qml/Quickshell/`:
- `Quickshell.Wayland` (`Wayland/qmldir` pulls `_WlrLayerShell`, `_ToplevelManagement`, `_Screencopy`, `_BackgroundEffect`, `_IdleInhibitor`): present. Types: `WlrLayershell`, `ToplevelManager` (used in `/usr/share/omarchy/shell/plugins/bar/widgets/ActiveWindow.qml:13`, `services/AppLibrary.qml:172-178`: `ToplevelManager.toplevels`, `.activeToplevel`), `Toplevel` (appId, title, activated, minimized, maximized, fullscreen, parent, `activate()`, `close()`), `ScreencopyView` (captureSource, live, constraintSize, hasContent, sourceSize; used Spaces.qml:1447), `captureFrame`.
- `Quickshell.Hyprland` (`Hyprland/_Ipc`, `_FocusGrab`, `_GlobalShortcuts`, `_SurfaceExtensions`): present. `Hyprland.toplevels` / `.workspaces` / `.monitors`, `Hyprland.focusedMonitor`, `Hyprland.monitorFor(screen)`, `Hyprland.dispatch()`, `Hyprland.rawEvent`/`onRawEvent` (Dock.qml), `Hyprland.refreshToplevels/Workspaces/Monitors`, `HyprlandToplevel` with `.address`, `.workspace`, `.wayland` (a Toplevel handle for ScreencopyView), `.lastIpcObject`, `.activated`, `.urgent`; `HyprlandFocusGrab` (DockWindow.qml:255); `GlobalShortcut` is present (Quickshell global shortcuts need Hyprland `bind = ..., global, appid:name`; unproven here and omagnet chose Lua binds instead).
- `Quickshell.Widgets` (`/usr/lib/qt6/qml/Quickshell/Widgets/`): `IconImage.qml`, `ClippingRectangle`, `WrapperItem`, `WrapperRectangle`, `WrapperMouseArea`: present (the first-party shell does not import it in Dock; it uses `Image` with `appLibrary.iconSource(icon)`).
- Icons / desktop entries: `DesktopEntries` (`.applications.values`, `.byId`, `.heuristicLookup(appId)`) and `DesktopEntry` (`id, name, icon, noDisplay, runInTerminal, execString, command`) in `Quickshell`; `Quickshell.iconPath(name, true)` (check-fallback form). Best practice already in Omarchy: `shell.appLibrary.iconSource(icon)` (`services/AppLibrary.qml:57-69`: handles file:// and absolute paths, a pre-scanned icon index, then `Quickshell.iconPath`, then fallback `application-x-executable`); Dock matches a window to its entry with `entryForAppId` (Dock.qml:36-45) including terminal apps (`--app-id=`).
- Also present: `Quickshell.Io` (`Process`, `FileView`, `IpcHandler`, `StdioCollector`), `Quickshell.Services.*`, `Quickshell.I3`, `Quickshell.X11` (not relevant).
- Limits to remember: `ScreencopyView` previews need the toplevel-export protocol (works under Hyprland; Spaces uses it with `live` option and `constraintSize` at 2x). Live capture of many windows is expensive; capture only the selected/hovered ones or take stills. Minimized windows on `special:minimized` still capture? (not verified here). Screencopy of hidden/unmapped workspaces windows may be blank (Spaces shows a placeholder until `hasContent`).

## Open items not verified
- Whether an in-shell `service` plugin from third parties can show a PanelWindow with `WlrKeyboardFocus.None` and `Region` mask (Dock does so as first-party; omagnet does it only in a separate `qs` process).
- Whether `hl.bind` with `{ repeating = true }` fires repeated Tab events while Alt held (not tested; test with real uinput keyboard as omagnet does, `wtype` cannot trigger modifier binds).
- Latency of `hl.exec_cmd("omarchy-shell <target> <method>")` per Tab press (shell.qml:1658 claims faster than qs ipc ~45 ms).

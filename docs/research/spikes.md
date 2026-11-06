# Phase 0 spike results

Method: probe files in `tests/spikes/`, real key events through a virtual keyboard on `/dev/uinput` (same path as omagnet's live tests), Hyprland 0.56.2,
Quickshell 0.3.2, Omarchy 4.5.0-3, 2026-11-06. Caveat for all key results: the keyboard is virtual; a hand check with the real keyboard is in `validation-checklist.md`.

## S1 repeat: does a held Tab keep firing? YES

`hl.bind("ALT + F10", fn, { repeating = true })` (test chord, stock Alt+Tab untouched). Alt down, F10 held 1.2 s: the handler fired dozens of times
(about 25 ms apart after a first delay of about 250 ms, the compositor repeat). A Quickshell `GlobalShortcut` bound with `hl.dsp.global` and `repeating = true`
also fires `onPressed` repeatedly. A bind with `release` or `long_press` cannot be `repeating` (Hyprland error text: "long_press / release is incompatible with repeat").

## S9 Alt release: which method works? Only polling is reliable

| Method | Alt pressed alone | Alt, Tab, Tab released, then Alt released (the real use) | Alt released before Tab |
|---|---|---|---|
| Lua release bind on `ALT_L` (`release`, `ignore_mods`, `non_consuming`) | fires | **does not fire** | fires |
| Quickshell `GlobalShortcut` on `ALT_L` (`ignore_mods`, `non_consuming`) | fires | **does not fire** | does not fire |
| Poll `hl.is_key_down("Alt_L")` / `("Alt_R")` on one-shot timers | works | **works** (false within one tick after release) | works |

Right Alt behaves like left Alt. So a release bind or a global shortcut alone cannot end a switch: after any other key was pressed in between, the
Alt release is not reported.
Measured only in our probes (virtual keyboard): a GlobalShortcut on ALT_L did not report the release after another key was pressed in between. UNVERIFIED guess about core PR #16548: its overlay takes the keyboard on the first Tab, so its QML key-release handler (the fallback its description mentions) is probably the path that works in practice. We did not run its code.
Our decision input for D5: the poll works with a focusless overlay and needs no keyboard grab, but see L1 (Alt menu) before closing D5.

## Trap found: loading the probe twice doubled every bind (L8)

`hyprctl eval dofile(...)` twice registered each bind twice, so every event fired twice. Our module must be idempotent: unbind its own chords before binding, and keep a load guard.
Also: `hl.get_time` does not exist; `os.clock` is CPU time, not wall time. Use `/proc/uptime` for timestamps in probes.

## S8 raise: what brings a floating window to the front? `alter_zorder top` or `bring_to_top`, NOT focus alone

Test `tests/spikes/s8_raise.py`: three coloured kitty windows overlapping on a spare workspace in real floating mode (the windows carried the
`omarchy-floating-workspace` tag), one-pixel `grim` screenshot says which is on top. Hyprland 0.56.2.

| Scenario | focus only | focus + `alter_zorder top` | focus + `bring_to_top` | `alter_zorder top` only |
|---|---|---|---|---|
| Plain overlapping floating windows | **stays behind** | front | front | front |
| Top window maximized | front | front | front | front |
| Top window fullscreen | front | front | front | front |

Reading: the stacking bug (core issues 16241, 16973, 17724) is real for plain overlapping floating windows: a focus call alone does not raise.
For a maximized or fullscreen top window, focus alone already works here, because Omarchy sets `misc.on_focus_under_fullscreen = 1` (seen in core PR 16548's comments) and hands the screen to the focused window.
Our rule: always focus AND `alter_zorder top`. Not tested: a window on another workspace, two monitors, a dialog over its owner, XWayland apps.
Cleanup was verified: no test windows left, workspace mode file removed, original workspace restored.

## S6 load order and the escape hatch

Order in `~/.config/hypr/hyprland.lua`: `default.hypr.omarchy` (stock binds, including the four ALT+TAB binds) then the user's
`hypr.monitors`, `hypr.input`, `hypr.bindings`, `hypr.looknfeel`, `hypr.autostart`, then personal lines at the end (where a plugin's guarded
`dofile` goes, as omagnet's does). So omahop loads AFTER the user's own `bindings.lua`: an unconditional `hl.unbind("ALT + TAB")` would delete a user's own Alt+Tab bind.
Detection of "is it still the stock bind" is not free: `o.bind` (`/usr/share/omarchy/default/hypr/helpers.lua`) keeps no list of binds, and calling `hyprctl` from inside the config load is untested and risky.
Decision: no detection. The escape hatch is (1) the settings switch "Take over Alt+Tab" (default on) and (2) a global `_G.omahop_takeover = false` that a user sets in `hyprland.lua` or `bindings.lua` before omahop loads. The README says: if you rebind Alt+Tab yourself, turn this off.
Lua exposes `hl.get_windows`, `hl.get_workspace_windows`, `hl.get_layers`, `hl.get_current_submap`, `hl.get_cursor_pos`, and `hl.dsp.send_shortcut`, `hl.dsp.pass`, `hl.dsp.send_key_state`.

## L8 reload: does the unbind-first guard matter? Hygiene only

`hyprctl reload` left the bind count unchanged (282 binds, 11 on TAB, before and after), so a reload clears and re-registers binds. The doubling seen in S1 came from `hyprctl eval dofile(...)`, which never clears. The module still unbinds its own chords before binding (cheap, and it protects development workflows).

## L1 Alt tap opens an app menu: CONFIRMED, and a mitigation works

Test `tests/spikes/l1_altmenu.py`: a tiny Qt Widgets window with a menu bar (the Qt menu bar takes focus on an Alt tap; LibreOffice Writer on this machine does NOT react, so it is a useless control), driven through `/dev/uinput`, screenshots of the menu strip.

| Input the app sees | Result |
|---|---|
| Alt down, Alt up (plain tap) | the text cursor disappears: the menu bar took the keyboard focus |
| Alt down, a key that a Hyprland bind consumes (the Tab step), Alt up | **same as the plain tap**: the app never sees the Tab, so it counts a tap of Alt |
| Same, but the consuming bind also runs `hl.dsp.send_shortcut({ mods = "ALT", key = "F24", window = active })` (and the variant with `mods = ""`) | **no change**: the menu bar does not take focus |

So the focusless overlay needs a mitigation, and a harmless injected key (F24) between Alt down and Alt up is one that works in the Qt test app. Not tested: GTK apps, Chromium and Electron apps, XWayland apps, apps that use F24. The injection can leave the app seeing a stray F24; hand check in `validation-checklist.md`.

## Trap: `send_shortcut` and `pass` make Hyprland call the bind a second time

Found by the first live test of the glue (every Alt+Tab stepped twice). A bind handler that calls `hl.dsp.send_shortcut` (or `pass`) is called AGAIN when the key is released.
Measured with a plain `ALT + F10` bind: one call alone; two calls (press and release) with `send_shortcut`, mods empty or ALT, and with `pass`; one call with `send_shortcut`
deferred by a 30 ms timer, and one call with `hl.dsp.send_key_state` (F24 down, then up). `is_key_down("Tab")` still reads true when the echo arrives, so it cannot filter it.
Both `send_key_state` and a 5 ms deferred `send_shortcut` still stop the Qt menu bar from taking focus (L1 test). omahop uses `send_key_state`.

## Still open

S2 thumbnails cost (needs the overlay), S3 file-watch latency, S4 focusless hover: they need a real overlay window and are the first build step of v0.1. S7 ghost windows: toplevel-only filter, tested with fixtures in batch 1. L1 for non-Qt apps: part of the same batch.

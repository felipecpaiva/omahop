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
Alt release is not reported. Core PR #16548 documents a QML key-release fallback while its overlay holds the keyboard, which fits this finding.
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
`hypr.monitors`, `hypr.input`, `hypr.bindings`, `hypr.looknfeel`, `hypr.autostart`, then personal lines at the end (this is where a plugin's guarded
`dofile` goes, as omagnet's does). So omahop loads AFTER the user's own `bindings.lua`: an unconditional `hl.unbind("ALT + TAB")` would delete a user's own Alt+Tab bind.
`hyprctl binds -j` lists binds with their description. Stock ones: modmask 8 (ALT) "Focus on next window" and "Reveal active window on top";
modmask 9 (ALT+SHIFT) "Focus on previous window" and "Reveal active window on top". Lua exposes `hl.get_windows`, `hl.get_workspace_windows`, `hl.get_layers`,
`hl.get_current_submap`, `hl.get_cursor_pos`, but no bind list.
Answer: omahop takes over Alt+Tab only if the binds on that chord are the stock ones (checked by description at load, through `hyprctl binds -j`), and the settings app has a
"Take over Alt+Tab" switch (default on). If a user bind is found, omahop leaves it alone and says so in a log line and in the settings app.

## S3 shell IPC cost: about 42 ms per call

`omarchy-shell -q <target> <method>` takes about 42 ms (a process start), and `hyprctl eval` about 5 ms. Too slow for every Tab press, fine for open and close.
Plan: Lua writes a small state file (selection index and entries) in `$XDG_RUNTIME_DIR` and the QML overlay watches it; one IPC call opens the overlay.
File-watch latency is NOT measured yet; it is the first thing to measure in batch 1 (target: overlay updates within one frame of a Tab).

## Still open

S2 thumbnails cost (needs the overlay), S3 file-watch latency, S4 focusless hover and L1 (Alt menu on tap), both need a minimal overlay prototype: they are the first build step of v0.1, not a separate probe, because they cannot be answered without a real overlay window. S7 ghost windows: toplevel-only filter, tested with fixtures in batch 1. See `ROADMAP.md`.

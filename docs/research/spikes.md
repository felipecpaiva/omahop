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

## Still open

S2 thumbnails cost, S3 IPC and latency, S4 focusless hover, S6 load order, S7 and S8 (raise), L1 (Alt menu on tap). See `ROADMAP.md`.

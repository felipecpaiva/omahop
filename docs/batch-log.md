# omahop batch log

2026-11-06: research and design docs written. No code yet.

## Batch 1 (2026-11-06): Lua core, pure modules and glue

Built: `lua/config.lua`, `scope.lua`, `windows.lua`, `mru.lua`, `session.lua` (pure, each with a `test_*.lua`), `omahop.lua` (Hyprland glue, tested against a fake `hl`
in `test_glue.lua`). Live test `tests/live.py` (16 checks, real keys through `/dev/uinput` on a spare workspace with three coloured windows): quick tap flips to the previous window
and raises it, hold Alt plus Tab picks, Shift+Tab, Escape cancels, Alt+arrows, hold Tab repeats, tiling workspace keeps stock Alt+Tab. All pass.
Found on the way: `send_shortcut` echo (fixed with `send_key_state`), minimized windows carry `omarchy-minimized-from-<id>` (so their origin workspace is known and the window filter uses it).
Not done: the overlay (the state file is written, nothing draws it yet), settings app, install line in `hyprland.lua`, hand checks.

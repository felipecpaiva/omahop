# omahop gotchas

Traps found so far. The long list from the sister project is in omagnet `docs/gotchas.md`; the short version is at the end of `architecture.md`.

- Quickshell `Quickshell.iconPath(name, true)` returned empty on this machine. Call it with one argument.
- `ToplevelManager` and `DesktopEntries` are lazy: the first read is empty. Touch them early.
- The old note "Z13 is on Omarchy 4.0.6" is stale: the machine reports 4.5.0-3 and `Commons/ShellIpc.qml` exists.
- A probe window opened with `qs -p` is tiled by Hyprland like any client. Float only that window to screenshot it.
- `hl.unbind("ALT + TAB")` removes every bind on that chord, including a user's own. Load order against the user's `bindings.lua` is open (spike S6).
- Traps other projects hit (floating raise, ghost windows, Alt scan codes, capture on a vanished output, config reload crash, bind duplicates on hotplug, pointer warp): see `competitive-analysis.md`.
- `hl.dsp.send_shortcut` and `hl.dsp.pass` inside a bind handler make Hyprland call the bind a second time at the key release. Use `send_key_state` (docs/research/spikes.md).
- A live test that checks "previous window" must start from a known recently-used order (`Spare.reset_order`); earlier steps change it.
- `hl.is_key_down` takes the xkb names `Tab`, `Alt_L`, `Alt_R` (`TAB`, `ALT_L` return nil).
- The shell does not hot-reload a plugin's QML: after editing it, run `omarchy-shell -q shell rescanPlugins`. That opens the theme picker; close it without key presses with `omarchy-shell image-selector cancel <any-done-file-path>`.
- A ListView resets `currentIndex` to 0 whenever its model is replaced; drive the highlight from your own `selected` value.
- Writing the state file every tick makes the overlay redraw every tick: write only on change.

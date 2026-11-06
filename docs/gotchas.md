# omahop gotchas

Traps found so far. The long list from the sister project is in omagnet `docs/gotchas.md`; the short version is at the end of `architecture.md`.

- Quickshell `Quickshell.iconPath(name, true)` returned empty on this machine. Call it with one argument.
- `ToplevelManager` and `DesktopEntries` are lazy: the first read is empty. Touch them early.
- The old note "Z13 is on Omarchy 4.0.6" is stale: the machine reports 4.5.0-3 and `Commons/ShellIpc.qml` exists.
- A probe window opened with `qs -p` is tiled by Hyprland like any client. Float only that window to screenshot it.
- `hl.unbind("ALT + TAB")` removes every bind on that chord, including a user's own. Load order against the user's `bindings.lua` is open (spike S6).
- Traps other projects hit (floating raise, ghost windows, Alt scan codes, capture on a vanished output, config reload crash, bind duplicates on hotplug, pointer warp): see `competitive-analysis.md`.

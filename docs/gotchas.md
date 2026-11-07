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
- The shell keeps a plugin's QML in memory: edits show only after `omarchy restart shell` (a rescan or a disable and enable does not reload them; checked in the shell log, which lists each QML file once per shell start). Close the theme picker it opens with `omarchy-shell image-selector cancel <any-path>`.
- The shell's `Style` mirrors Hyprland's rounding but not `general:border_size`; read it with `hyprctl getoption general:border_size -j` (omahop does, and its `border` setting can override).
- v0.2 is developed on branch `v0.2`; the installed plugin is a symlink to this working tree. If a half-done batch misbehaves: `git -C ~/Work/omahop checkout main && hyprctl reload && omarchy restart shell` (then close the theme picker with `omarchy-shell image-selector cancel <any-path>`).
- `gh release create` (a public page) is blocked by Claude Code's auto-mode safety check; Felipe runs it or allows it explicitly.
- NEVER call `hyprctl` synchronously from the Lua glue (`io.popen`, `os.execute`): Hyprland is the process that would answer, so it blocks for about 5 seconds and the whole desktop freezes. Run it detached with `hl.exec_cmd` and read the result from a file later.
- QML name clash, again: in a delegate or component instance, `reader: reader` (or `store: store`) assigns the item's OWN property to itself, leaving it null. Give the outer id a different name (`configReader`, `settings`).
- A QML error in any file the service imports makes the WHOLE service fail to load (the switcher overlay disappears). After every QML edit: restart the shell and grep the Quickshell log for `load failed` before testing.
- `hyprctl` cursor warps (`hl.dsp.cursor.move`) inside the window the pointer is already in send the app NO motion event, so hover handlers stay still; a real mouse always sends motion. In tests and demos, wiggle the virtual mouse by one pixel after a warp. (Found when the peek popup seemed dead in edge mode; the debug dump showed the strip hovered but no slot.)
- GIF captions: at most about 50 characters (the 1280 px frame fits about 55 at the caption font size).
- A layer surface with Exclusive keyboard focus gets EVERY click on its output, even outside its input mask (`mask: Region`), and the window under the click does not take focus. An exclusive overlay therefore needs a full-size MouseArea that does something with those clicks, or the user is stuck until the grab ends. Measured in the v1.1b spike (`research/linger-spike.md`, Result).
- A focus dispatch (`hl.dsp.focus`) is silently ignored while a layer holds Exclusive keyboard focus. Drop the grab first (omahop writes `open=0`), then focus from a short timer (`M.release_ms`).
- With `modifier` set to Ctrl, loading omahop twice without a Hyprland reload (an eval-based reload) is not idempotent: the second load's bind snapshot shows omahop's own Ctrl+Tab as used, so it logs "already used" and the first load keeps serving the chord. Use `hyprctl reload` after changing the modifier. Alt still unbinds and rebinds as before.
- Audio marker: the speaker is the Nerd Font glyph U+F028 drawn in the shell font. With a shell font that is not a Nerd Font it may show as a box (Omarchy's own audio panel takes the same risk). A browser plays all tabs through one process, so every window of that browser is marked; an uncorked but silent stream (a call app holding its output open) is marked too.
- Never print or save `pactl list sink-inputs` output while debugging the audio marker: `media.name` holds song, video and call titles. Reduce it first, for example `pactl -f json list sink-inputs | jq '[.[] | {corked, mute, pid: .properties["application.process.id"]}]'`.

# Hand checks Felipe owes

Automated checks (`tests/run-all.sh`) cover logic and the keyboard path with a virtual keyboard. These need a real keyboard and your eyes.

## v0.1

- [ ] Tiling workspace: Alt+Tab acts exactly as stock (default `scope = "floating"`).
- [ ] Floating workspace: a quick Alt+Tab flips between the last two windows, no overlay flash.
- [ ] Hold Alt: the list appears after a moment; Tab and Shift+Tab move; releasing Alt switches; Alt+Escape cancels; the window you pick is in front, also when windows overlap.
- [ ] Hold Tab: the selection repeats at a comfortable speed.
- [ ] Theme change (Omarchy theme picker): the list changes colours with it, no restart.
- [ ] The Alt-menu check: in a GTK app with a menu bar, a Chromium app and an Electron app, Alt+Tab (hold, release) does not open the app's menu bar or leave focus in it. (Qt is verified automatically.)
- [ ] A minimized window (Super+M) is listed last and comes back to your workspace when picked.
- [ ] `scope = "all"` and `windows.workspaces = "all"` in `~/.config/omahop/config.toml`, then `hyprctl reload`: the switcher works on tiling workspaces too.
- [ ] `takeover = false`: Alt+Tab is stock everywhere.
- [x] Two monitors: with `windows.monitors = "all"` the other monitor's windows are listed and picking one moves you there. (Automated: `tests/live_monitors.py` runs from every attached monitor in turn, passed 2026-11-07 with two monitors; `lua/test_monitors.lua` models 1 to 6 monitors and unplugging.) (The overlay shows on the focused monitor.)
- [ ] The empty-state: only one window open, Alt+Tab does nothing visible.

## v0.2 (settings window)

- [ ] Open **omahop** from the launcher: the window opens, looks like the other Omarchy windows, Escape and Close shut it.
- [ ] Change each control once (switch, buttons, the number field, the text field): the file changes on one line, your comments stay, the next Alt+Tab uses it.
- [ ] "Reset to default" appears when a value is set and removes the line from the file.
- [ ] Turn "Take over Alt+Tab" off: the window offers "Reload Hyprland now", and after the reload Alt+Tab is stock.
- [ ] Change the Omarchy theme with the window open: colours follow.

## v0.2 (cards)

- [ ] Settings window, Look: Style = Cards. Alt+Tab shows a strip of cards with a picture of each window, the picked card has the accent border and moves with Tab.
- [ ] A window on another floating workspace, a covered window and a minimized window each show their own picture (or the app icon if the app cannot be captured).
- [ ] With many windows open (more than 7) the strip scrolls and the picked card stays in view.
- [ ] Thumbnails = Live: the pictures update while the strip is up (try a terminal printing output); notice the CPU cost with many windows. Thumbnails = Off: icons only.
- [x] Unplug a monitor while windows are on it, then Alt+Tab: Hyprland must not crash (L6). (Felipe, 2026-11-07: worked, no problem.)

## v0.2 (search)

- [ ] Hold Alt, Tab, then type part of an app name or a title: the list narrows, the best match is selected, releasing Alt goes to it.
- [ ] Typing a display name works (for example "files" finds the file manager although its window class is different).
- [ ] Backspace deletes a letter; the first Escape clears the query, the second cancels.
- [ ] Nothing matches: the box says so, releasing Alt does nothing.
- [ ] None of your own Alt+letter shortcuts stop working after using search (they are only taken during a session, and never when you have bound them).
- [ ] Settings, "Type to search" off: typing does nothing while the list is up.

## v0.3 (pointer, quick actions, peek strip)

- [ ] List or cards up: moving the pointer over a row only highlights it lightly; your keyboard pick does not move; clicking a row goes to that window.
- [ ] A pointer resting where the list opens does nothing until you move it.
- [ ] The buttons on a hovered row or card: close closes that window (an app may ask first, the row stays until the window is gone); minimize sends it to the dock (floating workspaces).
- [ ] `Alt + Delete` closes the picked window.
- [ ] Settings, Peek strip = "Show when the pointer touches the screen edge": nothing shows until the pointer hits the edge; the strip then appears, an app hover shows its windows, a click goes there; it hides when the pointer leaves.
- [ ] Peek strip on the same edge as your dock or bar does not happen by default (auto picks a free edge); check with your layout, and try every explicit edge.
- [x] Two monitors (Felipe, 2026-11-07): a strip on each screen, listing that screen's windows (minimized ones on every screen).
- [ ] Peek = Off: no new thing anywhere on the desktop.
- [ ] Your own mouse snapping (omagnet) and the Omarchy dock still work with the strip on.

## v0.4 (same-app, rules, hints)

- [ ] `Alt + backtick` from an app with several windows lists only that app's windows; the first pick is its previous window; releasing goes there. With one window nothing opens.
- [ ] If you already use `Alt + backtick` for something, it keeps working (omahop does not take a used chord); set `same_app_key` to another `ALT + key` chord, reload Hyprland, and it works.
- [ ] Out of scope (a tiling workspace with the default scope): `Alt + backtick` still reaches the app as before.
- [ ] Rules: a title fragment hides matching windows; "List these apps first" puts them first; fullscreen game or remote desktop: Alt+Tab is left to it with "Step aside for fullscreen apps" on; a named app too.
- [ ] Quick jump keys: with numbers, `Alt + 3` picks the third row; with app letters (`c=google-chrome`) the letter jumps; a typed letter then a digit types; with hints off digits type.
- [ ] The settings window shows the new groups (App rules, Shortcuts) and the changes apply.

## v1.1a (search)

- [ ] A window titled with an accent (for example "ação" or "Café"): Alt+Tab, type `acao` or `cafe`, it is listed.
- [ ] Type `gc` with Google Chrome open: it is listed after any plain matches; `chrm` finds it too.
- [ ] Settings, "Fuzzy search" off: `gc` and `chrm` find nothing; `acao` still finds "ação".
- [ ] One letter, or an empty query, never brings in extra windows.
## v1.1a (thumbnail exclusions)

- [ ] Settings, "Never take a picture of these apps" = `kitty`, cards style: the kitty card shows its app icon in the middle, other cards still show pictures; same in the peek strip's hover popup. Works with Snapshot and Live. Empty again: kitty shows a picture.
## v1.1a (icon theme)

- [ ] Set `icon_theme = "Papirus"` (any installed theme folder name) in the settings window or config.toml, restart the shell: the rows show that theme's icons; apps it lacks still show an icon. An empty value or a name that is not installed shows the old icons.

## v1.3 (modifier)

- [ ] First, in a terminal: `hyprctl eval 'return tostring(hl.is_key_down("Alt_L")) .. tostring(hl.is_key_down("Control_L"))'` prints `falsefalse` (names resolve) and not `nilnil` (wrong names would never notice the release).
- [ ] `modifier = "ctrl"`, reload: Ctrl+Tab opens the list on a floating workspace, release picks, Ctrl+letters type into the search; a browser on a tiling workspace still switches tabs with Ctrl+Tab and Ctrl+Shift+Tab goes back (checks the `CTRL SHIFT` pass-back).
- [ ] Ctrl: start a region screenshot (the region picker enables its own Ctrl+Tab while it is open): its Ctrl+Tab still works, or note the clash.
- [ ] Settings window: "Key to hold" shows Alt and Ctrl with the warnings, a change offers the Hyprland reload. A bad value in config.toml (`modifier = "hyper"`) gives Alt and a log line.
## v1.3 (icon packs, step 1)

- [ ] Copy `docs/examples/packs/omahop-sample` to `~/.config/omahop/packs/`, set Icon pack to `omahop-sample` in the settings window (no restart): with kitty and firefox open, Alt+Tab shows the blue square for kitty and the green circle for firefox, in the list, the cards and the peek strip. Other apps keep their icons.
- [ ] Icon pack empty again: kitty and firefox show their usual icons at once.
- [ ] Delete `license` from the sample's pack.toml, set the pack again: the usual icons show and the shell log has a line `omahop icon pack omahop-sample: pack not used: pack.toml needs license`.
- [ ] Icon pack `../x` or a name that does not exist: usual icons, one note in the log, nothing else happens.

## v1.1b (keep the list open while searching)

- [ ] Settings, "Keep the list open after typing" = 5: Alt+Tab, type two letters, release Alt: the list stays, a thin line under the search runs down; type more (a capital, an accent such as `ç`), Return picks.
- [ ] Two monitors: start the session on each monitor in turn; the list and the keyboard grab are on the focused one; move the pointer to the other monitor and click: the list closes and nothing changes focus. Type while the pointer is on the other monitor: the keys still reach the list.
- [ ] Changing your mind: with the list lingering, start typing into the app below: the first keys go into the search (they are stolen until Escape, a click, or the timeout). Check that this is clear enough from the open list and the countdown line, and that one Escape plus one more Escape, or a click, gives the keyboard back at once.
- [ ] Setting 0 (default): typing then releasing Alt picks at once, exactly as v1.1.0.
- [ ] Kill the shell while lingering (`omarchy restart shell`): the keyboard comes back (the grab dies with the process) and the next Alt+Tab works.

## v1.3 part B (quit and minimize by key)

- [ ] Default (`action_keys` empty): Alt+Tab, press `q` and `m`: they type into the search, nothing closes.
- [ ] Settings, "Quit and minimize keys" = `q=close, m=minimize`: Alt+Tab with three windows, `m` minimizes the selected one, it leaves the list and the selection is on the next row (check the window really went to the dock); `q` closes the selected one (an app that asks to save may stay: its row is gone from the list anyway, check the window is still there afterwards).
- [ ] Type `b` first, then `q`: it types (query `bq`), nothing closes. Backspace to empty: `q` acts again.
- [ ] Close or minimize every window but one: the last action ends the session cleanly, no overlay left.
- [ ] `hints = "numbers"` with `action_keys = "3=close"`: `3` jumps, does not close; the log (`omarchy-debug` or the plugin log) has a `config: action_keys:` line naming the clash.
- [ ] A typo such as `q=quit` or `delete=close`: the log reports it, the rest still work.

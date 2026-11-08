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

## v1.4 part C (icon packs, step 2: zip import and export)

- [ ] With `omahop-sample` installed, `bash tools/pack-export.sh omahop-sample` (from the plugin folder) writes `~/omahop-sample.omahop-pack.zip`; running it again says the file exists; `--force` replaces it and `sha256sum` is the same both times.
- [ ] On a clean HOME (a new user, or `HOME=$(mktemp -d) XDG_CONFIG_HOME= XDG_CACHE_HOME=`): `bash tools/pack-import.sh ~/omahop-sample.omahop-pack.zip` shows name, author, licence, 2 icons and the file list, asks, and after `y` the pack is in `~/.config/omahop/packs/omahop-sample/`; answering `n` leaves nothing.
- [ ] Import the same zip again: refused as already installed; with `--replace` it installs. Set Icon pack to `omahop-sample`: kitty and firefox show the sample icons.
- [ ] A hostile zip: `python3 -c 'import zipfile; z=zipfile.ZipFile("/tmp/evil.zip","w"); z.writestr("pack.toml","name = \"x\""); z.writestr(zipfile.ZipInfo("../evil.png"), "x")'` then `bash tools/pack-import.sh /tmp/evil.zip`: refused with "a path that leads out of the pack", nothing new in `~/.config/omahop/packs/`, `~/.cache/omahop/` or the folder above the zip.
- [ ] The Icon pack help text in the settings window names both commands.

## v1.5 (icon pack editor)

Run on a desktop session with the branch installed as the plugin. Keep a copy of `~/.config/omahop/packs` first.

- [ ] Settings window, group Look: under Icon pack a button **Make or edit icon packs**; it swaps the list for the editor, **Back** returns, Escape closes the window. Reopening the window shows the settings list.
- [ ] **New pack** with name `Test Pack`, author, licence `CC0-1.0`: the status says `Made the pack test-pack.`, a `test-pack` button appears and is chosen, the fields show what was typed. `~/.config/omahop/packs/test-pack/pack.toml` holds the four lines.
- [ ] Making it again says a folder named test-pack exists. A name with a `"` is refused with the reason.
- [ ] Set Icon pack to `test-pack`. Open the editor again: open windows are listed first, then installed apps; Filter apps narrows the list.
- [ ] **Choose image** on kitty: the settings window disappears and the Omarchy file chooser opens on top (hand check 1, the main risk); pick a PNG or SVG: the window comes back, the status says `Added icons/kitty.svg.`, the row shows the picture and `pack icon kitty.svg`. Alt+Tab with a kitty window: the switcher shows the new icon without a shell restart.
- [ ] Cancel the chooser: the window comes back and nothing changes.
- [ ] Choose a `.jpg` (rename one to `.png` too): refused, the status names the reason, `icons/` unchanged.
- [ ] Choose image again on kitty with an SVG after a PNG: one file remains (`kitty.svg`), the row and the switcher show it (the switcher may need `omarchy restart shell` if the file name stayed the same).
- [ ] With `omarchy` off the PATH (or `omarchy-file-select` failing): Choose image shows the path field; a full path adds the image, a relative one is refused.
- [ ] **Remove** on kitty: the row shows the system icon again; Alt+Tab shows the system icon.
- [ ] **Save details** with a new author and an empty description: `pack.toml` has the new author, no description line, and any comment line added by hand is still there.
- [ ] **Export**: the status says `Exported test-pack (n icons) to ...`; again: the page asks to replace; **Replace** writes it, **Cancel** keeps it.
- [ ] **Import a zip** with the exported file: the summary names the pack, author, licence, icon count and says a pack of that name is installed; **Replace** installs, **Cancel** leaves it. Import `omahop-sample`'s zip on a HOME without it: **Install** installs and the new folder appears in the pack buttons.
- [ ] Import the hostile zip from the v1.4 part C check: refused with "a path that leads out of the pack", nothing new under `~/.config/omahop/packs/`.
- [ ] A linked pack folder (`ln -s ~/somewhere/pack ~/.config/omahop/packs/linked`): its row is listed, adding an image is refused with "edit it there", export works.
- [ ] Theme switch (`omarchy theme set ...`) while the editor is open: colours follow.

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

## v1.4 (browser tabs, omahop side)

Run `python3 tests/live_tabs.py` first (virtual keyboard, a fake tab file and a stand-in helper FIFO; no browser). Then by hand, with the `omahop-tabs` extension and helper installed in a temporary Chromium profile and data or example.com pages only:

- [ ] Live check 1 (spike section 10, the pid link): the helper's parent pid (the file's `pid` field) equals the browser window's `pid` in `hyprctl clients -j`. If not, omahop falls back to the browser's class; note which.
- [ ] Live check 2 (title and class per browser): for Chromium and Chrome (and Brave or Edge if installed) list `class`, the title suffix after ` - `, and `pid`. Confirm the classes in `Tabs.classes` (`lua/tabs.lua`).
- [ ] Live check 3 (focus semantics): two browser windows on two workspaces, Return on a tab of the window that is not focused: the right tab shows and its window comes to the front, no visible flash of the wrong tab. If there is a flash, note it (the spike's ack wait would fix it).
- [ ] Setting off (the default): `ls $XDG_RUNTIME_DIR/omahop` shows no `tabs.enabled`, `tabs.ignore` or `tabs.*.json`.
- [ ] Turn it on in the settings window: `tabs.enabled` and `tabs.ignore` appear at once (mode 600, folder 700); turn it off: they and the tab files go at once.
- [ ] Alt+Tab with nothing typed: no tab rows, Tab cycles windows as before. Type part of a hidden tab's title: its row appears under its browser window, in both the list and the cards style.
- [ ] Two windows whose shown tabs have the same title: Return on a tab of each goes to the right window (or note which goes wrong).
- [ ] `browser_tabs_ignore = "example.org"`: tabs of example.org and its subdomains never show; `*.example.org` hides subdomains only.
- [ ] Delete and the quit and minimize keys on a tab row do nothing (they never close the whole browser window).
- [ ] The omahop log (`$XDG_RUNTIME_DIR/omahop/log`) holds no tab title or address after a session with tabs.
- [ ] Quit the browser: its tab file goes; the next search shows no rows for it.

## v1.5 (named profiles)

Keep a copy of `~/.config/omahop/config.toml`, then add a `[profiles.work]` table with `style = "cards"` and a `[profiles.work.windows]` table with `ignore = "<a class you have open>"`:

- [ ] Settings window, General: a Profile row shows None and work; None is marked.
- [ ] Pick work: the file gets `profile = "work"` above the first table (never inside a profile table), and the next Alt+Tab shows cards and leaves out the ignored app, with no Hyprland reload.
- [ ] With work picked, the Style row and the "Never list these apps" row each show the caption "Profile work sets this to ..."; the Style buttons still mark the base value. Other rows have no caption.
- [ ] Change the Style row while work is picked: the base line changes in the file, the `[profiles.work]` line does not, and the caption stays.
- [ ] Pick None (or use the reset link): the next Alt+Tab uses the base settings again and the captions go.
- [ ] Add `takeover = false` and `style = "huge"` to `[profiles.work]`: Alt+Tab still works with the base style; the omahop log (`$XDG_RUNTIME_DIR/omahop/log`) has `config: profiles.work.style = huge` and `config: profiles.work.takeover: not overridable in a profile, ignored`.
- [ ] `profile = "ghost"` by hand: the log has `config: profile = ghost: no such profile, using the base settings`, the switcher uses the base, and no Profile button is marked.
- [ ] Peek strip: a profile with `peek = "always"` over a base with `peek = "off"` shows the strip at once when the profile is picked and hides it when None is picked (the overlay's live reader follows the profile).
- [ ] A bad value the overlay reads live (`peek = "sometimes"` in the base): the strip stays off (the default) instead of acting on the raw value.
## v1.5 (audio marker)

No automated live test (it would need real sound). By hand, at a low volume, with something you choose to play:

- [ ] Setting off (the default): play music in the browser, Alt+Tab: no speaker anywhere. `pgrep -f audio-sample` while the list is up shows nothing.
- [ ] Turn "Mark windows playing sound" on in the settings window. Play a video or music in the real browser, Alt+Tab: the browser's row shows a small speaker after the app name; the other rows show none. Same in the cards style.
- [ ] Pause it, Alt+Tab again: no speaker (corked). Play again and mute the tab or the stream in the audio panel: no speaker (muted).
- [ ] Two browser windows, sound in one: both show the speaker (known limit, one process); note it if only one does.
- [ ] A player with its own window (mpv) and a player in a terminal (`paplay` on a sound file): mpv's row and the terminal's row are marked.
- [ ] With the list closed, nothing runs: `pgrep -f audio-sample` is empty and the shell's CPU stays idle.
- [ ] The omahop log (`$XDG_RUNTIME_DIR/omahop/log`) and the shell log hold no song or video title after a session with sound.
- [ ] Note the glyph renders as a speaker with your shell font (a box means a non-Nerd font).
## v1.5 (touchpad swipe)

No live test drives the touchpad (no fake pointer or touch input is injected), so all of these are by hand on the real touchpad. Settings window, group Touchpad swipe, turn on "Swipe on the touchpad to switch", then `hyprctl reload`. Three or more windows on a floating workspace.

- [ ] First check (the spike read the callback form from the 0.56.2 source, never observed): a 4-finger swipe right opens the list. If nothing happens, look for `swipe:` lines in `$XDG_RUNTIME_DIR/omahop/log` and for a Hyprland config error, and note them.
- [ ] Keep moving right: the selection moves one row per stretch; left moves back. Lift: the selected window comes to the front.
- [ ] Swipe right one row, back one row, lift: the list closes and nothing switches.
- [ ] Swipe left: the list opens on the last window.
- [ ] A small 4-finger nudge (well under one row): no list, no flash.
- [ ] Feel of "Swipe distance per row": try 60, 100 and 200 (applies at once, no reload); note the value that feels right on this touchpad.
- [ ] Rest four fingers without moving after the list opened: after about 10 seconds it closes without switching.
- [ ] Tiling workspace (scope floating): a 4-finger swipe does nothing. Fullscreen window with "Step aside for fullscreen apps" on: nothing.
- [ ] 3-finger workspace swipe still changes workspace with the trigger on (fingers 4).
- [ ] Set fingers to 3 with the 3-finger workspace swipe in `~/.config/hypr/input.lua`, reload: Hyprland shows a config error naming the overshadowed gesture, and the workspace swipe still works. Set it back to 4.
- [ ] `lua tools/gesture-map.lua` lists the same gestures as `~/.config/hypr/input.lua` and says 4 fingers is free.
- [ ] Alt+Tab, then hold Alt and swipe with 4 fingers: the swipe changes nothing, releasing Alt picks as usual.
- [ ] Turn the setting off in the settings window (no reload): a 4-finger swipe does nothing at once.
- [ ] Touchscreen: a 4-finger swipe on the screen does nothing (expected: Hyprland does not pass touchscreen swipes to plugins).


## Open, 2026-11-08: install the browser tab search (hand check)

Felipe found that searching for a page in a background browser tab finds nothing. That is expected until `browser_tabs` is on and the `omahop-tabs` extension and helper are installed (neither is yet). Steps: Chrome `chrome://extensions`, Developer mode, Load unpacked `omahop-tabs/extension`, run the installer from the `omahop-tabs` repo (see its README for the exact name), turn on Search browser tabs in the settings window, then search for a title of a tab that is not showing. Also the first real test of the extension in a visible Chrome (window match by pid, focus).

## Open, 2026-11-08: page pictures on found tab cards (hand check, D25)

Needs the extension build with page pictures (omahop-tabs). Steps: turn on `browser_tabs` and `browser_tab_previews` in the settings window (cards style); open the extension's Options page and press Enable page pictures (Chrome asks for the permission); view a few tabs for a moment each; search for one of them in omahop: its card shows a picture of the page, the site icon stays in the footer. Check: a site on the ignore list never gets a picture; turning `browser_tab_previews` off removes `$XDG_RUNTIME_DIR/omahop/tabpics` within a second; the permission alone (setting off) captures nothing; a tab never shown since the setting went on shows the big site icon.

## Open, 2026-11-08: shot and drawn pictures (hand check, D26)

Needs a real Chrome with the new `omahop-tabs` extension and helper and the page pictures permission granted (Options, Enable page pictures). Nothing here was run against a real browser.

- [ ] Shot, every 12 s: `browser_tabs` and `browser_tab_previews` on, `browser_tab_previews_draw` off. Open a page with a clock or a changing counter and watch the tab for about 40 s. Switch away, open the switcher, search for that tab: its card shows the page as it was when you left, and no "approximate" label.
- [ ] Shown at session start: change the page (scroll it), then at once press Alt+Tab, type its name: the picture shows the scroll (taken when the switcher opened). While the list is open and a picture arrives late, the card updates on its own within about half a second.
- [ ] Drawn for a never opened tab: turn `browser_tab_previews_draw` on. In Chrome open a link in a background tab (Ctrl+click) and never look at it. Search for it: first its icon, then within a second or two a rough picture with the small label "approximate" in the card's corner. Images from other websites are blank there, which is expected.
- [ ] Shot and drawn do not mix up: a window you can see never gets "approximate" (it is photographed); a tab you looked at keeps its exact picture and is not redrawn.
- [ ] Windows on another workspace (0.4.1): with `browser_tab_previews_draw` on, put a browser window on a workspace that is not shown. Within a minute or so the tab it shows gets a picture marked "approximate" (a shot is impossible there); the options page status shows a drawn count for hidden windows above 0. Bring the window back: its next 12 s shot replaces the drawn picture with an exact one. With draw off, such a window keeps only its icon.
- [ ] Off means off: with `browser_tab_previews_draw` off, searching never produces an "approximate" card; turning it off removes `$XDG_RUNTIME_DIR/omahop/tabs.draw`; a site on the ignore list is never drawn.
- [ ] No input or desktop side effects: no tab flickers or switches in any browser window during any of the above.

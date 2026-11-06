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
- [ ] Two monitors: with `windows.monitors = "all"` the other monitor's windows are listed and picking one moves you there. (The overlay shows on the focused monitor.)
- [ ] The empty-state: only one window open, Alt+Tab does nothing visible.

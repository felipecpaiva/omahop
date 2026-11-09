# Dock plan S1.0: isolation proof and code-read checks

Date 2026-11-09. Method: code reading only. Nothing was started, no input was sent, nothing outside the repo was written. Source read: the installed shell at `/usr/share/omarchy` (version 4.0.0.alpha, `/usr/share/omarchy/version:1`; `~/omarchy` does not exist) and the read-only diff of upstream PR 16609 (`gh pr diff 16609 --repo omacom/omarchy`, state OPEN, not merged).

## Verdict: PARTIAL

An isolated run looks possible on paper, but it was not run, because no start of a nested or headless compositor could be shown to carry zero risk to the live session. Treat it as an untested design that Felipe approves before anyone runs it.

What the code supports:

- The shell instance is keyed by config path plus display. `bin/omarchy-shell:71` hashes `$OMARCHY_PATH/shell` and `$WAYLAND_DISPLAY`; `shell.qml:1668` builds the same socket name; `bin/omarchy-shell:110` calls `qs ipc -p "$OMARCHY_PATH/shell"`. A copy under another `OMARCHY_PATH` on another display is a different instance, so the real one (`quickshell -n -p /usr/share/omarchy/shell`, running) is not addressed by it.
- The shell reads and writes user config under `HOME`: `shell.qml:36` (`userConfigPath` is `home + "/.config/omarchy/shell.json"`, `home` from `HOME` at `shell.qml:27`), `shell.qml:112` (`persistShellConfig` writes it), `PluginRegistry.qml:10-11` (`pluginsDir` is `$HOME/.config/omarchy/plugins`). So the copy needs its own `HOME`, not just `XDG_CONFIG_HOME`.
- omahop reads `XDG_CONFIG_HOME` first (`SettingsStore.qml:13`, `Service.qml:389`, `lua/omahop.lua:30`), the shell reads `HOME` only. Set both to temp dirs, or the two halves disagree.
- Hyprland 0.56.2 ships aquamarine's headless backend (symbols `CHeadlessBackend`, `CHeadlessOutput` in `libaquamarine`), so a compositor with no screen and no seat is possible without a window on the live session. A nested Hyprland window inside the live session is NOT acceptable (it appears on the real screen and can take focus).

Why it was not started:

1. The session bus is shared: `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`. The copied shell has `plugins/notifications/Service.qml` (a DBus notification server) and other bus services; they would fight the real ones for the same names. It would need `dbus-run-session`, which is unproven here.
2. A full copied tree starts many services that run real commands (`BrightnessKeys` at `shell.qml:18`, lock, idle, `omarchy-*` scripts via `Util.execDetached`). Only a minimal `shell.qml` that mounts the dock and our plugin is safe.
3. Hyprland itself writes under `$XDG_RUNTIME_DIR/hypr` and reads `~/.config/hypr`; overriding the runtime dir also moves the Wayland socket. Two earlier tests closed the user's terminal, so no experiment here.

### Safe command to try (untested, run only with Felipe's go and nothing else open)

```
T=/tmp/omahop-s1-iso; rm -rf "$T"; mkdir -p "$T"/{home,run,omarchy}
chmod 700 "$T/run"
cp -a /usr/share/omarchy/shell "$T/omarchy/shell"          # then replace shell.qml with a minimal one
mkdir -p "$T/home/.config/omarchy/plugins"
# patched dock + our plugin id go in the copy; never touch the real ~/.config
env -i PATH="$PATH" HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" XDG_RUNTIME_DIR="$T/run" \
    XDG_STATE_HOME="$T/home/.local/state" XDG_DATA_HOME="$T/home/.local/share" \
    OMARCHY_PATH="$T/omarchy" AQ_BACKENDS=headless \
  dbus-run-session -- Hyprland -c "$T/hypr.conf"
# then, inside that env only: WAYLAND_DISPLAY=wayland-1 quickshell -n -p "$T/omarchy/shell"
```

`env -i` drops `WAYLAND_DISPLAY`, `HYPRLAND_INSTANCE_SIGNATURE` and `DBUS_SESSION_BUS_ADDRESS` so nothing can reach the live session. Pre-checks before running: confirm the live `pgrep -a quickshell` and the real runtime dir are unchanged afterwards. If any step needs the real bus or display, stop and fall back to the hand test below.

## Results

### (a) Does the shell discover a plugin in a `dock/` subfolder of a plugin repo? REFUTED

Third party scan only looks at `<pluginsDir>/*/manifest.json`, one level deep (`PluginRegistry.qml:771-778`: `for sub in "$dir"/*/; ... [[ -f "$sub/manifest.json" ]]`; comment at `PluginRegistry.qml:761`: "Third-party plugins stay at the top level"). The deeper scan (`-mindepth 2 -maxdepth 3`, `PluginRegistry.qml:771`) is first party only. A `dock/manifest.json` inside the omahop repo is never found. Plan change: the dock extension needs its own top level folder, for example a second repo, or a symlink `plugins/<dock-id>` to `plugins/io.github.felipecpaiva.omahop/dock` (the glob follows symlinks; whether the marketplace installer would create it is unchecked). Also the plugin folder name is used as the id for reload (`localPluginIdForPath`, `PluginRegistry.qml:739-749`).

### (b) Does a separate plugin id reach omahop's cards and config? PARTIAL (verified for config, unverifiable for cards)

Config does not depend on the id: `SettingsStore.qml:13-14` reads `<XDG_CONFIG_HOME or HOME/.config>/omahop/config.toml`, and `lua/omahop.lua:30` uses the same dir. The only id strings in code are `SettingsPanel.qml:60` (hide own panel, falls back to the literal id when `manifest.id` is missing) and the install path in `lua/omahop.lua:2`, `lua/config.lua:77`. So a second plugin id sharing `~/.config/omahop/config.toml` sees the same keys. "Cards" (the settings panel cards) are drawn by omahop's own `SettingsPanel.qml` from `spec.json`; a separate plugin has no access to them unless it is loaded by the omahop panel or ships its own panel. Not decidable from reading; the plan should state that the dock plugin gets no card of its own and the keys live in omahop's spec.

### (c) Hidden-dock rect rule: PARTIAL (plan text was wrong in detail)

Not in the installed tree (`launcherPayload` and `isPluginOpen` in the dock are absent from `/usr/share/omarchy/shell/plugins/dock`; the only `isPluginOpen` is the shell's own at `shell.qml:1238`). Read from the diff of PR 16609 (open): `launcherPayload()` returns only `{screen, position}` when `!window.shown` (diff line 293); otherwise it returns `dock` and `button` rects "reckoned where the dock comes out to", adding `body.tuck` (diff lines 283-300). And `shown` is `dock.isFloating(workspaceId) && fullscreenMode < 2` (`DockWindow.qml:40`), independent of auto-hide. So: an auto-hidden but shown dock DOES get rects (computed at the revealed position); a dock on a tiled workspace or under real fullscreen gets none. The plan line "returns no rects when hidden" should read "no rects when `shown` is false (tiled workspace or fullscreen 2/3)". Default rule stands: open the popover only when rects exist. Caveat: PR 16609 may still change before merge.

### (d) Source line for `fullscreenMode`: VERIFIED

`/usr/share/omarchy/shell/plugins/dock/DockWindow.qml:29-39` defines it (max of `lastIpcObject.fullscreen` over toplevels on the active workspace; comment line 27-28: 1 is maximized, 2 or 3 fullscreen). Line 40: `shown` needs `fullscreenMode < 2`. Line 44: `autohide: dock.autohide || fullscreenMode === 1`. So `=== 1` (maximized, not fullscreen) forces autohide, and `>= 2` hides the dock entirely. Plan wording "fullscreen forces autohide" should say "maximized forces autohide, fullscreen hides".

Also noted: the dock hide timer is `DockWindow.qml:221-228` (150 ms) and checks `bodyHover`, `edgeHover`, `menuOpen`, `dragging` only; there is no plugin-open input today, so the consumer needs the upstream patch (as planned).

## What Felipe must hand test

- Whether the headless isolated run in the command above is acceptable at all (it was never executed). If not, S1 runs on a throwaway user or VM.
- Whether the marketplace or `omarchy-plugin` install accepts a symlinked or second-repo dock plugin (decides the answer to (a)).
- Anything needing real pointer hover: S1 facts (a) to (e) in the plan.

## Decision 2026-11-09

Decision B: wait for a maintainer reply in discussion #18249 before any more dock work. No symlink experiment and no isolated run now. Verified from the code read above: plugins are discovered only at `plugins/*/manifest.json`, so a `dock/` subfolder inside the omahop plugin is refuted and a dock plugin needs its own top-level folder. Watch #18249, #16609, #16219 and #16479 every 3 days with the workspace `scripts/check-contributions.sh`.

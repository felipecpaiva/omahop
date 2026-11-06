# Window thumbnails in a Quickshell overlay, and prior art (2026-11-06)

## Verdict

1. Thumbnails: YES. Verified live on Hyprland 0.56.2, Quickshell 0.3.2 (Omarchy build).
2. Compositor advertises (checked with a small libwayland registry lister, wayland-info is not installed): hyprland_toplevel_export_manager_v1 v2, ext_foreign_toplevel_list_v1 v1, zwlr_foreign_toplevel_manager_v1 v3, hyprland_toplevel_mapping_manager_v1 v1, ext_image_copy_capture_manager_v1 v1, ext_foreign_toplevel_image_capture_source_manager_v1 v1, zwlr_screencopy_manager_v1 v3.
3. Probe: FloatingWindow with a Repeater over ToplevelManager.toplevels, one ScreencopyView per toplevel (live: true). `grim` screenshot shows real, readable content for Chrome and Slack (workspace 1), Claude Desktop (workspace 3) while another workspace was active. hasContent=true for all 5 views, no permission prompt.
4. Not tested (I would have had to move or hide the user's windows): minimized window, special-workspace window, true occlusion (windows here were tiled, none stacked). Core PR #16548 claims minimized and scratchpad windows are covered, but I did not verify it myself.
5. Cost: with 5 live views, the probe `qs` used about 7 to 19 percent CPU and Hyprland about 14 to 19 percent. No clean idle baseline was taken, so treat this as a rough upper bound, not a measurement. 10 views not tested.
6. Gotchas: DesktopEntries and ToplevelManager are lazy, touch them early (a property binding) or the first read returns empty. `Quickshell.iconPath(name, true)` returned empty for every app on this machine, `Quickshell.iconPath(name)` returned a working `image://icon/<name>`.
7. Prior art is the problem: the marketplace already lists about 25 Alt+Tab, switcher, overview and dock plugins, several with live previews.
8. Core Omarchy has an open PR, omacom/omarchy #16548 "Switch windows with Alt + Tab the way Windows does" (open, updated 2026-11-02): shell-run switcher, hold Alt, live thumbnails of every window on every workspace and monitor, MRU, minimized and scratchpad included. If merged, a switcher plugin is redundant. Core also already ships a dock (plugin, with many open dock PRs and issues).
9. Names: omaswitch is taken (marketplace id `piyush.omaswitch`, repo piyush97/omaswitch, Alt+Tab with live previews and OCR). omadock is taken (marketplace id `omadock`, thepathless/omadock, 48 stars, plus `io.github.matheusmedrado.omadock`). omatab is taken (r3dbars/omarchy-omatab, id `r3dbars.omatab`, plus tony-roslund/omatabs). omahop is free on GitHub (no repo) and in the marketplace.
10. Our ids `io.github.felipecpaiva.*` collide with nothing (only omabarconfigurator and omagnet exist under our namespace).

## Job A details

### Evidence in docs and local modules
- Local modules: /usr/lib/qt6/qml/Quickshell/Wayland/_Screencopy (ScreencopyView: captureSource, live, paintCursor, hasContent, sourceSize, constraintSize, captureFrame()), /usr/lib/qt6/qml/Quickshell/Wayland/_ToplevelManagement (Toplevel: appId, title, activated, minimized, maximized, fullscreen, screens, parent, activate(), close(), setRectangle(); ToplevelManager.toplevels). Quickshell.Hyprland also exists (_Ipc, _FocusGrab, _GlobalShortcuts) for Hyprland IPC and focus grab.
- I did not fetch quickshell.org docs, the local qmltypes plus the probe were enough.
- A toplevel is itself a valid `captureSource`, so no extra wiring is needed.

### Probe results (probe files are in the scratchpad `probe/` dir: probe.qml, icon.qml, reg.c, full.png)
- Toplevels exposed: all 5 windows across workspaces 1, 2 and 3 (including the probe window). Windows on other workspaces DO appear as Toplevel objects, with appId, title and minimized state.
- Window on another workspace: works, real content (screenshot full.png shows Chrome, Slack and Claude Desktop with readable page content).
- ScreencopyView reported hasContent=true, sourceSize = real window pixel size (for example 2560x1552, 1698x1552), constraintSize = -1x-1 (unconstrained, so the view takes the size of the item).
- Live updates: live: true was set and sourceSize changed as the tiled probe window itself resized. I did not measure frame rate, so "updates live" is expected from the API but not quantified.
- Occluded, minimized, special workspace: not tested, see verdict item 4.
- Permissions: none needed, the protocols are open to any client on this compositor.
- Hyprland tiled the probe window as a normal client. To screenshot it I used hyprctl togglefloating on that window only. No user config was changed, no virtual monitors were created.

### Icons
- appId to icon: `DesktopEntries.heuristicLookup(appId)` or `DesktopEntries.byId(appId)` then `.icon`, then `Quickshell.iconPath(icon)`.
- Results here: google-chrome to google-chrome, com.anthropic.Claude to claude-desktop (needed the heuristic or byId lookup, the class name is not the icon name), slack to slack, org.quickshell to org.quickshell. `TUI.tile` has no desktop entry, so keep a fallback icon (`iconPath(name, "application-x-executable")` returns a URL with `?fallback=`).
- Icons exist in /usr/share/icons/hicolor, icon theme is Yaru-grey.
- Do not pass `true` as the second argument of iconPath on this machine, it returned an empty path.

## Job B: prior art

### In flight at Omarchy
- omacom/omarchy PR #16548 (open, rndaom): Alt+Tab as a Windows-style switcher run by the shell. A quick tap goes to the previous window, nothing shows until Alt has been held 100ms, holding shows all windows as live thumbnails with icon and title, Tab, Shift+Tab and arrows move, releasing Alt goes, Escape cancels, Delete or the x closes a window, MRU from Hyprland focus events, covers all workspaces and monitors, minimized and scratchpad windows. This is the strongest overlap with a switcher plugin.
- Related open work: #16404 and #16412 (raise fullscreen window on Alt-Tab), #12118 (scrolling Alt-Tab order), #7839 (swap SUPER+TAB and ALT+TAB), issues #12117, #16241, #7838.
- Dock: core has a dock plugin with many open items (#16967 show on all workspaces, #17644 minimized windows missing from dock, #17539, #17538, #17575, #17339, #16609). A dock plugin is a crowded area.
- Overview: issue #6592 "Workspace Overview" is closed, the marketplace answered it with plugins.
- Our open items (docs/contributions.md): marketplace #14036 (omagnet, awaiting a maintainer), discussion #17754 (snapping, 0 comments). Nothing of ours touches switchers.

### Already in the marketplace (catalog.json, 6368 entries; status Available unless noted)
Alt+Tab or switcher: piyush.omaswitch (live preview and OCR, 13 stars), io.github.pablo-merino.altswitch (26), vbrosseau.alttab (14), io.github.codesmith28.omalt-tab (25), io.github.luwojtaszek.alt-tab, m4rone.slicetab, ewweberlin.quickswitch (hold SUPER, release to switch), losokos.window-gallery, io.github.gabrielvincent.switcharoo, io.github.xadacka.window-switcher, dev.cstav.omarchy.plugin.jump-to, stefans.app-switcher (manual setup), io.github.taisau.bottom-launcher, asaharan.omackey, paudelsamir.switcher, io.github.rohan-patnaik.window-switcher (Orbit), ikekavas.ikea.
Overview or Expose with live previews: expose.window-overview (kristofferR, 43), mirador (40), zzwong.stage, birdseye.window-overview, io.github.aastrand.panorama, io.github.falser101.window-preview, moorgrove.overview, roubilibo.workspace-navigator, io.github.sirmenef.workspace-overview, hancore.overview-workspaces, nahuelvara.windows-menu (bar dropdown with a live thumbnail per window), io.github.bwest8.open-apps (bar icons with live previews), plus about ten more.
Docks and taskbars: rosakodu.dock (53), omadock (thepathless, 48), macos.dock, io.github.nick-friedrich.hyprland-dock, rdf.dock, burninc0de.dock, bogdart.dock, io.github.joeyvigil.taskbar, marcho78.taskbar, io.github.hogar1977.top-bar-dock, io.github.hogar1977 and many macOS-style magnify docks.
Takeaway: a plain Alt+Tab with live thumbnails is the most crowded category. A differentiator is needed (for example something none of them do, a specific interaction model, or pairing with omagnet), or the plugin should not be built.

### Survey of non-Omarchy switchers

| Project | Stack | Alt hold and release | Thumbnails | License | Last push | Steal | Avoid |
|---|---|---|---|---|---|---|---|
| [H3rmt/hyprshell](https://github.com/H3rmt/hyprshell) (formerly hyprswitch) | Rust, GTK4, gtk4-layer-shell, libadwaita, 601 stars | Daemon plus Hyprland submap or keybinds, release of the modifier is watched by the overlay | Hyprland toplevel export (live previews, optional) | MIT | 2026-11-06 | CSS theming, config file, settings app | GTK stack, does not match the Omarchy QML theme |
| hyprswitch (old repos) | same project, old name | n/a | n/a | n/a | the original `hyprswitch/hyprswitch` repo returned 404, forks are dead (last pushes 2024 to 2026-04) | nothing | do not depend on it |
| [Pablo-Merino/omarchy-altswitch](https://github.com/Pablo-Merino/omarchy-altswitch) | Hyprland Lua (keys and state) plus QML shell plugin | Lua owns Alt hold state in a submap, calls `omarchy-shell -q altswitch <method>`, release of Alt commits, Escape cancels | list only in the file set I saw (no previews listed) | MIT | 2026-08-30 | Best template for the Omarchy-native split: Lua owns keys and state, QML only renders. Freeze the list at switch start, virtual selection and focus once on commit | n/a |
| [piyush97/omaswitch](https://github.com/piyush97/omaswitch) | QML plus JS model, tesseract OCR | Needs a one-time keybinding swap, default Alt+Tab keeps cycling until replaced | hyprland-toplevel-export for live preview pane and OCR | MIT | 2026-11-01 | Live preview pane following the selection, graceful degradation when the export protocol is missing, test_model.js for the model | The "installing does not change your bindings" trap generates most issues |
| [kristofferR/omarchy-expose](https://github.com/kristofferR/omarchy-expose) | QML (Overview.qml, WindowCard.qml, IconResolver.js, WindowModel.js) | Overview toggled by key or hot corner (not hold and release) | live previews per card | MIT | 2026-10-26 | Separate IconResolver and WindowModel files, AGENTS.md with PR model checks | n/a |
| [c4software/hyprland-alttab](https://github.com/c4software/hyprland-alttab) (id vbrosseau.alttab) | Rust | overlay | not checked | MIT | 2026-11-03 | not reviewed in depth | n/a |
| [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) | Quickshell QML, big dotfiles | Overview opened by key, not hold and release | ScreencopyView per window in the Overview, grid layout | GPL-3.0 | 2026-10-11 | Reference for ScreencopyView grid and drag between workspaces | GPL, cannot copy code into an MIT plugin |
| [caelestia-dots/shell](https://github.com/caelestia-dots/shell) | Quickshell QML plus C++ plugin | Launcher and overview style panels, not an Alt+Tab | ScreencopyView in previews | GPL-3.0 | 2026-11-05 | Visual polish, animation ideas | GPL, huge, tied to its own shell |
| Quickshell itself ([quickshell-mirror/quickshell](https://github.com/quickshell-mirror/quickshell)) | C++ and QML | n/a | ScreencopyView, ToplevelManager | LGPL-3.0 | 2026-10-22 | the API used by the probe | n/a |
| Waybar taskbar tooltips | C++ | tooltip only | none (Waybar has no per-window live preview) | MIT | not checked | nothing | not a switcher |
| KDE Plasma task switcher | KWin and QML, system component | KWin grabs the modifier and ends on release | KWin renders the windows itself | GPL | not checked | UX reference: delayed show, MRU, quick tap goes back one | cannot be reused |

Rows marked "not checked" were not opened. The behavior columns for hyprshell, end-4 and caelestia come from my prior knowledge, I only verified license, stars and last push date through the GitHub API this session. Verify before relying on them.

### Alt hold and release on Omarchy (pattern found in the plugins)
Hyprland binds cannot see a modifier release by themselves, so plugins use a Hyprland Lua submap (state machine) that enters on Alt+Tab, and a release bind on the Alt key that commits. The shell plugin only draws the card. This is what omarchy-altswitch does and what core PR #16548 does with `default/hypr/window-switcher.lua`.

### Name availability
- omaswitch: GitHub repos piyush97/omaswitch (13 stars, active), yesmeck/OmaSwitch, m4nik1/simple-omaswitcher. Marketplace `piyush.omaswitch` exists. Taken.
- omadock: thepathless/omadock (48), matheusmedrado/omadock, viniabdalla/OmaDocks, others. Marketplace `omadock` and `io.github.matheusmedrado.omadock` exist. Taken.
- omatab: r3dbars/omatab, r3dbars/omarchy-omatab (marketplace `r3dbars.omatab`, unrelated autocomplete tool), tony-roslund/omatabs, and six empty repos. Taken.
- omahop: only an unrelated repo `tehdesaomahopah/tehdesa-omahopah` (last push 2025-10-08). Free for practical purposes. No marketplace entry.
- `io.github.felipecpaiva.<name>`: existing ids under our namespace are `io.github.felipecpaiva.omabarconfigurator` and `io.github.felipecpaiva.omagnet`. No collision for any of the four names.

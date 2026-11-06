# Competitive analysis (2026-11-06)

Three agents scored 30 projects against 30 omahop feature keys (F1 to F30). Raw matrices and per-project notes:
[research/competitors-switchers.md](research/competitors-switchers.md),
[research/competitors-overviews.md](research/competitors-overviews.md),
[research/competitors-docks.md](research/competitors-docks.md).
Evidence is README text, source files and issue titles read through the GitHub API; nothing was installed or run.
A "No" means absent from what was read, not a full source audit. Open-issue counts are small, so praise is mostly README
self-claims. I spot-checked the switchers matrix rows F4, F10, F12, F13, F14, F17, F21, F23 against the file; they match the summaries.

## Where omahop is alone (open ground)

| Key | Feature | Who has it |
|---|---|---|
| F12 | Floating-workspace-only scope | Nobody (0 of 30) |
| F27 | Stock Alt+Tab fallback out of scope | Nobody |
| F21 | Settings GUI on a switcher | No switcher. Only docks (for example omarchy-spaces, 222 stars) |
| F13+F14 | Workspace and monitor filters together, as settings | switcharoo and luwojtaszek each have one half or part |
| F17 | Hover preview over the STOCK dock icon | Nobody (5 projects do it on their own dock; end-4 is GPL) |
| F24 | Letter hints | Nobody |
| F4+F6+F20 | List style with thumbnails that follows the Omarchy theme | Nobody has all three |

## Where others already are ahead or equal

| Area | Who | What it means for us |
|---|---|---|
| Core PR #16548 | Core | Tap to previous, 100 ms reveal, release commits, live thumbnails, all workspaces and monitors, minimized restore, theme, z-raise. Open, bot-reviewed only, 6 unresolved findings. No search, filters, config or floating scope |
| Vertical list | luwojtaszek/omarchy-alt-tab (reveal delay, search, jump numbers, per-bind profiles, tests), piyush97/omaswitch (list plus OCR search) | A list alone is NOT a differentiator. Ours must be better, not just present |
| Filters | switcharoo (workspace, monitor, class) | Match it, then add scope |
| Search | luwojtaszek, omaswitch (OCR of window content), window-gallery, xadacka | Table stakes in the list style: move search earlier |
| Hover previews | macos.dock, omadock, spaces, taskbar, top-bar-dock | Crowded on own docks. Open ground only for the stock dock, which has no hook (core issue 16609) |
| Cost control | omadock (VRAM 194 to 26 MiB, live Wayland tests), window-gallery (snapshots measured near free) | Default `thumbnails = snapshot`, live and off as options |
| Overviews | expose (43 stars), Mirador (40, 18 open PRs: MRU, search, close buttons) | Not our space, but Mirador may converge on our plan: watch it |

## Highlights worth stealing (ideas; code only from MIT, Apache-2.0 needs attribution, never GPL)

- Reveal delay and tap-to-previous (core, luwojtaszek, hyprshell). Already in v0.1.
- Jump numbers and per-bind profiles (luwojtaszek). Profiles fit our settings model.
- Separate `WindowModel` and `IconResolver` files with a model test (omaswitch, expose). Fits our pure-logic rule.
- Graceful degradation when the capture protocol is missing (omaswitch).
- Live Wayland test suite (omadock).

## Traps others hit (design them in from the start)

1. **Floating windows get focus but stay behind.** omaswitch issue 14 on Omarchy 4.5. luwojtaszek, omalt-tab and core fix it with `bring_to_top` and `alter_zorder`. Our focus step must raise. This is exactly our home turf.
2. **Wine and Proton ghost windows** fill the list with dead entries (omaswitch 13, core commit 2). Filter on real Wayland toplevel presence.
3. **Alt release arrives as an unmapped key.** Match scan codes 64 and 108, not only key names. Test both Alt keys.
4. **A capture on a vanished output aborts Hyprland.** Never capture a window whose output is gone. Same family: screen capture can crash the shell when another capture tool runs (falser window-preview issue 3).
5. **A plugin-triggered config reload crashed Hyprland** (macos.dock issue 24). Never reload config from the plugin.
6. **Duplicate keybinds on monitor hotplug** (hyprshell 526). Bind lifecycle needs a test.
7. **Pointer warping on focus** is a recurring complaint. Do not move the pointer.
8. **Tap versus hold races** (end-4 3728 and 3752). Reveal delay needs tests.

## Do we shift course? Verdict: sharpen, do not pivot

1. **Reposition.** omahop is not "another Alt+Tab with previews". It is the switcher that is floating-desktop aware: scope, window-set filters, stock fallback, a settings app, theme-live. Nobody has this. Keep the README and marketplace text on that line.
2. **Raise the bar on the list style.** Search moves from v0.4 to v0.2. The v0.1 list must handle floating raise, ghost windows and both Alt keys correctly, which the rivals show is where they fail.
3. **Demote hover previews, keep them.** F17 on the stock dock is open ground but blocked and risky. v0.3 stays, with D8 resolved toward an own strip or an upstream hook; do not depend on dock geometry.
4. **Core PR watch.** If #16548 merges, we keep our reasons (scope, filters, GUI), and we could offer scope and filters to it as upstream PRs instead of duplicating its switcher. Re-check its state before each release.
5. **Letter hints and profiles stay in v0.4.** Nobody has hints; profiles exist only in luwojtaszek.

Roadmap and spikes changed accordingly (see `ROADMAP.md`).

## Addendum: Omarchy community search (code and people)

Files: [research/community-code.md](research/community-code.md), [research/community-voices.md](research/community-voices.md).
Reddit was blocked and Hacker News showed nothing, so demand outside GitHub is UNVERIFIED. I spot-checked: core PR #16219 is open, and the repos `sparkrussell/omarchy-alt-tab-switcher` (8 stars, MIT) and `timurguseynov/omarchy-x-mode` (9 stars) exist.

**Answer to "did someone already build it?" Yes, in pieces, and more than we first counted.**

- Six more Alt+Tab plugins with live previews were missed by the first survey: sparkrussell, jburchel, jakubkozera, manateelazycat, rmacy (Mission Control 3.0.0), devmobasa. Closest duplicate of the switcher: `sparkrussell/omarchy-alt-tab-switcher` (Lua owns the keys, Quickshell draws with ScreencopyView, the same split as our plan).
- Closest duplicate of the "Mac on floating" idea: `timurguseynov/omarchy-x-mode` (floating, titlebars, snaps, dock, Command-Tab). It switches by app icon with no thumbnails and needs a C++ hyprbars plugin.
- Core has BOTH headline features as open PRs: #16548 (Alt+Tab with live thumbnails) and #16219 (dock hover live previews, plus a competing text-list version in #16479). No maintainer has replied on either, only bots. Merging either makes the matching omahop feature redundant. This is the top kill risk.
- Omarchy 4.5.0 (2026-11-05) already ships floating workspaces, a dock and Super+M minimize. The maintainer frames it as a traditional desktop mode with a dock (seen as a search snippet only).
- No maintainer has rejected a switcher or previews. The only unexplained "no" is the removal of minimize and edge snapping from the first floating PR (#14482), which later returned in 4.5.
- Plugins are unsandboxed; every update needs re-verification or shows "Update unverified"; a 4.0.3 regression for third-party overlays (#10907) is still open; the dock is core QML that plugins cannot extend (#16609).
- The ecosystem is large: `quantavil/awesome-omarchy-plugins` indexes 2,600+ plugins. Use it for duplicate checks before every release.

**Real gap nobody fills: raising a floating window.** Core issues #16241, #16973, #17724 show Hyprland leaves a fullscreen or maximized floating window unraised after Alt+Tab, and clicks pass through to it. Core PR #16412 proposes lowering other windows below the target. No community switcher handles it. x-mode contradicts itself on whether a focus dispatch raises a floating window, so we test on Hyprland 0.56.2 (spike S8) before trusting any claim.

**Techniques seen in public code (ideas, mind licences):**
- Alt release: a submap plus a global release bind, `release, submap_universal, transparent, non_consuming`. One plugin also binds Meta_L and Meta_R across mod-mask combinations. A claim that "release never fires, use a 3 s timeout" looks wrong. We use our own polling (omagnet `super_down`) and cross-check with this bind in spike S1.
- Per-class MRU kept by the plugin so cycling does not scramble order (x-mode). Focus by stable window id (rmacy). Same-app cycle (offGustavo). Quick-tap show delay (jburchel).
- Hyprland truncates socket2 events at 1024 bytes (issue #17078, E2BIG on long titles): never depend on full titles from events.

**Techniques to avoid:** grim region screenshots for previews (wrong content for occluded floating windows); a C++ Hyprland plugin that hooks internals (breaks on version bumps, hyprdrive).

**Updated verdict.** The plain "Alt+Tab with previews" space is taken, and core may take it officially. What stays ours: floating-correct raise and focus, scope and window-set settings, stock fallback, the settings app, and per-app cycling. Before building the switcher core, read PRs #16548 and #16219 in full and decide whether to offer our parts to them as PRs (decision D12, Felipe's call: commenting on upstream is outward-facing and I will not do it unasked).

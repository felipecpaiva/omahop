# Omarchy community and maintainer voices: switcher, floating mode, dock, previews

Research date 2026-11-06. Public read only (gh API on omacom/omarchy and omacom/omarchy-plugin-marketplace, omarchy.org pages, web search). Not repeated here: the four existing research files. Reddit could not be searched (blocked for the crawler), so Reddit/YouTube demand is UNVERIFIED.

## Verdict (10 lines)
1. Demand is real but it is already being absorbed upstream: Omarchy 4.5.0 (released 2026-11-05) ships floating workspaces, a dock and Super+M minimize in core, with "traditional desktop" as an explicit goal.
2. The two features omahop plans are both open PRs against core right now: Alt+Tab Windows-style switcher with live thumbnails (#16548, 2026-10-25) and dock hover window previews with live thumbnails (#16219, 2026-10-21). Neither is merged; neither has a maintainer reply.
3. Both PRs come from outside contributors (#16548 author_association is NONE; #16219 not checked), not DHH. Open for 12 to 16 days with only bot comments. So the maintainers have not said yes or no.
4. DHH's stated direction is "kill the reasons not to switch": "Traditional desktop mode with a dock!" (X post). A Windows-style Alt+Tab fits that direction; a plugin that duplicates it would likely be redundant if #16548 lands.
5. Maintainers removed minimize and edge snapping from the first floating PR (#14482, commit 97fd964c, no rationale given), then minimize came back within weeks. Scope was cut for the first release, not obviously rejected on principle. Snapping question is unanswered (discussion #17754, 0 comments).
6. Plugin route is encouraged and structured (marketplace, commit-bound verification), but plugins are unsandboxed and the shell plugin API has been unstable (4.0.3 broke third-party overlays and menus, still open).
7. Floating mode is young and buggy: about 15 open floating/dock issues in the last 3 weeks (stacking order, fullscreen not raised on Alt+Tab, double titlebars, click-through). Any switcher that raises or focuses windows must work around these Hyprland bugs.
8. Biggest kill risk: #16548 merging into 4.5.x/4.6 (then omahop switcher is a duplicate), and #16219 or #16479 merging (then omahop hover previews are a duplicate). Second: the dock is core QML (shell/plugins/dock), which a plugin cannot extend (see #16609: "a plugin can't reach the dock").
9. Safest differentiation: things core PRs explicitly exclude or have not touched (floating-workspace-scoped MRU, per-app window lists on Alt+` , search, snapping-aware layouts), or contribute the switcher as a PR instead of a plugin.
10. Recommendation: before building, comment on #16548 and #16219 to learn whether core wants them, and decide plugin-vs-PR from the answer.

## 1. Timeline of what core did (context)

| Date | Event | Source |
|---|---|---|
| 2026-08-06 | Overview feature request closed as completed 2 days later | #6592 |
| 2026-08-25 | `Cycle Super + L on into a floating workspace` opened by the Omarchy bot, closed in favor of #14482 | #8260 |
| 2026-10-07 | Floating mode PR #14482 by ryanrhughes (COLLABORATOR), merged 2026-10-11 | #14482 |
| 2026-10-20 | 4.5.0-rc1 | releases |
| 2026-11-05 | 4.5.0 final, "over 740 pull requests merged from more than 180 contributors in just twelve weeks" | release notes |

Floating mode origin and rationale (#14482 body, 2026-10-07, author ryanrhughes): "Adds a floating mode to the `Super + L` workspace layout cycle, and gives floating workspaces titlebars in the current theme's colors." Same body: "There's no minimizing and no edge snapping: an earlier version of this PR had a Shelf for minimized windows and drag-to-edge snapping, and both were removed." Commit 97fd964c message: "A floating workspace is now titlebars with maximize and close, and nothing else." No reason is given beyond that. Meaning for omahop: OPPORTUNITY and RISK. Snapping/minimize were scope cuts that core later partly reversed (minimize), so features can migrate into core quickly.

Implementation facts useful as TECHNIQUE: floating mode is `default/hypr/workspace-modes.lua`, it floats windows itself and tags them (`omarchy-mode-floated`, `omarchy-floating-workspace`); titlebars come from a hyprbars fork `omacom/omarchy-hyprland-titlebars` (a native Hyprland plugin, so it breaks when Hyprland bumps: see #17819 "dependency conflict with hyprland 0.57.1").

## 2. Direct signal on the omahop features

### 2.1 Alt+Tab switcher in core: PR #16548 (HIGHEST RISK)
- Link: https://github.com/omacom/omarchy/pull/16548 , "Switch windows with Alt + Tab the way Windows does", author rndaom, opened 2026-10-25, open, 2 comments (bots only), label enhancement, still unmerged on 2026-11-06 (updated 2026-11-02).
- Key text: "This makes it the Windows switcher, run by the shell ... Holding Alt shows every window, most recently used first, as live thumbnails with each app's icon and title. That covers every workspace and monitor, minimized and scratchpad windows included."
- Design: a QML plugin `shell/plugins/switcher/`, three global shortcuts, shows after Alt held 100 ms, quick tap flips to previous window, Delete closes a window, hover only highlights.
- Technique worth copying (omahop can reuse the ideas): overlay maps on first Tab so the keyboard leaves the app (otherwise the app sees Alt tap and opens its menu bar); Hyprland refuses focus while an exclusive layer-shell surface holds the keyboard ("Refusing a keyboard focus to a window because of an exclusive ls") so the pick is dispatched on the overlay's `closelayer` event with a 500 ms fallback; list only windows with a Wayland toplevel (Wine/Proton create never-mapped windows); `foreground-lock.lua` turns off `focus_on_activate` for fullscreen XWayland windows that lost focus (Proton bounce-back).
- Verified by author on Hyprland 0.56.2 with two monitors. UNVERIFIED whether maintainers want it.
- Meaning: if merged, omahop's switcher (live thumbnails, MRU, tap-to-flip) is a duplicate. Third-party switchers already listed in the marketplace (see competitors-switchers.md) would be too.
- Also related: #16404 "Raise fullscreen floating window on focus and Alt-Tab" (hari45wavin, open, 7 comments) and #16412 by the Omarchy bot, "Raise a fullscreen window over the floating windows Alt-Tab left on it". Bug #16241 (dhoutz, 2026-10-22): "a fullscreen window is never brought to the front when Alt-Tabbing ... It does receive focus ... but it stays visually behind the rest of the stack." Bot reply (2026-10-23): "The cause is in Hyprland, and its `main` branch has the same logic." Meaning: TECHNIQUE/RISK, any plugin that focuses windows on floating workspaces inherits this; the fix used is `alter_zorder({ mode = "bottom" })` on siblings (PR #16404 comment, 2026-10-25).

### 2.2 Hover previews in the dock: PR #16219 and #16479
- #16219 https://github.com/omacom/omarchy/pull/16219 "Improve dock UI: window previews on hover and cleaner indicators", author itscallssh, opened 2026-10-21, open, 2 comments + 1 APPROVED review (chessing234, "all good"). Text: "Hovering a running app in the dock now shows a live thumbnail of each of its windows instead of a plain list of window titles. Up to 4 previews on horizontal docks and 3 on vertical docks ... Click a preview to focus that window. Minimized windows are restored first."
- #16479 https://github.com/omacom/omarchy/pull/16479 "Show an app's windows from the dock", dedeanth, 2026-10-24, open. Text-list variant: "Hovering an app with two or more windows opens a list of them after a short delay (350 ms): each row shows the window title and where it is (its workspace, or 'Minimized')." Review requested changes (toplevel null-check).
- Competing designs for the same feature at once means core has not picked one. Meaning: DEMAND signal (two independent contributors wrote hover previews within 3 days), and RISK (one will likely merge, and a plugin cannot override the dock; see 3.3).
- Dock window-count/indicator PRs: #15278 "Show a line under running apps" (nightdevil00, 2026-10-13, 5 comments). A maintainer-ish reviewer (jandrusk) asked to split unrelated change: "easier to review and revert separately." Meaning: core reviewers prefer small focused PRs.

### 2.3 Dock confined to floating workspaces: demand to widen
- #16967 (R1T1KKUMAR, 2026-10-29) "Dock plugin: Add an option to show the Dock on all workspaces": "Users who prefer tiling layouts cannot keep the Dock visible across all workspaces."
- #17882 (gumbledore, 2026-11-06): "The new dock in 4.5 is great. I'd like to use it on tiling and dwindle workspaces too, but today it is floating-only in two places" (`DockWindow.qml:40` and `bin/omarchy-hyprland-window-minimize:18`).
- PRs #17575 (sanjyay, `dock.showOn`), #17538 (mstio, `dock.showOnAllLayouts`), all open 2026-11-04.
- Meaning: DEMAND that the floating-only scope is too narrow; core is likely to widen it. An omahop that is strictly floating-only (like most Omarchy floating features) may be narrower than where core goes. Consider "works on any layout, MRU includes all workspaces".

### 2.4 Bugs users hit in floating mode (what a switcher must survive)
All open, filed 2026-10-19 to 2026-11-05, almost all 0 to 3 comments, no maintainer fix merged:
- #16973 stacking order breaks when switching back to a maximized window.
- #17724 clicks on floating windows over a maximized window pass through to the maximized one (PR #17360 by rndaom "Let clicks reach a window drawn over a maximized one").
- #17049 opening a second window un-maximizes the first.
- #16736 REAPER XWayland menu un-maximizes window.
- #17644 "4.5.0: minimized windows don't show up on the dock" (RajdeepVerma, 2026-11-05). Also #17632 minimize leaves keyboard focus on hidden window. Meaning: minimized-window state is fragile; the switcher should read it from Hyprland (special:minimized workspace) not assume dock state. Issue #17882 says minimized windows live in `special:minimized`.
- Duplicate titlebars with client-side-decoration apps: #15996, #16974, #17736 (lloydshinee: "you end up with two titlebars stacked on top of each other"), #17704, #17540.
- #16366 titlebars ignore tablet pen input.
- #17391 grouped window cannot move between monitors.
Meaning: RISK/opportunity. Floating mode is unstable, so users will blame any overlay for focus glitches; and quality (stacking-order-correct raise) is a selling point.

## 3. Maintainer direction and plugin policy

### 3.1 What maintainers say they want
- DHH on X (https://x.com/dhh/status/2109945839494086939, date not retrieved, page returned 402; text seen via search snippet only, UNVERIFIED wording source): "One more excuse not to switch to Omarchy has been stricken from the list: Traditional desktop mode with a dock! We'll keep killing reasons until there's very little reason not to join us in the future." Search summary also attributes to the same thread that floating mode "comes with Alt+Tab, minimization, left/right/top/bottom positioning" (UNVERIFIED).
- 4.5 release notes, https://omarchy.org/news/2026/11/omarchy-4-5/ (2026-11-05): "It now offers a traditional desktop mode next to the tiling default." "Super + L now cycles any workspace between tiling, scrolling, and floating." "every window gets a titlebar in your theme's colors, and a dock shows your pinned apps, everything that's running, and a grid of every app installed." "Super + M minimizes a window down to the dock." Only Alt+Tab mention: "Fix Alt + Shift + Tab not cycling backwards through every window." The notes call this an on-ramp for people from macOS or Windows (via secondary coverage, UNVERIFIED wording).
- Manual (https://omarchy.org/manual/navigation/): "A floating workspace works like a traditional desktop: windows overlap, and you move and size them yourself." Dock click "brings its window forward, and clicking again cycles through its windows." "You navigate between the window you want to be active with `Super + Arrow`." `Super + Tab` cycles workspaces; the manual does not document Alt+Tab. Meaning: Alt+Tab remains Hyprland's `cycle_next` (active workspace only, fixed order) in 4.5.0 final, as #16548 states. So the gap omahop targets exists today.
- Rejections or "no" statements: none found from DHH for switcher/previews. Only rejection-like item is the pre-release scope cut of minimize/snapping (2.1 above). Earlier signal on window search: Walker maintainer (abenz1267, #1208 2025-08-28, closed) said window module is disabled "due to an upstream bug" and told the user to write a dmenu script over `hyprctl clients`; the issue was about a rofi-like window switcher (10 comments). Old, but shows windows listing was a long-standing ask.

### 3.2 Demand signals for switching and overview
- #7838 (nestor-bolivar, 2026-08-23, open): "A large share of new Omarchy users are coming from macOS ... one of the most deeply ingrained habits is Cmd + Tab". Proposes swapping SUPER+TAB to windows; companion PR #7839 (0 comments). Meaning: DEMAND from the macOS audience, with a keybinding angle (omahop should be bindable).
- #6592 (flaxrora, 2026-08-06, closed completed 2026-08-08, 0 comments): "I often find myself switching back and forth between workspaces just to locate a specific window" and asks for a Mission Control/Activities-style overview. Closed as completed with no linked comment seen: UNVERIFIED how (likely a community plugin exists; `expose.window-overview` is referenced in #10907). Meaning: DEMAND for overview, handled by plugin route.
- #11182 (alihancaliskanx, 2026-09-10): smart focus navigation while maximized. #12117 (DaDecky, 2026-09-16) Alt+Tab does not follow adjacent windows in scrolling layout, with PR #12118. #7561 "Alt+Shift+Tab cycles between only two windows" closed 2026-08-20 (fixed, in 4.5 notes).
- Numeric demand is low per item: most issues have 0 to 3 comments. Real demand is shown by PR volume (3 dock PRs on all-layouts, 2 on previews, 1 on Alt+Tab) rather than upvote counts. Reaction counts were not collected.

### 3.3 Plugin system direction
- Marketplace repo: https://github.com/omacom/omarchy-plugin-marketplace (policy files SUBMISSION.md, VERIFICATION.md, SECURITY.md read 2026-11-06).
- Encouraged: one public repo, `manifest.json` at root, README with install and removal, license, globally unique ID outside reserved `omarchy.*` namespace. Categories include Desktop, Appearance, Productivity, Widgets; tags include `launcher`, `workspaces`, `quickshell`, `hyprland`.
- Verification: "Every new submission must be published through the explicit `approved-and-verified` label"; verified snapshot is commit-bound; "`Update unverified` means the current observed upstream commit differs from the verified snapshot." So every omahop release needs a promotion request or it shows Update unverified.
- Blocked/flagged by static scan: `curl-pipe-shell`, unpinned cargo git / remote git execution, dangerous NOPASSWD sudoers, privileged PID from /tmp. Needs maintainer review ("capabilities"): installer, package-manager, privilege (sudo/pkexec), remote-build, bundled executable binary, systemd service management, sudoers changes.
- Overlays and input handling: no restriction found in these three files. SECURITY.md: "Plugins run as unsandboxed upstream code." So a QML overlay and Hyprland global shortcuts are allowed in principle; only shell/privilege/binary patterns trigger review. A native module (compiled binary) would trigger `bundled-executable-binary` review. UNVERIFIED: whether a manifest permission model exists beyond this.
- API stability: #11229 (closed) and #10907 (open): "Since 4.0.3, a third-party panel, overlay, menu or service plugin gets the scoped `PluginShellApi` ... That facade has no `shellConfig` ... so the plugin silently sees nothing" (omarchybot, 2026-10-11). Also #13382 "A throwing plugin close() leaves the panel overlay mapped and locks all pointer input", #10979 third-party popups become stuck overlays, #12601 plugin hot-reload re-initialises every installed plugin, #17261 menu plugin loses Apps list after reload. Meaning: RISK, third-party overlay plugins are a known weak spot; test with config reload and failure paths. Also: bar API is public ("publicBarConfig"), dock is not.
- Dock extensibility: #16609 (rndaom, 2026-10-25, open): "a plugin can't reach the dock, and a cloned dock gets neither the dock config nor the app library." It adds `dock.launcher` so a menu plugin can take over the apps button. Meaning: hover previews cannot be added to core dock as plugin; omahop would need its own dock or a PR. The `omarchy-shell omarchy.dock apps` IPC exists.
- Core hint the plugin route is the norm: the maintainer-affiliated reviewers and the Omarchy bot (omarchybot) test PRs on VM workers built from the ISO and post verification. Contribution style = small, tested, bot-verified. A plugin submission is lower friction than a core PR but a core PR is how rndaom's switcher is going.
- Note: the omahop author's own question to maintainers, discussion #17754 "Window snapping on floating workspaces: plugin or core?" (2026-11-05, 0 comments) is the live probe of "plugin or core". An answer there will indicate stance; check it before committing the omahop architecture.

## 4. External community voices (thin)
- Starry Hope, https://www.starryhope.com/linux/omarchy-floating-windows-dock/ and https://www.starryhope.com/linux/omarchy-4-5-whats-new/ (2026-10-21, RC1): "Minimizing works only on floating workspaces; on a tiled one, Super M does nothing." RC1 known issue: "with two windows of the same app open, clicking the icon did not always restore the minimized one." Window switching is described via the dock only, Alt+Tab not covered. Meaning: reviewers do not yet treat Alt+Tab as a feature of floating mode, which is the gap.
- Same site notes a third-party "Familiar Desktop" plugin giving window buttons, taskbar/dock and macOS-style left buttons and hover previews (UNVERIFIED, search summary only; not read in full). Likely also in competitors-docks.md; check.
- OmaSwitch blog https://piyushmehta.com/blog/omaswitch-alt-tab-omarchy ("The Alt+Tab Omarchy Has Been Missing", per search title) already covered in competitors-switchers.md.
- Phoronix, AlternativeTo, daily.dev: confirm 4.5 release and floating/dock; no switcher discussion.
- Hacker News: only a roughly 14-month-old comment on Omarchy 2.0 turned up; nothing on switchers or floating mode. Lobsters: nothing found. Reddit and YouTube comments: NOT SEARCHABLE here, UNVERIFIED. YouTube title seen: "What's Coming in Omarchy 4.5" (https://www.youtube.com/watch?v=FtGIFydnvUg), snippet only.
- So organic community talk about Alt+Tab or previews outside GitHub is thin or invisible to these tools. Do a manual r/omarchy search before treating demand as proven.

## 5. What it means for omahop (ranked)

1. RISK, critical: #16548 (Alt+Tab, live thumbnails, MRU, all workspaces) is a feature-complete core PR. If it merges, omahop switcher loses its reason to exist. Action: read it fully, test it on this machine, and either (a) differentiate or (b) contribute review and tests there.
2. RISK, high: #16219/#16479 own hover previews in the dock. Action: decide whether omahop previews live in a separate dock/overlay or get dropped.
3. OPPORTUNITY: core's floating mode is unstable; a switcher that raises correctly (alter_zorder bottom on siblings, closelayer dispatch, Wayland-toplevel-only list) and handles minimized (`special:minimized`) windows is a real quality gap today, even if temporary.
4. OPPORTUNITY: dock/minimize are floating-only in 4.5.0 and users are asking to widen (#16967, #17882); a layout-agnostic switcher/preview is not blocked by that and may beat core on scope.
5. DEMAND: macOS and Windows switchers are the stated audience (#7838, release notes on-ramp). Cmd+Tab (app-level cycling, per-app window cycling) is not covered by #16548 as far as read; UNVERIFIED, read the full diff.
6. TECHNIQUE: copy the failure-mode list in 2.1 (Alt tap opens app menu, exclusive layer blocks focus, Wine ghost windows, Proton bounce-back, `focus_on_activate`).
7. RISK, medium: plugin API churn (PluginShellApi 4.0.3 regression still open) and verification flow (each update needs re-promotion). Budget for CI against omarchy-dev and Quattro betas.
8. Governance: no quote found of DHH rejecting a switcher or previews. The only "no" is the unexplained pre-merge drop of minimize/snapping in #14482 (minimize returned in 4.5). Ask in an issue or discussion rather than assume.

## 6. Not done / UNVERIFIED
- Reddit, Lobsters, YouTube comment bodies; DHH tweet date; full text of #16548 review thread beyond bots; PR reaction counts; whether #6592 closure pointed to a plugin; manifest permission model beyond the three policy files; whether 4.5.0 final contains #16548 (it does not: shell/plugins listing at tag v4.5.0 has no `switcher` dir).

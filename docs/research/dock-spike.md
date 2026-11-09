# Dock spike (v1.7, decision D23)

Read 2026-11-09 with `gh`, read only. Nothing was commented, reacted to or opened upstream. "Verified" means read in the PR diff, API or repo file on that date. Anything else is marked NOT VERIFIED.

## Facts: the open dock PRs

All are against `quattro` (the base of every dock PR and of our own #10789). All are open on 2026-11-09. Mergeable state shown is GitHub's, not a maintainer verdict.

| PR | Author | Opened | Last activity | Size | CI | Human review |
|----|--------|--------|---------------|------|----|--------------|
| #16219 dock hover live previews | itscallssh | 2026-10-21 | 2026-11-09 (bot) | +661/-35, 5 files | `test` FAILING, i18n and visual-evidence pass, mergeable but UNSTABLE | one approval (chessing234, 2026-10-23), one suggestion from sanjyay 2026-10-28, no maintainer reply |
| #16479 dock window list and dots | dedeanth | 2026-10-24 | 2026-11-06 | +262/-6, 4 files | only Greptile reported, UNSTABLE | chessing234 CHANGES_REQUESTED 2026-10-24, author replied "fixed" 2026-10-24 and 2026-10-29, never re-approved; a user (Raynok) proposed badges and highlight on 2026-11-06; no maintainer reply |
| #16609 menu plugin takes over the apps button | rndaom | 2026-10-25 | 2026-11-02 | +222/-9, 11 files | only Greptile, UNSTABLE | none; Greptile P1 "Super tap fails" (a `workspace_modes.floating` that does not exist) NOT VERIFIED as fixed |

Greptile findings still standing on #16219 (2026-11-09): P1 the new Minimize row uses `MenuRow`, which is not available, so `DockWindow.qml` cannot load; animations ignore the disable-animations setting; bounce and `Easing.OutCubic` break the motion guide. In other words #16219 is mid-rework, not ready.

The called "dock hook" #16609 is not a hover hook. It is a launcher takeover (see below).

### What each diff does

**#16219** (files `shell/plugins/dock/Dock.qml`, `DockModel.js`, `DockWindow.qml`, `shell/services/AppLibrary.qml`, `default/i18n/en/shell.json`).
- Replaces the plain tooltip with a tooltip that holds up to 4 (3 on a vertical dock) live thumbnails. Dwell 350 ms (`tipTimer`), 250 ms grace to cross onto the previews (`tipLeaveTimer`), warm re-show 400 ms.
- Thumbnails are a private `component PreviewCard` inside `DockWindow.qml` using `ScreencopyView { captureSource: card.active ? card.toplevel : null; live: true; constraintSize: ... }`. So yes, it uses ScreencopyView, only for the card in view.
- Hover state is internal: `tipSlot`, `pendingTipSlot`, `tipWarm`, `showTip(slot)`, `hideTip(slot)`, `dismissTip()`, plus a `tipHover` HoverHandler that also keeps an auto-hidden dock revealed. Nothing is exported, no signal, no IPC.
- Slot geometry stays internal (`slot.mapToItem(window.contentItem, ...)` in `popupX`/`popupY`, existing code). The dock mask gets a new `Region` for the tooltip, and surface depth becomes `previewRoom`.
- Click on a card focuses the window, restoring a minimized one first. Minimized cards are dimmed. Adds a `minimize` action in the icon context menu and a `newWindow` action, `markLaunching` pulse, indicator moves. No close button on cards (NOT seen in the diff).

**#16479** (`DockWindow.qml`, `DockModel.js`, `test/shell.d/dock-test.sh`, i18n).
- Up to three dots per running app (`DockModel.dotCount`), focused window's dot in accent color.
- Hover over an app with 2 or more windows, after 350 ms (`listOpenTimer`), opens a popup list: title plus workspace or "Minimized". Click row calls the existing `bringForward`. Closes 300 ms after the pointer leaves icon and list.
- Hover state is internal: `slotHovered(slot, key, hovered)`, `listKey`, `listSlot`, `listHover`. Input mask extended. No export, no signal. No close or minimize on rows. No thumbnails.
- Has a unit test through `dock-test.sh` (`dotCount`, `listsWindows`).

**#16609** (11 files: `bin/omarchy-dock`, `Dock.qml`, `DockModel.js`, `DockWindow.qml`, `docs/omarchy-shell.md`, Hyprland Lua binds, tests).
- New config `dock.launcher` names a `menu` kind plugin that the apps button (and `omarchy-shell omarchy.dock apps`, Super+Alt+Space) opens instead of the app grid. `omarchy dock launcher <plugin-id>` or `grid`.
- The launcher's `open(payloadJson)` gets screen, dock edge, and the rects of the dock and its apps button in screen coordinates. Auto-hidden dock stays out while it is open; clicking elsewhere in the dock closes it. Contract is written into `docs/omarchy-shell.md`. A Super tap opens apps on floating workspaces (separate commit, offered as optional by the author).
- This is the only open PR that gives third parties a documented dock seam, and it is the right shape to copy (payload JSON, rects, existing `menu` kind, no new kind). Example consumer by the author: `rndaom/omarchy-start-menu` (NOT cloned or read).

### Related issues and PRs

- Issue #16967 (R1T1KKUMAR, opened 2026-10-29, no replies, no maintainer): dock on all workspaces. Duplicated by issue #17882 and by PRs #17575 (sanjyay, `dock.showOn`, closes #16967, CI test/i18n/visual all pass) and #17538 (mstio, `dock.showOnAllLayouts` plus styling). Relevant to us: if merged, the dock exists on tiled workspaces, which widens where our dock features apply.
- Issue #17644 (opened 2026-11-05, no replies): minimized windows (Super+M) do not appear on the dock. Related: #17890, #16156. Means "minimize on cards" depends on core's minimize model (a `special:minimized` workspace) that is itself unsettled.
- #17539 (itscallssh, +517/-88, `test` CI failing): app grid polish, type to filter, pin keys. This is the stock "search" for apps, not windows.
- #17339 (kill74, Hyprland reload blink, mergeable) duplicates #17140 and issue #17333. Dock is churning: roughly 40 open dock-titled PRs on 2026-11-09 (e.g. #16765 stop starting a running app, #18140 hide the dock under a covering window, #16960, #17362, #17149, #18082).
- Every PR above was read as having no reply from dhh or another human maintainer. The only non-bot actor with authority in the threads is `omarchybot` (see process section) and it commented on none of #16219, #16479, #16609, #17538, #17539, #17575 (checked by author association).

### Maintainer statements about third party plugins and the dock

None found. Searched PRs and issues for dock plus plugin, extension, clone, hook, third-party; nothing from a maintainer. What is documented (`docs/omarchy-shell.md` and `agents/skills/shell-dev.md` on `quattro`):
- Plugin kinds are `bar-widget`, `bar`, `panel`, `overlay`, `menu`, `service`. The dock is `omarchy.dock`, kind `service`, a first-party plugin with no extension point.
- Third-party plugins get "capability-scoped facades", not host objects. Built-in clones get "narrow source-specific configuration and UI compatibility", and "Clone is limited to" built-ins (a cloned dock "gets neither the dock config nor the app library", per #16609's body, which is the author's claim, NOT verified in code).
- The docs state the facades are not a sandbox. Any new seam must not hand out toplevel objects or authentication services.
- Dock is not mentioned as extensible anywhere. NOT VERIFIED: any private maintainer intent.

## Facts: contribution rules

- No `CONTRIBUTING.md` (404 in repo root and `.github/`). `AGENTS.md` on `quattro` is the authority; the omarchy skill says the same.
- Base: `quattro` (all 40-odd open dock PRs and #10789 use it). NOT VERIFIED whether `dev` or `master` still take fixes.
- One problem per PR. Atomic commits, short messages. Run `./test/all` (CLI plus `test/shell.d/*`). Dock work already has `test/shell.d/dock-test.sh` to extend; pure logic goes in `DockModel.js` so the shell test can cover it (this is how #16479 and #16609 did it).
- Screenshots: required in practice. The PR template says CI flags shell PRs with an empty Screenshots section; `visual-evidence` check exists. Recordings for motion. Never commit them to the repo; drag into the PR. `agents/skills/visual-verification.md` requires verifying in the running UI. `agents/skills/motion.md` is enforced by Greptile (use `Style.duration`, `Style.easeOut`, no bounce).
- New strings need `default/i18n/en/shell.json` entries (i18n-check fails otherwise); displayed numbers go through the I18n number helper.
- Docs: `docs/` for contracts (the launcher contract went into `docs/omarchy-shell.md`), `manual/` only for end users.
- Issue or discussion first: not required by any file. The skill routes verified bugs to issues and feature ideas to Discussions "suggestions", but the dock PRs listed all went straight to a PR and the bot does review them. NOT VERIFIED that a maintainer wants a discussion first for a plugin API.
- Hooks and plugin APIs: no stated preference, but the one in flight (#16609) shows the pattern that reviewers have at least not rejected: reuse an existing plugin kind, JSON payload, config key plus `omarchy dock ...` command, contract documented in `docs/omarchy-shell.md`, fall back to stock when the plugin is missing or off.
- Human maintainer response time: none seen on any dock PR in 19 days, with about 40 open. Expect weeks to months.

### Our own PR #10789 (process example)

felipecpaiva:fix/bar-center-anchor-fallback, base `quattro`, title "Keep the bar center pinned when centerAnchor's widget leaves the layout". Opened 2026-09-08. State on 2026-11-09: OPEN, not merged, last update 2026-10-11 (two months). Activity was from `omarchybot` only: a reproduction on a disposable VM (2026-10-02), it pushed two commits to our branch crediting another contributor (2026-10-07), and a note on 2026-10-11 that its classification as bug vs feature is "unsettled" between two models. Greptile reviewed. No human maintainer review in the visible comments. Lesson: a PR that has a clean reproduction still sat two months; a plugin API PR is bigger and more contentious, so plan for the same or worse. A bot may push to our branch, so keep the branch rebased and watch it.

## Gap analysis against our four features

| Feature | #16219 | #16479 | #16609 | Gap if all three merge |
|---------|--------|--------|--------|------------------------|
| Hover previews | Yes, live, up to 4, click focuses | no | no | None for the plain case. Ours differs only in extras (tab previews of browser windows, per-card actions, our style). Largely redundant |
| Window list per app | tooltip shows thumbnails per window | Yes, titles and workspace, dots | no | Mostly redundant. Gap: close and minimize per row, search within the list |
| Close and minimize on cards | Minimize only in the icon menu (whole app). No per-card close or minimize | none | none | Open gap. Cheapest as a follow-up to #16219: two small buttons on `PreviewCard` using `toplevel.close()` and the existing minimize helper |
| Search in the dock | no | no | Yes, as a seam: our `menu` plugin becomes the apps button | Reachable with #16609 only. Stock `AppGrid` (#17539) has app filter but not windows or tabs |

Overlap: #16219 and #16479 both add a hover popup on the same slot with the same 350 ms dwell and both edit `popupRoom`, the dock mask and hide timers in `DockWindow.qml`. They will conflict textually and one will have to rebase; a maintainer may merge one and drop the other (the 16479 list is cheaper, the 16219 previews are richer). #16609 touches the apps button path and is independent apart from `DockWindow.qml` merge noise.

Our existing assets: omahop already has `CardItem.qml` with a ScreencopyView and its own overlay surface and search. So we do not need Omarchy to draw cards. What we cannot do today is know which slot is hovered and where it is, and we cannot take the apps button. That reduces the needed seam to geometry and a hover signal, not a popup component.

## Smallest upstream contribution that unlocks all four

Model it on #16609's contract, because it is the one precedent.

**Proposal: a `dock.popover` seam (working name), about 120 lines plus test and doc.**
1. Config `dock.popover`, set with `omarchy dock popover <plugin-id>` or `off`. Default off, so no change for anyone.
2. On the existing hover dwell the dock calls `open(payloadJson)` on that `menu` plugin with: screen, dock edge, the hovered slot rect and the dock rect in screen coordinates (reuse `mapToItem` as in `popupX`), `appKey`/`appId`, and a detached list of windows (`address`, `title`, `minimized`, `workspaceId`, `focused`). No toplevel objects, which respects the facade rule.
3. The dock calls `close()` on leave after a grace period, unless the plugin item has `readonly property bool held: true` (its own pointer is inside). The dock already reads hover for auto-hide, so it adds the plugin's `held` to `tipHover || held` in the hide timer. One boolean, no signal back-channel.
4. Our side then draws cards (we already do, ScreencopyView in our own layer surface), adds close and minimize buttons through Hyprland IPC we already use, and search through #16609's `dock.launcher`.
5. Documented in `docs/omarchy-shell.md` beside the launcher contract; test in `dock-test.sh` for payload building, which is pure logic in `DockModel.js`.

This covers features 1 to 3 (a plugin draws what it wants from geometry and windows) and, with #16609, feature 4. It does not depend on #16219 or #16479 merging, and it stays valid if they do (a user then chooses stock popup or plugin popover; the dock must not show both, so when `dock.popover` is set it suppresses the stock tooltip and list).

Alternatives considered:
- A Quickshell `signal slotHovered(...)` on the dock. Third parties cannot connect to it through the facade, so it would need the same payload plumbing. Rejected.
- An IPC target (`omarchy-shell omarchy.dock hovered`) polled by us. Violates "react to events, do not poll" in `AGENTS.md` and `shell-idle-spawn-test.sh`. Rejected.
- Slot geometry exported only (no popup call). Insufficient: we still need the hover event and the stock tooltip suppressed.
- A seam inside `AppSlot` for a plugin supplied QML component. Highest coupling, facade and sandbox problem (arbitrary QML in the dock's scene), and conflicts with #16219 and #16479 churn. Rejected.

### Comparison of plans

| | A. Upstream seam now (above) | B. Wait for #16219, #16479, #16609 and add only the missing bits | C. Clone of the dock plugin (already ruled out by Felipe) |
|---|---|---|---|
| Time to users | unknown, weeks to months (see #10789) | unknown, same queue, plus rebases against two overlapping PRs | immediate |
| Code to maintain | small seam, our cards already exist | follow-ups: per-card close and minimize | whole dock forked, breaks every update (about 40 dock PRs open means heavy churn) |
| Risk of rejection | medium: new API, "why not just merge previews" | low per piece, but depends on others | none |
| Works with stock updates | yes | yes | no |
| Redundancy risk | if previews merge, our previews are redundant but the seam still serves cards with actions and search | none | n/a |

Recommendation: do A in a reduced form and B in parallel, in this order.
1. Do not file anything before Felipe confirms (we are read only). Open a Discussion in "suggestions" or an issue first only if a maintainer hint is wanted; no rule requires it.
2. Wait about 2 weeks for #16219's CI and P1 to be fixed and for any maintainer reply on #16609 (which tells us whether the launcher-style contract is welcome). If #16609 merges or gets a maintainer thumbs-up, file `dock.popover` as a sibling PR reusing its payload shape. If it is rejected, do not file the seam.
3. If #16219 merges, drop our hover previews and ship only close and minimize (as a PR to core adding buttons to `PreviewCard`, or inside our plugin if the seam exists), search and quick actions.
4. Work on #16219 and #16479 cannot be edited by us; we can only offer a review or a PR against their branch later. Not done here.

### Interim story for users until Omarchy ships anything

- v1.7 keeps the omahop peek strip, off by default (D11), documented as "works without any Omarchy change, stops when the dock offers it".
- We ship regardless: our window and tab search overlay, the quick actions (close, minimize, move) on our own cards, the card renderer (ScreencopyView in our own surface), and the settings. None of these depend on the dock.
- Nothing in the stock dock is touched, no clone, no layer.

## Risks

- Dock code is a moving target: about 40 open dock PRs, a P1 load failure in the largest one, overlapping popups in #16219 and #16479. Any seam PR will need rebases.
- No maintainer has spoken on dock extensibility; a seam may be refused as "the dock is not a plugin host". Facade policy says plugins must not get toplevels or auth services, so the payload must be detached data.
- Minimize semantics are in flux (#17644, #17890, `special:minimized`), so "minimize on cards" must use whatever core settles on.
- `omarchybot` may push to our PR branch and reclassify it; a bug versus feature call can stall review.
- Our bundled dock facts come from `quattro` and open PR heads on 2026-11-09. The installed `/usr/share/omarchy` on this machine reports version `4.0.0.alpha`, older than the 4.5 dock; code read there is not authoritative.

## Open questions

1. Does Felipe want the seam proposed before #16609 gets any maintainer signal, accepting the risk of rejection? (Recommendation: no, wait.)
2. Is `quattro` still the only base accepted? Check the repo's default and release branches before filing. NOT VERIFIED.
3. Do maintainers want a Discussion first for a plugin API? NOT VERIFIED; no rule found.
4. Does a third-party `menu` plugin facade allow reading a `held` property from the plugin item, and does the dock input mask let a second layer surface take hover without the dock hiding? Needs a spike on a running 4.5 shell (needs a `service`-kind test dock patch; must not modify the installed dock). NOT VERIFIED.
5. How does `dock.launcher` in #16609 pass the apps button rect when the dock is auto-hidden ("reckoned where an auto-hidden dock comes out to")? Same trick is needed for slot rects. Read the final diff before copying. NOT VERIFIED beyond the PR body.
6. Will #16479 or #16219 win the hover popup slot? If neither, the seam is worth more.

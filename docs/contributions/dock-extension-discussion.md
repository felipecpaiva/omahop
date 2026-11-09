# Draft: Discussion for omacom/omarchy (NOT POSTED)

Status 2026-11-09: draft for Felipe to approve. Nothing has been posted. Facts behind it: `docs/research/dock-spike.md`.

Category: **Suggestions** ("Feature requests, changes, or other ideas", and where the Omarchy skill sends feature ideas). Our earlier discussion #17754 used Ideas and #17222 used Suggestions, so either is fine; Suggestions is the safer match. Checked 2026-11-09, categories are general, ideas, manual, polls, q-a, show-and-tell, suggestions, support.

Existing discussions checked (none covers a plugin seam, so no duplicate): #15523 "Dock customization options" (2 comments; one commenter runs a clone of the 4.5 dock), #18145 floating workspaces and a dock that steps aside, #17892 app name on hover, #15497 and #15995 dock on tiled workspaces. Link #15523 in the body only if Felipe wants it. No maintainer reply seen on any of them.

Title:

Dock: a small extension point so plugins can add to the dock without cloning it

Body:

---
Hi all, and thanks for the dock in 4.5.

**The problem**

`omarchy.dock` is a first party `service` plugin with no way for a third party plugin to join in. A plugin that wants to show something when you hover an app icon, or to open from the apps button, has two options today: clone the whole dock (then it stops getting dock fixes, and the dock is changing fast, about 40 open dock PRs right now), or reimplement the dock. Several people already run a clone for small additions (see #15523).

**What I need**

I maintain a small public plugin for floating workspaces (an Alt+Tab style window switcher with hover cards and search). I would like it to also work from the dock without owning the dock. It needs three things:

1. To know when a pointer rests on an app icon, and where that icon is.
2. The windows of that app, as plain data.
3. Optionally, to be the thing the apps button opens.

I draw my own cards and search, so I do not need the dock to render anything for me.

**What already exists upstream (as I read it today)**

- #16609 lets a `menu` plugin take over the apps button through `dock.launcher`, with a JSON payload carrying the screen, the dock edge and the rects of the dock and the button, documented in `docs/omarchy-shell.md`. This is the part of my list that covers point 3, and it is a good pattern.
- #16219 adds live window previews on hover, drawn by the dock itself.
- #16479 adds window dots and a hover list of an app's windows, drawn by the dock itself.

Those cover the built in look. They do not give a plugin a way to hook the same hover, and the two of them overlap, so I would rather not add a third popup.

**A small proposal**

Follow the shape of #16609, so there is one idea to review, not two:

- A config key `dock.popover`, set with `omarchy dock popover <plugin-id>` or `off`. Default off, so nothing changes for anyone.
- When it is set and the pointer rests on an app icon (the dock already has a dwell timer for its tooltip), the dock calls `open(payloadJson)` on that `menu` plugin with: the screen, the dock edge, the rect of the hovered icon and of the dock in screen coordinates, the app id, and a detached list of that app's windows (`address`, `title`, `workspaceId`, `minimized`, `focused`). Plain data only, no toplevel objects, in line with the capability scoped facades.
- The dock calls `close()` when the pointer leaves, after a short grace period, unless the plugin item reports `held: true` (its own surface has the pointer). The dock already reads hover for auto hide, so this is one more boolean in that timer.
- While a popover plugin is set, the dock does not show its own hover popup for the same icon, so the two never stack.
- The contract goes in `docs/omarchy-shell.md` next to the launcher one, and `test/shell.d/dock-test.sh` covers building the payload (pure logic in `DockModel.js`).

That is roughly a hundred lines. It does not add a plugin kind, does not let plugins draw inside the dock, and falls back to the stock behavior when the plugin is missing or off.

**Questions**

- Is a dock seam something you want at all, or should the dock stay closed and plugins stay separate surfaces?
- If yes, is the `menu` plugin plus JSON payload the right shape, as in #16609, or would you rather have something else?
- Should this wait for #16219 and #16479 to settle, so it does not collide with them?

I am happy to send the PR, with before and after captures and the dock test, once you tell me which way you would like it. Thanks for reading.
---

Notes for Felipe before posting:
- No private data and no screenshots in the body. Say the plugin name (omahop, public) only if you want to; the draft does not name it.
- No dashes used as punctuation. Re-read once for tone.
- Tracker entry: the workspace tracker `docs/contributions.md`, status "draft, not posted". After posting, replace with the discussion URL and run `bash scripts/check-contributions.sh`.

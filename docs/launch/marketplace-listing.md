# Marketplace listing (SUBMITTED 2026-11-07, issue 14254 in omacom/omarchy-plugin-marketplace; waiting for a maintainer)

The marketplace is `omacom/omarchy-plugin-marketplace`. It reads `manifest.json` and the root `preview.png`. Rules are in its `SUBMISSION.md` (the omagnet notes of 2026-11-05 list the same checks). Not submitted: a submission is outward-facing and is Felipe's call. Submitting needs a public listing request, and a listing is bound to the commit the bot validates (an earlier plugin took weeks to be reviewed): keep `main` frozen at the submitted commit until it is approved, work on a branch.

## Checks against SUBMISSION.md

| Rule | Status |
|---|---|
| Public repo, one plugin, `manifest.json` in the root | ok |
| Root README with install and removal | ok (Install, "To remove") |
| Root licence file | ok (`LICENSE`, MIT) |
| External dependencies documented | ok (README "Requirements") |
| Unique ID outside `omarchy.*` | `io.github.felipecpaiva.omahop`; search the marketplace for the ID before submitting (it is permanent once listed). `omahop` was free in the registry and on GitHub on 2026-11-06 |
| Does not overwrite user config without consent | ok: it never edits `hyprland.lua`; the user adds one line. It writes the launcher entry file (`omahop.desktop`) only if it carries its own marker |
| Optional `preview.png` in the root | ok (1280x640, lockup, tagline and the real settings window) |
| Passes Omarchy's own validation | `omarchy plugin validate .` passes |

## Listing values

- **Category:** `Desktop` (second choice: `Productivity`)
- **Tags (1 to 3):** `hyprland`, `workspaces`, `quickshell`
- **Suggest a missing tag:** `window-switcher` (there is no tag for Alt+Tab or window switching)

## Maintainer notes (goes in the form)

An Alt+Tab window switcher for Omarchy's floating workspaces. The plugin is the overlay and the settings window; the key handling is a Lua file loaded from `hyprland.lua` with one guarded line the user adds (the plugin does not edit that file). By default it only acts on floating workspaces; tiling workspaces keep Omarchy's own Alt+Tab. List or cards with window thumbnails, type to search, mouse and quick actions, an optional peek strip of running apps (off by default), a same-app shortcut, app rules, quick jump keys.
Overlaps with core: pull requests 16548 (Alt+Tab with live thumbnails) and 16219 and 16479 (dock hover previews) are open; omahop differs by its floating-workspace scope, settings window, list style and search, and its own optional strip (a third-party plugin cannot extend the dock).
Known limits: monitors are tested live from every attached monitor (2026-11-07, two monitors) and modelled for 1 to 6; unplugging a monitor is not yet checked on real hardware; the Alt-menu fix is verified on a Qt app only.

## Submit from the command line (when approved)

See omagnet's `docs/launch/marketplace-listing.md` for the exact `gh issue create` body (repository URL, category, tags, suggested tag, maintainer notes, submission checklist). Use the values above with `https://github.com/felipecpaiva/omahop`.

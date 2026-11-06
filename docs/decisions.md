# omahop decisions

| ID | Decision | Why | Status |
|---|---|---|---|
| D1 | Name `omahop`, plugin id `io.github.felipecpaiva.omahop` | omaswitch, omadock, omatab are taken in the marketplace and on GitHub; omahop is free on both (checked 2026-11-06) | decided |
| D2 | Public repo, MIT | Felipe's call, like omagnet. Scrub before every push (no LAN IPs, hostnames, home paths, client names) | decided |
| D3 | One repo, repo root is the plugin | Same as omagnet: `omarchy plugin add <git-url>` clones it, marketplace wants `manifest.json` at root | decided |
| D4 | `scope` is a setting: `floating` (default) or `all` | Felipe: default floating only, user free to extend. Stock behaviour must stay byte-for-byte on out-of-scope workspaces | decided |
| D4b | Window set is its own setting group, independent of scope: workspaces (`current`, `floating`, `all`) and monitors (`active`, `all`), default floating and active | Felipe: a user who limits hop to floating desktops should not see other windows; showing other monitors is a separate choice | decided, see `settings.md` |
| D5 | Lua owns keys and state, QML draws | Overlay never takes focus; omagnet proved the Alt hold/release poll | decided, spike S3 confirms IPC |
| D6 | Cards and list are both shipped, user picks | Felipe asked for both (DockDoor and Contexts styles) | decided |
| D7 | Take ideas, never GPL code | DockDoor, end-4, caelestia are GPL-3.0 | decided |
| D8 | Where hover previews live (upstream dock hook, own dock strip, or hover layer) | Stock dock has no hooks | open, phase 4 |
| D9 | Plugin or contribute to core | Core PR omacom/omarchy#16548 (Windows-style Alt+Tab, live thumbnails, all workspaces, MRU) is open. If it merges, a plain switcher is redundant. omahop's difference: floating-scope default, vertical list style, hover previews, settings app, theme-live | decided 2026-11-06: build omahop, grow it release by release (Felipe asked for a gradual roadmap); revisit if #16548 merges |

## Prior art summary (full table in `research/thumbnails-and-prior-art.md`)

- BetterCmdTab (rokartur, macOS, GPL-3.0, active) adds ideas: tap vs hold with a reveal delay, opt-in live config file, per-shortcut profiles, letter hints, per-app rules. Top 6 are in its reference file; fold the winners into ROADMAP phase 1 and 3.
- Marketplace already lists about 25 switcher, overview and dock plugins, several with live previews.
- Core dock exists (floating workspaces only), no previews, many open items.
- Pattern to copy: `omarchy-altswitch` (Lua for keys and state, QML renders the list, Alt release handled by a Lua submap).
- The research agents' notes on hyprshell, end-4 and caelestia behaviour come from prior knowledge, not from reading code.

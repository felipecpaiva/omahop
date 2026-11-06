# omahop decisions

| ID | Decision | Why | Status |
|---|---|---|---|
| D1 | Name `omahop`, plugin id `io.github.felipecpaiva.omahop` | omaswitch, omadock, omatab are taken in the marketplace and on GitHub; omahop is free on both (checked 2026-11-06) | decided |
| D2 | Public repo, MIT | Felipe's call, like omagnet. Scrub before every push (no LAN IPs, hostnames, home paths, client names) | decided |
| D3 | One repo, repo root is the plugin | Same as omagnet: `omarchy plugin add <git-url>` clones it, marketplace wants `manifest.json` at root | decided |
| D4 | `scope` is a setting: `floating` (default) or `all` | Felipe: default floating only, user free to extend. Stock behaviour must stay byte-for-byte on out-of-scope workspaces | decided |
| D4b | Window set is its own setting group, independent of scope: workspaces (`current`, `floating`, `all`) and monitors (`active`, `all`), default floating and active | Felipe: a user who limits hop to floating desktops should not see other windows; showing other monitors is a separate choice | decided, see `settings.md` |
| D10 | Positioning: floating-aware switcher (scope, filters, stock fallback, settings app, theme-live), not a plain Alt+Tab. Search moves to v0.2. Hover previews stay v0.3 but demoted | Competitive analysis: nobody has F12, F27 or a switcher GUI; vertical list and search already exist elsewhere | decided, see `competitive-analysis.md` |
| D11 | Product principles from omagnet: no new icons by default, one settings app for everything, slim and simple but complete (see `engineering-standards.md`). Consequence for D8: an own dock strip (option b) adds a new surface and is ruled out unless it is an opt-in setting; hover previews go through the stock dock (upstream hook) or an opt-in strip | Felipe, 2026-11-06 | decided |
| D12 | Engage upstream before building the switcher core: read core PRs #16548 and #16219, and decide whether to comment or offer scope, filters and raise handling as PRs | Both headline features are open core PRs with no maintainer reply; a merge makes our matching feature redundant | open, Felipe's call (commenting is outward-facing) |
| D5 | Split between Lua (keys, state) and QML (drawing), and whether the overlay takes the keyboard | Earlier plan: focusless overlay, Lua polls Alt. Core's choice (overlay takes the keyboard on first Tab) avoids the Alt-menu problem. We do not pick by imitation: spikes S1, S3, S9 compare designs by the criteria in `lessons-from-others.md` L1, L2, L5 | OPEN, decided by evidence |
| D6 | Cards and list are both shipped, user picks | Felipe asked for both (DockDoor and Contexts styles) | decided |
| D7 | Take ideas, never GPL code | DockDoor, end-4, caelestia are GPL-3.0 | decided |
| D8 | Where hover previews live (upstream dock hook, own dock strip, or hover layer) | Stock dock has no hooks | open, phase 4 |
| D9 | Plugin or contribute to core | Core PR omacom/omarchy#16548 (Windows-style Alt+Tab, live thumbnails, all workspaces, MRU) is open. If it merges, a plain switcher is redundant. omahop's difference: floating-scope default, vertical list style, hover previews, settings app, theme-live | decided 2026-11-06: build omahop, grow it release by release (Felipe asked for a gradual roadmap); revisit if #16548 merges |

| D13 | Learn, do not copy: study others, keep the best ideas, avoid their mistakes, design our own structure. Quality bar is the omagnet level (gates in `lessons-from-others.md`) | Felipe, 2026-11-06 | decided |

## Prior art summary (full table in `research/thumbnails-and-prior-art.md`)

- BetterCmdTab (rokartur, macOS, GPL-3.0, active) adds ideas: tap vs hold with a reveal delay, opt-in live config file, per-shortcut profiles, letter hints, per-app rules. Top 6 are in its reference file; fold the winners into ROADMAP phase 1 and 3.
- Marketplace already lists about 25 switcher, overview and dock plugins, several with live previews.
- Core dock exists (floating workspaces only), no previews, many open items.
- Pattern to copy: `omarchy-altswitch` (Lua for keys and state, QML renders the list, Alt release handled by a Lua submap).
- The research agents' notes on hyprshell, end-4 and caelestia behaviour come from prior knowledge, not from reading code.

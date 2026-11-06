# omahop roadmap

Method, same as omagnet: small batches. Each row has plan, implementation, test, validation. No row is done until its test
passes and the real shell shows it. Live tests drive the real keyboard through `/dev/uinput`; tell Felipe, keep hands off.
Agents on cheaper models do mechanical work, a strong model judges. Agent reports are data, the orchestrator re-runs tests.

Every row must meet [engineering-standards.md](engineering-standards.md): flexibility, scalability, code standards per language.

## Phase 0: spikes (answer before design is final)

| ID | Question | Pass when |
|---|---|---|
| S1 | Does `hl.bind` with repeating fire Tab again while Alt is held? | Counted in a Lua probe |
| S2 | Cost and behaviour of thumbnails: 10 live views, minimized, special, occluded, frame rate | Numbers in `research/`, default for `thumbnails` chosen |
| S3 | Lua to shell IPC: state file plus which IPC call opens/updates/closes an overlay from a plugin, latency per Tab | Overlay opens within 50 ms of Alt+Tab |
| S4 | Can an in-shell overlay window be focusless and still receive hover? | Hover works, keys stay in Lua |
| S5 | Read core PR #16548 diff: key handling, IPC, what we can copy by idea | Notes in `research/` |

| S6 | Load order: does the guarded load of `omahop.lua` run before or after the user's own `bindings.lua`? `hl.unbind("ALT + TAB")` removes every bind on that chord. Is a "do not take Alt+Tab" escape hatch needed? | Order documented, setting decided |

## Phase 1: switcher core, list style (no thumbnails)

| ID | Feature | Source ids |
|---|---|---|
| A1 | Override Alt+Tab and Alt+Shift+Tab, guarded Lua load | C-baseline |
| A2 | Scope guard: floating default, `all` option, stock behaviour out of scope | D4 |
| A2b | Window set filter: `windows.workspaces` (current, floating, all), `windows.monitors` (active, all), minimized, specials, ignore; table test over every combination | `settings.md` |
| A3 | MRU list from focus events, first Tab picks previous window | C-UX |
| A4 | Alt hold/release commit, Esc cancel, Enter, arrows, Tab repeat | S1 |
| A5 | Vertical list overlay: icon, app name, title, theme colours | C1.. |
| A6 | Show delay (quick tap flips with no overlay) | C-UX |

## Phase 2: cards style and thumbnails

B1 cards strip, B2 `ScreencopyView` thumbnails, B3 `thumbnails` setting (live, snapshot, off), B4 minimized and special windows,
B5 multi-monitor (overlay per screen, list scope), B6 window quick actions (close, minimize).

## Phase 3: settings app

C1 settings panel in the shell (style, scope, thumbnails, show delay, list scope, include minimized, ignore list),
C2 config file `~/.config/omahop/config.toml` with a parser tested under Lua 5.5, C3 live apply.

## Phase 4: hover previews (needs D8)

D1 hover panel per app icon, D2 preview with title and window controls, D3 delay and position settings.

## Phase 5: release

E1 `tests/scrub.sh` clean, E2 offline and live suites green, E3 branding kit, E4 `v0.1.0`, E5 marketplace submission (only with Felipe's go).

## Tests

- `tests/run-all.sh`: pure (MRU, scope, config), glue (fake `hl`), scrub, then live.
- Scope test: on a tiling workspace, Alt+Tab result equals stock for every run.
- Never create headless monitors in live tests.

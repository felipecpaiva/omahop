# omahop engineering standards

Three rules always apply, to every batch and every agent brief: **flexibility, scalability, code standards per language.**
A batch is not done until it meets all three. Agent briefs must quote this file.

## Product principles (same as omagnet)

- **No new icons or widgets by default.** Nothing is added to the bar, the dock or the desktop unless the user turns it on in the settings app (any icon is off by default).
- **One settings app for everything adjustable.** Every behaviour is a setting there, with the default stated; no hidden options only in a file, and no setting only in the app that the file cannot hold.
- **Slim and simple, but complete.** Few screens, plain words, sensible defaults that work with zero setup; the details are all present but out of the way (an Advanced section).
- **Follows Omarchy.** Theme, fonts and spacing come from the shell, no own palette.
- **Stays out of the way.** Nothing runs while the switcher is closed; out-of-scope desktops are untouched.

## Flexibility

- Behaviour is a setting with a safe default, never a constant buried in code. Defaults live in one place (`lua/config.lua`
  defaults table), the settings app reads the same table.
- Policies are swappable behind a small interface: scope (`floating`, `all`), window source (which windows are listed),
  view style (`cards`, `list`, later more), thumbnail mode (`live`, `snapshot`, `off`). Adding a value must not touch the
  key handling.
- The config file is versioned (`schema = 1`). Unknown keys are kept, unknown values fall back to the default and are logged.
- Lua (state, keys) and QML (drawing) talk through one narrow contract (state file plus IPC calls). A view can be replaced
  without touching Lua; Lua can be tested without Quickshell.
- No hard-coded paths, colours, fonts, sizes. Paths from XDG variables, colours from `Color.*`, sizes from `Style.*` or settings.

## Scalability

- Must stay smooth with 100+ windows, several monitors, and long titles. Lists are virtualised (a `ListView`, not a `Repeater`
  of everything) and thumbnails are created only for visible cards.
- Idle cost is zero: no timers or captures while the switcher is closed. Per-tick polling (the Alt watch) runs only during a session.
- Capture cost is bounded by setting (`thumbnails`), and live capture is limited to what is on screen.
- Work per Tab press is constant time (index move), not a rebuild of the list.
- Measure, do not guess: any batch that adds per-frame or per-tick work records numbers in `docs/research/`.

## Code standards per language

| Language | Standard | Check |
|---|---|---|
| Lua (Hyprland, 5.5) | Everything `local`, no globals, one module table per file, small pure functions for logic (no `hl` calls inside), `hl` only in a thin glue file. Loop variables are read-only in 5.5. snake_case names, 2-space indent, early returns, errors returned or logged, never swallowed. | Unit tests with `lua` (not `lua5.4`); `luacheck` and `stylua --check` when installed |
| QML (Quickshell) | One component per file, PascalCase file names, `id` and properties camelCase, no business logic in delegates (call a JS or Lua-fed model), no hard-coded colours (use `Color.*`), declarative bindings over imperative code, `pragma Singleton` only for shared state. | `qmllint` and `qmlformat` (in `/usr/lib/qt6/bin`) |
| JavaScript (QML `.js`) | Pure functions in `.pragma library` files so Node can test them, `const` first, no side effects at import. | Node tests |
| Shell | `#!/usr/bin/env bash`, `set -euo pipefail` in scripts that are not sourced, quote everything, no bashisms hidden in `sh`. | `shellcheck` when installed |
| Python (live tests only) | PEP 8, type hints on helpers, no logic in module scope, `go_home()` at the start of every live test. | `ruff` when installed |
| Markdown | Plain hyphens and commas, no em or en dashes, no private data. | `tests/scrub.sh` |

Missing linters are installed when possible (stylua, luacheck, shellcheck, ruff are not on this machine yet); `run-all.sh`
prints `SKIP <tool> not installed` instead of passing silently. A skip is a visible debt, listed in the batch log.

## Definition of done for a batch

1. Plan row in ROADMAP names the files and the test.
2. Pure logic has unit tests; glue has a fake-`hl` test; anything user-visible has a live test or a hand check in the checklist.
3. Linters for the touched languages pass or are logged as SKIP.
4. `bash tests/run-all.sh` and `bash tests/scrub.sh` pass.
5. The scope test still passes: a tiling workspace is untouched when scope is `floating`.
6. The batch is written in `docs/batch-log.md` with what was verified and how.

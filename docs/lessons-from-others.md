# Lessons from others (learn, do not copy)

Rule (Felipe, 2026-11-06): we read what others built, keep the best ideas, avoid their mistakes, and build our own design. No copied
structure, no copied code. Each lesson below names the problem, who showed it, and OUR answer (a requirement or a test). If our answer
is not decided yet, it is a spike that decides by evidence, not by imitation.

| # | Lesson (problem) | Seen in | Our answer |
|---|---|---|---|
| L1 | A tap of Alt with nothing between (app sees Alt down and up) opens the app's menu bar | core #16548 | Spike S1 measures it for our overlay design. Pick the design that passes: test on terminal, browser, GTK and Qt apps. D5 stays open until then |
| L2 | A focus call is refused while an overlay holds the keyboard | core #16548 | Whatever overlay design we pick must show the pick lands on the right window within one frame. Test: pick, then check active window |
| L3 | A focused floating window stays behind others | omaswitch #14, core #16241, #16973, #17724 | Spike S8 tests every raise call on Hyprland 0.56.2 including maximized and fullscreen; we keep a table of what works |
| L4 | Wine and Proton ghost windows fill the list | omaswitch #13, core | List only windows with a real Wayland toplevel; unit test with ghost fixtures |
| L5 | Alt release arrives as an unmapped key, both Alt keys | community plugins | Spike S9 compares release methods; both Alt keys in every test |
| L6 | A capture of a vanished output aborts Hyprland; other capture tools crash the shell | docks research | Never capture a window whose output is gone; `thumbnails` setting; test with unplugging a real monitor by hand |
| L7 | A plugin-triggered config reload crashed Hyprland | macos.dock #24 | We never reload config from the plugin |
| L8 | Duplicate binds on monitor hotplug | hyprshell #526 | Bind lifecycle test: hotplug twice, count binds |
| L9 | Pointer warps on focus | docks research | We never move the pointer; test asserts position unchanged |
| L10 | Tap versus hold races | end-4 #3728, #3752 | Reveal delay is a tested state machine (pure Lua), not timer glue |
| L11 | List overflows the screen with many windows, selection leaves the view | core #16548 bot finding | Virtualised list that scrolls with the selection; test with 100 windows |
| L12 | A minimized window comes back too soon in the order | core #16548 bot finding | Order logic has its own tests, including shell restart with minimized windows |
| L13 | Dialog or owner windows break "previous window" | core #16548 bot finding | Define dialog handling in the design before the code; test with an owner and a dialog |
| L14 | Event data is cut at 1024 bytes (long titles) | Hyprland #17078 | Never trust titles from events; read them from the window list |
| L15 | Live thumbnails cost CPU and VRAM | omadock (VRAM 194 to 26 MiB), window-gallery | `thumbnails` setting; capture only what is visible; numbers recorded in S2 |
| L16 | Fullscreen games take focus back after a switch | core foreground-lock | Test with a Proton game in a later phase; not v0.1 |
| L17 | No settings at all, so users cannot narrow the list | core #16548 | Our settings model (`settings.md`) and one settings app |

## Quality bar: the omagnet level, nothing less

Every batch follows the same gates omagnet used. This is a checklist, so it can be audited:

1. A ROADMAP row with plan, implementation, test and validation columns, filled in before code.
2. Pure logic in small Lua or JS modules with unit tests (run with `lua` 5.5 and Node). Glue tested against a fake `hl`. Live tests with the real keyboard and mouse through `/dev/uinput`, on real monitors only.
3. `tests/run-all.sh` runs everything and `tests/scrub.sh` passes. Linters run or print `SKIP`.
4. A `docs/batch-log.md` entry per batch: what was built, how it was verified, what is left.
5. `docs/validation-checklist.md` lists the hand checks Felipe owes, per feature.
6. `docs/gotchas.md` gets every trap found, the day it is found.
7. Branding, README, release notes and marketplace text are written to the same standard as omagnet before any release.
8. Agent reports are data: the orchestrator re-runs tests and looks at the real result in the real shell.

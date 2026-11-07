# Spike: keep the list open while searching (`search_linger_seconds`)

Date 2026-11-07, omahop v1.0.0, Quickshell 0.3.2, Omarchy 4.5, Hyprland 0.56. Question: with Alt up, how do typed keys reach the list?
Verdict at the end: **go with changes, route B (overlay takes exclusive keyboard focus while lingering).**

## What exists today (read in the code)

- `lua/session.lua`: `tick` counts Alt-up ticks; two in a row end the session with a `commit` (the selected row is picked). Failsafe: 60 s.
- `lua/omahop.lua` `bind_session_keys`: while a session is open, `ALT + <key>` chords are bound for navigation keys and (setting `search`) letters, digits, Space, Backspace, only if free in the `hyprctl binds` snapshot (D14). All are unbound at the session end.
- `Service.qml`: the overlay is `OverlayWindow` with `shownKeyboardFocus: WlrKeyboardFocus.None`, `mask: Region { item: column }` (pointer only over the card). Pointer actions already call Lua through detached `hyprctl eval` (`_G.omahop.pick(i)`).
- `/usr/share/omarchy/shell/Ui/OverlayWindow.qml` defaults to `WlrKeyboardFocus.Exclusive` and puts the window on the focused screen only; the image picker and lock screen use it, so exclusive focus is a path the shell itself relies on.
- Quickshell type on disk (`_WlrLayerShell` qmltypes): `WlrKeyboardFocus { None, Exclusive, OnDemand }`, property `WlrLayershell.keyboardFocus`, writable at runtime.

## Route A: bare-key binds during a linger session (`hl.bind`)

Not run live (stealing real keys is the risk, and the user is at the machine); reasoning from the code and D14 plus Hyprland bind semantics:

- Bare binds are cheap (38 chords register in under 10 ms, D14) and need no focus change, so there is no gap at the moment Alt is released.
- A bind matches an exact modifier mask. `A` does not catch `Shift + A`, `Ctrl + C` or `AltGr + key`: a capital letter typed in the query would leak to the app under the list, so each key needs a `SHIFT +` twin (about 76 binds), and anything non-ASCII (accents, other layouts, IME) cannot be typed at all. Search is limited to what `typing_keys()` knows.
- Key repeat needs `repeating = true` per bind, with the delay and rate owned by Hyprland; arrows and Backspace work, but every bind handler then runs in the compositor thread per repeat.
- Stealing: for N seconds every bare Return, Escape, letter and digit goes to omahop. If the user changes their mind and types into the app, the first keys vanish silently. Exactly the same exposure as B, but with no visual cue the keys are taken.
- A user's own bare bind on a letter (rare, but `bindings.lua` is user-editable) is skipped by the "free in snapshot" rule, so that letter silently cannot be typed in a query. In today's design this collision is rare because chords need ALT.
- A Hyprland reload drops all binds (documented in architecture), so a reload mid-linger leaves the session without key capture, then the Lua side resets: safe.

## Route B: exclusive keyboard focus for the overlay while lingering

### Live spike (virtual keyboard, Spare workspace, standalone probe `qs -p`, about 40 s of runtime)

Probe: a 120x40 `PanelWindow`, `WlrLayer.Overlay`, `keyboardFocus: Exclusive`, an `Item` with `Keys.onPressed` logging key, text, modifiers, `isAutoRepeat`. Keys sent through `tests/uinput_kbd.py`, no Alt held.

| Check | Result |
|---|---|
| Plain keys `a`, `b` | received with `text` "a", "b", `modifiers` 0 |
| `Shift+C` | Shift key event, then `C` with text "C" (capital handled by Qt, no twin binds) |
| Backspace, Return, Escape | received (`\b`, `\r`, Escape key codes) |
| Hold Backspace 0.9 s | first press, then about 25 events with `isAutoRepeat = true`: repeat comes free, at the compositor's repeat rate |
| `hyprctl activewindow` while the probe holds Exclusive | still the previously focused window (Hyprland keeps its logical active window; no `window.active` event fires) |
| `hl.dsp.focus({ window = A })` while the probe holds Exclusive | **ignored**: active window stayed the old one. This confirms the existing gotcha "an exclusive overlay makes focus calls fail" |
| Same dispatch after the probe set `keyboardFocus = None` (layer still mapped) | **worked**: A became active |
| After the layer closed | active window consistent, no stray state; layer gone from `hyprctl layers` |

Consequence for the commit path: on Return or click, QML (or the state file `open=0`) must drop to `None` first, and the Lua `M.activate` must run after that (a short delayed timer, or the Lua side sets a `release_keys=1` state line and activates on the next tick after QML acknowledges). Doing the focus call while still Exclusive silently does nothing: the pick would appear to work but the window would not change. This is the biggest build risk of route B and must have a live test.

### Not measured (flagged)

- Latency between Alt release and the first key delivered to the layer: the keyboard enter is one compositor round trip; keys typed in that window go to the app. Mitigation: switch focus to Exclusive when the first query character is typed (Alt still held, so the user is mid-gesture), not when Alt is released. Then the grab is already there. Cost: while Alt is held and query non-empty, Alt chords still arrive as binds (consumed by the compositor before the client), so nothing changes in that phase.
- Click behaviour while Exclusive: a click on another window probably does not take focus. Design: while lingering, widen the mask to the full screen and treat a click outside the card as cancel. Needs a live check with the virtual mouse.
- Two monitors: the overlay exists on the focused screen only (`OverlayWindow.focusedScreen`), so the grab is on that output. If the pointer moves to another monitor the grab stays. Needs a live check; acceptable.

## Comparison

| | A: bare binds | B: exclusive focus |
|---|---|---|
| Capital letters, accents, layouts, IME | needs twin binds, ASCII only | handled by Qt (`event.text`) |
| Key repeat | per-bind flag, compositor thread | free, client side |
| Gap at Alt release | none | none if grabbed at the first query key |
| Silent stolen keys | yes | yes, but the app visibly loses focus ring |
| Commit path | unchanged (`apply`) | must drop to None, then focus (spike proved) |
| Key transport to Lua | direct | `hyprctl eval` per event (spawn cost, ordering) |
| Failure when shell crashes | keys captured until timer | grab disappears with the process |
| Failure when Lua errors | binds stay until tick cleanup | grab stays until `open=0` |
| New code | about 60 lines Lua | about 90 lines QML plus 40 Lua |

B wins on input correctness (the thing a search box needs) and on crash safety (a dead shell releases the grab by protocol; a dead Lua tick would leave binds). A is simpler for the transport.

## Ordering problem in B and its fix

`Quickshell.execDetached(["hyprctl","eval",...])` spawns one process per call, and processes can finish out of order, so typing "ab" could arrive as "ba". Fix: QML owns the typed text while lingering and sends the **whole query with a sequence number**: `_G.omahop.set_query(seq, "abc")`, idempotent, Lua drops any call with a seq lower than the last applied. Coalesce with a 30 ms timer so key repeat sends the latest text only. Navigation: `_G.omahop.key(seq, "down")` shares the same sequence counter. Return and a click call the existing `pick(index)`; Escape calls `key(seq, "escape")`. Input validation stays in Lua (query length cap, characters stripped of control codes, as `write_state` already does).

## Chosen approach (design)

1. **Pure (`lua/session.lua`)**: add a `lingering` phase. `tick` with Alt gone and `linger_ms > 0` and `query_started` moves to `lingering` instead of `commit`, with `deadline = now + linger_ms`. `touch(now)` restarts the deadline on every key; `tick` past the deadline returns `cancel` (never `commit`). Escape: first clears the query (existing rule), second cancels. `session` gets `query_started` fed by glue (`mark_query(bool)`). The 60 s failsafe stays but a lingering session is exempt from it only up to `linger_ms` after the last touch. Add a hard cap on `search_linger_seconds` (for example 1 to 60).
2. **Config (`lua/config.lua`, `settings.md`, `SettingsPanel.qml`)**: `search_linger_seconds`, number, default 0 (today), under "General" with the default stated. Read at session start like the rest.
3. **State file**: add `linger_ms=N` and `linger_rev=k` (k bumps on every restart) only while lingering; QML animates a thin line under the `SearchChip` from full to empty over N ms, restarting on rev change (no per-tick writes, so the "write only on change" rule holds).
4. **QML**: `Service.qml` sets `shownKeyboardFocus` to Exclusive only when `st.lingering` or (`st.query != ""` and linger enabled, so the grab precedes the Alt release); a new `LingerKeys.qml` (one component per file) holds the `Keys.onPressed` item, the local query text, the 30 ms coalescer, and sequence numbers. Colours from `Color.*`. When `Window.active` is lost or `st.open` goes 0, it stops sending. While lingering the mask widens to the whole overlay and a click outside the card sends `cancel`.
5. **Lua glue**: `M.set_query(seq, text)`, `M.key(seq, name)`; on commit/cancel, set state `open=0` first (QML drops to None), then run `M.activate` from a 50 ms `hl.timer` (the spike shows the focus dispatch only works after the grab is gone). `bind_session_keys` is untouched: Alt chords keep working while Alt is held.
6. **takeover=false**: no session ever starts, so the setting is inert; document it. **Same-app profile**: same session object, linger applies unchanged. **Tiling workspaces out of scope**: `on_tab` returns `stock` before any session or grab exists, so no change.
7. **Hyprland reload mid-linger**: `setup()` bumps `gen`, creates a new closed session and writes `open=0`; QML drops the grab. Needs one live test.

Decision to record: with `search_linger_seconds > 0`, releasing Alt after typing no longer picks; Return picks. Users who rely on "type, release Alt" would wait for the timeout and lose their pick (timeout cancels). Mitigation: default stays 0, the settings text says so. Alternative to consider: Alt release picks if no key was typed in the last 300 ms (rejected for now: a hidden second rule).

## Test plan

- **Pure (Lua, `lua/test_session.lua`)**: Alt gone with empty query commits as today; Alt gone with query and linger 0 commits; with linger 3 s enters lingering; `touch` restarts the deadline; timeout cancels, never commits; Escape clears then cancels; failsafe still ends a non-lingering session; `search_linger_seconds` bounds in `test_config.lua`; stale-seq rejection (`set_query` ordering) as a pure function.
- **Glue (`lua/test_glue.lua`, fake `hl`)**: linger keeps `M.session:is_open()` true after Alt up; `set_query` seq order; commit writes `open=0` before `activate` and activates on the timer; reload mid-linger resets; takeover false inert; no bare binds are ever registered (assert on the fake `hl.bind` calls).
- **QML**: `qml-health.sh` (qmllint, load check, grep `load failed`); the coalescer and sequence logic in a `.pragma library` JS file with a Node test.
- **Live (`tests/live_linger.py`, Spare workspace, virtual keyboard)**: hold Alt, Tab, type "br", release everything, wait 1 s under the limit, type "a", press Return, assert bravo is active; second run: release, wait past the limit, assert the list closed and the focused window is unchanged; third: Escape twice; fourth: click outside cancels; fifth: `hyprctl reload` mid-linger leaves no grab (`hyprctl layers` keyboard interactivity, then a plain typed key reaches the app). Close the theme picker with `omarchy-shell image-selector cancel /tmp/x` if a shell restart opened it.

## Effort

Pure and config 3 h, state and Lua glue 3 h, QML (`LingerKeys.qml`, grab, mask, countdown line, settings row) 5 h, live tests and hardening (multi-monitor, click-outside, reload) 4 h, docs and checklist 1 h. **About 16 h.**

## Risks

1. **Focus dispatch ignored while Exclusive** (measured): the pick must release the grab first. A race here means a visible "picked but nothing happened". Needs the delayed activate and its live test.
2. **Stolen keys and stuck grab**: the user who changes their mind types into a list that eats keys, and a bad click handling can leave a full-screen grab for N seconds. Bound by the setting maximum, the click-outside cancel, and `open=0` dropping the grab; the failsafe must be tested with the shell killed (protocol drops the grab) and with Lua erroring.
3. **Transport ordering and latency**: one `hyprctl` process per event can reorder. Solved by whole-query plus sequence numbers; must be live-checked with fast typing.
4. Behaviour change: release-Alt-picks becomes release-Alt-waits when the setting is on and a query exists.
5. Layer-shell exclusive on a multi-monitor setup (grab on one output only) and click behaviour: not measured.

## Go / no-go

**Go with changes**: route B, default off, about 16 h, behind one setting. Proceed only after a 1 h follow-up measuring risks 5 (click while Exclusive, two outputs) with the virtual mouse.

What would change my mind: if clicking a window while Exclusive cannot be intercepted (the user would be stuck until the timeout), or if the focus-after-drop timing proves flaky across 20 runs, fall back to route A for ASCII-only search (smaller, but capital letters and layouts are second class); if the owner prefers "release Alt picks" muscle memory over a linger, no-go and keep Alt held for search.

## Result (follow-up spike and build, 2026-11-07)

### Click while the overlay holds the keyboard (measured)

Probe: a full-screen `PanelWindow` on the Overlay layer, `keyboardFocus: Exclusive`, a 200x100 card in the centre, a full-size `MouseArea` behind it, key and click logging; Spare workspace with A, B, C (C focused); virtual keyboard and mouse from `tests/uinput_kbd.py`; pointer placed with `hl.dsp.cursor.move`. Two masks: `card` (input region is the card only) and `full` (the whole window). Sequence per run: key, click on window A at (320, 270) outside the card, key, click on the card, key.

| Check | Result (11 runs: 5 `full`, 6 `card`) |
|---|---|
| Click on window A outside the card, mask `full` | delivered to the overlay's backdrop at (320, 270); `activewindow` stays C; next key still reaches the overlay. 5 of 5 |
| Same, mask `card` | **also delivered to the overlay** although outside its input region; A does not take focus; keys stay. 5 of 6 |
| Click on the card | delivered, 11 of 11 |
| After the probe exits | active window consistent (C) |

One `card` run (the first of the session) was different: `activewindow` already read a window of the origin workspace before the click, the click on A and the following key were not seen by the probe, and the click on the card restored delivery. Not reproduced in the 10 runs after it; most likely Spare setup timing (the workspace switch not finished when the probe mapped). Recorded as unexplained, not as a design failure.

Reading: Hyprland routes all pointer input on the output to an exclusive layer, whatever its input region. So the design works, and the part that makes click-outside-cancel work is the full-size `MouseArea`, not widening the mask (widened anyway while the grab is held, so the behaviour does not depend on that compositor detail). Without a handler, clicks outside the card would be swallowed and the user would wait for the timeout. Also in `docs/gotchas.md`.

### Two monitors

**Not measured**: one output attached, and virtual monitors are never created on this machine. Expected from the code: the overlay and its grab live on the focused output only (`OverlayWindow.focusedScreen`); whether a click on the other output reaches the exclusive layer is unknown. Hand check in `docs/validation-checklist.md` (v1.1b).

### Build as done

Route B as designed, with these details settled during the build:

- Lua writes `grab=1` in the state file (not QML deciding): open, revealed, linger on, and lingering or a query typed. QML sets `Exclusive` from it. The grab therefore starts at the first typed letter while Alt is still held.
- Every overlay call is `set_query(seq, text)` with the whole text, and a key is sent in the SAME `hyprctl eval` right after it (`...; _G.omahop.key(seq + 1, name)`), so a key can never overtake the text it applies to. An unchanged text is a no-op in Lua (no refilter, the selection stays) but restarts the countdown.
- Sequence numbers: Lua keeps the last applied one across sessions and writes it to the state file as `seq`; QML continues from `max(own, seq) + 1`, so a restarted shell is not locked out and a late call from an older session is older than anything newer. A Hyprland reload starts Lua at 0, which accepts anything (and with no session open, nothing applies).
- QML takes Lua's query as its own text only when nothing of its own is pending or unapplied (`Linger.adopt`), so Escape and letters typed with Alt held (Lua's binds) and keys typed after the release (QML) do not fight.
- Escape with text typed is handled in QML as an edit to an empty text; only the second Escape is sent as a key. Lua keeps the same rule for `Alt + Escape`, now in `session.lua` (action `clear`).
- Activation after commit: `open=0` written first, then the focus from a 50 ms `hl.timer`, only when the grab was held during this session (plain Alt+Tab keeps its immediate focus). Live: 5 of 5 picks landed.
- Keys with Alt, Ctrl or Super are ignored by the overlay: Alt chords are omahop's binds, the rest are not ours.

Open risks: two monitors (above); stolen keys when the user changes their mind (bounded by the countdown line, Escape, a click, and the 60 s cap); the 50 ms release delay is measured on this machine only (a slower shell could need more; `M.release_ms` is one constant).

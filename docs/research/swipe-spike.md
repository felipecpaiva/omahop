# Swipe trigger spike (v1.5, 2026-11-08)

Question: can a multi-finger swipe open the switcher, move the selection and pick on lift, so omahop works without a keyboard (tablet use)?
Feature gap rows B51 and C20, ranked #9 in `feature-gap-analysis.md`.

**Verdict: GO for the touchpad, NO-GO for the touchscreen.** Built as `swipe_trigger` (off by default), decision D20.

## 1. What Hyprland 0.56.2 offers

Sources: `/usr/share/hypr/stubs/hl.meta.lua` (installed), the strings of `/usr/bin/Hyprland` (installed), and the v0.56.2 sources read
through the GitHub API (`src/config/lua/bindings/LuaBindingsConfigRules.cpp` `hlGesture`, `src/managers/input/trackpad/TrackpadGestures.cpp`,
`gestures/LuaFunctionGesture.cpp`, `gestures/ITrackpadGesture.cpp`, `src/managers/input/InputManager.cpp`, `Touch.cpp`, `src/config/lua/ConfigManager.cpp`).
`hyprctl version`: 0.56.2, tag v0.56.2.

- `hl.gesture({ fingers, direction, action, mods?, scale?, disable_inhibit? })`. `fingers` 2 to 9. `direction`: `left`, `right`, `up`, `down`,
  `horizontal`, `vertical`, `swipe` (any), `pinch`, `pinchin`, `pinchout`.
- `action` can be a built-in name (`workspace`, `move`, `resize`, `special`, `close`, `float`, `fullscreen`, `cursor_zoom`, `scroll_move`, `unset`),
  a function, or **a table of callbacks `{ start, update, finish }`**. A plain function is the legacy form: it is called once at the end with no
  argument. The table form is the one with continuous events. Note: the end callback is read from the key `finish`; the error text mentions `end`
  but the code only reads `finish` (`end` is a Lua keyword).
- Callback arguments (`LuaFunctionGesture.cpp`): start and update get `{ phase, direction, type = "swipe", time_ms, fingers, delta = { x, y } }`;
  finish gets `{ phase = "end", direction, type, time_ms, cancelled }`. `delta` is the travel of **that one event**, not a total
  (`TrackpadGestures::gestureUpdate` passes the raw `e.delta`). On update, `direction` is the direction detected at the start (`LEFT` or `RIGHT`
  for a horizontal gesture, because `isDirectionSensitive()` is false by default); on finish it is the registered one (`HORIZONTAL`).
  omahop reads only the sign of `delta.x`, never the direction string.
- Matching: the first 5 px of travel pick the axis and the direction, then the first registered gesture with the same finger count, the same
  mods and a matching direction wins. Gestures are skipped while an app inhibits shortcuts (a VM, a remote desktop), unless `disable_inhibit`.
- Registering a second gesture on the same fingers, mods and axis is refused with "Gesture will be overshadowed by a previous gesture". This is
  `Internal::configError`: it logs and adds a **config error** (the red banner), it does **not** raise a Lua error, so `pcall` cannot see it.
- There is no way to list or query gestures at runtime: `hyprctl gestures` is an unknown request, there is no `hl.get_gestures`.
- A config reload makes a new Lua state (`reinitLuaState`) and clears every gesture (`clearGestures`) before the config runs again. An
  eval-based reload keeps both the Lua state and the gestures.
- Each callback runs under Hyprland's event-callback time limit, so the update path must stay small (omahop: one sum, at most one step and one
  state write, which is skipped when nothing changed).

So the "only discrete triggers" fallback (one row per swipe, a tap or timeout to pick) is not needed: start, update and finish exist, and finish
is the lift.

### The touchscreen

`hl.gesture` is fed only by touchpad (libinput pointer) swipes: `InputManager::onSwipeBegin/Update/End` call `g_pTrackpadGestures`. Touch
events (`Touch.cpp`) go to the clients, and a touchscreen swipe only reaches Hyprland's own workspace swipe when `gestures:workspace_swipe_touch`
is on. The Lua events list (`HL.EventName`) has no touch or gesture event. So **no touchscreen trigger is possible** from a plugin today.
Nearest safe alternatives on a touchscreen: the opt-in peek strip (`peek = always`: tap an app, tap one of its windows), and a tap on a row once
the list is open. An upstream path would be a touch gesture API in Hyprland; not pursued.

## 2. What the machine already uses

Made with `lua tools/gesture-map.lua` (a sibling of `tools/key-map.py`: Hyprland cannot list gestures, so it reads the Lua files Omarchy loads,
`~/.config/hypr/*.lua` and `$OMARCHY_PATH/default/hypr/**/*.lua`, and lists every `hl.gesture` call outside a comment). On this machine:

| Fingers | Direction | Mods | Action | File |
|---|---|---|---|---|
| 3 | horizontal | none | workspace | ~/.config/hypr/input.lua |
| 3 | up | none | function | ~/.config/hypr/input.lua |
| 3 | down | none | function | ~/.config/hypr/input.lua |

- 3 fingers left and right: **taken** (workspace swipe).
- 4 fingers left and right: **free**.

Stock Omarchy 4.5 registers no gesture: the 3-finger workspace swipe and the 3-finger focus swipes are commented examples in
`config/hypr/input.lua`, which users often switch on. Also, libinput's three-finger drag (`drag_3fg`, commented in the same file) would turn a
3-finger move into a drag. Hence the default of **4 fingers**.

## 3. Design

- Settings (group "Touchpad swipe", the settings window only, no widget): `swipe_trigger` (off, needs a Hyprland reload), `swipe_fingers`
  (3 or 4, default 4, needs a reload), `swipe_distance` (px of travel per row, 20 to 600, default 100, applies at once). The distance is
  hardware calibration: Hyprland's whole-workspace swipe is 300 px by default, a row must be well under that.
- Registration: one `hl.gesture` at load with `direction = "horizontal"` and the `{ start, update, finish }` table, only when `swipe_trigger`
  is on and `takeover` is on. omahop's `dofile` is the last line of `hyprland.lua` (README install step), so a user's own gesture on the same
  fingers is registered first and keeps working; omahop's is the one Hyprland refuses, with a config error naming the clash. omahop does not
  scan the config at load (a text scan would miss computed calls and could only guess); `tools/gesture-map.lua` is the check to run by hand.
- Once per Lua state: the flag `swipe_registered` carries over from the previous `_G.omahop` on an eval-based reload, where a second call would be
  refused. The callbacks call `_G.omahop.*`, so the module that is loaded now serves them.
- Pure state machine `lua/swipe.lua`: start, update (adds `delta.x`, returns whole rows crossed, rounded toward zero, and whether they are the
  first), finish (whether the list was opened), idle expiry. Tested in `lua/test_swipe.lua`.
- Glue (`lua/omahop.lua`): `swipe_start` checks the same rules as Alt+Tab (passthrough for fullscreen and listed apps, scope) and does nothing where
  omahop is not active (a swipe has no stock meaning to fall back to). A swipe while a keyboard session is open is ignored. The first row of
  travel opens the session through `open_session`, shared with Alt+Tab (same list, `Mru.first_pick`: right starts on the previous window, left on
  the last), with no injected F24 (no Alt is involved). Further rows step. While the fingers are down the session tick treats the swipe as the
  held modifier.

## 4. Safety: the list must always close

Escape cannot be assumed on a tablet.

| Way out | How |
|---|---|
| Lift the fingers | Always ends the session: picks the selected window, or closes without switching (rows below) |
| Swipe back | Lifting with the window the swipe started from selected closes without switching |
| Hyprland cancels the swipe | `cancelled = true` on finish closes without switching |
| A lost finish event | No gesture event for 10 s (`Swipe.idle_ms`) while the fingers are down closes without picking; the 60 s session failsafe stays |
| A stray touch | Under one row of travel nothing opens at all |
| Alt+Tab with a stale swipe | A new keyboard session stops any swipe whose finish never came, so it cannot hold that session open |

A tap outside is not needed as a way out: the list only lives while the fingers are on the touchpad, so there is nothing left to tap away. A click
on a row still picks, as before.

## 5. What can be tested here, and what not

- Pure (`lua/test_swipe.lua`): accumulation, rounding, several rows in one update, left first, non-finite and missing deltas, finish, idle.
- Glue with the fake `hl` (`lua/test_glue.lua`): off by default registers nothing; a Hyprland without `hl.gesture` loads; on registers one
  4-finger horizontal gesture with `start`, `update` and `finish`; a second load does not register again; callback tables shaped exactly like
  Hyprland's; a short swipe opens nothing; first row opens on the previous window with nothing injected; the session survives ticks without Alt;
  rows step; lift picks; swipe back closes; left starts at the end; cancelled closes; the idle limit closes; tiling workspace and fullscreen
  passthrough do nothing; a keyboard session is left alone; the setting turned off without a reload makes the gesture idle; 3 fingers on
  request, 5 falls back to 4.
- Not tested here, by rule: real touchpad gestures. This agent must not drive the real touchpad or touchscreen, and `/dev/uinput` is used for
  keys only (`tests/uinput_kbd.py`); no fake pointer or touch input is injected into the session. So these are hand checks in
  `validation-checklist.md` (v1.5): the feel of `swipe_distance`, that Hyprland really calls the table callbacks from a plugin's `dofile`, the
  config error on a 3-finger clash, and that the shortcut inhibit rule behaves.

## 6. Open risks

- The callback form `{ start, update, finish }` is read from the 0.56.2 source, not observed on this machine. First hand check.
- Per-event `delta` units are libinput's, so the right `swipe_distance` depends on the touchpad; 100 is a guess to tune by hand.
- A user who loads omahop before their own gesture lines makes their gesture the refused one. The README install step puts omahop last.
- Changing `swipe_fingers` or turning the swipe on needs a Hyprland reload; turning it off applies at once (the gesture stays registered and idle).

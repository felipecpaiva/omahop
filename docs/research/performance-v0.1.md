# Performance check, v0.1 (2026-11-06)

Report from Felipe after trying v0.1: the look is fine, but it feels slow and laggy. Measured before changing anything (scripts were throwaway probes driving the glue directly, no key events, Alt faked as held, scope set to all in memory only).

## Before

| What | Number |
|---|---|
| Lua cost to open a session (build the list of 4 windows, first pick) | 0.7 ms |
| Lua cost of all key-poll ticks in 3 s (131 ticks) | 1 ms total |
| State file writes in 3 s with the overlay open | **133** (one per 25 ms tick, content mostly unchanged) |
| Time for those writes | 15 ms CPU total |
| Hyprland CPU with the overlay open / idle | 1% / 1% of one core |
| Shell CPU with the overlay open / idle | 4% / 3% |
| Tab -> overlay layer appears (Hyprland openlayer event) | median 122 ms (100 ms of it is the planned reveal delay) |
| Cancel -> layer gone | median 8 ms |

Reading: CPU and window mapping are not the problem. The churn is: every write made the overlay re-read the file and replace the list model, which rebuilds every row and reloads every icon, 40 times a second (bursts the averages hide).

## Changes

1. `write_state` writes only when the content changed (3 real writes in 3 s: open, reveal, close).
2. `Service.qml` replaces the list model only when the windows themselves change; a selection change only moves the highlight (verified with a synthetic state: highlight moves 1 -> 3 with the same list).
3. App name and icon lookups are cached per app id.
4. Key polling every 16 ms instead of 25 ms (Alt release and Tab repeat are noticed sooner; a tick costs microseconds).

## After

State file writes in 3 s: 3. Tab -> layer 119 ms (median of 8). Cancel -> gone 8 ms. Ticks 205 in 3 s, 1.6 ms CPU total.

## Not measurable here

How it feels. The frame time of the list redraw and the Tab-to-highlight latency inside the shell are not instrumented. If it is still slow, the next things to test, in this order: lower `reveal_delay_ms` (the 100 ms before the list shows is the largest fixed delay, setting `reveal_delay_ms = 0` shows the list at once), the 2-tick Alt-release wait (about 32 ms now), and Hyprland's own window animations on focus (outside omahop).

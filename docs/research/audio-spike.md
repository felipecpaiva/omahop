# Audio marker spike (v1.5, 2026-11-08)

Question: can a window row or card show a small speaker marker when its app is playing sound, opt-in (`audio_marker`, off by
default), with no idle cost, no new icon asset, nothing private logged or written, and tests that never make real sound or
touch the mixer?

**Verdict: GO**, with a snapshot of `pactl -f json list sink-inputs` taken once when the switcher opens, mapped to windows by
process id and the parent chain, with a window class fallback. Not the live Quickshell PipeWire service. Decision D21.

## How it was checked (read only on this machine)

- Quickshell 0.3.2: `/usr/lib/qt6/qml/Quickshell/Services/Pipewire/quickshell-service-pipewire.qmltypes` exists. `PwNode` has
  `isStream`, `isSink`, `properties` (QVariantMap), `audio.muted`, `audio.volume`; there is no node state (running or paused),
  only link state (`PwLinkState`: Error, Unlinked, Init, Negotiating, Allocating, Paused, Active) and a `PwNodePeakMonitor`.
- Omarchy's shell (`/usr/share/omarchy/shell`) uses the service in `plugins/panels/audio/Panel.qml`,
  `plugins/services/media/Service.qml` and `plugins/bar/widgets/Microphone.qml`. Two comments in the audio panel are the key
  evidence: reading `PwNode.properties` before the node is bound (through a `PwObjectTracker`), while capture streams are
  appearing, "can destabilize Quickshell's Pipewire service"; and a row that holds a `PwNode` which PipeWire removes during
  the removal signal "segfaults the shell", so the panel copies primitives on a timer instead.
- `pactl` is in `libpulse` (17.0), `pipewire-pulse` is installed by Omarchy (explicit install), `pactl info` answers.
  `pactl -f json list sink-inputs` gives, per playback stream: `index`, `corked`, `mute`, `volume`, and `properties` with
  `application.process.id`, `application.process.binary`, `application.name` and `media.name` (the media title: private).
  The command was run here with its output reduced by `jq` to keys and booleans only; nothing was playing, so it printed `[]`.
- Cost, 10 runs each with Python `perf_counter`: `pactl -f json list sink-inputs` median 2.8 ms (max 3.6),
  `ps -e -o pid=,ppid=` median 5.1 ms (max 8.4) with 579 processes. Both are one process start, once per switcher opening.
- The marker glyph: Omarchy's audio panel draws its output icon with the Nerd Font glyph U+F028 (`outputIcon()`), and
  Omarchy depends on `ttf-jetbrains-mono-nerd-basic`. omahop reuses that glyph as text, so no icon asset is shipped.

## Routes compared

| Route | Idle cost | Which app | Corked or muted | Risk |
|---|---|---|---|---|
| A. Quickshell PipeWire service, live | A registry listener plus a `PwObjectTracker` on every playback stream for as long as the setting is on, switcher open or not | `properties["application.process.id"]` after binding | `audio.muted`; corked is not exposed on the node (only link state Paused, indirect) | The two shell crashes Omarchy works around (unbound properties, removed nodes in delegates) |
| B. `pactl -f json list sink-inputs`, sampled at open | None: one 3 ms process when the switcher opens, only with the setting on | `application.process.id`, `application.process.binary`, `application.name` | `corked` and `mute` are plain fields | A snapshot: sound that starts while the list is up shows at the next open. Needs `pipewire-pulse` (present on Omarchy); without it there is no marker, nothing else breaks |
| C. `wpctl status` or `pw-dump` | Same as B | `pw-dump` has the same properties as JSON; `wpctl` is text for people, not a contract | `pw-dump` has node state (running, idle) but no corked flag | Larger output (the whole graph), parsing more |
| D. None | None | | | No feature |

Route B wins on the rule that decides it: "Nothing runs while the switcher is closed" (`engineering-standards.md`). It also
keeps omahop away from the PipeWire objects the shell itself has trouble with. `pw-dump` stays the documented fallback if a
system ever lacks `pipewire-pulse`.

## Mapping a stream to a window

Inputs: the streams (pid, binary, app name, playing), the process table (`ps -e -o pid=,ppid=`), and the windows from
`Hyprland.toplevels` (`lastIpcObject.pid` and `.class`, keyed by the normalized address as `toplevelFor` does).

1. **Process id and the parent chain.** Start at the stream's pid; if a window has that pid, mark it; otherwise go to the
   parent and repeat, at most 16 steps, stopping at pid 1. The nearest owner wins. This covers browsers and Electron apps, whose
   sound comes from a child utility process of the process that owns the window, and a player started in a terminal (the
   terminal is marked when the player has no window of its own).
2. **Class fallback**, only when no ancestor owns a window (a sandbox such as Flatpak reports its own namespace pid): the
   stream's `application.process.binary` or `application.name`, lower case, equal to a window class or to the last dot part
   of one (`firefox` matches `org.mozilla.firefox`).
3. **Nothing matches:** no marker. A wrong marker is worse than none.

Known limits, stated in the setting's help and in `gotchas.md`:
- **One browser process, many windows.** Chromium and Firefox play every tab through one process tree, so every window of
  that browser gets the marker. The tabs API has an `audible` flag; the `omahop-tabs` extension could carry it later to
  pinpoint the window (roadmap note).
- An uncorked stream that is silent (a call app holding its output open) is marked. pactl cannot tell silence from sound;
  only a peak monitor could, and that is a live cost.
- The marker is taken when the list opens; it does not follow sound that starts or stops while the list is up.
- With a non-Nerd shell font the glyph may show as a box (the same risk Omarchy's own audio panel takes).

A stream counts as playing only when `corked` is exactly `false` and `mute` is exactly `false`; anything missing or odd is
not playing.

## Privacy

`pactl` output carries `media.name` (a song, a video or a call title) and `application.process.binary`. The sample is read
from the process pipe straight into the parser, which keeps only pid, binary, app name and the playing flag; the raw text is
never logged, never written to a file and never put in the state file. `pactl` errors go to `/dev/null` in the sampling
script. The process table holds only numbers.

## Idle cost

- Setting off (the default): no process, no PipeWire object, nothing imported beyond what is already there.
- Setting on, switcher closed: nothing runs.
- Setting on, quick tap (no list shown): nothing runs.
- Setting on, the list shows: one `bash` running `pactl` and `ps` (about 8 ms together, off the UI thread), then a pure JS
  match over the windows (constant work per stream, bounded parent walk). The result is dropped when the list closes.

## Testable without sound

- Pure `.pragma library` matcher `AudioMarker.js`, tested by Node (`tests/audio_marker.test.mjs`) with pactl JSON fixtures:
  several streams, two streams from one pid, a browser child process with three browser windows, corked and muted streams,
  a sandbox pid with the class fallback, a parent loop, garbage input.
- The sampling script `tools/audio-sample.sh` tested with a fake `pactl` first in `PATH` (`tests/audio_sample.test.sh`):
  output shape, and a missing or failing `pactl` gives an empty list.
- No test starts a real stream or changes volume or mute. The real check is a hand check in `validation-checklist.md`.

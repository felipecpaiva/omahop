#!/usr/bin/env bash
# One sample for the audio marker (setting audio_marker, D21), run by Service.qml once when the switcher opens and only with the setting on.
# Prints the playback streams as `pactl -f json list sink-inputs` gives them, a line "--", then "pid ppid" for every process (AudioMarker.js reads both).
# Read only: it never plays, pauses, mutes or changes a volume. pactl errors are dropped (stderr would reach the shell log); no pactl means no streams.
# The pactl text holds media titles: it goes only to the caller's pipe, never to a file or a log.
set -uo pipefail
out=$(pactl -f json list sink-inputs 2>/dev/null) || out=""
printf '%s\n' "${out:-[]}"
printf -- '--\n'
ps -e -o pid=,ppid=

#!/usr/bin/env bash
# After editing QML and restarting the shell (omarchy restart shell): did omahop's own QML load? Prints our plugin's errors from the newest Quickshell log
# and exits 1 if there are any. (A plain grep for "load failed" matches the shell's own source text in the log, so this looks only at lines naming our plugin.)
log=$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$UID}"/quickshell/by-id/*/log.qslog 2>/dev/null | head -1)
[ -n "$log" ] || { echo "no Quickshell log found"; exit 1; }
bad=$(strings "$log" | grep "io.github.felipecpaiva.omahop" | grep -E "unavailable|is not a type|TypeError|ReferenceError|load failed|Cannot (read|call|assign)|Binding loop" | grep -v "Got intercept" | head -8)
if [ -n "$bad" ]; then echo "omahop QML problems:"; echo "$bad" | cut -c1-260; exit 1; fi
echo "omahop QML loaded without errors"

#!/usr/bin/env bash
# Lists app icon files, scalable first, then PNGs with the largest folders first. One path per line.
set -euo pipefail
dirs="$HOME/.icons $HOME/.local/share/icons"
IFS=":"
for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done
unset IFS
{
  for b in $dirs; do
    [[ -d $b ]] && find "$b" -path "*/apps/*" \( -name "*.svg" -o -name "*.png" \) 2>/dev/null
  done
  find /usr/share/pixmaps -maxdepth 1 \( -name "*.svg" -o -name "*.png" \) 2>/dev/null
} | sort -rV | awk '/\.svg$/ { print; next } { png[++n] = $0 } END { for (i = 1; i <= n; i++) print png[i] }'

#!/usr/bin/env bash
# Prints one icon file path per icon name, best first: app icons (scalable, then the biggest PNG), then pixmaps,
# then every other icon kind (devices, categories, places, actions, status, mimetypes). Used by Service.qml.
set -euo pipefail
dirs="$HOME/.icons $HOME/.local/share/icons"
IFS=":"
for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done
unset IFS
find_in() { # find_in <path-pattern> <extension>
  for b in $dirs; do
    [[ -d $b ]] && find -L "$b" -path "$1" -name "*.$2" 2>/dev/null
  done | sort -rV
}
{
  find_in "*/apps/*" svg; find_in "*/apps/*" png
  for ext in svg png xpm; do find /usr/share/pixmaps -maxdepth 1 -name "*.$ext" 2>/dev/null | sort; done
  for kind in devices categories places actions status mimetypes; do
    find_in "*/$kind/*" svg; find_in "*/$kind/*" png
  done
} | awk '{ f = $0; sub(/^.*\//, "", f); sub(/\.[^.]*$/, "", f); if (!(f in seen)) { seen[f] = 1; print } }'

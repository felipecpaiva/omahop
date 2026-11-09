#!/usr/bin/env bash
# Lists the installed icon themes the picker can offer, one per line: <folder name><TAB><display name>, sorted by display name.
# Display name = Name= of index.theme, else the folder name. Dropped: hicolor and default (fallbacks, not choices), Hidden=true themes, and
# themes with no app icons of their own (cursor themes, empty folders). A folder name found in several bases is listed once (first base wins,
# the same order icon-index.sh scans). Reads only; runs nothing from a theme.
set -euo pipefail
# shellcheck source=tools/icon-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/icon-lib.sh"

declare -A seen=()
for b in "${bases[@]}"; do
  [[ -d $b ]] || continue
  for dir in "$b"/*/; do
    dir=${dir%/}
    name=${dir##*/}
    valid "$name" || continue
    [[ $name == hicolor || $name == default || -n ${seen[$name]:-} ]] && continue
    seen[$name]=1
    if [[ -f $dir/index.theme ]]; then
      grep -qi '^Hidden=true' "$dir/index.theme" && continue
    fi
    # app icons of its own: the first file under any apps folder is enough
    [[ -n $(find -L "$dir" -path '*/apps/*' \( -name '*.svg' -o -name '*.png' \) -print -quit 2>/dev/null) ]] || continue
    title=$(grep -m1 '^Name=' "$dir/index.theme" 2>/dev/null || true)
    title=${title#Name=}
    title=${title//$'\t'/ }
    printf '%s\t%s\n' "$name" "${title:-$name}"
  done
done | sort -t$'\t' -k2,2f -k1,1

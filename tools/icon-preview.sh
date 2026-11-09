#!/usr/bin/env bash
# The icon files one theme gives for some app ids, for the picker's cards. Usage: icon-preview.sh <theme|-> <app id>...
# Prints <id><TAB><path> for every id the theme (or its parents, Inherits=) has an app icon for, scalable first, then the biggest PNG.
# "-" means no theme: every installed theme, first match. An id with no icon prints nothing. Names are checked (letters, digits . _ + -),
# a theme name that fails the rule acts like "-". The picker runs this only for the cards on screen and caches the answer.
set -euo pipefail
# shellcheck source=tools/icon-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/icon-lib.sh"

theme=${1:--}
shift || true
roots=()
if [[ $theme != - ]] && valid "$theme"; then mapfile -t roots < <(theme_roots "$theme"); fi
if (( ${#roots[@]} == 0 )); then roots=("${bases[@]}"); fi

for id in "$@"; do
  [[ $id =~ ^[A-Za-z0-9._+-]+$ ]] || continue
  hit=""
  for r in "${roots[@]}"; do
    [[ -d $r ]] || continue
    hit=$(find -L "$r" -path '*/apps/*' \( -name "$id.svg" -o -name "$id.png" \) 2>/dev/null | sort -rV | awk '/\.svg$/ { print; found = 1; exit } { if (!p) p = $0 } END { if (!found && p) print p }')
    [[ -n $hit ]] && break
  done
  [[ -n $hit ]] && printf '%s\t%s\n' "$id" "$hit"
done
exit 0

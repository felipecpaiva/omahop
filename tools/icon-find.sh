#!/usr/bin/env bash
# Searches every installed icon theme for an icon by name, for the icon builder. Usage: icon-find.sh <query> [limit]
# Prints <theme><TAB><icon name><TAB><path>: one line per icon name and theme (its own files only, not its parents'), scalable first, then the
# biggest PNG; app icons only. Best first: the exact name, then names that start with the query, then the rest; at most PER_THEME per theme and
# <limit> in all (default 120, at most 400). Files over the pack size limits are left out. The theme list is icon-themes.sh's (hicolor, default,
# hidden and cursor-only themes dropped). A query is 2 to 64 of letters, digits . _ + - ; anything else prints nothing.
# The answer is cached for CACHE_MINUTES in a private folder under the cache, so typing the same text again costs nothing.
set -euo pipefail
here=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=tools/icon-lib.sh
source "$here/icon-lib.sh"

readonly PER_THEME=12 MAX_LIMIT=400 CACHE_MINUTES=10
query=${1:-}
limit=${2:-120}
[[ $query =~ ^[A-Za-z0-9._+-]{2,64}$ ]] || exit 0
[[ $limit =~ ^[0-9]{1,4}$ ]] && (( limit >= 1 )) || limit=120
(( limit <= MAX_LIMIT )) || limit=$MAX_LIMIT
q=${query,,}

cache=${XDG_CACHE_HOME:-$HOME/.cache}/omahop/icon-find
file=$cache/$q.$limit
if [[ -f $file && ! -L $file && -z $(find "$file" -mmin "+$CACHE_MINUTES" -print 2>/dev/null) ]]; then cat -- "$file"; exit 0; fi

search() {
  local theme dir b
  while IFS=$'\t' read -r theme _; do
    dir=""
    for b in "${bases[@]}"; do [[ -d $b/$theme ]] && { dir=$b/$theme; break; }; done
    [[ -n $dir ]] || continue
    # awk keeps the best file per icon name (svg, else the biggest png) and ranks the name against the query
    find -L "$dir" -path '*/apps/*' \( \( -iname "*$q*.svg" -size -257k \) -o \( -iname "*$q*.png" -size -2049k \) \) 2>/dev/null \
      | awk -v theme="$theme" -v q="$q" '
          { path = $0; file = path; sub(/^.*\//, "", file); ext = file; sub(/^.*\./, "", ext); name = file; sub(/\.[^.]*$/, "", name)
            if (index(tolower(name), q) == 0) next   # the pattern matched the folder only
            n = 0; if (match(path, /\/[0-9]+(x[0-9]+)?\//)) n = substr(path, RSTART + 1, RLENGTH - 2) + 0
            score = (ext == "svg") ? 100000 : n
            if (!(name in best) || score > best[name]) { best[name] = score; where[name] = path } }
          END { for (name in best) { l = tolower(name); m = (l == q) ? 0 : (index(l, q) == 1 ? 1 : 2)
                  printf "%d\t%s\t%s\t%s\n", m, theme, name, where[name] } }' \
      | sort -t$'\t' -k1,1n -k3,3f | head -n "$PER_THEME"
  done < <(bash "$here/icon-themes.sh")
}

result=$(search | sort -t$'\t' -k1,1n -s | head -n "$limit" | cut -f2- | sed '/^$/d')
if (umask 077; mkdir -p -- "$cache") 2>/dev/null && [[ ! -L $cache && ! -L $file ]]; then
  chmod 700 -- "${cache%/*}" "$cache" 2>/dev/null || true
  printf '%s\n' "$result" > "$file.tmp$$" && mv -f -- "$file.tmp$$" "$file"
fi
[[ -z $result ]] || printf '%s\n' "$result"
exit 0

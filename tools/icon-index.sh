#!/usr/bin/env bash
# Prints one icon file path per icon name, best first: app icons (scalable, then the biggest PNG), then pixmaps,
# then every other icon kind (devices, categories, places, actions, status, mimetypes). Used by Service.qml.
# Files of omahop's own launcher overlay (tools/icon-overlay.sh) are never listed, so the overlay cannot feed back into the choice it was built from.
# Optional first argument: an icon theme name (the icon_theme setting). That theme and the themes it inherits are listed first,
# then everything else, so an app the theme lacks still gets an icon. The name comes from a config file: letters, digits, . - _ only.
set -euo pipefail
bases=("$HOME/.icons" "$HOME/.local/share/icons")
IFS=":" read -r -a xdg <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for d in "${xdg[@]}"; do bases+=("$d/icons"); done

valid() { [[ $1 =~ ^[A-Za-z0-9._-]+$ && $1 != "." && $1 != ".." ]]; }

# theme_roots <name>: the folder of the theme in every base, then those of its parents (Inherits=), depth 4, each theme once.
theme_roots() {
  local queue=("$1") seen=" " depth name b line parent next parents
  for depth in 1 2 3 4; do
    next=()
    for name in "${queue[@]}"; do
      [[ $seen == *" $name "* ]] && continue
      seen+="$name "
      for b in "${bases[@]}"; do
        [[ -d $b/$name ]] || continue
        printf '%s\n' "$b/$name"
        [[ -f $b/$name/index.theme ]] || continue
        line=$(grep -m1 '^Inherits=' "$b/$name/index.theme" 2>/dev/null || true)
        IFS=',' read -r -a parents <<< "${line#Inherits=}"
        for parent in "${parents[@]}"; do
          parent=${parent//[[:space:]]/}
          if valid "$parent"; then next+=("$parent"); fi
        done
      done
    done
    queue=("${next[@]}")
    [[ ${#queue[@]} -gt 0 ]] || break
  done
}

# find_in <path-pattern> <extension> <root>...
find_in() {
  local pat=$1 ext=$2 b
  shift 2
  for b in "$@"; do
    [[ -d $b ]] && find -L "$b" -path "$pat" -name "*.$ext" 2>/dev/null
  done | sort -rV
}

# emit_themed <root>...: per root in the given order (the theme, then its parents), apps first, then the other kinds; no pixmaps (they belong to no theme)
emit_themed() {
  local r kind
  for r in "$@"; do
    find_in "*/apps/*" svg "$r"; find_in "*/apps/*" png "$r"
  done
  for kind in devices categories places actions status mimetypes; do
    for r in "$@"; do find_in "*/$kind/*" svg "$r"; find_in "*/$kind/*" png "$r"; done
  done
}

emit_all() {
  local ext kind
  find_in "*/apps/*" svg "${bases[@]}"; find_in "*/apps/*" png "${bases[@]}"
  for ext in svg png xpm; do find /usr/share/pixmaps -maxdepth 1 -name "*.$ext" 2>/dev/null | sort; done
  for kind in devices categories places actions status mimetypes; do
    find_in "*/$kind/*" svg "${bases[@]}"; find_in "*/$kind/*" png "${bases[@]}"
  done
}

{
  if [[ -n ${1:-} ]] && valid "$1"; then
    mapfile -t roots < <(theme_roots "$1")
    [[ ${#roots[@]} -gt 0 ]] && emit_themed "${roots[@]}"
  fi
  emit_all
} | awk '/\/icons\/omahop-launcher\// { next } { f = $0; sub(/^.*\//, "", f); sub(/\.[^.]*$/, "", f); if (!(f in seen)) { seen[f] = 1; print } }'

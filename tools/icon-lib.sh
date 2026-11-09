#!/usr/bin/env bash
# Shared by icon-index.sh, icon-themes.sh and icon-preview.sh (sourced, never run): where icon themes live, the theme name rule,
# and the folders of a theme and its parents.
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

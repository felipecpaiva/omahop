#!/usr/bin/env bash
# The icon overlay for the Omarchy app grid, bar and menu app rows (setting icons_in_launcher, docs/research/launcher-icons.md, D30).
#   icon-overlay.sh on|refresh [<Icon= name> <svg file> ...]   (re)build $XDG_DATA_HOME/icons/omahop-launcher/apps/<name>.svg, one symlink per pair
#   icon-overlay.sh off                                          delete that folder, but only when it holds the marker file .omahop
# The caller (Service.qml) picks the file for each desktop entry with its own resolver (pack first, then theme); this script only links, and
# checks every pair again. The one folder is the only thing ever written: a folder of that name without the marker is refused, a marker or
# folder that is a symlink is refused, a name that could leave apps/ and a target that is not a real .svg file are skipped (note on stderr).
# Only SVG in version one: a PNG would lose to a system SVG of the same name in the shell's icon index.
set -euo pipefail

dir=${XDG_DATA_HOME:-$HOME/.local/share}/icons/omahop-launcher
marker=$dir/.omahop
mode=${1:-}
shift || true

# The folder is ours: a real directory (not a link) holding a regular marker file.
owned() { [[ -d $dir && ! -L $dir && -f $marker && ! -L $marker ]]; }
note() { printf 'omahop icon overlay: %s\n' "$1" >&2; }

case $mode in
  off)
    [[ -e $dir || -L $dir ]] || exit 0
    if owned; then rm -rf -- "$dir"; else note "off: $dir has no marker, left alone"; fi
    ;;
  on | refresh)
    if [[ -e $dir || -L $dir ]] && ! owned; then note "refused: $dir exists and is not made by omahop (no .omahop marker)"; exit 1; fi
    if [[ ! -e $dir ]]; then
      mkdir -p -- "${dir%/*}"
      mkdir -- "$dir"
      : > "$marker"
    fi
    owned || { note "refused: $dir is not a plain folder with a marker"; exit 1; }
    new=$dir/apps.new
    rm -rf -- "$new"
    mkdir -- "$new"
    while (( $# >= 2 )); do
      name=$1 target=$2
      shift 2
      if ! [[ $name =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; then note "skipped a name that is not a plain icon name"; continue; fi
      if [[ $target != /*.svg || $target == "$dir"/* || ! -f $target ]]; then note "skipped $name: its file is not an existing .svg"; continue; fi
      [[ -e $new/$name.svg || -L $new/$name.svg ]] || ln -s -- "$target" "$new/$name.svg"
    done
    rm -rf -- "${dir:?}/apps"
    mv -- "$new" "$dir/apps"
    ;;
  *) echo "usage: icon-overlay.sh on|refresh [name svg ...] | off" >&2; exit 2 ;;
esac

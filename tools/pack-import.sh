#!/usr/bin/env bash
# Installs an icon pack shared as one zip (made by pack-export.sh) into ${XDG_CONFIG_HOME:-~/.config}/omahop/packs/<folder>/.
# Usage: pack-import.sh <file.zip> [--yes] [--replace]. --yes installs without asking, --replace replaces an installed pack of that name.
# The zip comes from someone else, so in this order:
#   1. the listing is checked before anything is extracted: only pack.toml and icons/<name>.png|svg, no absolute or leaving paths, no
#      links or special files, no hidden names, no other folders, no duplicates ignoring case, caps on entries, sizes and compression ratio;
#   2. each allowed entry is extracted by this script itself, by its checked name, under a byte cap, into a fresh folder under the cache dir;
#   3. the extracted tree passes the same rules as pack-index.sh (pack-lib.sh), strictly: one bad file refuses the pack;
#   4. the folder name comes from pack.toml's name through the icon_pack name rule, never from the zip's file name or paths;
#   5. after a yes, the pack is copied next to the packs and renamed into place, so it appears whole or not at all.
# Nothing from the archive is ever run. Any refusal exits 1 and leaves nothing behind.
set -euo pipefail
export LC_ALL=C   # byte rules for names, ASCII-only lowercase and printing
shopt -s extglob
# shellcheck source=tools/pack-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/pack-lib.sh"

readonly MAX_ARCHIVE=$((50 * 1024 * 1024))
readonly MAX_ENTRIES=$((PACK_MAX_ICONS + 2))    # every icon, pack.toml and the icons/ folder entry
readonly MAX_TOTAL=$((100 * 1024 * 1024))       # bytes after unpacking, all entries together
readonly MAX_RATIO=100                          # unpacked bytes per zip byte; icons barely compress, a zip bomb compresses 1000 to 1
readonly MAX_FOLDER=64                          # characters in the derived folder name
readonly TOOL_TIMEOUT=20s                       # per bsdtar call
readonly ZIP_MAGIC=504b0304                     # a zip starts with a local file header

die() { printf 'omahop pack import: %s\n' "$1" >&2; exit 1; }
usage() { die "usage: pack-import.sh <file.zip> [--yes] [--replace]"; }
reject() { die "refused, the zip holds $(pack_shown "$1"): $2"; }
# printable() <text>: pack.toml text as it may be shown in a terminal (no escape sequences)
printable() { printf '%s' "${1//[^[:print:]]/?}"; }
# entry_cap <entry>: the most bytes that entry may unpack to
entry_cap() {
  case $1 in
    pack.toml) echo "$PACK_MAX_TOML" ;;
    *.svg) echo "$PACK_MAX_SVG" ;;
    *) echo "$PACK_MAX_PNG" ;;
  esac
}

zip="" yes=0 replace=0
for arg in "$@"; do
  case $arg in
    --yes) yes=1 ;;
    --replace) replace=1 ;;
    -*) usage ;;
    *) [[ -z $zip ]] || usage; zip=$arg ;;
  esac
done
[[ -n $zip ]] || usage
command -v bsdtar >/dev/null || die "needs bsdtar (libarchive)"

# ---- 1. the archive and its listing, before anything is extracted
[[ -f $zip ]] || die "$(pack_shown "$zip") is not a file"
archive_size=$(stat -L -c %s -- "$zip")
(( archive_size <= MAX_ARCHIVE )) || die "refused, the zip is larger than $((MAX_ARCHIVE / 1024 / 1024)) MB"
[[ $(od -An -tx1 -N4 -- "$zip" | tr -d ' \n') == "$ZIP_MAGIC" ]] || die "refused, not a zip file"
listing=$(timeout "$TOOL_TIMEOUT" bsdtar -tvf "$zip") || die "refused, the zip cannot be read"

declare -A seen=()
files=()
count=0 total=0
while IFS= read -r line; do
  [[ -n $line ]] || continue
  count=$((count + 1))
  (( count <= MAX_ENTRIES )) || die "refused, the zip has more than $MAX_ENTRIES entries"
  # bsdtar -tv prints: mode links owner group size month day time-or-year name (control characters in a name come out escaped)
  read -r mode _ _ _ size _ _ _ name <<< "$line"
  kind=${mode:0:1}
  [[ $name != /* ]] || reject "$name" "an absolute path"                                      # rule:absolute
  [[ /$name/ != */../* ]] || reject "$name" "a path that leads out of the pack"               # rule:zip-slip
  [[ $kind == - || $kind == d ]] || reject "$name" "a link or special file"                   # rule:links
  [[ /$name != */.* ]] || reject "$name" "a hidden name"                                      # rule:hidden
  if [[ $kind == d ]]; then
    [[ $name == icons/ ]] || reject "$name" "a folder; only icons/ may be one"                 # rule:nested
    continue
  fi
  [[ $name == pack.toml || $name =~ ^icons/${PACK_ICON_NAME}$ ]] \
    || reject "$name" "a file that is not pack.toml or icons/<app>.png|svg"                   # rule:allow-list
  [[ -z ${seen[${name,,}]:-} ]] || reject "$name" "a name listed twice (case is ignored)"     # rule:duplicate
  seen[${name,,}]=1
  [[ $size =~ ^[0-9]+$ ]] || reject "$name" "an entry without a size"
  cap=$(entry_cap "$name")
  (( size <= cap )) || reject "$name" "a file larger than $cap bytes"                        # rule:size
  total=$((total + size))
  files+=("$name")
done <<< "$listing"
[[ -n ${seen[pack.toml]:-} ]] || die "refused, the zip has no pack.toml"
(( total <= MAX_TOTAL )) || die "refused, the zip unpacks to more than $((MAX_TOTAL / 1024 / 1024)) MB"
(( total <= archive_size * MAX_RATIO )) \
  || die "refused, the zip unpacks to more than $MAX_RATIO times its size (a zip bomb)"     # rule:ratio

# ---- 2. extract each checked entry by its own name into a fresh folder; the listing may lie about sizes, the bytes cannot
cache=${XDG_CACHE_HOME:-$HOME/.cache}/omahop
mkdir -p -- "$cache"
stage=$(mktemp -d -- "$cache/import.XXXXXX")
incoming="" aside=""
cleanup() { rm -rf -- "$stage" ${incoming:+"$incoming"} ${aside:+"$aside"}; }
trap cleanup EXIT
mkdir -- "$stage/pack" "$stage/pack/icons"
written=0
for name in "${files[@]}"; do
  cap=$(entry_cap "$name")
  dest=$stage/pack/$name
  read_ok=1
  # -q stops at the first match; head stops a stream that runs past the cap (bsdtar then ends on a closed pipe)
  timeout "$TOOL_TIMEOUT" bsdtar -xOqf "$zip" -- "$name" | head -c "$((cap + 1))" > "$dest" || read_ok=0
  size=$(stat -c %s -- "$dest")
  (( size <= cap )) || reject "$name" "a file that unpacks to more than $cap bytes"
  (( read_ok )) || reject "$name" "an entry that cannot be read"
  written=$((written + size))
  (( written <= MAX_TOTAL )) || die "refused, the zip unpacks to more than $((MAX_TOTAL / 1024 / 1024)) MB"
done

# ---- 3. the same rules as an installed pack, strictly
pack_check_strict "$stage/pack" || die "refused:"$'\n'"$PACK_ERR"
icon_count=${#PACK_GOOD[@]}

# ---- 4. the folder name: pack.toml name, lower case, runs of other characters as one dash, no leading or trailing dot or dash
folder=${PACK_META[name],,}
folder=${folder//+([^a-z0-9._-])/-}
folder=${folder##+([.-])}
folder=${folder:0:MAX_FOLDER}
folder=${folder%%+([.-])}
pack_name_ok "$folder" || die "refused, pack.toml name gives no usable folder name (use letters or digits)"
packs=$(dirname -- "$(pack_dir "$folder")")
target=$packs/$folder
exists=0
[[ ! -e $target && ! -L $target ]] || exists=1
(( ! exists || replace )) || die "a pack named $folder is already installed, add --replace to replace it"

# ---- 5. show what it is, ask, install
printf 'Pack:     %s\n' "$(printable "${PACK_META[name]}")"
printf 'Author:   %s\n' "$(printable "${PACK_META[author]}")"
printf 'License:  %s\n' "$(printable "${PACK_META[license]}")"
printf 'Icons:    %d\n' "$icon_count"
printf 'Install:  %s%s\n' "$target" "$( (( exists )) && echo " (replaces the installed one)" )"
printf 'Files:\n'
printf '  %s\n' "${files[@]}"
if (( ! yes )); then
  [[ -t 0 ]] || die "not installed: answer in a terminal, or add --yes"
  read -r -p "Install this pack? [y/N] " answer
  [[ $answer == [yY]* ]] || die "not installed"
fi
mkdir -p -- "$packs"
# Copy beside the packs first (same filesystem as the target), then one rename puts it in place.
incoming=$(mktemp -d -- "$packs/.incoming.XXXXXX")
cp -R -- "$stage/pack/." "$incoming/"
chmod -R u=rwX,go=rX -- "$incoming"
if (( exists )); then
  aside=$(mktemp -d -- "$packs/.replaced.XXXXXX")
  mv -T -- "$target" "$aside/pack"
fi
if ! mv -T -- "$incoming" "$target"; then
  [[ -z $aside ]] || mv -T -- "$aside/pack" "$target"
  die "could not move the pack into $target"
fi
incoming=""
printf 'Installed. Set Icon pack to %s in the settings to use it.\n' "$folder"

#!/usr/bin/env bash
# Writes one installed icon pack as a zip to share: pack.toml and icons/ only (format: docs/icon-packs.md).
# Usage: pack-export.sh <pack name> [out.zip] [--force]. Default out: ~/<name>.omahop-pack.zip; an existing file is kept unless --force.
# The pack must pass the same rules as pack-index.sh (pack-lib.sh), strictly: a file pack-index would skip refuses the export, so a
# shared pack carries no junk. In-pack links become plain copies (a zip holds no links). Ordering, timestamps, owners and modes are fixed,
# so the same pack always gives the same bytes. Uses bsdtar (libarchive, which pacman needs, so every Arch system has it).
set -euo pipefail
export LC_ALL=C
# shellcheck source=tools/pack-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/pack-lib.sh"

readonly EXPORT_TIME=946684800   # 2000-01-01 00:00 UTC: any fixed time after 1980 (the zip format starts there)
readonly FILE_MODE=0644
readonly DIR_MODE=0755

die() { printf 'omahop pack export: %s\n' "$1" >&2; exit 1; }
usage() { die "usage: pack-export.sh <pack name> [out.zip] [--force]"; }

name="" out="" force=0
for arg in "$@"; do
  case $arg in
    --force) force=1 ;;
    -*) usage ;;
    *) if [[ -z $name ]]; then name=$arg; elif [[ -z $out ]]; then out=$arg; else usage; fi ;;
  esac
done
[[ -n $name ]] || usage
pack_name_ok "$name" || die "a pack name has only letters, digits, dot, dash and underscore"
dir=$(pack_dir "$name")
[[ -d $dir ]] || die "no pack folder at $dir"
command -v bsdtar >/dev/null || die "needs bsdtar (libarchive)"
pack_check_strict "$dir" || die "not exported, fix the pack first:"$'\n'"$PACK_ERR"

out=${out:-$HOME/$name.omahop-pack.zip}
[[ ! -d $out ]] || die "$out is a folder"
[[ ! -e $out || $force == 1 ]] || die "$out exists, add --force to replace it"

cache=${XDG_CACHE_HOME:-$HOME/.cache}/omahop
mkdir -p -- "$cache"
stage=$(mktemp -d -- "$cache/export.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
mkdir -- "$stage/pack" "$stage/pack/icons"
cp -L -- "$PACK_TOML" "$stage/pack/pack.toml"
for path in "${PACK_GOOD[@]}"; do cp -L -- "$path" "$stage/pack/icons/${path##*/}"; done
# The zip is built from an mtree list, so each entry carries only what is written here: name, type, mode, owner 0 and one fixed time.
# Built from file metadata instead, bsdtar also stores the change time, and two exports of the same pack would differ.
{
  printf '#mtree\n/set uid=0 gid=0 time=%s.0\n' "$EXPORT_TIME"
  printf 'pack.toml type=file mode=%s contents=pack.toml\nicons type=dir mode=%s\n' "$FILE_MODE" "$DIR_MODE"
  # icon names are letters, digits and . _ + - (pack-lib.sh), so nothing needs mtree escaping; PACK_GOOD is sorted
  for path in "${PACK_GOOD[@]}"; do printf 'icons/%s type=file mode=%s contents=icons/%s\n' "${path##*/}" "$FILE_MODE" "${path##*/}"; done
} > "$stage/list.mtree"
zip_file=$stage/out.zip
# TZ: the zip also stores a local-time stamp, pinned so exports match across machines.
(cd "$stage/pack" && TZ=UTC bsdtar --format zip -cf "$zip_file" "@$stage/list.mtree")
mv -f -- "$zip_file" "$out"
printf 'Exported %s (%d icons) to %s\n' "$name" "${#PACK_GOOD[@]}" "$out"

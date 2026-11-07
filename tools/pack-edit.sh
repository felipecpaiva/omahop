#!/usr/bin/env bash
# The icon pack editor's one writer: the settings window runs it through Process, and it works by hand too (format: docs/icon-packs.md).
#   pack-edit.sh list                                              installed pack folders, one per line
#   pack-edit.sh stem <app id>                                     the icon file stem for that app (fails when it cannot be a file name)
#   pack-edit.sh init <name> <author> <license> [description]      a new pack; prints its folder
#   pack-edit.sh meta <folder> <name> <author> <license> [description]   rewrites those keys of pack.toml, keeps every other line
#   pack-edit.sh add <folder> <app id> </full/path/to/image>       copies a PNG or SVG in as icons/<stem>.png|svg; prints the file name
#   pack-edit.sh remove <folder> <icon file>                       deletes that icon (a link itself, never its target)
# Arguments are positional only, so no value is ever read as a flag. Every rule comes from pack-lib.sh (the ones export and import use);
# writes go only under packs/<folder>/, through hidden temporary names in that folder and one rename. Any refusal exits 1 with the reason.
set -euo pipefail
export LC_ALL=C   # byte rules for names and lower case, like the importer
# shellcheck source=tools/pack-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/pack-lib.sh"

readonly META_KEYS=(name author license description)

die() { printf 'omahop pack edit: %s\n' "$1" >&2; exit 1; }
usage() { die "usage: pack-edit.sh list | stem <app id> | init <name> <author> <license> [description] | meta <folder> <name> <author> <license> [description] | add <folder> <app id> <image> | remove <folder> <icon file>"; }

packs_dir() { dirname -- "$(pack_dir x)"; }

# icon_stem <app id>: lower case, runs of whitespace as one dash (a form IconResolve.candidates tries), and it must make a valid icon name.
icon_stem() {
  local stem=${1,,}
  stem=${stem//+([[:space:]])/-}
  [[ $stem.png =~ ^${PACK_ICON_NAME}$ ]] || return 1
  printf '%s\n' "$stem"
}

# meta_ok <key> <value> <required>: a value pack.toml can hold.
meta_ok() {
  local key=$1 value=$2 required=$3
  [[ $required == 0 || -n $value ]] || die "$key must not be empty"
  [[ $value != *\"* ]] || die "$key cannot hold a double quote"
  [[ $value != *[[:cntrl:]]* ]] || die "$key cannot hold a line break or a control character"
  (( ${#value} <= PACK_MAX_TEXT )) || die "$key is longer than $PACK_MAX_TEXT characters"
}

# meta_args <name> <author> <license> [description]: checks the four values and fills META.
declare -A META=()
meta_args() {
  (( $# == 3 || $# == 4 )) || usage
  META=([name]=$1 [author]=$2 [license]=$3 [description]=${4:-})
  local key
  for key in name author license; do meta_ok "$key" "${META[$key]}" 1; done
  meta_ok description "${META[description]}" 0
}

# open_pack <folder>: an installed, editable pack: a valid name, a real folder (a linked pack is edited where it lives), a good pack.toml.
# Sets DIR, and pack_check's PACK_ROOT, PACK_TOML and PACK_ICONS.
open_pack() {
  pack_name_ok "$1" || die "a pack name has only letters, digits, dot, dash and underscore"
  DIR=$(pack_dir "$1")
  [[ ! -L $DIR ]] || die "$1 is a link to a folder kept elsewhere; edit it there"
  [[ -d $DIR ]] || die "no pack folder named $1"
  pack_check "$DIR" || die "the pack cannot be edited until it is fixed: $PACK_ERR"
  [[ $PACK_ROOT == "$(realpath -e -- "$(packs_dir)")/$1" ]] || die "$1 is not a folder of the packs folder"
  [[ ! -L $DIR/pack.toml ]] || die "pack.toml is a link; edit the file it points to"
}

# toml_line <key>: the pack.toml line for META[key].
toml_line() { printf '%s = "%s"\n' "$1" "${META[$1]}"; }

# write_toml <folder> <text>: the new pack.toml must pass pack_check (in a hidden staging pack beside it), then replaces the old one by rename.
write_toml() {
  local root=$1 text=$2 stage
  stage=$(mktemp -d -- "$root/.edit.XXXXXX")
  STAGES+=("$stage")
  printf '%s' "$text" > "$stage/pack.toml"
  mkdir -- "$stage/icons"
  pack_check "$stage" || die "not saved: $PACK_ERR"
  chmod 0644 -- "$stage/pack.toml"
  mv -fT -- "$stage/pack.toml" "$root/pack.toml"
}

STAGES=()
cleanup() { (( ${#STAGES[@]} == 0 )) || rm -rf -- "${STAGES[@]}"; }
trap cleanup EXIT

cmd_list() {
  (( $# == 0 )) || usage
  local packs path name
  packs=$(packs_dir)
  [[ -d $packs ]] || return 0
  while IFS= read -r -d '' path; do
    name=${path##*/}
    [[ $name != .* ]] && pack_name_ok "$name" && [[ -d $path ]] && printf '%s\n' "$name"
  done < <(find "$packs" -mindepth 1 -maxdepth 1 -print0 | sort -z)
  return 0
}

cmd_stem() {
  (( $# == 1 )) || usage
  icon_stem "$1" || die "$(pack_shown "$1") cannot be an icon file name (letters, digits and . _ + - only)"
}

cmd_init() {
  meta_args "$@"
  local folder packs dir stage key text=""
  folder=$(pack_folder_name "${META[name]}") || die "the name needs a letter or digit"
  dir=$(pack_dir "$folder")
  [[ ! -e $dir && ! -L $dir ]] || die "a pack folder named $folder already exists"
  packs=$(packs_dir)
  mkdir -p -- "$packs"
  stage=$(mktemp -d -- "$packs/.new.XXXXXX")
  STAGES+=("$stage")
  for key in "${META_KEYS[@]}"; do [[ -z ${META[$key]} ]] || text+=$(toml_line "$key")$'\n'; done
  printf '%s' "$text" > "$stage/pack.toml"
  mkdir -- "$stage/icons"
  pack_check "$stage" || die "not created: $PACK_ERR"
  chmod -R u=rwX,go=rX -- "$stage"
  [[ ! -e $dir && ! -L $dir ]] || die "a pack folder named $folder already exists"
  mv -T -- "$stage" "$dir"
  printf '%s\n' "$folder"
}

cmd_meta() {
  (( $# >= 1 )) || usage
  local folder=$1 line key text="" done_keys=" "
  shift
  meta_args "$@"
  open_pack "$folder"
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ ^[[:space:]]*(name|author|license|description)[[:space:]]*= ]]; then
      key=${BASH_REMATCH[1]}
      [[ $done_keys == *" $key "* || -z ${META[$key]} ]] || text+=$(toml_line "$key")$'\n'
      done_keys+="$key "
    else
      text+=$line$'\n'
    fi
  done < "$PACK_TOML"
  for key in "${META_KEYS[@]}"; do
    [[ $done_keys == *" $key "* || -z ${META[$key]} ]] || text+=$(toml_line "$key")$'\n'
  done
  write_toml "$PACK_ROOT" "$text"
  printf 'Saved %s\n' "$folder"
}

cmd_add() {
  (( $# == 3 )) || usage
  local folder=$1 app=$2 src=$3 stem real icons stage file ext size path
  open_pack "$folder"
  icons=$PACK_ICONS
  stem=$(icon_stem "$app") || die "$(pack_shown "$app") cannot be an icon file name (letters, digits and . _ + - only)"
  [[ $src == /* ]] || die "give the image as a full path"
  real=$(realpath -e -- "$src") || die "no file at $(pack_shown "$src")"
  [[ -f $real ]] || die "$(pack_shown "$src") is not a file"
  size=$(stat -c %s -- "$real")
  (( size <= PACK_MAX_PNG )) || die "the image is larger than $((PACK_MAX_PNG / 1024 / 1024)) MB"
  ext=svg
  [[ $(od -An -tx1 -N8 -- "$real" | tr -d ' \n') != 89504e470d0a1a0a ]] || ext=png
  file=$stem.$ext
  # A staging pack inside this pack (same disk, so the move is one rename), held to the strict rule of export and import.
  stage=$(mktemp -d -- "$PACK_ROOT/.edit.XXXXXX")
  STAGES+=("$stage")
  mkdir -- "$stage/icons"
  cp -- "$PACK_TOML" "$stage/pack.toml"
  head -c "$((PACK_MAX_PNG + 1))" -- "$real" > "$stage/icons/$file"
  pack_check_strict "$stage" || die "not added, the image must be a PNG or a plain SVG:"$'\n'"$PACK_ERR"
  chmod 0644 -- "$stage/icons/$file"
  mv -fT -- "$stage/icons/$file" "$icons/$file"
  # One file per app: drop the other extension and other spellings of the same name.
  while IFS= read -r -d '' path; do
    [[ ${path##*/} == "$file" ]] || rm -f -- "$path"
  done < <(find "$icons" -mindepth 1 -maxdepth 1 \( -iname "$stem.png" -o -iname "$stem.svg" \) -print0)
  printf '%s\n' "$file"
}

cmd_remove() {
  (( $# == 2 )) || usage
  local folder=$1 file=$2
  open_pack "$folder"
  [[ $file =~ ^${PACK_ICON_NAME}$ ]] || die "$(pack_shown "$file") is not an icon file name"
  [[ -e $PACK_ICONS/$file || -L $PACK_ICONS/$file ]] || die "the pack has no icons/$file"
  rm -f -- "$PACK_ICONS/$file"
  printf 'Removed %s\n' "$file"
}

(( $# >= 1 )) || usage
command=$1
shift
case $command in
  list) cmd_list "$@" ;;
  stem) cmd_stem "$@" ;;
  init) cmd_init "$@" ;;
  meta) cmd_meta "$@" ;;
  add) cmd_add "$@" ;;
  remove) cmd_remove "$@" ;;
  *) usage ;;
esac

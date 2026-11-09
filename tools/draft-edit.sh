#!/usr/bin/env bash
# The icon builder's one writer (docs/icon-packs.md, "The builder draft"): a draft is a private pack-shaped folder in the cache, never in the packs
# folder, so it is never listed, indexed or exported. The settings window runs it through Process; it works by hand too.
#   draft-edit.sh list                         icons in the draft, one per line: <stem><TAB><file><TAB><full path>
#   draft-edit.sh add <app id> </full/path>    copies a PNG or SVG in as icons/<stem>.png|svg (a theme icon is copied, never linked); prints the file name
#   draft-edit.sh remove <icon file>           deletes that icon
#   draft-edit.sh reset-app <app id>           deletes the icon of that app (back to the theme's own)
#   draft-edit.sh undo                         reverses the last add, remove or reset-app (the last HIST_MAX steps are kept); prints the stem
#   draft-edit.sh discard                      deletes the whole draft
# Positional arguments only. Every image rule is pack-lib.sh's, the one export and import use, so a draft file always passes what export accepts.
# Writes stay under $XDG_CACHE_HOME/omahop/draft/, through a hidden staging folder and one rename. A refusal exits 1 with the reason.
set -euo pipefail
export LC_ALL=C
# shellcheck source=tools/pack-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/pack-lib.sh"

readonly HIST_MAX=30
HIST_LINE='^[0-9]+'$'\t''[a-z0-9][a-z0-9._+-]{0,199}'$'\t''(png|svg|-)$'

die() { printf 'omahop draft edit: %s\n' "$1" >&2; exit 1; }
usage() { die "usage: draft-edit.sh list | add <app id> <image> | remove <icon file> | reset-app <app id> | undo | discard"; }

DRAFT=${XDG_CACHE_HOME:-$HOME/.cache}/omahop/draft
STAGES=()
cleanup() { (( ${#STAGES[@]} == 0 )) || rm -rf -- "${STAGES[@]}"; }
trap cleanup EXIT

# open_draft [create]: checks the folder (no links) and sets PACK_ROOT, PACK_ICONS. With "create" a missing draft is made, mode 700.
open_draft() {
  [[ ! -L ${DRAFT%/*} && ! -L $DRAFT ]] || die "the draft folder is a link"
  if [[ ! -d $DRAFT ]]; then
    [[ ${1:-} == create ]] || return 1
    (umask 077; mkdir -p -- "$DRAFT/icons" "$DRAFT/undo")
    chmod 700 -- "${DRAFT%/*}" "$DRAFT"
    printf 'name = "draft"\nauthor = "draft"\nlicense = "draft"\n' > "$DRAFT/pack.toml"
  fi
  mkdir -p -- "$DRAFT/undo" "$DRAFT/icons"
  pack_check "$DRAFT" || die "the draft is damaged ($PACK_ERR); run discard"
  [[ $PACK_ROOT == "$(realpath -e -- "${DRAFT%/*}")/draft" ]] || die "the draft folder is not where it should be"
}

# existing <stem>: the icons/ file of that stem, if any (png or svg).
existing() { local e; for e in png svg; do [[ -f $PACK_ICONS/$1.$e && ! -L $PACK_ICONS/$1.$e ]] && { printf '%s\n' "$1.$e"; return; }; done; return 0; }

# record <stem> <old file or empty>: push one undo step (the old file is kept in undo/<n>), drop the oldest beyond HIST_MAX.
record() {
  local stem=$1 old=$2 n=1 last drop lines ext=-
  if [[ -s $DRAFT/history ]]; then last=$(tail -n 1 -- "$DRAFT/history"); n=$(( ${last%%$'\t'*} + 1 )); fi
  [[ -z $old ]] || { cp -p -- "$PACK_ICONS/$old" "$DRAFT/undo/$n"; ext=${old##*.}; }
  printf '%s\t%s\t%s\n' "$n" "$stem" "$ext" >> "$DRAFT/history"
  lines=$(wc -l < "$DRAFT/history")
  while (( lines > HIST_MAX )); do
    drop=$(head -n 1 -- "$DRAFT/history"); rm -f -- "$DRAFT/undo/${drop%%$'\t'*}"
    tail -n +2 -- "$DRAFT/history" > "$DRAFT/history.new" && mv -f -- "$DRAFT/history.new" "$DRAFT/history"
    lines=$((lines - 1))
  done
}

cmd_list() {
  (( $# == 0 )) || usage
  open_draft || return 0
  local path file
  pack_icons note_skip
  for path in "${PACK_GOOD[@]}"; do file=${path##*/}; printf '%s\t%s\t%s\n' "${file%.*}" "$file" "$path"; done
}
note_skip() { printf 'omahop draft edit: %s\n' "$1" >&2; }

cmd_add() {
  (( $# == 2 )) || usage
  local stem src=$2 real size ext file stage old icons toml
  stem=$(icon_stem "$1") || die "$(pack_shown "$1") cannot be an icon file name (letters, digits and . _ + - only)"
  [[ $src == /* ]] || die "give the image as a full path"
  real=$(realpath -e -- "$src") || die "no file at $(pack_shown "$src")"
  [[ -f $real ]] || die "$(pack_shown "$src") is not a file"
  size=$(stat -c %s -- "$real")
  (( size <= PACK_MAX_PNG )) || die "the image is larger than $((PACK_MAX_PNG / 1024 / 1024)) MB"
  open_draft create
  icons=$PACK_ICONS toml=$PACK_TOML
  old=$(existing "$stem")
  if [[ -z $old ]]; then (( $(find "$PACK_ICONS" -mindepth 1 -maxdepth 1 | wc -l) < PACK_MAX_ICONS )) || die "the draft already holds $PACK_MAX_ICONS icons"; fi
  ext=svg
  [[ $(od -An -tx1 -N8 -- "$real" | tr -d ' \n') != 89504e470d0a1a0a ]] || ext=png
  file=$stem.$ext
  stage=$(mktemp -d -- "$PACK_ROOT/.edit.XXXXXX")
  STAGES+=("$stage")
  mkdir -- "$stage/icons"
  cp -- "$toml" "$stage/pack.toml"
  head -c "$((PACK_MAX_PNG + 1))" -- "$real" > "$stage/icons/$file"
  pack_check_strict "$stage" || die "not added, the image must be a PNG or a plain SVG:"$'\n'"$PACK_ERR"
  PACK_ICONS=$icons   # pack_check_strict pointed these at the staging pack
  chmod 0600 -- "$stage/icons/$file"
  record "$stem" "$old"
  mv -fT -- "$stage/icons/$file" "$icons/$file"
  [[ -z $old || $old == "$file" ]] || rm -f -- "$icons/$old"
  printf '%s\n' "$file"
}

# drop_stem <stem>: records and deletes the icon of a stem; refuses when there is none.
drop_stem() {
  local old
  open_draft || die "the draft is empty"
  old=$(existing "$1")
  [[ -n $old ]] || die "the draft has no icon for $1"
  record "$1" "$old"
  rm -f -- "$PACK_ICONS/$old"
  printf 'Removed %s\n' "$old"
}

cmd_remove() {
  (( $# == 1 )) || usage
  [[ $1 =~ ^${PACK_ICON_NAME}$ ]] || die "$(pack_shown "$1") is not an icon file name"
  drop_stem "${1%.*}"
}

cmd_reset() {
  (( $# == 1 )) || usage
  local stem
  stem=$(icon_stem "$1") || die "$(pack_shown "$1") cannot be an icon file name"
  drop_stem "$stem"
}

cmd_undo() {
  (( $# == 0 )) || usage
  open_draft || die "nothing to undo"
  [[ -s $DRAFT/history ]] || die "nothing to undo"
  local line n stem ext
  line=$(tail -n 1 -- "$DRAFT/history")
  [[ $line =~ $HIST_LINE ]] || { rm -f -- "$DRAFT/history"; die "the undo history was damaged and is cleared"; }
  IFS=$'\t' read -r n stem ext <<< "$line"
  rm -f -- "$PACK_ICONS/$stem.png" "$PACK_ICONS/$stem.svg"
  if [[ $ext != - ]]; then
    [[ -f $DRAFT/undo/$n && ! -L $DRAFT/undo/$n ]] || die "the saved copy for $stem is missing"
    mv -f -- "$DRAFT/undo/$n" "$PACK_ICONS/$stem.$ext"
  fi
  head -n -1 -- "$DRAFT/history" > "$DRAFT/history.new" && mv -f -- "$DRAFT/history.new" "$DRAFT/history"
  printf '%s\n' "$stem"
}

cmd_discard() {
  (( $# == 0 )) || usage
  [[ ! -L $DRAFT ]] || die "the draft folder is a link"
  [[ ! -e $DRAFT ]] || rm -rf -- "$DRAFT"
  printf 'Discarded the draft\n'
}

(( $# >= 1 )) || usage
command=$1
shift
case $command in
  list) cmd_list "$@" ;;
  add) cmd_add "$@" ;;
  remove) cmd_remove "$@" ;;
  reset-app) cmd_reset "$@" ;;
  undo) cmd_undo "$@" ;;
  discard) cmd_discard "$@" ;;
  *) usage ;;
esac

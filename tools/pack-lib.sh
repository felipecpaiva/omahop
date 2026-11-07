# shellcheck shell=bash
# The rules for one installed icon pack folder (format: docs/icon-packs.md), shared so they live in one place:
# pack-index.sh uses them leniently (a bad icon is skipped with a note), pack-export.sh and pack-import.sh strictly (any note refuses the pack).
# Sourced, never run. Packs come from other people: nothing in a pack is ever run or sourced, pack.toml is only read line by line.
shopt -s extglob   # pack_folder_name

PACK_MAX_PNG=$((2 * 1024 * 1024))
PACK_MAX_SVG=$((256 * 1024))
PACK_MAX_SIDE=4096
PACK_MAX_ICONS=2000
PACK_MAX_TOML=$((16 * 1024))
PACK_MAX_TEXT=500
PACK_REQUIRED_KEYS=(name author license)
# An icon file name: letters, digits, . _ + -, starting with a letter or digit, ending in .png or .svg. No anchors, so callers can embed it.
PACK_ICON_NAME='[A-Za-z0-9][A-Za-z0-9._+-]{0,199}\.(png|svg)'

PACK_ROOT=""    # the pack folder, links resolved
PACK_TOML=""    # its pack.toml, links resolved
PACK_ICONS=""   # its icons folder, links resolved
PACK_ERR=""     # why pack_check refused the pack
PACK_GOOD=()    # pack_icons: the good icon paths, sorted
declare -gA PACK_META=()

# pack_name_ok <name>: the icon_pack rule for a pack folder name (no slash, no traversal, nothing a shell would read).
pack_name_ok() { [[ $1 =~ ^[A-Za-z0-9._-]+$ && $1 != "." && $1 != ".." ]]; }

# pack_folder_name <text>: the folder for a pack whose pack.toml name is <text>: lower case, every run of other characters one dash, no
# leading or trailing dot or dash, at most PACK_MAX_FOLDER characters. Prints it, or returns 1 when nothing usable is left. ASCII rules:
# callers run with LC_ALL=C. Shared by the importer and the editor, so a pack exported and imported lands in the folder it was made in.
PACK_MAX_FOLDER=64
pack_folder_name() {
  local folder=${1,,}
  folder=${folder//+([^a-z0-9._-])/-}
  folder=${folder##+([.-])}
  folder=${folder:0:PACK_MAX_FOLDER}
  folder=${folder%%+([.-])}
  pack_name_ok "$folder" || return 1
  printf '%s\n' "$folder"
}

# pack_dir <name>: where the pack of that folder name lives.
pack_dir() { printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/omahop/packs/$1"; }

# pack_shown <text>: a file name made safe to print (it may hold control characters).
pack_shown() { printf '%q' "$1"; }

pack_fail() { PACK_ERR=$1; return 1; }
pack_inside() { [[ $1 == "$PACK_ROOT"/* ]]; }

# pack_check <folder>: pack.toml (the flat TOML subset of config.toml: required text keys name, author, license) and the icons folder.
# Fills PACK_ROOT, PACK_TOML, PACK_ICONS and PACK_META, or sets PACK_ERR and returns 1. The folder itself may be a link (a git clone
# kept elsewhere); everything inside must stay inside its real folder.
pack_check() {
  local line n=0 key
  PACK_META=()
  PACK_ROOT=$(realpath -e -- "$1") || { pack_fail "the pack folder is missing"; return; }
  PACK_TOML=$PACK_ROOT/pack.toml
  [[ -e $PACK_TOML ]] || { pack_fail "pack.toml is missing"; return; }
  PACK_TOML=$(realpath -e -- "$PACK_TOML")
  pack_inside "$PACK_TOML" && [[ -f $PACK_TOML ]] || { pack_fail "pack.toml is not a file inside the pack"; return; }
  (( $(stat -c %s -- "$PACK_TOML") <= PACK_MAX_TOML )) || { pack_fail "pack.toml is larger than $PACK_MAX_TOML bytes"; return; }
  while IFS= read -r line || [[ -n $line ]]; do
    n=$((n + 1))
    line=${line%$'\r'}
    [[ $line =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if [[ $line =~ ^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*\"([^\"]*)\"[[:space:]]*(#.*)?$ ]]; then
      PACK_META[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
    elif [[ $line =~ ^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*=[[:space:]]*(-?[0-9]+|true|false)[[:space:]]*(#.*)?$ ]]; then
      : # a number or a switch (for example a later schema = 1): allowed, not used yet
    else
      pack_fail "pack.toml line $n is not  key = \"text\""; return
    fi
  done < "$PACK_TOML"
  for key in "${PACK_REQUIRED_KEYS[@]}"; do
    [[ -n ${PACK_META[$key]:-} ]] || { pack_fail "pack.toml needs $key = \"...\""; return; }
  done
  for key in "${!PACK_META[@]}"; do
    (( ${#PACK_META[$key]} <= PACK_MAX_TEXT )) || { pack_fail "pack.toml $key is longer than $PACK_MAX_TEXT characters"; return; }
  done
  [[ -e $PACK_ROOT/icons ]] || { pack_fail "the icons folder is missing"; return; }
  PACK_ICONS=$(realpath -e -- "$PACK_ROOT/icons")
  pack_inside "$PACK_ICONS" && [[ -d $PACK_ICONS ]] || { pack_fail "icons is not a folder inside the pack"; return; }
}

# pack_png_ok <file>: the PNG signature, IHDR first, and a picture no bigger than PACK_MAX_SIDE on each side (a small file can decode
# to a huge one).
pack_png_ok() {
  local head sides w h
  head=$(od -An -tx1 -N16 -- "$1" | tr -d ' \n')
  [[ $head == 89504e470d0a1a0a????????49484452 ]] || return 1
  sides=$(od -An -tu4 --endian=big -j16 -N8 -- "$1")
  read -r w h <<< "$sides"
  [[ -n $w && -n $h ]] && (( w > 0 && h > 0 && w <= PACK_MAX_SIDE && h <= PACK_MAX_SIDE ))
}

# pack_svg_ok <file>: an <svg> document that can load nothing outside itself: no scripts or foreign content, no event handlers,
# no DOCTYPE or entities, and every href or url() is an in-document #fragment or embedded image data. Read as one line, so a tag split
# over lines is still seen.
pack_svg_ok() {
  local text ref
  text=$(tr '\r\n\t' '   ' < "$1")
  grep -qiE '<svg[ >]' <<< "$text" || return 1
  grep -qiE '<!(DOCTYPE|ENTITY)|<(script|foreignObject|iframe|embed|object|handler|listener)[ />]|(^| )on[a-z]+ *=' <<< "$text" && return 1
  grep -qiE "url\( *[\"']?[^#\"' ]" <<< "$text" && return 1
  while IFS= read -r ref; do
    ref=${ref#*=}
    ref=${ref#"${ref%%[\"\']*}"}
    ref=${ref:1}
    [[ $ref == \#* || $ref =~ ^data:image/(png|jpeg|webp)\;base64, ]] || return 1
  done < <(grep -oiE "href *= *[\"'][^\"']*" <<< "$text" || true)
  return 0
}

# pack_icons <note command>: after pack_check, fills PACK_GOOD with the good icon files of the flat icons folder (a link's own name, under
# the real icons folder: the name is the app the file is for) and runs <note command> "<why>" for every file it skips.
pack_icons() {
  local note=$1 path file real size
  PACK_GOOD=()
  while IFS= read -r -d '' path; do
    file=${path##*/}
    if ! [[ $file =~ ^${PACK_ICON_NAME}$ ]]; then
      "$note" "skipped icons/$(pack_shown "$file"): use letters, digits and . _ + - in the name, ending in .png or .svg"
      continue
    fi
    if ! real=$(realpath -e -- "$path" 2>/dev/null) || ! pack_inside "$real"; then
      "$note" "skipped icons/$file: a link that leads outside the pack, or nowhere"
      continue
    fi
    if [[ ! -f $real ]]; then "$note" "skipped icons/$file: not a file"; continue; fi
    size=$(stat -c %s -- "$real")
    if [[ $file == *.svg ]]; then
      if (( size > PACK_MAX_SVG )); then "$note" "skipped icons/$file: larger than $((PACK_MAX_SVG / 1024)) KB"; continue; fi
      if ! pack_svg_ok "$real"; then "$note" "skipped icons/$file: not a plain SVG (scripts, external links and DOCTYPE are not allowed)"; continue; fi
    else
      if (( size > PACK_MAX_PNG )); then "$note" "skipped icons/$file: larger than $((PACK_MAX_PNG / 1024 / 1024)) MB"; continue; fi
      if ! pack_png_ok "$real"; then "$note" "skipped icons/$file: not a PNG, or larger than ${PACK_MAX_SIDE}x${PACK_MAX_SIDE}"; continue; fi
    fi
    if (( ${#PACK_GOOD[@]} >= PACK_MAX_ICONS )); then "$note" "only the first $PACK_MAX_ICONS icons are used"; break; fi
    PACK_GOOD+=("$PACK_ICONS/$file")
  done < <(find "$PACK_ICONS" -mindepth 1 -maxdepth 1 -print0 | sort -z)
}

# pack_check_strict <folder>: pack_check plus pack_icons where any skipped file refuses the pack (export and import: a shared pack has no
# junk in it). Sets PACK_ERR to every reason, one per line.
pack_check_strict() {
  local -a bad=()
  pack_check "$1" || return 1
  _pack_strict_note() { bad+=("$1"); }
  pack_icons _pack_strict_note
  (( ${#bad[@]} == 0 )) || { pack_fail "$(printf '%s\n' "${bad[@]}")"; return; }
}

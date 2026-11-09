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
declare -gA PACK_FLAGS=()   # the bare true/false keys of pack.toml (for example follows_theme)
# Built-in generators a pack may name with generator = "<name>" (with follows_theme = true). Only these run, never anything from the pack.
PACK_GENERATORS=(refpack)
PACK_THEMED=""   # pack_themed: the folder it made
PACK_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

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
  PACK_META=() PACK_FLAGS=()
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
    elif [[ $line =~ ^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*(-?[0-9]+|true|false)[[:space:]]*(#.*)?$ ]]; then
      PACK_FLAGS[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}  # a number or a switch: only follows_theme is used, the rest is room for later versions
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

# pack_generator_ok <name>: is it one of the built-in generators.
pack_generator_ok() { local g; for g in "${PACK_GENERATORS[@]}"; do [[ $g == "$1" ]] && return 0; done; return 1; }

# pack_themed <pack name> <generator>: for a pack with follows_theme = true. Makes the pack's icons from the running Omarchy theme palette with the
# built-in generator of that name, in a private folder $XDG_CACHE_HOME/omahop/themed-packs/<name>/<stamp>/ (mode 700; the stamp is a hash of the
# palette and the generator, so a new palette is a new path and no picture cache keeps the old file), and sets PACK_THEMED to that folder. Nothing is redone
# when the stamp folder exists. Returns 1 with PACK_ERR set when there is no palette, the generator is not on the list, or it fails.
pack_themed() {
  local name=$1 gen=$2 colors stamp cache dir tmp old
  pack_generator_ok "$gen" || { pack_fail "generator \"$gen\" is not a built-in one (${PACK_GENERATORS[*]})"; return; }
  colors=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme/colors.toml
  [[ -f $colors ]] || { pack_fail "no theme palette at $colors"; return; }
  stamp=$(cat -- "$colors" "$PACK_LIB_DIR/refpack/gen.py" "$PACK_LIB_DIR/refpack/apps.tsv" | sha256sum) || { pack_fail "cannot hash the palette"; return; }
  stamp=${stamp:0:12}
  cache=${XDG_CACHE_HOME:-$HOME/.cache}/omahop/themed-packs/$name
  dir=$cache/$stamp
  if [[ ! -d $dir/icons ]]; then
    [[ -L ${cache%/*} || -L $cache ]] && { pack_fail "the themed cache folder is a link"; return; }
    (umask 077; mkdir -p -- "$cache") && chmod 700 -- "${cache%/*/*}" "${cache%/*}" "$cache" || { pack_fail "cannot make $cache"; return; }
    tmp=$(mktemp -d -- "$cache/.new.XXXXXX") || { pack_fail "cannot make a folder in $cache"; return; }
    case $gen in
      refpack) python3 -I "$PACK_LIB_DIR/refpack/gen.py" --colors "$colors" --out "$tmp" >/dev/null 2>&1 ;;
    esac || { rm -rf -- "$tmp"; pack_fail "generator $gen failed on $colors"; return; }
    rm -rf -- "$dir"
    mv -- "$tmp" "$dir" || { rm -rf -- "$tmp"; pack_fail "cannot move the generated icons into place"; return; }
    for old in "$cache"/*; do [[ $old == "$dir" ]] || rm -rf -- "$old"; done
  fi
  PACK_THEMED=$dir
}

# pack_check_strict <folder>: pack_check plus pack_icons where any skipped file refuses the pack (export and import: a shared pack has no
# junk in it). Sets PACK_ERR to every reason, one per line. A pack with follows_theme = true must name a built-in generator.
pack_check_strict() {
  local -a bad=()
  pack_check "$1" || return 1
  if [[ ${PACK_FLAGS[follows_theme]:-} == true ]]; then
    pack_generator_ok "${PACK_META[generator]:-}" || { pack_fail "follows_theme = true needs generator = \"<built-in name>\" (${PACK_GENERATORS[*]})"; return; }
  fi
  _pack_strict_note() { bad+=("$1"); }
  pack_icons _pack_strict_note
  (( ${#bad[@]} == 0 )) || { pack_fail "$(printf '%s\n' "${bad[@]}")"; return; }
}

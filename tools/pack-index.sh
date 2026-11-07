#!/usr/bin/env bash
# Prints the icon files of one hand-made icon pack (the icon_pack setting), one path per line, for Service.qml.
# Usage: pack-index.sh <pack name>. A pack is ${XDG_CONFIG_HOME:-~/.config}/omahop/packs/<name>/ holding pack.toml and a flat icons/ folder
# (format: docs/icon-packs.md). Packs come from other people, so everything is checked and nothing in a pack is ever run or sourced:
# the name, pack.toml (a bad one refuses the whole pack), and each icon (name, type, size, links that leave the pack, content).
# Why a file or a pack was refused goes to stderr, which lands in the shell log. An empty name prints nothing (no pack chosen).
set -euo pipefail

max_png=$((2 * 1024 * 1024))
max_svg=$((256 * 1024))
max_side=4096
max_icons=2000
max_toml=$((16 * 1024))

name=${1:-}
[[ -n $name ]] || exit 0
if ! [[ $name =~ ^[A-Za-z0-9._-]+$ && $name != "." && $name != ".." ]]; then
  echo "omahop icon pack: icon_pack ignored, a pack name has only letters, digits, dot, dash and underscore" >&2
  exit 0
fi
note() { printf 'omahop icon pack %s: %s\n' "$name" "$1" >&2; }
# shown() <text>: a file name made safe to print (it may hold control characters)
shown() { printf '%q' "$1"; }

dir=${XDG_CONFIG_HOME:-$HOME/.config}/omahop/packs/$name
if [[ ! -d $dir ]]; then note "no pack folder at $dir, using system icons"; exit 0; fi
# The pack folder itself may be a link (a git clone kept elsewhere); everything inside must stay inside its real folder.
root=$(realpath -e -- "$dir")
inside() { [[ $1 == "$root"/* ]]; }

refuse() { note "pack not used: $1"; exit 0; }

# ---- pack.toml: the flat TOML subset of config.toml. Required text keys: name, author, license. Optional: description.
toml=$root/pack.toml
[[ -e $toml ]] || refuse "pack.toml is missing"
toml=$(realpath -e -- "$toml")
inside "$toml" && [[ -f $toml ]] || refuse "pack.toml is not a file inside the pack"
(( $(stat -c %s -- "$toml") <= max_toml )) || refuse "pack.toml is larger than $max_toml bytes"
declare -A meta=()
n=0
while IFS= read -r line || [[ -n $line ]]; do
  n=$((n + 1))
  line=${line%$'\r'}
  [[ $line =~ ^[[:space:]]*(#.*)?$ ]] && continue
  if [[ $line =~ ^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*\"([^\"]*)\"[[:space:]]*(#.*)?$ ]]; then
    meta[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
  elif [[ $line =~ ^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*=[[:space:]]*(-?[0-9]+|true|false)[[:space:]]*(#.*)?$ ]]; then
    : # a number or a switch (for example a later schema = 1): allowed, not used yet
  else
    refuse "pack.toml line $n is not  key = \"text\""
  fi
done < "$toml"
for key in name author license; do
  [[ -n ${meta[$key]:-} ]] || refuse "pack.toml needs $key = \"...\""
done
for key in "${!meta[@]}"; do
  (( ${#meta[$key]} <= 500 )) || refuse "pack.toml $key is longer than 500 characters"
done

# ---- icons/: flat, one file per app, named after the app id or window class.
[[ -e $root/icons ]] || refuse "the icons folder is missing"
icons=$(realpath -e -- "$root/icons")
inside "$icons" && [[ -d $icons ]] || refuse "icons is not a folder inside the pack"

# png_ok <file>: the PNG signature, IHDR first, and a picture no bigger than max_side on each side (a small file can decode to a huge one).
png_ok() {
  local head sides w h
  head=$(od -An -tx1 -N16 -- "$1" | tr -d ' \n')
  [[ $head == 89504e470d0a1a0a????????49484452 ]] || return 1
  sides=$(od -An -tu4 --endian=big -j16 -N8 -- "$1")
  read -r w h <<< "$sides"
  (( w > 0 && h > 0 && w <= max_side && h <= max_side ))
}

# svg_ok <file>: an <svg> document that can load nothing outside itself: no scripts or foreign content, no event handlers,
# no DOCTYPE or entities, and every href or url() is an in-document #fragment or embedded image data. Read as one line, so a tag split
# over lines is still seen.
svg_ok() {
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

count=0
while IFS= read -r -d '' path; do
  file=${path##*/}
  if ! [[ $file =~ ^[A-Za-z0-9][A-Za-z0-9._+-]{0,199}\.(png|svg)$ ]]; then
    note "skipped icons/$(shown "$file"): use letters, digits and . _ + - in the name, ending in .png or .svg"
    continue
  fi
  if ! real=$(realpath -e -- "$path" 2>/dev/null) || ! inside "$real"; then
    note "skipped icons/$file: a link that leads outside the pack, or nowhere"
    continue
  fi
  if [[ ! -f $real ]]; then note "skipped icons/$file: not a file"; continue; fi
  size=$(stat -c %s -- "$real")
  if [[ $file == *.svg ]]; then
    if (( size > max_svg )); then note "skipped icons/$file: larger than $((max_svg / 1024)) KB"; continue; fi
    if ! svg_ok "$real"; then note "skipped icons/$file: not a plain SVG (scripts, external links and DOCTYPE are not allowed)"; continue; fi
  else
    if (( size > max_png )); then note "skipped icons/$file: larger than $((max_png / 1024 / 1024)) MB"; continue; fi
    if ! png_ok "$real"; then note "skipped icons/$file: not a PNG, or larger than ${max_side}x${max_side}"; continue; fi
  fi
  if (( count >= max_icons )); then note "only the first $max_icons icons are used"; break; fi
  count=$((count + 1))
  # The link's own name is printed (it is the app the file is for), under the real icons folder.
  printf '%s\n' "$icons/$file"
done < <(find "$icons" -mindepth 1 -maxdepth 1 -print0 | sort -z)

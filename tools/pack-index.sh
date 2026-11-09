#!/usr/bin/env bash
# Prints the icon files of one hand-made icon pack (the icon_pack setting), one path per line, for Service.qml.
# Usage: pack-index.sh <pack name>. A pack is ${XDG_CONFIG_HOME:-~/.config}/omahop/packs/<name>/ holding pack.toml and a flat icons/ folder
# (format: docs/icon-packs.md). Packs come from other people, so everything is checked (rules in pack-lib.sh, shared with export and import)
# and nothing in a pack is ever run or sourced. Here a bad icon is skipped and the rest of the pack is used; a bad pack.toml refuses the pack.
# A pack with follows_theme = true and a built-in generator name (pack-lib.sh) is regenerated from the running Omarchy theme and that copy is listed.
# Why a file or a pack was refused goes to stderr, which lands in the shell log. An empty name prints nothing (no pack chosen).
set -euo pipefail
# shellcheck source=tools/pack-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/pack-lib.sh"

name=${1:-}
[[ -n $name ]] || exit 0
if ! pack_name_ok "$name"; then
  echo "omahop icon pack: icon_pack ignored, a pack name has only letters, digits, dot, dash and underscore" >&2
  exit 0
fi
note() { printf 'omahop icon pack %s: %s\n' "$name" "$1" >&2; }

dir=$(pack_dir "$name")
if [[ ! -d $dir ]]; then note "no pack folder at $dir, using system icons"; exit 0; fi
if ! pack_check "$dir"; then note "pack not used: $PACK_ERR"; exit 0; fi
if [[ ${PACK_FLAGS[follows_theme]:-} == true ]]; then
  # The icons are made again from the running theme by a built-in generator; on any trouble the pack's own icons stay in use.
  if pack_themed "$name" "${PACK_META[generator]:-}" && pack_check "$PACK_THEMED"; then :
  else note "follows_theme: $PACK_ERR, using the committed icons"; pack_check "$dir" || { note "pack not used: $PACK_ERR"; exit 0; }; fi
fi
pack_icons note
(( ${#PACK_GOOD[@]} == 0 )) || printf '%s\n' "${PACK_GOOD[@]}"

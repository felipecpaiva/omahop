#!/usr/bin/env bash
# The reference pack generator (tools/refpack): regenerates into a temp folder with a fixed palette and checks the pack with the strict rules
# of pack-export (pack-lib.sh), unique stems, size limits, and that nothing private got in. Also checks the committed pack lists the same stems.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL refpack: $1" >&2; exit 1; }
cat > "$tmp/colors.toml" <<'T'
accent = "#7aa2f7"
background = "#1a1b26"
foreground = "#c0caf5"
muted = "#565f89"
red = "#f7768e"
yellow = "#e0af68"
green = "#9ece6a"
cyan = "#7dcfff"
blue = "#7aa2f7"
magenta = "#bb9af7"
T
bash "$here/tools/refpack/gen.sh" --colors "$tmp/colors.toml" --out "$tmp/pack" > "$tmp/log"
# shellcheck source=tools/pack-lib.sh
source "$here/tools/pack-lib.sh"
pack_check_strict "$tmp/pack" || fail "strict check refused the pack: $PACK_ERR"
n=$(find "$tmp/pack/icons" -name '*.svg' | wc -l)
want=$(grep -vc -E '^(#|$)' "$here/tools/refpack/apps.tsv")
(( n == want && n >= 100 && n <= PACK_MAX_ICONS )) || fail "icon count $n, apps.tsv has $want"
[[ $(find "$tmp/pack/icons" -type f -size +16k | wc -l) == 0 ]] || fail "an icon is larger than 16 KB (limit is 256 KB)"
dups=$(ls "$tmp/pack/icons" | sed 's/\.svg$//' | tr 'A-Z' 'a-z' | sort | uniq -d)
[[ -z $dups ]] || fail "duplicate stems: $dups"
grep -q 'fill="#ffc83d"' "$tmp/pack/icons/omahop.svg" || fail "omahop.svg is not the real brand logo"
grep -q 'fill="#7aa2f7"' "$tmp/pack/icons/firefox.svg" || fail "tile colour does not come from the given palette"
if grep -rlE '/home/|192\.168\.|@[a-z]+\.[a-z]{2,}|https?://[^"]*' --exclude=LICENSE "$tmp/pack" | grep -v 'icons/' | grep -q .; then fail "private-looking text in pack files"; fi
grep -rlE '/home/|192\.168\.' "$tmp/pack/icons" | grep -q . && fail "home path or LAN address in an icon"
# the committed pack must have exactly the stems of apps.tsv (regenerate with tools/refpack/gen.sh after editing it)
diff <(ls "$tmp/pack/icons") <(ls "$here/packs/omahop-reference/icons") >/dev/null || fail "packs/omahop-reference is out of date, run tools/refpack/gen.sh"
pack_check_strict "$here/packs/omahop-reference" || fail "committed pack refused: $PACK_ERR"
echo "refpack ok ($n icons)"

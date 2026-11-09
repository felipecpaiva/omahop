#!/usr/bin/env bash
# follows_theme packs (docs/icon-packs.md): the built-in generator list, the strict check of the two keys, pack-index.sh regenerating from the running
# theme into a private cache (temp HOME only), fallbacks, and the tile colour rules of tools/refpack/gen.py on every installed Omarchy theme.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL refpack_theme: $1" >&2; exit 1; }
# shellcheck source=tools/pack-lib.sh
source "$here/tools/pack-lib.sh"

for g in refpack; do pack_generator_ok "$g" || fail "$g must be allowed"; done
for g in "" evil ../refpack "refpack " gen.py; do ! pack_generator_ok "$g" || fail "generator '$g' must be refused"; done

export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_STATE_HOME=$tmp/state XDG_CACHE_HOME=$tmp/cache
packs=$tmp/config/omahop/packs
mkpack() { # <folder> <extra toml lines>
  mkdir -p "$packs/$1/icons"; cp "$here/docs/examples/packs/omahop-sample/icons/firefox.svg" "$packs/$1/icons/"
  printf 'name = "t"\nauthor = "a"\nlicense = "CC0-1.0"\n%b' "$2" > "$packs/$1/pack.toml"
}
setpalette() { mkdir -p "$tmp/state/omarchy/current/theme"; cp "/usr/share/omarchy/themes/$1/colors.toml" "$tmp/state/omarchy/current/theme/colors.toml"; }
index() { bash "$here/tools/pack-index.sh" "$1" 2> "$tmp/err"; }

mkpack ok 'follows_theme = true\ngenerator = "refpack"\n'
mkpack nogen 'follows_theme = true\n'
mkpack evil 'follows_theme = true\ngenerator = "../../x"\n'
mkpack plain 'follows_theme = false\n'
pack_check_strict "$packs/ok" || fail "strict check refused a good follows_theme pack: $PACK_ERR"
pack_check_strict "$packs/plain" || fail "follows_theme = false refused: $PACK_ERR"
! pack_check_strict "$packs/nogen" || fail "follows_theme without generator must be refused (strict)"
! pack_check_strict "$packs/evil" || fail "unknown generator must be refused (strict)"

# no palette: the committed icons, with a note
[[ $(index ok) == "$(realpath "$packs/ok/icons")/firefox.svg" ]] || fail "no palette must list the committed icons"
grep -q "committed icons" "$tmp/err" || fail "no palette must leave a note"
# a palette: the generated copy, private
setpalette tokyo-night
out=$(index ok); n=$(wc -l <<< "$out")
(( n >= 100 )) && [[ $out == "$tmp/cache/omahop/themed-packs/ok/"* ]] || fail "themed pack lists the generated icons ($n)"
[[ ! -s $tmp/err ]] || fail "a good themed pack logs nothing: $(cat "$tmp/err")"
for d in "$tmp/cache/omahop" "$tmp/cache/omahop/themed-packs" "$tmp/cache/omahop/themed-packs/ok"; do [[ $(stat -c %a "$d") == 700 ]] || fail "$d must be mode 700"; done
f=$(grep '/firefox.svg$' <<< "$out"); grep -q 'fill="#7aa2f7"' "$f" || fail "tokyo-night browser tile must be its blue"
# same palette: same folder, not regenerated
touch -d @978307200 "$f"; f1=$(index ok | grep "/firefox.svg$"); [[ $f1 == "$f" ]] || fail "same palette lists another folder: $f1 vs $f"; [[ $(stat -c %Y "$f") == 978307200 ]] || fail "unchanged palette must not regenerate"
# another palette: a new folder (so no picture cache keeps the old file), the old one removed
setpalette gruvbox
f2=$(index ok | grep '/firefox.svg$')
[[ $f2 != "$f" && ! -e $f && -f $f2 ]] || fail "a new palette must list a new folder and drop the old"
! grep -q 'fill="#7aa2f7"' "$f2" || fail "the icons must follow the new palette"
# bad generator and a script planted in the pack: committed icons, nothing run
mkdir -p "$packs/evil"; printf 'touch %s/ran\n' "$tmp" > "$packs/evil/gen.sh"; cp "$packs/evil/gen.sh" "$packs/evil/gen.py"
[[ $(index evil) == "$(realpath "$packs/evil/icons")/firefox.svg" && -s $tmp/err && ! -e $tmp/ran ]] || fail "unknown generator must fall back and run nothing"
# no follows_theme: untouched
[[ $(index plain) == "$(realpath "$packs/plain/icons")/firefox.svg" ]] || fail "plain pack must list its own icons"

# tile colours on every installed theme: 11 distinct tiles, glyph contrast of 4.5 or more
python3 -I - "$here" <<'PY'
import sys, glob
sys.path.insert(0, sys.argv[1] + "/tools/refpack")
import gen
fs = glob.glob("/usr/share/omarchy/themes/*/colors.toml") + [sys.argv[1] + "/tests/fixtures/none"]
for f in fs[:-1]:
    pal = gen.read_palette(f); v = list(gen.tile_colors(pal).values())
    assert len(v) == len(gen.ACCENT) and min(gen.dist(a, b) for i, a in enumerate(v) for b in v[i + 1:]) >= 12, f + ": tiles too alike"
    assert min(gen.contrast(c, gen.ink_for(c, pal)) for c in v) >= 4.5, f + ": glyph contrast under 4.5"
print(len(fs) - 1, "themes ok")
PY
echo "refpack_theme ok"

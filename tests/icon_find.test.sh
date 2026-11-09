#!/usr/bin/env bash
# tools/icon-find.sh against fake themes in a temporary XDG_DATA_DIRS: every theme's match is kept (not the first), scalable first then the biggest PNG, exact names
# before partial ones, a theme's own files only, hidden and cursor themes left out, oversize files left out, bounded output, hostile queries print nothing, and the answer is cached
# in a private folder.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
icons=$tmp/share/icons
mk() { mkdir -p "$icons/$1/$2/apps"; : > "$icons/$1/$2/apps/$3"; }
mk alpha 48x48 firefox.png; mk alpha 128x128 firefox.png; mk alpha scalable firefox.svg; mk alpha scalable firefox-nightly.svg; mk alpha 48x48 fire.png
mk beta 32x32 firefox.png; mk beta 256x256 firefox.png
printf '[Icon Theme]\nName=Beta Theme\nInherits=alpha\n' > "$icons/beta/index.theme"
mk secret 48x48 firefox.png; printf '[Icon Theme]\nName=Secret\nHidden=true\n' > "$icons/secret/index.theme"
mk hicolor 48x48 firefox.png
mkdir -p "$icons/alpha/48x48/places"; : > "$icons/alpha/48x48/places/firefox-folder.png"
head -c 300000 /dev/zero > "$icons/alpha/scalable/apps/firefox-huge.svg"
mk gamma 64x64 FireFox.png
export HOME=$tmp/home XDG_DATA_DIRS=$tmp/share XDG_CACHE_HOME=$tmp/cache
find_() { bash "$here/tools/icon-find.sh" "$@"; }
fail() { echo "FAIL icon_find: $1" >&2; exit 1; }
tab=$'\t'

out=$(find_ firefox)
want="alpha${tab}firefox${tab}$icons/alpha/scalable/apps/firefox.svg
beta${tab}firefox${tab}$icons/beta/256x256/apps/firefox.png
gamma${tab}FireFox${tab}$icons/gamma/64x64/apps/FireFox.png
alpha${tab}firefox-nightly${tab}$icons/alpha/scalable/apps/firefox-nightly.svg"
[[ $out == "$want" ]] || fail "results:
$out"
[[ $(find_ FIREFOX | wc -l) == 4 ]] || fail "the query is case blind"
[[ $(find_ fire | head -1) == "alpha${tab}fire${tab}$icons/alpha/48x48/apps/fire.png" ]] || fail "an exact name comes first: $(find_ fire | head -1)"
[[ $(find_ fire | wc -l) == 5 ]] || fail "a partial name matches too: $(find_ fire | wc -l)"
[[ $(find_ firefox 2 | wc -l) == 2 ]] || fail "the limit bounds the output"
(( $(find_ firefox 99999 | wc -l) <= 400 )) || fail "the limit is capped"
[[ -z $(find_ secret) && -z $(find_ folder) ]] || fail "hidden themes and non-app icons are not searched"
[[ $(find_ firefox | grep -c hicolor) == 0 ]] || fail "hicolor is not a choice"
[[ $(find_ firefox | grep -c huge) == 0 ]] || fail "an oversize svg is left out"
for bad in "" "a" "../x" "a b" 'x;touch y' '$(id)' 'a*' "$(printf 'a%.0s' {1..65})"; do [[ -z $(find_ "$bad") ]] || fail "bad query '$bad' prints nothing"; done
[[ ! -e y ]] || fail "a query reached a shell"

# the second run answers from the cache even when the themes are gone
[[ $(stat -c %a "$XDG_CACHE_HOME/omahop" "$XDG_CACHE_HOME/omahop/icon-find") == $'700\n700' ]] || fail "the cache folder is private"
first=$(find_ firefox)
mv "$icons" "$tmp/gone"
[[ $(find_ firefox) == "$first" ]] || fail "cached"
mv "$tmp/gone" "$icons"
find "$XDG_CACHE_HOME/omahop/icon-find" -type f -exec touch -d '1 hour ago' {} +
[[ $(find_ firefox) == "$first" ]] || fail "an old cache is searched again, same answer"
echo "ok   icon find: every theme's match, ranked, bounded, cached privately, hostile queries ignored"

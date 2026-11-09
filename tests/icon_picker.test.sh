#!/usr/bin/env bash
# tools/icon-themes.sh and tools/icon-preview.sh against fake themes in a temporary XDG_DATA_DIRS.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
icons=$tmp/share/icons
mk() { mkdir -p "$icons/$1/48x48/apps"; : > "$icons/$1/48x48/apps/$2"; }
mk zeta a.png; printf '[Icon Theme]\nName=Alpha Pretty\n' > "$icons/zeta/index.theme"
mk beta a.png; mk beta b.svg; mkdir -p "$icons/beta/scalable/apps"; : > "$icons/beta/scalable/apps/a.svg"
mk child c.png; printf '[Icon Theme]\nName=Child\nInherits=beta\n' > "$icons/child/index.theme"
mk hicolor a.png; mk default a.png
mk secret a.png; printf '[Icon Theme]\nName=Secret\nHidden=true\n' > "$icons/secret/index.theme"
mkdir -p "$icons/cursory/cursors"; : > "$icons/cursory/cursors/left_ptr"; printf '[Icon Theme]\nName=Cursory\n' > "$icons/cursory/index.theme"
mkdir -p "$icons/empty"
mk "bad;name" a.png

run() { HOME=$tmp/home XDG_DATA_DIRS=$tmp/share bash "$here/tools/$1" "${@:2}"; }
fail() { echo "FAIL icon_picker: $1" >&2; exit 1; }

themes=$(run icon-themes.sh)
[[ $themes == "$(printf 'zeta\tAlpha Pretty\nbeta\tbeta\nchild\tChild')" ]] || fail "theme list (sorted by display name, no hicolor, default, hidden, cursor, empty or bad names): $themes"

[[ $(run icon-preview.sh beta a b) == "$(printf 'a\t%s/beta/scalable/apps/a.svg\nb\t%s/beta/48x48/apps/b.svg' "$icons" "$icons")" ]] || fail "svg first, one line per id"
[[ $(run icon-preview.sh child a c nope) == "$(printf 'a\t%s/beta/scalable/apps/a.svg\nc\t%s/child/48x48/apps/c.png' "$icons" "$icons")" ]] || fail "parent theme fills in, a miss prints nothing"
[[ $(run icon-preview.sh zeta a) == "$(printf 'a\t%s/zeta/48x48/apps/a.png' "$icons")" ]] || fail "own theme wins"
[[ -n $(run icon-preview.sh - c) ]] || fail "dash searches every theme"
for bad in '../beta' 'a b' 'x;touch y'; do [[ $(run icon-preview.sh "$bad" c) == *child* ]] || fail "bad theme '$bad' acts like dash"; done
[[ -z $(run icon-preview.sh beta '../a' 'a;touch y' '$(id)') ]] || fail "bad ids print nothing"
[[ ! -e y ]] || fail "a name reached a shell"
echo "ok   icon picker scripts: theme list rules, preview order, bad names ignored"

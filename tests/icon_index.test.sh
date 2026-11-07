#!/usr/bin/env bash
# tools/icon-index.sh against fake icon themes in a temporary XDG_DATA_DIRS: theme first, parents next, the rest as fallback, bad names ignored.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
icons=$tmp/share/icons
mk() { mkdir -p "$icons/$1/apps/48"; : > "$icons/$1/apps/48/$2"; }
mk child child-only.png; mk child shared.png
mk parent parent-only.png; mk parent shared.png; mk parent loop.png
mk other other-only.png; mk other shared.png; mk other child-only.png
mk "zzz;bad" evil.png
printf '[Icon Theme]\nName=child\nInherits=parent, ghost, bad/name\n' > "$icons/child/index.theme"
printf '[Icon Theme]\nName=parent\nInherits=child\n' > "$icons/parent/index.theme" # a loop back to the child

run() { HOME=$tmp/home XDG_DATA_DIRS=$tmp/share bash "$here/tools/icon-index.sh" "$@"; }
fail() { echo "FAIL icon_index: $1" >&2; exit 1; }
pos() { grep -n -- "$1" <<< "$2" | head -1 | cut -d: -f1; }

plain=$(run)
for n in child-only parent-only other-only shared loop evil; do grep -q "/$n\.png$" <<< "$plain" || fail "no-theme output lacks $n"; done
[[ $(grep -c '/shared\.png$' <<< "$plain") -eq 1 ]] || fail "one path per icon name"

themed=$(run child)
grep -q "/child/apps/48/shared.png$" <<< "$themed" || fail "the theme's own icon wins over other themes"
grep -q "/child/apps/48/child-only.png$" <<< "$themed" || fail "theme icon beats the same name in an unrelated theme"
grep -q "/parent/apps/48/loop.png$" <<< "$themed" || fail "inherited theme is read"
grep -q "/other/apps/48/other-only.png$" <<< "$themed" || fail "an icon the theme lacks still comes from the fallback"
[[ $(pos parent-only "$themed") -lt $(pos other-only "$themed") ]] || fail "parent theme before unrelated theme"
[[ $(wc -l <<< "$themed") -eq $(wc -l <<< "$plain") ]] || fail "same set of names with and without a theme"

for bad in "" "../child" "child/../other" 'a b' 'child;touch x' '$(id)' ".." "nosuchtheme"; do
  [[ $(run "$bad") == "$plain" ]] || fail "theme '$bad' must act like no theme"
done
[[ ! -e x ]] || fail "a theme name reached a shell"
echo "ok   icon index: theme first, parents next, fallback, bad names ignored"

#!/usr/bin/env bash
# tools/icon-overlay.sh in a temporary HOME (never the real one): links, name and target checks, refusal without the marker, safe off.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME=$tmp/home
unset XDG_DATA_HOME
mkdir -p "$HOME" "$tmp/src"
dir=$HOME/.local/share/icons/omahop-launcher
fail() { echo "FAIL icon_overlay: $1" >&2; exit 1; }
ov() { bash "$here/tools/icon-overlay.sh" "$@" 2>"$tmp/err"; }
svg() { printf '<svg xmlns="http://www.w3.org/2000/svg"/>' > "$tmp/src/$1"; }
svg a.svg; svg b.svg; : > "$tmp/src/c.png"

# on: valid pairs become symlinks named by the Icon= value; bad names, a PNG, a missing file, a relative path and a duplicate are skipped
ov on kitty "$tmp/src/a.svg" org.gnome.Foo "$tmp/src/b.svg" ../evil "$tmp/src/a.svg" "a/b" "$tmp/src/a.svg" .hidden "$tmp/src/a.svg" \
  pngapp "$tmp/src/c.png" gone "$tmp/src/none.svg" rel "src/a.svg" kitty "$tmp/src/b.svg" || fail "on failed"
[[ -f $dir/.omahop ]] || fail "marker missing"
[[ $(readlink "$dir/apps/kitty.svg") == "$tmp/src/a.svg" ]] || fail "kitty link wrong (the first pair wins a duplicate)"
[[ $(readlink "$dir/apps/org.gnome.Foo.svg") == "$tmp/src/b.svg" ]] || fail "dotted name link wrong"
[[ $(find "$dir/apps" -mindepth 1 | wc -l) -eq 2 ]] || fail "only the two good pairs are linked"
[[ ! -e $HOME/.local/share/icons/evil.svg && ! -e $dir/evil.svg && ! -e $dir/.hidden.svg ]] || fail "a bad name escaped"
[[ $(grep -c skipped "$tmp/err") -eq 6 ]] || fail "each skipped pair gets a note: $(cat "$tmp/err")"

# refresh replaces the set, and a user file beside apps/ is kept (the marker proves the folder is ours)
ov refresh kitty "$tmp/src/b.svg" || fail "refresh failed"
[[ $(readlink "$dir/apps/kitty.svg") == "$tmp/src/b.svg" && ! -e $dir/apps/org.gnome.Foo.svg && ! -e $dir/apps.new ]] || fail "refresh did not replace the set"
# a target inside the overlay itself is refused (a loop)
ov refresh loop "$dir/apps/kitty.svg" || fail "refresh with a loop failed"
[[ -z $(ls "$dir/apps") ]] || fail "a link to the overlay itself was made"

# off: removes the folder only
mkdir -p "$HOME/.local/share/icons/other"
ov off || fail "off failed"
[[ ! -e $dir && -d $HOME/.local/share/icons/other ]] || fail "off must remove only omahop-launcher"
ov off || fail "off twice must be fine"
[[ ! -e $HOME/.local/share/icons/other/../omahop-launcher ]] || fail "off twice recreated it"

# a folder without the marker: on and refresh refuse, off leaves it alone, its files are untouched
mkdir -p "$dir/apps"
: > "$dir/apps/mine.svg"
if ov on kitty "$tmp/src/a.svg"; then fail "on over a foreign folder must fail"; fi
grep -q refused "$tmp/err" || fail "no refusal note"
ov off || fail "off over a foreign folder must not fail"
[[ -f $dir/apps/mine.svg && ! -e $dir/.omahop ]] || fail "a foreign folder was changed"
rm -rf "$dir"

# a symlinked folder, and a symlinked marker, are never followed
mkdir -p "$tmp/victim" "$HOME/.local/share/icons"
: > "$tmp/victim/.omahop"; : > "$tmp/victim/keep"
ln -s "$tmp/victim" "$dir"
if ov on kitty "$tmp/src/a.svg"; then fail "on through a symlinked folder must fail"; fi
ov off || true
[[ -f $tmp/victim/keep && -L $dir ]] || fail "off followed a symlinked folder"
rm -f "$dir"
mkdir -p "$dir"; ln -s "$tmp/victim/.omahop" "$dir/.omahop"
if ov on kitty "$tmp/src/a.svg"; then fail "a symlinked marker must not count"; fi
ov off || true
[[ -f $tmp/victim/keep && -d $dir ]] || fail "off removed a folder whose marker is a link"

# bad mode
if ov frobnicate; then fail "unknown mode must fail"; fi
echo "icon_overlay ok"

#!/usr/bin/env bash
# tools/draft-edit.sh (the icon builder's writer) in a temporary HOME and cache folder, so the real cache is never touched: add, remove, reset-app, undo, list
# and discard work; the draft is private (mode 700) and outside the packs folder; a theme icon (a link) is copied, never linked; hostile app ids, images and file
# names are refused with a reason and change nothing at all; undo is bounded; a draft file passes the strict check export uses; and a mutation check: with the strict
# image check removed from a copy of the script, the script-in-an-SVG case fails.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
draft=$here/tools/draft-edit.sh
sample=$here/docs/examples/packs/omahop-sample/icons
fail() { echo "FAIL draft_edit: $1" >&2; exit 1; }

export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_CACHE_HOME=$tmp/cache
mkdir -p "$HOME" "$tmp/src"
dir=$XDG_CACHE_HOME/omahop/draft
snap() { (cd "$tmp" && find . -path ./src -prune -o -printf '%p %y %s\n' | sort && find . -path ./src -prune -o -type f -print0 | sort -z | xargs -0r sha256sum); }

# refused <words> <args...>: exits 1, says <words>, changes nothing anywhere
refused() {
  local words=$1 before after err=$tmp/src/err
  shift
  before=$(snap)
  if bash "$draft" "$@" > /dev/null 2> "$err"; then fail "accepted: $*"; fi
  grep -qF -- "$words" "$err" || fail "$*: wanted '$words', got: $(cat "$err")"
  after=$(snap)
  [[ $before == "$after" ]] || fail "$* changed files: $(diff <(echo "$before") <(echo "$after") | head -5)"
}

# ---- nothing to list, nothing made by looking
[[ -z $(bash "$draft" list) && ! -e $dir ]] || fail "list without a draft prints nothing and makes nothing"
refused "nothing to undo" undo
refused "the draft is empty" reset-app kitty

# ---- add: a PNG, an SVG, a theme icon that is a link
[[ $(bash "$draft" add "Kit ty" "$sample/kitty.png") == kit-ty.png ]] || fail "add prints the file"
[[ $(stat -c %a "$XDG_CACHE_HOME/omahop" "$dir") == $'700\n700' ]] || fail "the draft folders are private"
[[ ! -e $XDG_CONFIG_HOME/omahop/packs ]] || fail "nothing is made in the packs folder"
ln -s "$sample/firefox.svg" "$tmp/src/theme-icon.svg"
[[ $(bash "$draft" add firefox "$tmp/src/theme-icon.svg") == firefox.svg ]] || fail "a theme icon (a link) is added"
[[ -f $dir/icons/firefox.svg && ! -L $dir/icons/firefox.svg ]] || fail "a theme icon is copied, never linked"
cmp -s "$sample/firefox.svg" "$dir/icons/firefox.svg" || fail "the copy is the same file"
[[ $(bash "$draft" list | cut -f1,2 | tr '\n' ' ') == $'firefox\tfirefox.svg kit-ty\tkit-ty.png ' ]] || fail "list: $(bash "$draft" list)"
[[ $(bash "$draft" list | head -1 | cut -f3) == "$dir/icons/firefox.svg" ]] || fail "list prints full paths"
cp "$sample/kitty.png" "$tmp/src/no-extension"
[[ $(bash "$draft" add FIREFOX "$tmp/src/no-extension") == firefox.png ]] || fail "the type comes from the bytes, and replaces the other extension"
[[ $(ls "$dir/icons" | tr '\n' ' ') == "firefox.png kit-ty.png " ]] || fail "one file per app: $(ls "$dir/icons")"
# a draft is pack-shaped: it passes what export and import hold a pack to
cp -r "$dir" "$tmp/src/asapack"
rm -rf "$tmp/src/asapack/undo" "$tmp/src/asapack/history"
bash -c 'source "$1"; pack_check_strict "$2"' _ "$here/tools/pack-lib.sh" "$tmp/src/asapack" || fail "a draft passes pack_check_strict"

# ---- undo: replace, remove, reset, in reverse
bash "$draft" undo > /dev/null
[[ $(ls "$dir/icons" | tr '\n' ' ') == "firefox.svg kit-ty.png " ]] || fail "undo of a replace brings the old file back: $(ls "$dir/icons")"
cmp -s "$sample/firefox.svg" "$dir/icons/firefox.svg" || fail "the old file is the same bytes"
[[ $(bash "$draft" remove kit-ty.png) == "Removed kit-ty.png" ]] || fail "remove"
[[ $(bash "$draft" reset-app "FireFox") == "Removed firefox.svg" ]] || fail "reset-app finds the icon by the app id"
refused "has no icon for" reset-app firefox
refused "has no icon for" remove firefox.svg
[[ -z $(bash "$draft" list) ]] || fail "the draft is empty again"
[[ $(bash "$draft" undo) == firefox && $(bash "$draft" undo) == kit-ty ]] || fail "undo restores both, newest first"
[[ $(bash "$draft" list | cut -f2 | tr '\n' ' ') == "firefox.svg kit-ty.png " ]] || fail "both back"
bash "$draft" undo > /dev/null; bash "$draft" undo > /dev/null
[[ -z $(bash "$draft" list) ]] || fail "undoing the adds empties the draft"
refused "nothing to undo" undo
[[ -z $(ls "$dir/undo") ]] || fail "no saved copies are left behind"

# ---- the history is bounded
for i in $(seq 1 35); do bash "$draft" add "app$i" "$sample/kitty.png" > /dev/null; done
[[ $(wc -l < "$dir/history") == 30 && $(ls "$dir/undo" | wc -l) == 0 ]] || fail "history keeps 30 steps: $(wc -l < "$dir/history")"
for i in $(seq 1 30); do bash "$draft" undo > /dev/null; done
[[ $(bash "$draft" list | wc -l) == 5 ]] || fail "30 undos leave the 5 oldest adds: $(bash "$draft" list | wc -l)"
refused "nothing to undo" undo
printf 'garbage\n' > "$dir/history"
bash "$draft" undo 2> "$tmp/src/err" && fail "a damaged history was accepted"
grep -qF damaged "$tmp/src/err" && [[ ! -e $dir/history ]] || fail "a damaged history is refused and cleared"

# ---- hostile input changes nothing
printf '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>' > "$tmp/src/script.svg"
printf '\xff\xd8\xff\xe0 a jpeg' > "$tmp/src/photo.jpg"
head -c $((3 * 1024 * 1024)) /dev/zero > "$tmp/src/huge.png"
head -c 300000 /dev/zero | tr '\0' ' ' | sed 's/^/<svg xmlns="http:\/\/www.w3.org\/2000\/svg">/' > "$tmp/src/big.svg"
python3 -I -c 'import struct,sys,zlib; sys.stdout.buffer.write(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 60000, 1) + b"\x08\x06\x00\x00\x00" + b"\0" * 4)' > "$tmp/src/wide.png"
ln -s /nowhere "$tmp/src/dangling.png"
mkdir "$tmp/src/dir.png"
refused "not a plain SVG" add kitty "$tmp/src/script.svg"
refused "not a plain SVG" add kitty "$tmp/src/photo.jpg"
refused "larger than 256 KB" add kitty "$tmp/src/big.svg"
refused "larger than 2 MB" add kitty "$tmp/src/huge.png"
refused "not a PNG, or larger than" add kitty "$tmp/src/wide.png"
refused "no file at" add kitty "$tmp/src/dangling.png"
refused "is not a file" add kitty "$tmp/src/dir.png"
refused "full path" add kitty "relative.png"
refused "full path" add kitty "-rf.png"
refused "usage" add kitty
refused "usage" frobnicate
refused "usage" undo extra
for app in "../x" "a/b" "" "-x" ".x" "a:b" "café" '$(touch x)' "$(printf 'a%.0s' {1..201})"; do
  refused "cannot be an icon file name" add "$app" "$sample/kitty.png"
  refused "cannot be an icon file name" reset-app "$app"
done
for file in "../pack.toml" "icons/app1.png" ".hidden.png" "app1" "app1.jpg" '$(x).png'; do refused "not an icon file name" remove "$file"; done
[[ ! -e $tmp/x && -z $(find "$dir" -name '.edit.*') ]] || fail "nothing leaked, no staging folder left"

# ---- a linked draft folder is refused
mv "$dir" "$tmp/real-draft" && ln -s "$tmp/real-draft" "$dir"
refused "is a link" add kitty "$sample/kitty.png"
refused "is a link" list
rm "$dir" && mv "$tmp/real-draft" "$dir"

# ---- discard
bash "$draft" discard > /dev/null
[[ ! -e $dir && -z $(bash "$draft" list) ]] || fail "discard removes the draft"
bash "$draft" discard > /dev/null || fail "discard of nothing is fine"

# ---- mutation: without the strict check, the script SVG would be added
mutant=$tmp/src/mutant.sh
cp "$here/tools/pack-lib.sh" "$tmp/src/pack-lib.sh"
sed 's/  pack_check_strict "\$stage" || die/  true || die/' "$draft" > "$mutant"
cmp -s "$draft" "$mutant" && fail "mutation did not apply"
bash "$mutant" add kitty "$tmp/src/script.svg" > /dev/null 2>&1 || fail "mutant still refuses: the strict check is not what stops it"

echo "ok   draft edit: add, remove, reset-app, undo (bounded), list, discard; private; copies not links; hostile input changes nothing; strict check is load-bearing"

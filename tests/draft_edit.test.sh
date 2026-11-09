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

# ---- save: the draft becomes an installed pack; open-pack loads one back
packs=$XDG_CONFIG_HOME/omahop/packs
mkdraft() { bash "$draft" add kitty "$sample/kitty.png" > /dev/null; bash "$draft" add firefox "$sample/firefox.svg" > /dev/null; }
refused "the draft is empty" save mine Me CC0-1.0
mkdraft
bash "$draft" discard > /dev/null
refused "the draft is empty" save mine Me CC0-1.0
mkdraft
refused "usage" save mine Me
refused "usage" save --based-on
for name in "..." "///" "---"; do refused "needs a letter or digit" save "$name" Me CC0-1.0; done
refused "name must not be empty" save "" Me CC0-1.0
refused "license must not be empty" save mine Me ""
refused "license cannot hold a double quote" save mine Me 'MIT"'
refused "author cannot hold a line break" save mine $'Me\nx' MIT
refused "description is longer than 500" save mine Me MIT "$(printf 'd%.0s' {1..501})"
refused "based_on cannot hold a double quote" save --based-on 'a"b' mine Me MIT
[[ ! -e $packs ]] || fail "a refused save makes no packs folder"
[[ $(bash "$draft" save --based-on Papirus "My Icons!" "Nova" CC-BY-4.0 "Mine, all mine") == my-icons ]] || fail "save prints the folder"
[[ ! -e $dir ]] || fail "a saved draft is discarded"
[[ $(ls -A "$packs") == my-icons && $(ls "$packs/my-icons/icons" | tr '\n' ' ') == "firefox.svg kitty.png " ]] || fail "only icons/ and pack.toml: $(ls -A "$packs/my-icons")"
[[ $(ls -A "$packs/my-icons" | tr '\n' ' ') == "icons pack.toml " ]] || fail "no history or undo in the pack"
grep -qx 'based_on = "Papirus"' "$packs/my-icons/pack.toml" && grep -qx 'name = "My Icons!"' "$packs/my-icons/pack.toml" || fail "pack.toml: $(cat "$packs/my-icons/pack.toml")"
bash -c 'source "$1"; pack_check_strict "$2" && [[ ${PACK_META[based_on]} == Papirus && ${PACK_META[license]} == CC-BY-4.0 ]]' _ "$here/tools/pack-lib.sh" "$packs/my-icons" || fail "based_on passes pack_check_strict"
[[ $(stat -c %a "$packs/my-icons" "$packs/my-icons/pack.toml" "$packs/my-icons/icons/kitty.png") == $'755\n644\n644' ]] || fail "modes of the saved pack"
! grep -rqF -e "$tmp" -e "$HOME" "$packs" || fail "a home or temp path in the saved pack"
[[ -z $(find "$packs" -name '.*' -not -path "$packs") ]] || fail "no staging folder left"

# a name clash is refused and leaves the draft and the pack alone; --replace swaps it
mkdraft
bash "$draft" add zed "$sample/kitty.png" > /dev/null
refused "already exists" save my-icons Me CC0-1.0
refused "already exists" save "My Icons" Me CC0-1.0
[[ $(bash "$draft" save --replace my-icons Me2 MIT) == my-icons ]] || fail "replace"
grep -qx 'author = "Me2"' "$packs/my-icons/pack.toml" && ! grep -q based_on "$packs/my-icons/pack.toml" || fail "replaced pack.toml"
[[ $(ls "$packs/my-icons/icons" | tr '\n' ' ') == "firefox.svg kitty.png zed.png " && -z $(ls -A "$packs" | grep '^\.') ]] || fail "replaced icons: $(ls -A "$packs")"

# atomic: a draft file that fails the strict check (planted by hand) leaves the old pack and the draft untouched
mkdraft
printf '<svg xmlns="http://www.w3.org/2000/svg"><script>x</script></svg>' > "$dir/icons/evil.svg"
refused "not saved, the draft is untouched" save --replace my-icons Me3 MIT
refused "not saved, the draft is untouched" save fresh Me3 MIT
[[ ! -e $packs/fresh && -f $dir/icons/evil.svg && -n $(ls -A "$packs/my-icons/icons") ]] || fail "failed save is atomic"
grep -qx 'author = "Me2"' "$packs/my-icons/pack.toml" || fail "the old pack is unchanged"

# open-pack: a round trip, no history, refuses over changes unless --force
refused "the draft has changes" open-pack my-icons
[[ $(bash "$draft" open-pack --force my-icons) == "Opened my-icons with 3 icons" ]] || fail "open-pack --force"
[[ $(bash "$draft" list | cut -f2 | tr '\n' ' ') == "firefox.svg kitty.png zed.png " && ! -e $dir/history && -z $(ls -A "$dir/undo") ]] || fail "opened draft"
[[ $(stat -c %a "$dir" "$dir/icons/kitty.png") == $'700\n600' ]] || fail "the draft stays private"
refused "no pack folder named" open-pack nope
refused "only letters, digits" open-pack "../x"
refused "usage" open-pack
bash "$draft" save --replace round Me MIT > /dev/null
cmp -s "$packs/round/icons/zed.png" "$sample/kitty.png" && [[ $(ls "$packs/round/icons" | wc -l) == 3 ]] || fail "round trip keeps the icons"
bash "$draft" open-pack round > /dev/null || fail "an empty draft is replaced without --force"
bash "$draft" undo 2> /dev/null && fail "an opened draft has no history"
bash "$draft" discard > /dev/null
# a themed pack: the committed icons are copied, follows_theme and generator are dropped on save
mkdir -p "$packs/themed/icons"
cp "$sample/kitty.png" "$packs/themed/icons/"
printf 'name = "themed"\nauthor = "a"\nlicense = "MIT"\nfollows_theme = true\ngenerator = "refpack"\n' > "$packs/themed/pack.toml"
bash "$draft" open-pack themed > /dev/null
bash "$draft" save themed-copy a MIT > /dev/null
! grep -q "follows_theme\|generator" "$packs/themed-copy/pack.toml" || fail "follows_theme is dropped"
# a pack with a bad icon: the good ones load, the reason is printed
cp "$tmp/src/script.svg" "$packs/themed/icons/evil.svg"
bash "$draft" open-pack themed 2> "$tmp/src/err" > /dev/null
grep -q "skipped icons/evil.svg" "$tmp/src/err" && [[ $(bash "$draft" list | wc -l) == 1 ]] || fail "a bad icon is skipped with a note"
bash "$draft" discard > /dev/null

# ---- mutation: without the strict check, the script SVG would be added
mutant=$tmp/src/mutant.sh
cp "$here/tools/pack-lib.sh" "$tmp/src/pack-lib.sh"
sed 's/  pack_check_strict "\$stage" || die/  true || die/' "$draft" > "$mutant"
cmp -s "$draft" "$mutant" && fail "mutation did not apply"
bash "$mutant" add kitty "$tmp/src/script.svg" > /dev/null 2>&1 || fail "mutant still refuses: the strict check is not what stops it"

echo "ok   draft edit: add, remove, reset-app, undo (bounded), list, discard, save (atomic, replace, based_on), open-pack; private; copies not links; hostile input changes nothing; strict check is load-bearing"

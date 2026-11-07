#!/usr/bin/env bash
# tools/pack-edit.sh (the icon pack editor's writer) in a temporary HOME and XDG folders, so real packs are never touched: init, meta, add,
# remove and list work; hostile pack names, app ids, images and metadata are refused with a reason and change nothing at all; a success
# changes nothing outside packs/<folder>/; the shell stem and PackEditor.js iconStem agree; and a mutation check: with the strict image
# check removed from a copy of the script, the script-in-an-SVG case fails.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
edit=$here/tools/pack-edit.sh
sample=$here/docs/examples/packs/omahop-sample/icons
fail() { echo "FAIL pack_edit: $1" >&2; exit 1; }

export HOME=$tmp/home XDG_CONFIG_HOME=$tmp/config XDG_CACHE_HOME=$tmp/cache
mkdir -p "$HOME" "$tmp/src"
packs=$XDG_CONFIG_HOME/omahop/packs
# snap: every path, type, size and content hash under the temp folder, except the sources the test made
snap() { (cd "$tmp" && find . -path ./src -prune -o -printf '%p %y %s\n' | sort && find . -path ./src -prune -o -type f -print0 | sort -z | xargs -0r sha256sum); }

# refused <words> <args...>: exits 1, says <words>, changes nothing anywhere
refused() {
  local words=$1 before after err=$tmp/src/err
  shift
  before=$(snap)
  if bash "$edit" "$@" > /dev/null 2> "$err"; then fail "accepted: $*"; fi
  grep -qF -- "$words" "$err" || fail "$*: wanted '$words', got: $(cat "$err")"
  after=$(snap)
  [[ $before == "$after" ]] || fail "$* changed files: $(diff <(echo "$before") <(echo "$after") | head -5)"
}

# ---- init and list
[[ -z $(bash "$edit" list) ]] || fail "list without a packs folder prints nothing"
[[ $(bash "$edit" init "My Pack!" "Me" "CC0-1.0" "Mine") == my-pack ]] || fail "init prints the derived folder"
[[ -f $packs/my-pack/pack.toml && -d $packs/my-pack/icons ]] || fail "init makes pack.toml and icons/"
bash "$here/tools/pack-index.sh" my-pack 2> "$tmp/src/err" > /dev/null
[[ ! -s $tmp/src/err ]] || fail "a new pack passes pack-index: $(cat "$tmp/src/err")"
refused "already exists" init "my pack" "Me" "MIT"
refused "needs a letter or digit" init "..." "Me" "MIT"
refused "name must not be empty" init "" "Me" "MIT"
refused "author must not be empty" init "X" "" "MIT"
refused "double quote" init "X" 'a"b' "MIT"
refused "line break" init "X" $'a\nb' "MIT"
refused "control character" init "X" "Me" $'M\x1bIT'
refused "longer than 500" init "X" "Me" "MIT" "$(printf 'd%.0s' {1..501})"
refused "usage" init "X" "Me"
mkdir -p "$packs/.incoming.x" "$packs/linked-target"
ln -s "$packs/linked-target" "$packs/linked"
[[ $(bash "$edit" list | tr '\n' ' ') == "linked linked-target my-pack " ]] || fail "list skips hidden folders: $(bash "$edit" list | tr '\n' ' ')"
rm -rf "$packs/.incoming.x" "$packs/linked-target"

# ---- add
base=$(snap)
[[ $(bash "$edit" add my-pack "Foo Bar" "$sample/firefox.svg") == foo-bar.svg ]] || fail "add prints the file"
[[ $(bash "$edit" add my-pack "FOO bar" "$sample/kitty.png") == foo-bar.png ]] || fail "add the same app as a PNG"
[[ $(ls "$packs/my-pack/icons") == foo-bar.png ]] || fail "one file per app: $(ls "$packs/my-pack/icons")"
cp "$sample/kitty.png" "$tmp/src/no-extension"
[[ $(bash "$edit" add my-pack kitty "$tmp/src/no-extension") == kitty.png ]] || fail "the type comes from the bytes, not the name"
cp "$sample/firefox.svg" "$packs/my-pack/icons/Zed.svg"
bash "$edit" add my-pack zed "$sample/firefox.svg" > /dev/null
[[ $(ls "$packs/my-pack/icons" | tr '\n' ' ') == "foo-bar.png kitty.png zed.svg " ]] || fail "another spelling is replaced: $(ls "$packs/my-pack/icons")"
outside=$(diff <(echo "$base") <(snap) | grep '^[<>]' | grep -v ' \./config/omahop/packs/my-pack/icons' || true)
[[ -z $outside ]] || fail "add changed something outside icons/: $outside"
[[ -z $(find "$packs/my-pack" -name '.*') ]] || fail "no temporary files left"

printf '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>' > "$tmp/src/script.svg"
printf '\xff\xd8\xff\xe0 a jpeg' > "$tmp/src/photo.jpg"
head -c $((3 * 1024 * 1024)) /dev/zero > "$tmp/src/huge.png"
python3 -I -c 'import struct,sys,zlib; sys.stdout.buffer.write(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 60000, 1) + b"\x08\x06\x00\x00\x00" + b"\0" * 4)' > "$tmp/src/wide.png"
ln -s /nowhere "$tmp/src/dangling.png"
mkdir "$tmp/src/dir.png"
refused "not a plain SVG" add my-pack kitty "$tmp/src/script.svg"
refused "not a plain SVG" add my-pack kitty "$tmp/src/photo.jpg"
refused "larger than 2 MB" add my-pack kitty "$tmp/src/huge.png"
refused "not a PNG, or larger than" add my-pack kitty "$tmp/src/wide.png"
refused "no file at" add my-pack kitty "$tmp/src/dangling.png"
refused "is not a file" add my-pack kitty "$tmp/src/dir.png"
refused "full path" add my-pack kitty "relative.png"
refused "full path" add my-pack kitty "-rf.png"
for app in "../x" "a/b" "" "-x" ".x" "a:b" "café" '$(touch x)' "$(printf 'a%.0s' {1..201})"; do
  refused "cannot be an icon file name" add my-pack "$app" "$sample/kitty.png"
done
for name in ".." "../my-pack" "a/b" '$(touch x)' ""; do
  refused "a pack name has only" add "$name" kitty "$sample/kitty.png"
done
refused "no pack folder named" add nope kitty "$sample/kitty.png"
refused "is a link" add linked kitty "$sample/kitty.png"
refused "usage" add my-pack kitty
refused "usage" frobnicate

# ---- remove
ln -s kitty.png "$packs/my-pack/icons/alias.png"
bash "$edit" remove my-pack alias.png > /dev/null
[[ ! -L $packs/my-pack/icons/alias.png && -f $packs/my-pack/icons/kitty.png ]] || fail "remove deletes the link, not its target"
bash "$edit" remove my-pack zed.svg > /dev/null
[[ ! -e $packs/my-pack/icons/zed.svg ]] || fail "remove deletes the icon"
refused "has no icons/" remove my-pack zed.svg
refused "not an icon file name" remove my-pack ../pack.toml
refused "not an icon file name" remove my-pack "icons/kitty.png"
refused "not an icon file name" remove my-pack ".hidden.png"

# ---- meta keeps other lines, replaces the four keys once, drops an empty description
printf '# made by hand\nschema = 1\nname = "dup"\n' >> "$packs/my-pack/pack.toml"
bash "$edit" meta my-pack "Renamed" "You" "MIT" "" > /dev/null
want=$'name = "Renamed"\nauthor = "You"\nlicense = "MIT"\n# made by hand\nschema = 1'
[[ $(cat "$packs/my-pack/pack.toml") == "$want" ]] || fail "meta result: $(cat "$packs/my-pack/pack.toml")"
bash "$edit" meta my-pack "Renamed" "You" "MIT" "Now with a description" > /dev/null
grep -qx 'description = "Now with a description"' "$packs/my-pack/pack.toml" || fail "meta adds a missing key"
refused "double quote" meta my-pack 'a"b' "You" "MIT"
refused "license must not be empty" meta my-pack "X" "You" ""
refused "no pack folder named" meta nope "X" "You" "MIT"
printf 'not toml\n' > "$packs/broken.toml.tmp"
mkdir -p "$packs/broken/icons" && mv "$packs/broken.toml.tmp" "$packs/broken/pack.toml"
refused "cannot be edited until it is fixed" meta broken "X" "You" "MIT"
bash "$here/tools/pack-export.sh" my-pack > /dev/null || fail "an edited pack exports"

# ---- pick: without omarchy it is exit 2 (the page then offers a typed path); with it, the chooser gets the title and the types
bin=$tmp/src/bin
mkdir -p "$bin"
ln -s "$(command -v dirname)" "$bin/dirname"
code=0
PATH=$bin "$BASH" "$edit" pick image > /dev/null 2>&1 || code=$?
(( code == 2 )) || fail "pick without omarchy exits 2, got $code"
printf '#!/bin/sh\nprintf "%%s|" "$@"\n' > "$bin/omarchy"
chmod +x "$bin/omarchy"
[[ $(PATH=$bin:$PATH bash "$edit" pick zip) == "file|select|--title|Choose an icon pack zip|--extensions|zip|" ]] || fail "pick zip arguments"
refused "usage" pick ../etc

# ---- the shell stem and PackEditor.js iconStem agree
ids=("firefox" "com.Mitchellh.Ghostty" "Steam App 440" $'a \t b' "../x" "a/b" "-x" ".x" "a:b" "café" '$(x)' "UPPER+lower_1.2" "$(printf 'a%.0s' {1..200})" "$(printf 'a%.0s' {1..201})")
for id in "${ids[@]}"; do
  shell=$(bash "$edit" stem "$id" 2> /dev/null || true)
  js=$(node -e 'const fs=require("fs");const s=fs.readFileSync(process.argv[1],"utf8").replace(".pragma library","");process.stdout.write(new Function(s+";return iconStem")()(process.argv[2]))' "$here/PackEditor.js" "$id")
  [[ $shell == "$js" ]] || fail "stem of $(printf %q "$id"): shell '$shell', js '$js'"
done

# ---- mutation: without the strict check, the script SVG would be added
mutant=$tmp/src/mutant.sh
cp "$here/tools/pack-lib.sh" "$tmp/src/pack-lib.sh"
sed 's/  pack_check_strict "\$stage" || die/  true || die/' "$edit" > "$mutant"
cmp -s "$edit" "$mutant" && fail "mutation did not apply"
bash "$mutant" add my-pack kitty "$tmp/src/script.svg" > /dev/null 2>&1 || fail "mutant still refuses: the strict check is not what stops it"

echo "ok   pack edit: init, meta, add, remove, list; hostile names, ids, images and metadata change nothing; stems agree; strict check is load-bearing"

#!/usr/bin/env bash
# tools/pack-index.sh against the sample pack and hostile packs in a temporary XDG_CONFIG_HOME: good icons listed, every bad file or pack refused with a note.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
packs=$tmp/config/omahop/packs
mkdir -p "$packs" "$tmp/outside"
sample=$here/docs/examples/packs/omahop-sample
fail() { echo "FAIL pack_index: $1" >&2; exit 1; }
run() { XDG_CONFIG_HOME=$tmp/config HOME=$tmp/home bash "$here/tools/pack-index.sh" "$@" 2> "$tmp/err"; }
listed() { grep -qx -- "$1" <<< "$2"; }

# the sample pack, as shipped
cp -r "$sample" "$packs/good"
out=$(run good)
real=$(realpath "$packs/good/icons")
[[ $out == "$real/firefox.svg"$'\n'"$real/kitty.png" ]] || fail "sample pack lists its two icons, sorted: got '$out'"
[[ ! -s $tmp/err ]] || fail "a good pack logs nothing: $(cat "$tmp/err")"

# no pack chosen, or a name that is not a plain folder name: nothing listed, nothing run
[[ -z $(run "") && ! -s $tmp/err ]] || fail "empty name lists nothing, silently"
for bad in ".." "." "../good" "good/../good" "a b" 'a;touch x' '$(touch x)' "good/" "nosuchpack"; do
  [[ -z $(run "$bad") ]] || fail "pack name '$bad' must list nothing"
  [[ -s $tmp/err ]] || fail "pack name '$bad' must leave a note"
done
[[ ! -e x && ! -e $packs/x ]] || fail "a pack name reached a shell"

# hostile files inside an otherwise good pack: each is skipped with a note, the good ones stay
cp -r "$sample" "$packs/mixed"
i=$packs/mixed/icons
cp "$sample/icons/kitty.png" "$tmp/outside/secret.png"   # a valid PNG, so only the link rule can stop it
ln -s "$tmp/outside/secret.png" "$i/escape.png"         # a link out of the pack
ln -s /etc/passwd "$i/passwd.svg"                       # another one
ln -s "$i/missing.png" "$i/dangling.png"                # a link to nothing
ln -s kitty.png "$i/alacritty.png"                      # a link inside the pack: allowed, under its own name
cp "$i/kitty.png" "$i/..png"                            # a dot name
cp "$i/kitty.png" "$i/.hidden.png"
cp "$i/kitty.png" "$i/photo.jpg"                        # wrong extension
cp "$i/kitty.png" "$i/KITTY.PNG"                        # extension in capitals
cp "$i/kitty.png" "$i/bad"$'\n'"name.png"               # a newline would split the output
mkdir -p "$i/nested" && cp "$i/kitty.png" "$i/nested/foot.png"  # only a flat folder is read
head -c 8 "$i/kitty.png" > "$i/huge.png" && truncate -s 3M "$i/huge.png"  # a PNG signature, then 3 MB
printf '<svg xmlns="http://www.w3.org/2000/svg"/>' > "$i/notpng.png"                     # content does not match the name
printf 'hello' > "$i/text.svg"
printf '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>' > "$i/script.svg"
printf '<svg xmlns="http://www.w3.org/2000/svg"><image href="file:///etc/passwd"/></svg>' > "$i/href.svg"
printf '<svg xmlns="http://www.w3.org/2000/svg">\n<image\n xlink:href =\n "https://example.org/x.png"/></svg>' > "$i/split.svg"
printf '<svg xmlns="http://www.w3.org/2000/svg" onload="x()"></svg>' > "$i/onload.svg"
printf '<?xml version="1.0"?><!DOCTYPE svg [<!ENTITY x SYSTEM "file:///etc/passwd">]><svg>&x;</svg>' > "$i/entity.svg"
printf '<svg xmlns="http://www.w3.org/2000/svg"><rect fill="url(https://e.org/a)"/></svg>' > "$i/url.svg"
printf '<svg xmlns="http://www.w3.org/2000/svg"><foreignObject/></svg>' > "$i/foreign.svg"
{ printf '<svg xmlns="http://www.w3.org/2000/svg"><!--'; head -c 300000 /dev/zero | tr '\0' 'a'; printf -- '--></svg>'; } > "$i/big.svg"
printf '<?xml version="1.0"?>\n<!-- made by hand -->\n<svg xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="g"/></defs><rect fill="url(#g)"/><use href="#g"/><image href="data:image/png;base64,AAAA"/></svg>' > "$i/zen.svg"
# a PNG header that claims 60000 x 1 pixels
{ printf '\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR\x00\x00\xea\x60\x00\x00\x00\x01'; head -c 20 /dev/zero; } > "$i/wide.png"

out=$(run mixed)
real=$(realpath "$i")
for good in firefox.svg kitty.png alacritty.png zen.svg; do listed "$real/$good" "$out" || fail "good icon $good must be listed"; done
[[ $(wc -l <<< "$out") -eq 4 ]] || fail "only the four good icons are listed, got: $out"
for bad in escape.png passwd.svg dangling.png ..png .hidden.png photo.jpg KITTY.PNG huge.png notpng.png text.svg script.svg href.svg split.svg onload.svg entity.svg url.svg foreign.svg big.svg wide.png nested; do
  grep -qF "icons/$bad" "$tmp/err" || fail "a note must name $bad"
done
grep -q "bad" "$tmp/err" || fail "a note names the file with a newline"
grep -q "secret" <<< "$out" && fail "nothing from outside the pack is listed"

# pack.toml problems refuse the whole pack, with a note, and list nothing
mkpack() { rm -rf "$packs/p"; cp -r "$sample" "$packs/p"; }
expect_refused() { # expect_refused <why> <words the note must hold>
  [[ -z $(run p) ]] || fail "$1: the pack must list nothing"
  grep -q "pack not used: .*$2" "$tmp/err" || fail "$1: note must say '$2', got: $(cat "$tmp/err")"
}
mkpack; rm "$packs/p/pack.toml"; expect_refused "no pack.toml" "missing"
mkpack; sed -i '/^author/d' "$packs/p/pack.toml"; expect_refused "no author" "author"
mkpack; sed -i '/^license/d' "$packs/p/pack.toml"; expect_refused "no license" "license"
mkpack; sed -i 's/^name = .*/name = ""/' "$packs/p/pack.toml"; expect_refused "empty name" "name"
mkpack; echo 'run = $(touch x)' >> "$packs/p/pack.toml"; expect_refused "a line that is not key = text" "line 6"
mkpack; echo '[section]' >> "$packs/p/pack.toml"; expect_refused "a section header" "line 6"
mkpack; rm "$packs/p/pack.toml"; ln -s "$tmp/outside/secret.png" "$packs/p/pack.toml"; expect_refused "pack.toml linked out" "inside the pack"
mkpack; head -c 20000 /dev/zero | tr '\0' '#' >> "$packs/p/pack.toml"; expect_refused "huge pack.toml" "larger"
mkpack; rm -r "$packs/p/icons"; expect_refused "no icons folder" "missing"
mkpack; rm -r "$packs/p/icons"; ln -s "$tmp/outside" "$packs/p/icons"; expect_refused "icons linked out" "inside the pack"
[[ ! -e x ]] || fail "pack.toml content reached a shell"

# extra keys, numbers, comments and CRLF line ends are fine
mkpack; printf 'schema = 1\r\nhomepage = "x" # a comment\r\n' >> "$packs/p/pack.toml"
[[ $(run p | wc -l) -eq 2 && ! -s $tmp/err ]] || fail "extra keys, a number, a comment and CRLF are accepted: $(cat "$tmp/err")"

# the pack folder itself may be a link (a clone kept elsewhere)
cp -r "$sample" "$tmp/outside/clone"
ln -s "$tmp/outside/clone" "$packs/linked"
[[ $(run linked | wc -l) -eq 2 ]] || fail "a linked pack folder is read"

echo "ok   pack index: sample listed, hostile names, links, sizes, types, SVG content and bad pack.toml refused with notes"

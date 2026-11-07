#!/usr/bin/env bash
# tools/pack-export.sh and tools/pack-import.sh in a temporary HOME and XDG folders (the real packs are never touched): hostile zips built
# here are refused with the right reason and leave nothing in the packs or cache folder; export then import gives the same files; and a
# mutation check: with the zip-slip or the link rule deleted from a copy of the importer, the matching case here fails.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sample=$here/docs/examples/packs/omahop-sample
importer=$here/tools/pack-import.sh
exporter=$here/tools/pack-export.sh
readonly MANY_ENTRIES=3000
readonly BOMB_BYTES=1900000            # under the 2 MB PNG cap, so only the ratio rule can stop it
readonly HUGE_BYTES=$((3 * 1024 * 1024))
fail() { echo "FAIL pack_zip: $1" >&2; exit 1; }

# mkzip <out.zip> <kind:name[:arg]>...: f = a copy of file arg, s = the text arg, z = arg zero bytes, r = arg random bytes,
# l = a symlink to arg, d = a folder, n = arg files named <name>NNNN.png. Python writes names exactly as given, which zip tools refuse to.
cat > "$tmp/mkzip.py" <<'EOF'
import os, sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for spec in sys.argv[2:]:
        kind, name, arg = (spec.split(":", 2) + [""])[:3]
        if kind == "f":  # ZipInfo keeps the name as given (z.write would strip a leading / and fold ..)
            with open(arg, "rb") as f:
                z.writestr(zipfile.ZipInfo(name), f.read(), zipfile.ZIP_DEFLATED)
        elif kind == "s":
            z.writestr(name, arg)
        elif kind == "z":
            z.writestr(name, b"\0" * int(arg))
        elif kind == "r":
            z.writestr(name, os.urandom(int(arg)))
        elif kind == "l":
            info = zipfile.ZipInfo(name)
            info.external_attr = (0o120777 << 16)
            z.writestr(info, arg)
        elif kind == "d":
            z.writestr(name, "")
        elif kind == "n":
            for i in range(int(arg)):
                z.writestr(f"{name}{i:04d}.png", "x")
EOF
mkzip() { python3 -I "$tmp/mkzip.py" "$@"; }
good=("f:pack.toml:$sample/pack.toml" "d:icons/" "f:icons/kitty.png:$sample/icons/kitty.png" "f:icons/firefox.svg:$sample/icons/firefox.svg")

# fresh <who>: an empty HOME, config and cache for one run; sets H, P (packs) and C (cache) and exports the variables
fresh() {
  rm -rf "$tmp/$1"; mkdir -p "$tmp/$1/home"
  H=$tmp/$1/home P=$tmp/$1/config/omahop/packs C=$tmp/$1/cache/omahop
  export HOME=$H XDG_CONFIG_HOME=$tmp/$1/config XDG_CACHE_HOME=$tmp/$1/cache
}
empty() { [[ ! -e $1 ]] || [[ -z $(ls -A "$1") ]]; }

# refused <zip> <words> [importer]: the import fails, says <words>, and leaves no pack, no staging and no temp folder. Returns 1 otherwise.
refused() {
  local zip=$1 words=$2 tool=${3:-$importer} err=$tmp/err
  fresh victim
  if bash "$tool" "$zip" --yes > /dev/null 2> "$err" < /dev/null; then echo "  $zip was installed" >&2; return 1; fi
  grep -qF -- "$words" "$err" || { echo "  $zip: wanted '$words', got: $(cat "$err")" >&2; return 1; }
  empty "$P" && empty "$C" || { echo "  $zip left files behind" >&2; return 1; }
}

z=$tmp/zips
mkdir -p "$z"
mkzip "$z/slip.zip" "${good[@]}" "f:../evil.png:$sample/icons/kitty.png"
mkzip "$z/slip2.zip" "${good[@]}" "f:icons/../../evil.png:$sample/icons/kitty.png"
mkzip "$z/absolute.zip" "${good[@]}" "f:$tmp/abs-evil.png:$sample/icons/kitty.png"
mkzip "$z/symlink.zip" "${good[@]}" "l:icons/link.png:/etc/passwd"
mkzip "$z/bomb.zip" "${good[@]}" "z:icons/bomb.png:$BOMB_BYTES"
mkzip "$z/many.zip" "${good[@]}" "n:icons/a:$MANY_ENTRIES"
mkzip "$z/case.zip" "${good[@]}" "f:icons/Kitty.png:$sample/icons/kitty.png"
mkzip "$z/fakepng.zip" "${good[@]}" 's:icons/fake.png:<svg xmlns="http://www.w3.org/2000/svg"/>'
mkzip "$z/script.zip" "${good[@]}" 's:icons/evil.svg:<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>'
mkzip "$z/notoml.zip" "d:icons/" "f:icons/kitty.png:$sample/icons/kitty.png"
mkzip "$z/huge.zip" "${good[@]}" "r:icons/huge.png:$HUGE_BYTES"
mkzip "$z/hidden.zip" "${good[@]}" "f:icons/.hidden.png:$sample/icons/kitty.png"
mkzip "$z/nested.zip" "${good[@]}" "d:icons/sub/"
mkzip "$z/nestedfile.zip" "${good[@]}" "f:icons/sub/a.png:$sample/icons/kitty.png"
mkzip "$z/extra.zip" "${good[@]}" 's:install.sh:#!/bin/sh'
mkzip "$z/badtoml.zip" "s:pack.toml:name = \$(touch $tmp/ran)" "d:icons/"
mkzip "$z/noname.zip" 's:pack.toml:name = "***"
author = "a"
license = "CC0-1.0"' "d:icons/"
tar -cf "$z/tar.zip" -C "$sample" pack.toml icons

refused "$z/slip.zip" "a path that leads out of the pack" || fail "zip slip ../"
refused "$z/slip2.zip" "a path that leads out of the pack" || fail "zip slip inside icons/"
refused "$z/absolute.zip" "an absolute path" || fail "absolute path"
refused "$z/symlink.zip" "a link or special file" || fail "symlink entry"
refused "$z/bomb.zip" "a zip bomb" || fail "high-ratio bomb"
refused "$z/many.zip" "more than 2002 entries" || fail "$MANY_ENTRIES entries"
refused "$z/case.zip" "listed twice" || fail "Kitty.png next to kitty.png"
refused "$z/fakepng.zip" "not a PNG" || fail ".png that is an SVG"
refused "$z/script.zip" "not a plain SVG" || fail "SVG with a script"
refused "$z/notoml.zip" "no pack.toml" || fail "missing pack.toml"
refused "$z/huge.zip" "a file larger than" || fail "huge file"
refused "$z/hidden.zip" "a hidden name" || fail "hidden file"
refused "$z/nested.zip" "only icons/ may be one" || fail "nested folder"
refused "$z/nestedfile.zip" "not pack.toml or icons/" || fail "file in a nested folder"
refused "$z/extra.zip" "not pack.toml or icons/" || fail "a script next to the pack"
refused "$z/badtoml.zip" "line 1" || fail "pack.toml that is not key = text"
refused "$z/noname.zip" "no usable folder name" || fail "pack.toml name without letters"
refused "$z/tar.zip" "not a zip" || fail "a tar named .zip"
for f in "$tmp/evil.png" "$tmp/abs-evil.png" "$tmp/ran" "$tmp/victim/evil.png" "$tmp/victim/config/evil.png"; do
  [[ ! -e $f ]] || fail "a hostile zip wrote $f"
done

# round trip: export a pack (with an in-pack link) from one HOME, import it into another, same files and bytes
fresh alice
mkdir -p "$P"
cp -r "$sample" "$P/omahop-sample"
ln -s kitty.png "$P/omahop-sample/icons/alacritty.png"
bash "$exporter" omahop-sample > /dev/null
out=$H/omahop-sample.omahop-pack.zip
[[ -f $out ]] || fail "export writes ~/<name>.omahop-pack.zip"
first=$(sha256sum < "$out")
bash "$exporter" omahop-sample 2> /dev/null && fail "export must not overwrite without --force"
bash "$exporter" omahop-sample --force > /dev/null
[[ $(sha256sum < "$out") == "$first" ]] || fail "two exports of one pack give the same bytes"
[[ $(bsdtar -tf "$out") == $'pack.toml\nicons/\nicons/alacritty.png\nicons/firefox.svg\nicons/kitty.png' ]] \
  || fail "the zip holds pack.toml and icons/ only, sorted: $(bsdtar -tf "$out")"
empty "$C" || fail "export leaves no temp folder"
src=$P/omahop-sample
cp "$out" "$tmp/shared.zip"
cp "$sample/icons/kitty.png" "$src/icons/.DS_Store"
bash "$exporter" omahop-sample "$tmp/junk.zip" 2> "$tmp/err" && fail "export refuses a pack with a file pack-index would skip"
grep -q "DS_Store" "$tmp/err" || fail "export says which file it refused"
rm "$src/icons/.DS_Store"

fresh bob
bash "$importer" "$tmp/shared.zip" < /dev/null > /dev/null 2>&1 && fail "without --yes and no terminal, nothing is installed"
empty "$P" && empty "$C" || fail "a declined import leaves nothing"
bash "$importer" "$tmp/shared.zip" --yes > "$tmp/out" || fail "the exported zip imports"
grep -q "Author:   omahop contributors" "$tmp/out" && grep -q "Icons:    3" "$tmp/out" || fail "import shows author and icon count: $(cat "$tmp/out")"
dst=$P/omahop-sample
for f in pack.toml icons/alacritty.png icons/firefox.svg icons/kitty.png; do
  [[ $(sha256sum < "$src/$f") == $(sha256sum < "$dst/$f") ]] || fail "round trip keeps $f byte for byte"
done
[[ $(cd "$dst" && find . | sort | tr '\n' ' ') == ". ./icons ./icons/alacritty.png ./icons/firefox.svg ./icons/kitty.png ./pack.toml " ]] \
  || fail "the imported pack holds only those files"
[[ ! -L $dst/icons/alacritty.png ]] || fail "an in-pack link arrives as a plain file"
empty "$C" || fail "import leaves no temp folder"
[[ $(ls -A "$P") == omahop-sample ]] || fail "import leaves nothing else in the packs folder"
[[ $(XDG_CONFIG_HOME=$tmp/bob/config bash "$here/tools/pack-index.sh" omahop-sample | wc -l) -eq 3 ]] || fail "pack-index uses the imported pack"
bash "$importer" "$tmp/shared.zip" --yes > /dev/null 2> "$tmp/err" && fail "an installed pack is not replaced without --replace"
grep -q "already installed" "$tmp/err" || fail "the refusal says the pack is installed"
echo "old" > "$dst/icons/old.png"
bash "$importer" "$tmp/shared.zip" --yes --replace > /dev/null || fail "--replace replaces"
[[ ! -e $dst/icons/old.png && -f $dst/pack.toml ]] || fail "--replace swaps the whole folder"
[[ $(ls -A "$P") == omahop-sample ]] || fail "--replace leaves nothing beside the pack"

# mutation check: delete one rule from a copy of the importer; the case for that rule must then fail
for rule in zip-slip:slip.zip:"a path that leads out of the pack" links:symlink.zip:"a link or special file"; do
  IFS=: read -r tag zipname words <<< "$rule"
  mkdir -p "$tmp/mutant"
  cp "$here/tools/pack-lib.sh" "$tmp/mutant/"
  grep -q "# rule:$tag\$" "$importer" || fail "rule:$tag is tagged in the importer"
  grep -v "# rule:$tag\$" "$importer" > "$tmp/mutant/pack-import.sh"
  if refused "$z/$zipname" "$words" "$tmp/mutant/pack-import.sh" 2> /dev/null; then fail "the $tag case still passes with its rule deleted"; fi
done

echo "ok   pack zip: 18 hostile zips refused with nothing left, export is stable, round trip is byte for byte, rules are load-bearing"

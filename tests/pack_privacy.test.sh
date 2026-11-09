#!/usr/bin/env bash
# Privacy of a shared zip (D29): a pack built in a temporary HOME is exported and the zip is read back. It holds only pack.toml, icons/ and the icons,
# pack.toml holds only the allowed keys (unknown keys are left out, with a note), and nothing that names the maker's computer is in any file name, file or
# byte of the zip: no home path, temp path, user name, host name or absolute path. A pack whose text carries such a place is REFUSED (never edited), with
# nothing written. Also: open-zip (Edit as draft) goes through the importer's checks and installs nothing.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sample=$here/docs/examples/packs/omahop-sample
fail() { echo "FAIL pack_privacy: $1" >&2; exit 1; }

user=zorbatester
export HOME=$tmp/home/$user XDG_CONFIG_HOME=$tmp/config XDG_CACHE_HOME=$tmp/cache USER=$user LOGNAME=$user
P=$XDG_CONFIG_HOME/omahop/packs
mkdir -p "$HOME" "$P/mine/icons" "$tmp/out"
cp "$sample/icons/"* "$P/mine/icons/"
host=$(uname -n)
write_toml() { printf '%s\n' "$@" > "$P/mine/pack.toml"; }
exporter() { bash "$here/tools/pack-export.sh" mine "$tmp/out/mine.zip" --force "$@"; }

# 1. a normal pack, with keys the format does not know, and a comment and a path-like word in a comment
write_toml '# made in /home/zorbatester/secret' 'name = "Mine"' 'author = "Nova Test"' 'license = "CC0-1.0"' 'description = "Round shapes, https://example.org/x and and/or fine."' \
  'based_on = "Papirus"' "notes = \"$HOME/private\"" 'internal = 7'
out=$(exporter) || fail "a clean pack exports: $out"
grep -q "Left out of pack.toml: internal,notes" <<< "$out" || fail "the left-out keys are named: $out"
grep -qE "Exported mine \(2 icons, [0-9]+ bytes\) to $tmp/out/mine.zip" <<< "$out" || fail "export reports icons and size: $out"

mkdir "$tmp/x" && bsdtar -xf "$tmp/out/mine.zip" -C "$tmp/x"
listing=$(bsdtar -tf "$tmp/out/mine.zip" | sort | tr '\n' ' ')
[[ $listing == "icons/ icons/firefox.svg icons/kitty.png pack.toml " ]] || fail "the zip holds pack.toml and icons/ only: $listing"
[[ -z $(find "$tmp/x" -mindepth 1 -type l) ]] || fail "no links in the zip"
keys=$(sed -E 's/ *=.*//' "$tmp/x/pack.toml" | sort | tr '\n' ' ')
[[ $keys == "author based_on description license name " ]] || fail "only allowed keys: $keys"
grep -q "^# " "$tmp/x/pack.toml" && fail "no comment lines in pack.toml"
# no trace of the maker, in names, text or raw bytes (the zip itself included)
for needle in "$HOME" "$tmp" "/home/" "$user" "$host" "/Users/" "/tmp"; do
  [[ -n $needle ]] || continue
  grep -raqF -- "$needle" "$tmp/x" "$tmp/out/mine.zip" && fail "'$needle' is in the zip"
  bsdtar -tvf "$tmp/out/mine.zip" | grep -qF -- "$needle" && fail "'$needle' is in the listing (names, owners)"
done
bsdtar -tvf "$tmp/out/mine.zip" | awk '{print $3, $4}' | sort -u | grep -qvx "0 0" && fail "owner and group are not the maker's"
grep -raqE '(^|[^[:alnum:]_./-])/[[:alnum:]_.~-]' "$tmp/x/pack.toml" && fail "no absolute path in pack.toml"

# 2. a text that names a place is refused, not edited, and writes nothing
rm -f "$tmp/out/mine.zip"
for bad in "see $HOME/pics" "from /home/other/icons" "~/Pictures" "C:\\Users\\x\\a" "\\\\server\\share" "file:///etc/x" "made on $host-box" "in /tmp/work"; do
  for key in description author license name; do
    base=('name = "Mine"' 'author = "Nova"' 'license = "CC0-1.0"')
    case $key in description) write_toml "${base[@]}" "description = \"$bad\"" ;; name) write_toml "name = \"$bad\"" 'author = "Nova"' 'license = "CC0-1.0"' ;;
      author) write_toml 'name = "Mine"' "author = \"$bad\"" 'license = "CC0-1.0"' ;; license) write_toml 'name = "Mine"' 'author = "Nova"' "license = \"$bad\"" ;; esac
    exporter > /dev/null 2> "$tmp/err" && fail "export accepted $key = '$bad'"
    grep -q "names a place on this computer" "$tmp/err" || fail "$key '$bad': wrong reason: $(cat "$tmp/err")"
    [[ ! -e $tmp/out/mine.zip ]] || fail "a refused export wrote a zip"
  done
done
[[ -z $(ls -A "$XDG_CACHE_HOME/omahop" 2>/dev/null) ]] || fail "a refused export leaves nothing in the cache"
# the same pack with the author's words changed to something harmless exports
write_toml 'name = "Mine"' 'author = "Nova"' 'license = "CC0-1.0"' 'description = "Rounded, flat, and/or bright. See https://example.org"'
exporter > /dev/null || fail "plain words and a web address are fine"
# the missing folder and a folder as the target
bash "$here/tools/pack-export.sh" mine "$tmp/nope/x.zip" 2> "$tmp/err" && fail "a missing folder is refused"
grep -q "there is no folder" "$tmp/err" || fail "the missing folder is named: $(cat "$tmp/err")"

# 3. follows_theme survives (the generator name is data, not a path)
write_toml 'name = "Mine"' 'author = "Nova"' 'license = "CC0-1.0"' 'follows_theme = true' 'generator = "refpack"' 'other = true'
exporter > /dev/null && bsdtar -xOf "$tmp/out/mine.zip" pack.toml | grep -qx 'follows_theme = true' || fail "follows_theme is kept"
write_toml 'name = "Mine"' 'author = "Nova"' 'license = "CC0-1.0"' 'follows_theme = true'
exporter > /dev/null 2>&1 && fail "follows_theme without a generator is still refused"

# 4. open-zip: Edit as draft installs nothing, keeps every import rule, loads the icons
write_toml 'name = "Mine"' 'author = "Nova"' 'license = "CC0-1.0"'
exporter > /dev/null
rm -rf "$P" "$XDG_CACHE_HOME"
draft=$XDG_CACHE_HOME/omahop/draft
bash "$here/tools/draft-edit.sh" open-zip "$tmp/out/mine.zip" > "$tmp/o" || fail "open-zip opens a good zip"
grep -q "Opened the zip with 2 icons" "$tmp/o" || fail "open-zip says what it opened: $(cat "$tmp/o")"
[[ ! -e $P ]] || fail "open-zip installs nothing"
[[ $(ls "$draft/icons" | tr '\n' ' ') == "firefox.svg kitty.png " ]] || fail "the zip's icons are in the draft"
[[ $(ls -A "$XDG_CACHE_HOME/omahop" | tr '\n' ' ') == "draft " ]] || fail "open-zip leaves no staging folder: $(ls -A "$XDG_CACHE_HOME/omahop")"
bash "$here/tools/draft-edit.sh" open-zip "$tmp/out/mine.zip" 2> "$tmp/err" && fail "a draft with changes is not replaced without --force"
grep -q "has changes" "$tmp/err" || fail "the refusal says why"
bash "$here/tools/draft-edit.sh" open-zip --force "$tmp/out/mine.zip" > /dev/null || fail "--force replaces the draft"
python3 -I - "$tmp/evil.zip" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z:
    z.writestr("pack.toml", 'name = "x"\nauthor = "a"\nlicense = "l"\n'); z.writestr("../evil.png", "x")
PY
before=$(cd "$draft" && find . -type f | sort | xargs sha256sum)
bash "$here/tools/draft-edit.sh" open-zip --force "$tmp/evil.zip" 2> "$tmp/err" && fail "a hostile zip is refused by open-zip"
grep -q "leads out of the pack" "$tmp/err" || fail "the importer's reason comes through: $(cat "$tmp/err")"
[[ $before == "$(cd "$draft" && find . -type f | sort | xargs sha256sum)" ]] || fail "a refused zip leaves the draft as it was"
[[ ! -e $tmp/evil.png && ! -e $tmp/cache/evil.png ]] || fail "nothing escaped"
bash "$here/tools/draft-edit.sh" open-zip relative.zip 2> "$tmp/err" && fail "a relative path is refused"
bash "$here/tools/pack-import.sh" "$tmp/out/mine.zip" --extract "$tmp/exists" --extract "$tmp/b" 2> /dev/null && fail "--extract twice is a usage error"

# mutation check: with the private-text refusal deleted from a copy of the exporter, the path case must fail
mkdir -p "$tmp/mutant"; cp "$here/tools/pack-lib.sh" "$tmp/mutant/"
grep -v 'private_text "\$value"' "$here/tools/pack-export.sh" > "$tmp/mutant/pack-export.sh"
mkdir -p "$P/mine/icons" && cp "$sample/icons/"* "$P/mine/icons/"
write_toml 'name = "Mine"' 'author = "Nova"' 'license = "CC0-1.0"' "description = \"see $HOME/pics\""
bash "$tmp/mutant/pack-export.sh" mine "$tmp/out/m.zip" > /dev/null 2>&1 || fail "mutant setup"
bsdtar -xOf "$tmp/out/m.zip" pack.toml | grep -qF "$HOME" || fail "the privacy case is load-bearing (the mutant leaks)"

echo "ok   pack privacy: zip holds pack.toml and icons only, allowed keys only, no trace of the maker, paths refused, open-zip safe"

#!/usr/bin/env bash
# tools/omahop-tabs-activate and tools/omahop-tabs-files in a temporary runtime folder: bad arguments refused, no reader returns at once,
# a reader receives the tab id, file modes, and turning off leaves nothing behind. Usage: bash tests/tabs_helpers.test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
act=$PWD/tools/omahop-tabs-activate
files=$PWD/tools/omahop-tabs-files
tmp=$(mktemp -d)
reader_pid=""
cleanup() { [ -n "$reader_pid" ] && kill "$reader_pid" 2>/dev/null; rm -rf "$tmp"; }
trap cleanup EXIT
export XDG_RUNTIME_DIR=$tmp
dir=$tmp/omahop
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# ---- activate ----
for args in "" "1" "1 2 3" "a 1" "1 b" "-1 2" "1 2;touch $tmp/pwned" "12345678901 1" "1 \$(touch $tmp/pwned)"; do
  # shellcheck disable=SC2086
  rc=0; "$act" $args >/dev/null 2>&1 || rc=$?
  check "bad arguments refused: '$args'" "[ $rc -ne 0 ] && [ ! -e $tmp/pwned ]"
done
check "no FIFO: quiet success" "\"$act\" 42 7 && [ -z \"\$(\"$act\" 42 7 2>&1)\" ]"
mkdir -p "$dir"
mkfifo -m 600 "$dir/tabs.42.activate"
start=$(date +%s%N)
"$act" 42 7
ms=$(( ($(date +%s%N) - start) / 1000000 ))
check "FIFO with no reader returns at once (${ms} ms)" "[ $ms -lt 900 ]"
# a reader the way the host holds it (read and write end, non-blocking), collecting what arrives
python3 -I -c '
import os, select, sys, time
fd = os.open(sys.argv[1], os.O_RDWR | os.O_NONBLOCK)
data, end = b"", time.time() + 3
while time.time() < end and b"\n" not in data:
    if select.select([fd], [], [], 0.1)[0]:
        data += os.read(fd, 64)
open(sys.argv[2], "wb").write(data)
' "$dir/tabs.42.activate" "$tmp/got" &
reader_pid=$!
sleep 0.3
"$act" 42 1234
wait "$reader_pid" || true
reader_pid=""
check "with a reader the tab id arrives" "[ \"\$(cat $tmp/got)\" = 1234 ]"
ln -s /dev/null "$dir/tabs.43.activate"
check "not a FIFO: nothing written" "\"$act\" 43 1"

# ---- files ----
rm -rf "$dir"
"$files" "$dir" on Bank.example.com 'bad name' 'x;y' '*.corp.example' '[ab]x.example' mail.example.org '$(id)'
check "on: folder mode 700" "[ \"\$(stat -c %a $dir)\" = 700 ]"
check "on: flag mode 600" "[ \"\$(stat -c %a $dir/tabs.enabled)\" = 600 ]"
check "on: ignore file mode 600" "[ \"\$(stat -c %a $dir/tabs.ignore)\" = 600 ]"
check "on: only valid names and globs written, lower case" "[ \"\$(cat $dir/tabs.ignore)\" = \"\$(printf 'bank.example.com\n*.corp.example\n[ab]x.example\nmail.example.org')\" ]"
chmod 755 "$dir"
"$files" "$dir" on
check "on again: folder tightened, empty ignore file" "[ \"\$(stat -c %a $dir)\" = 700 ] && [ ! -s $dir/tabs.ignore ]"
echo '{}' > "$dir/tabs.42.json"; echo keep > "$dir/state"; mkfifo -m 600 "$dir/tabs.42.activate"
"$files" "$dir" off
check "off: flag, ignore file and tab files removed" "[ ! -e $dir/tabs.enabled ] && [ ! -e $dir/tabs.ignore ] && [ ! -e $dir/tabs.42.json ]"
check "off: other files and the helper's FIFO left alone" "[ -e $dir/state ] && [ -p $dir/tabs.42.activate ]"
# ---- pictures ----
"$files" "$dir" on
"$files" "$dir" pictures-on
check "pictures-on: flag mode 600" "[ \"\$(stat -c %a $dir/tabs.pictures)\" = 600 ]"
mkdir -p "$dir/tabpics"; echo x > "$dir/tabpics/1-2-3.jpg"
"$files" "$dir" pictures-off
check "pictures-off: flag and every picture removed, the rest kept" "[ ! -e $dir/tabs.pictures ] && [ ! -e $dir/tabpics ] && [ -e $dir/tabs.enabled ] && [ -e $dir/state ]"
"$files" "$dir" pictures-on; mkdir -p "$dir/tabpics"; echo x > "$dir/tabpics/1-2-3.jpg"
"$files" "$dir" off
check "off also removes the pictures flag and tabpics" "[ ! -e $dir/tabs.pictures ] && [ ! -e $dir/tabpics ] && [ ! -e $dir/tabs.enabled ]"
check "pictures-off with no folder is fine" "\"$files\" $tmp/none pictures-off"
check "off with no folder is fine" "\"$files\" $tmp/none off"
# ---- draw ----
"$files" "$dir" on; "$files" "$dir" pictures-on; "$files" "$dir" draw-on
check "draw-on: flag mode 600" "[ \"\$(stat -c %a $dir/tabs.draw)\" = 600 ]"
"$files" "$dir" draw-off
check "draw-off: only the draw flag removed" "[ ! -e $dir/tabs.draw ] && [ -e $dir/tabs.pictures ] && [ -e $dir/tabs.enabled ]"
"$files" "$dir" draw-on; "$files" "$dir" pictures-off
check "pictures-off also removes the draw flag" "[ ! -e $dir/tabs.draw ] && [ ! -e $dir/tabs.pictures ]"
"$files" "$dir" pictures-on; "$files" "$dir" draw-on; "$files" "$dir" off
check "off also removes the draw flag" "[ ! -e $dir/tabs.draw ]"
check "draw-off with no folder is fine" "\"$files\" $tmp/none draw-off"
rc=0; "$files" relative on || rc=$?
check "a relative folder is refused" "[ $rc -ne 0 ] && [ ! -e relative ]"
rc=0; "$files" "$dir" sideways || rc=$?
check "an unknown mode is refused" "[ $rc -ne 0 ]"

[ $fail = 0 ] && echo "tabs helpers ok" || { echo "tabs helpers FAILED"; exit 1; }

#!/usr/bin/env bash
# tools/audio-sample.sh with a fake pactl first in PATH (no real audio is read, played or changed): output shape, a failing or missing pactl.
# Usage: bash tests/audio_sample.test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
tool=$PWD/tools/audio-sample.sh
fixture=$PWD/tests/fixtures/pactl-sink-inputs.json
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
mkdir -p "$tmp/ok" "$tmp/bad" "$tmp/none"
printf '#!/usr/bin/env bash\n[ "$*" = "-f json list sink-inputs" ] || exit 9\ncat "%s"\n' "$fixture" > "$tmp/ok/pactl"
printf '#!/usr/bin/env bash\necho "Connection failure" >&2\nexit 1\n' > "$tmp/bad/pactl"
chmod +x "$tmp/ok/pactl" "$tmp/bad/pactl"
# the commands the script needs besides pactl, without pactl itself
for c in bash ps; do ln -s "$(command -v "$c")" "$tmp/none/$c"; done

out=$(PATH="$tmp/ok:$PATH" bash "$tool")
check "pactl JSON first" "[ \"\$(printf '%s\n' \"\$out\" | sed -n '/^--\$/q;p')\" = \"\$(cat \"$fixture\")\" ]"
check "one separator line" "[ \"\$(printf '%s\n' \"\$out\" | grep -c '^--\$')\" = 1 ]"
check "process table after it, own pid listed" "printf '%s\n' \"\$out\" | sed '1,/^--\$/d' | grep -Eq '^ *[0-9]+ +[0-9]+\$'"

out=$(PATH="$tmp/bad:$PATH" bash "$tool" 2>"$tmp/err")
check "failing pactl: empty list" "[ \"\$(printf '%s\n' \"\$out\" | head -1)\" = '[]' ]"
check "failing pactl: nothing on stderr" "[ ! -s \"$tmp/err\" ]"

out=$(PATH="$tmp/none" "$tmp/none/bash" "$tool" 2>"$tmp/err")
check "no pactl: empty list, table still there" "[ \"\$(printf '%s\n' \"\$out\" | head -2 | tr '\n' ' ')\" = '[] -- ' ]"
check "no pactl: nothing on stderr" "[ ! -s \"$tmp/err\" ]"

[ "$fail" = 0 ] && echo "audio sample ok"
exit "$fail"

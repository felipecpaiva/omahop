#!/usr/bin/env bash
# Throwaway spike driver. Hermetic: temp profile, headless Chromium (no window, never touches a running browser),
# host manifest inside that profile, runtime folder in the temp dir. Usage: bash run.sh [chromium-binary]
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
bin=${1:-chromium}
tmp=$(mktemp -d)
rt="$tmp/rt"
ud="$tmp/profile"
id=$(jq -r .key "$here/extension/manifest.json" | base64 -d | sha256sum | head -c32 | tr '0-9a-f' 'a-p')
pid=""
cleanup() { [ -n "$pid" ] && kill "$pid" 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT

mkdir -p "$ud/NativeMessagingHosts" "$rt"
jq -n --arg p "$here/host.py" --arg o "chrome-extension://$id/" \
  '{name:"com.omahop.tabs",description:"omahop spike",path:$p,type:"stdio",allowed_origins:[$o]}' \
  >"$ud/NativeMessagingHosts/com.omahop.tabs.json"

OMAHOP_RT="$rt" "$bin" --headless=new --user-data-dir="$ud" --no-first-run --disable-gpu \
  --load-extension="$here/extension" \
  'data:text/html,<title>spike one</title>' \
  >"$tmp/browser.log" 2>&1 &
pid=$!

waitfor() { for _ in $(seq 1 100); do if eval "$1"; then return 0; fi; sleep 0.2; done; echo "TIMEOUT: $1"; tail -5 "$tmp/browser.log"; exit 1; }

waitfor "[ -s '$rt/tabs.json' ] && [ \$(jq '[.windows[].tabs[]]|length' '$rt/tabs.json') -ge 3 ]"
echo "OK list written: $(jq -c '[.windows[]|{id,focused,n:(.tabs|length)}]' "$rt/tabs.json")"
echo "OK caller arg: $(jq -r '.caller[0]' "$rt/tabs.json")"
echo "OK file mode: $(stat -c %a "$rt/tabs.json") dir mode: $(stat -c %a "$rt")"

# Activate the tab that is not active, then wait for the snapshot to show it active.
target=$(jq -r '[.windows[].tabs[]|select(.active|not)][0].id' "$rt/tabs.json")
printf '{"type":"activate","tab":%s,"focusWindow":false}\n' "$target" >"$rt/activate.fifo"
waitfor "[ \"\$(jq -r '[.windows[].tabs[]|select(.id==$target)][0].active' '$rt/tabs.json')\" = true ]"
echo "OK tab $target became active after an activate request"

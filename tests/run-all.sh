#!/usr/bin/env bash
# All omahop checks. The pure ones run anywhere with Lua 5.5; the live one needs Hyprland, kitty, grim and write access to /dev/uinput
# and uses the real keyboard (keep your hands off it for about a minute). Usage: bash tests/run-all.sh [--no-live]
set -e
cd "$(dirname "$0")/.."
# Hyprland embeds Lua 5.5; 5.4 accepts code that 5.5 rejects, so a pass on 5.4 proves little.
lua -e 'assert(_VERSION == "Lua 5.5", "run these tests with Lua 5.5, like Hyprland (found " .. _VERSION .. ")")'
for t in config scope windows mru session search glue; do lua "lua/test_$t.lua"; done
bash tests/scrub.sh
node tests/state.test.mjs
node tests/config_io.test.mjs
lua tools/gen-spec.lua --check
command -v omarchy >/dev/null && omarchy plugin validate . >/dev/null && echo "plugin validates"
# Linters: run when installed, otherwise say so (a skip is a visible debt, see docs/engineering-standards.md)
for tool in luacheck stylua shellcheck ruff; do
  command -v "$tool" >/dev/null || echo "SKIP $tool not installed"
done
if command -v luacheck >/dev/null; then luacheck lua --no-color -q --globals hl o omahop_takeover || true; fi
# qmllint cannot resolve the shell's qs.* imports (they only exist inside the running shell), so it can only check syntax: a syntax error fails the run, import warnings are hidden.
if [ -x /usr/lib/qt6/bin/qmllint ]; then /usr/lib/qt6/bin/qmllint --unqualified disable --unresolved-type disable --import disable ./*.qml 2>&1 | grep -E "^(Error|Syntax)" && exit 1 || echo "qml syntax ok"; else echo "SKIP qmllint not installed"; fi
[ "${1:-}" = "--no-live" ] && exit 0
echo "Live test next: it uses your real keyboard. Keep your hands off it."
python3 tests/live.py
python3 tests/live_panel.py
python3 tests/live_cards.py

#!/usr/bin/env bash
# Regenerates packs/omahop-reference from apps.tsv in the active Omarchy theme colours. Extra arguments go to gen.py (--colors, --out).
exec python3 -I "$(dirname "${BASH_SOURCE[0]}")/gen.py" "$@"

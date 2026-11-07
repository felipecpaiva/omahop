#!/usr/bin/env python3
"""Map which keys the live Hyprland binds already use, for each modifier combination omahop could hold (Alt, Ctrl, Super and their combos).
Prints Markdown: for each combination, whether its Tab trigger (and the Shift variant that goes back) is free, which session keys (Escape, Return, Delete, arrows,
the same-app backtick) and which typing keys (letters, digits, Space, Backspace) are already taken. Read-only: it only runs `hyprctl binds -j`.
Usage: python3 tools/key-map.py   (the result is kept in docs/omarchy-key-map.md, with notes added by hand)"""
import json, string, subprocess, sys

SHIFT = 1
COMBOS = [("Alt", 8), ("Ctrl", 4), ("Super", 64), ("Ctrl + Alt", 12), ("Super + Alt", 72), ("Super + Ctrl", 68), ("Super + Ctrl + Alt", 76)]
SESSION = ["ESCAPE", "RETURN", "DELETE", "LEFT", "RIGHT", "UP", "DOWN", "GRAVE"]
TYPING = [c.upper() for c in string.ascii_lowercase + string.digits] + ["SPACE", "BACKSPACE"]


def binds():
    out = subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True, check=True).stdout
    used = {}
    for b in json.loads(out):
        if b.get("submap"):
            continue  # a submap only matters while it is active
        used.setdefault((b["modmask"], b["key"].upper()), b.get("description") or b.get("dispatcher") or "")
    return used


# Keys worth listing as free: letters, digits, Tab, Grave, Space and the function keys.
CANDIDATES = [c.upper() for c in string.ascii_lowercase + string.digits] + ["TAB", "GRAVE", "SPACE"] + [f"F{i}" for i in range(1, 13)]


def main():
    used = binds()
    print("| Held key | Tab | Shift + Tab | Session keys taken | Typing keys taken (of 38) |")
    print("|---|---|---|---|---|")
    for name, mask in COMBOS:
        tab = used.get((mask, "TAB")); back = used.get((mask + SHIFT, "TAB"))
        def cell(d): return "free" if d is None else "taken: " + (d or "no description")
        sess = [k for k in SESSION if (mask, k) in used]
        typ = [k for k in TYPING if (mask, k) in used]
        print(f"| {name} | {cell(tab)} | {cell(back)} | {', '.join(sess) or 'none'} | {len(typ)}{': ' + ' '.join(typ) if typ and len(typ) <= 12 else ''} |")

    print("\nFree keys (neither the plain chord nor its Shift variant is bound):\n")
    for name, mask in COMBOS:
        free = [k for k in CANDIDATES if (mask, k) not in used and (mask + SHIFT, k) not in used]
        print(f"- **{name}**: {' '.join(free)}")


if __name__ == "__main__":
    sys.exit(main())

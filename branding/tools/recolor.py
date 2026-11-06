#!/usr/bin/env python3
"""Makes colour variations of one logo concept: the same shapes, a new palette. Reads the concept's SVGs, swaps the family colours, exports the PNGs, checks WCAG contrast.
Usage: python3 branding/tools/recolor.py v2-tilehop   (writes explorations/v2-tilehop-<palette>/ for every palette below)"""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXP = os.path.join(ROOT, "explorations")

# The colours of the source concept (omagnet's family) and, for each new palette, what replaces them.
SRC = {"ground": "#16181d", "main": "#e8e6ff", "accent": "#8b7bff", "ticks": "#6b7080", "accent_deep": "#6a5af0", "ticks_light": "#5b5f6e"}
PALETTES = {
    "tide": {"title": "Tide (blue)", "ground": "#0f1b24", "main": "#e4f4fb", "accent": "#38bdf8", "ticks": "#5d7587", "accent_deep": "#0b78b5", "ticks_light": "#55687a"},
    "coral": {"title": "Coral (rose red)", "ground": "#1c1316", "main": "#ffe8ec", "accent": "#ff6b81", "ticks": "#7d6168", "accent_deep": "#d12f4d", "ticks_light": "#6e5a60"},
    "citrus": {"title": "Citrus (golden yellow)", "ground": "#1a1812", "main": "#fff5d6", "accent": "#ffc83d", "ticks": "#7c7560", "accent_deep": "#9a6b00", "ticks_light": "#6a634f"},
}
PAPER = "#f4f3f0"


def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def main(concept):
    src = os.path.join(EXP, concept)
    for name, pal in PALETTES.items():
        out = os.path.join(EXP, f"{concept}-{name}")
        os.makedirs(out, exist_ok=True)
        for f in ("icon.svg", "glyph.svg", "glyph-light.svg", "icon-mono.svg"):
            text = open(os.path.join(src, f)).read()
            if f == "glyph-light.svg":
                # on light backgrounds the source uses ink #16181d for the lilac shapes, deep accent and the light tick grey
                text = text.replace(SRC["ground"], pal["ground"]).replace(SRC["accent_deep"], pal["accent_deep"]).replace(SRC["ticks_light"], pal["ticks_light"])
            else:
                for k in ("ground", "main", "accent", "ticks"):
                    text = text.replace(SRC[k], pal[k])
            open(os.path.join(out, f), "w").write(text)
        for size in (512, 16):
            subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), os.path.join(out, "icon.svg"), "-o", os.path.join(out, f"icon-{size}.png")], check=True)
        rows = [("main on ground", contrast(pal["main"], pal["ground"]), 7.0, "AAA text size"), ("accent on ground", contrast(pal["accent"], pal["ground"]), 3.0, "graphics"),
                ("ticks on ground", contrast(pal["ticks"], pal["ground"]), 3.0, "decoration only"), ("ink on paper", contrast(pal["ground"], PAPER), 7.0, "AAA"),
                ("deep accent on paper", contrast(pal["accent_deep"], PAPER), 3.0, "graphics"), ("light ticks on paper", contrast(pal["ticks_light"], PAPER), 3.0, "decoration only")]
        lines = [f"# {concept}-{name}: {pal['title']}", "",
                 f"The same shapes as `{concept}` with a new palette, made by `tools/recolor.py`. Nothing but colour changed.", "",
                 "| Role | Hex |", "|---|---|"]
        for k, label in (("ground", "Ground (icon tile, and ink on light)"), ("main", "Main shape"), ("accent", "Accent: the tile that is hopped to"), ("ticks", "Motion ticks"), ("accent_deep", "Accent on light backgrounds"), ("ticks_light", "Ticks on light backgrounds")):
            lines.append(f"| {label} | `{pal[k]}` |")
        lines += ["", f"Contrast (WCAG, computed; paper is `{PAPER}`):", "", "| Pair | Ratio | Bar | Note |", "|---|---|---|---|"]
        ok = True
        for label, r, bar, note in rows:
            flag = "ok" if r >= bar else "BELOW BAR"
            ok = ok and r >= bar
            lines.append(f"| {label} | {r:.1f}:1 | {bar}:1 | {note}, {flag} |")
        open(os.path.join(out, "notes.md"), "w").write("\n".join(lines) + "\n")
        print(f"{name}: wrote {out}  contrast {'all above the bar' if ok else 'SOME BELOW THE BAR'}  " + ", ".join(f"{l} {r:.1f}" for l, r, _, _ in rows))


main(sys.argv[1] if len(sys.argv) > 1 else "v2-tilehop")

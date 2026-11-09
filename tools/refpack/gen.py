#!/usr/bin/env python3
"""Writes the omahop reference icon pack: one plain SVG per line of apps.tsv, in the Omarchy look (flat rounded tile, one glyph or monogram).
Usage: gen.py [--colors colors.toml] [--out DIR] [--apps apps.tsv]. Stdlib only. Colours come from an Omarchy colors.toml (default: the active theme)."""
import argparse, os, re, sys
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
ACTIVE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "omarchy/current/theme/colors.toml")
# category -> palette key for the tile
ACCENT = {"browser": "blue", "terminal": "green", "dev": "magenta", "files": "yellow", "media": "red", "chat": "cyan", "office": "accent",
          "system": "muted", "game": "bright_red", "graphics": "bright_cyan", "utility": "bright_green"}
# Hand drawn glyphs: stroked shapes inside the 32..96 box, drawn with the foreground colour (stroke only, round joins).
GLYPHS = {
    "terminal": '<path d="M36 44l16 14-16 14M60 76h24"/>',
    "browser": '<circle cx="64" cy="64" r="30"/><path d="M34 64h60M64 34c-16 18-16 42 0 60M64 34c16 18 16 42 0 60"/>',
    "files": '<path d="M34 48v34a4 4 0 0 0 4 4h52a4 4 0 0 0 4-4V54a4 4 0 0 0-4-4H64l-8-10H38a4 4 0 0 0-4 4z"/>',
    "code": '<path d="M50 46L32 64l18 18M78 46l18 18-18 18M70 38L58 90"/>',
    "music": '<path d="M52 82V40l32-8v42"/><circle cx="44" cy="82" r="8"/><circle cx="76" cy="74" r="8"/>',
    "video": '<rect x="32" y="44" width="46" height="40" rx="8"/><path d="M78 58l18-10v32L78 70"/>',
    "chat": '<path d="M36 40h56a4 4 0 0 1 4 4v32a4 4 0 0 1-4 4H64L46 94V80H36a4 4 0 0 1-4-4V44a4 4 0 0 1 4-4z"/>',
    "mail": '<rect x="32" y="42" width="64" height="44" rx="8"/><path d="M36 48l28 22 28-22"/>',
    "settings": '<circle cx="64" cy="64" r="10"/><path d="M64 32v10M64 86v10M32 64h10M86 64h10M41 41l7 7M80 80l7 7M87 41l-7 7M48 80l-7 7"/>',
    "calculator": '<rect x="38" y="32" width="52" height="64" rx="8"/><path d="M48 48h32"/><path d="M50 64h2M64 64h2M78 64h2M50 78h2M64 78h2M78 78h2" stroke-width="9"/>',
    "camera": '<path d="M34 50a4 4 0 0 1 4-4h14l6-8h12l6 8h14a4 4 0 0 1 4 4v32a4 4 0 0 1-4 4H38a4 4 0 0 1-4-4z"/><circle cx="64" cy="66" r="12"/>',
    "monitor": '<path d="M32 76h14l8-24 10 36 8-20h16"/>',
    "doc": '<path d="M42 32h30l18 18v42a4 4 0 0 1-4 4H42a4 4 0 0 1-4-4V36a4 4 0 0 1 4-4zM72 32v18h18M48 66h32M48 80h22"/>',
    "sheet": '<rect x="34" y="36" width="60" height="56" rx="6"/><path d="M34 54h60M34 72h60M54 54v38"/>',
    "slides": '<rect x="32" y="40" width="64" height="42" rx="6"/><path d="M64 82v12M50 94h28"/>',
    "gamepad": '<path d="M44 48h40c8 0 14 6 16 16l3 14c1 6-6 9-10 4L76 70H52L39 82c-4 5-11 2-10-4l3-14c2-10 8-16 16-16z"/><path d="M48 58v10M43 63h10M80 62h2M88 62h2" stroke-width="6"/>',
    "calendar": '<rect x="34" y="40" width="60" height="54" rx="8"/><path d="M34 58h60M50 32v14M78 32v14"/>',
    "image": '<rect x="32" y="38" width="64" height="52" rx="8"/><circle cx="52" cy="56" r="5"/><path d="M34 84l20-18 14 12 10-8 18 14"/>',
    "download": '<path d="M64 34v40M46 58l18 18 18-18M38 92h52"/>',
    "notes": '<path d="M38 36h44l10 10v46H38zM50 58h30M50 72h30"/>',
    "disk": '<ellipse cx="64" cy="44" rx="28" ry="10"/><path d="M36 44v40c0 6 12 10 28 10s28-4 28-10V44M36 64c0 6 12 10 28 10s28-4 28-10"/>',
    "mic": '<rect x="54" y="32" width="20" height="38" rx="10"/><path d="M42 62c0 14 10 22 22 22s22-8 22-22M64 84v10"/>',
    "record": '<circle cx="64" cy="64" r="30"/><circle cx="64" cy="64" r="12" fill="currentColor"/>',
}

def read_palette(path):
    pal = {}
    for line in open(path, encoding="utf-8"):
        m = re.match(r'\s*([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{6})"', line)
        if m: pal[m.group(1)] = m.group(2).lower()
    return pal

def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]

def contrast(a, b):
    x, y = sorted((lum(a), lum(b)), reverse=True)
    return (x + 0.05) / (y + 0.05)

def svg(label, cat, glyph, pal):
    tile = pal.get(ACCENT.get(cat, "accent"), pal["accent"])
    # glyph colour: whichever of the theme's background or foreground reads better on the tile
    ink = max((pal["background"], pal["foreground"]), key=lambda c: contrast(tile, c))
    if glyph.startswith("@"):
        body = f'<g fill="none" stroke="{ink}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round" color="{ink}">{GLYPHS[glyph[1:]]}</g>'
    else:
        size = 64 if len(glyph) == 1 else 50 if len(glyph) == 2 else 40
        body = (f'<text x="64" y="64" text-anchor="middle" dominant-baseline="central" font-family="sans-serif" font-weight="700" '
                f'font-size="{size}" fill="{ink}">{escape(glyph)}</text>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128"><title>{escape(label)}</title>'
            f'<rect x="8" y="8" width="112" height="112" rx="28" fill="{tile}"/>{body}</svg>\n')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--colors", default=ACTIVE)
    ap.add_argument("--out", default=os.path.join(HERE, "../../packs/omahop-reference"))
    ap.add_argument("--apps", default=os.path.join(HERE, "apps.tsv"))
    a = ap.parse_args()
    pal = read_palette(a.colors)
    for k in ("accent", "background", "foreground"):
        if k not in pal: sys.exit(f"gen.py: {a.colors} has no {k}")
    for k in set(ACCENT.values()): pal.setdefault(k, pal["accent"])
    icons = os.path.join(a.out, "icons")
    os.makedirs(icons, exist_ok=True)
    for f in os.listdir(icons):  # drop icons removed from apps.tsv
        if f.endswith(".svg"): os.remove(os.path.join(icons, f))
    seen = set()
    for n, line in enumerate(open(a.apps, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#"): continue
        f = line.split("\t")
        if len(f) != 5: sys.exit(f"apps.tsv line {n}: need 5 tab separated fields")
        stem, label, cat, glyph, src = f
        if stem != stem.lower() or stem in seen: sys.exit(f"apps.tsv line {n}: stem not lower case or duplicate: {stem}")
        if cat not in ACCENT or src not in ("machine", "common") or (glyph.startswith("@") and glyph[1:] not in GLYPHS):
            sys.exit(f"apps.tsv line {n}: unknown category, source or glyph")
        seen.add(stem)
        open(os.path.join(icons, stem + ".svg"), "w", encoding="utf-8").write(svg(label, cat, glyph, pal))
    open(os.path.join(a.out, "pack.toml"), "w").write(
        'name = "omahop reference"\nauthor = "omahop"\nlicense = "CC0-1.0"\n'
        'description = "Reference pack: common Linux apps and the apps of one Omarchy machine, flat tiles in the active theme colours. Made by tools/refpack/gen.py."\n')
    open(os.path.join(a.out, "LICENSE"), "w").write("CC0 1.0 Universal: the icons in this pack are dedicated to the public domain.\nhttps://creativecommons.org/publicdomain/zero/1.0/\n")
    print(f"{len(seen)} icons in {a.out}")

main()

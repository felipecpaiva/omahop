#!/usr/bin/env python3
"""Comparison board for the logo concepts: each concept big, then at 128/64/32/16 px on dark and light, then its one-colour stencil.
Writes board.html and board.png (needs chromium). Usage: python3 branding/tools/board.py"""
import base64, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXP = os.path.join(ROOT, "explorations")
names = sorted(d for d in os.listdir(EXP) if os.path.isdir(os.path.join(EXP, d)))


def uri(path):
    mime = "image/svg+xml" if path.endswith(".svg") else "image/png"
    return f"data:{mime};base64," + base64.b64encode(open(path, "rb").read()).decode()


def cell(name):
    d = os.path.join(EXP, name)
    icon, concept = uri(os.path.join(d, "icon.svg")), uri(os.path.join(d, "concept.png"))
    mono = os.path.join(d, "icon-mono.svg")
    stencil = f'<img src="{uri(mono)}" width="64">' if os.path.exists(mono) else ""
    sizes = lambda bg: "".join(f'<img src="{icon}" width="{s}" height="{s}">' for s in (128, 64, 32, 16))
    return f"""<section><h2>{name}</h2><img class="big" src="{concept}">
<div class="row dark">{sizes('dark')}</div><div class="row light">{sizes('light')}</div>
<div class="row dark">{stencil}</div><div class="row light"><img src="{uri(mono)}" width="64" style="filter:none">{stencil}</div></section>"""


html = f"""<!doctype html><meta charset="utf-8"><style>
body{{margin:0;padding:24px;background:#15171c;color:#cfd3da;font:14px monospace}}
main{{display:flex;gap:24px}} section{{width:340px}} h2{{margin:0 0 8px;font-size:15px}}
.big{{width:340px;height:340px;border-radius:24px;display:block}}
.row{{display:flex;gap:14px;align-items:center;padding:12px;margin-top:10px;border-radius:10px}}
.dark{{background:#101216}} .light{{background:#f1f2f4}}
.light img[src*="svg"]{{}}
</style><h1 style="margin:0 0 16px;font-size:18px">omahop concepts</h1><main>{''.join(cell(n) for n in names)}</main>"""
out_html = os.path.join(ROOT, "board.html")
open(out_html, "w").write(html)
png = os.path.join(ROOT, "board.png")
subprocess.run(["chromium", "--headless=new", "--no-sandbox", "--hide-scrollbars", "--window-size=1120,1010", f"--screenshot={png}", "file://" + out_html], capture_output=True)
print("wrote", png, os.path.exists(png))

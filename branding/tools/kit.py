#!/usr/bin/env python3
"""Builds the whole omahop brand kit from numbers and one palette (Citrus): the logo set (icon, small icon, glyphs, stencils, PNG sizes, favicon), the wordmark and lockups,
the social images, the marketplace preview and the brand sheet. Everything is vector first; PNGs come from the SVGs.
Needs rsvg-convert, ImageMagick (magick) and chromium. Usage: python3 branding/tools/kit.py   (screens/settings-top.png must exist for the preview)"""
import os, re, subprocess, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGO, SOCIAL = os.path.join(ROOT, "logo"), os.path.join(ROOT, "social")
for d in (LOGO, SOCIAL):
    os.makedirs(d, exist_ok=True)

# Citrus palette (see explorations/v2-tilehop-citrus/notes.md for the contrast numbers)
C = dict(ground="#1a1812", main="#fff5d6", accent="#ffc83d", tick="#7c7560",
         ink="#1a1812", accent_light="#9a6b00", tick_light="#6a634f", paper="#f4f3f0",
         mute="#a39d86", mute_light="#6a634f", chip="#27241a", chip_light="#e6e3da")


# ---------------------------------------------------------------- the mark
def mark(main, accent, tick, ticks=True, small=False):
    """Two rounded tiles and an arc leaping from the first to the second; three ticks mark the departure."""
    if small:  # below 64 px: no ticks, bigger tiles, a thicker arc
        tiles = [(92, 262, 132, 28, main), (284, 262, 132, 28, accent)]
        arc, sw = "M 160 208 C 180 112 324 112 352 208", 56
    else:
        tiles = [(104, 270, 120, 24, main), (288, 270, 120, 24, accent)]
        arc, sw = "M 164 218 C 184 126 318 126 348 218", 48
    parts = [f'<rect x="{x}" y="{y}" width="{w}" height="{w}" rx="{rx}" fill="{c}"/>' for x, y, w, rx, c in tiles]
    parts.append(f'<path d="{arc}" fill="none" stroke="{main}" stroke-width="{sw}" stroke-linecap="round"/>')
    if ticks and not small:
        for y in (170, 189, 208):
            parts.append(f'<line x1="114" y1="{y}" x2="132" y2="{y - 18}" stroke="{tick}" stroke-width="9" stroke-linecap="round"/>')
    return "\n  ".join(parts)


def svg(body, tile=None):
    bg = f'<rect width="512" height="512" rx="97" fill="{tile}"/>\n  ' if tile else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">\n  {bg}{body}\n</svg>\n'


def write(folder, name, text):
    with open(os.path.join(folder, name), "w") as f:
        f.write(text)


def png(src, name, w, h=None, folder=LOGO):
    subprocess.run(["rsvg-convert", "-w", str(w)] + (["-h", str(h)] if h else []) + [os.path.join(folder, src), "-o", os.path.join(folder, name)], check=True)


def build_logo():
    write(LOGO, "icon.svg", svg(mark(C["main"], C["accent"], C["tick"]), tile=C["ground"]))
    write(LOGO, "icon-small.svg", svg(mark(C["main"], C["accent"], C["tick"], small=True), tile=C["ground"]))
    write(LOGO, "glyph.svg", svg(mark(C["main"], C["accent"], C["tick"])))
    write(LOGO, "glyph-light.svg", svg(mark(C["ink"], C["accent_light"], C["tick_light"])))
    write(LOGO, "stencil.svg", svg(mark("#000000", "#000000", "#000000")))
    write(LOGO, "stencil-white.svg", svg(mark("#ffffff", "#ffffff", "#ffffff")))
    for s in (1024, 512, 256, 192, 180, 128, 64):
        png("icon.svg", f"icon-{s}.png", s)
    for s in (48, 32, 16):
        png("icon-small.svg", f"icon-{s}.png", s)
    for name in ("glyph", "glyph-light", "stencil", "stencil-white"):
        png(f"{name}.svg", f"{name}-512.png", 512)
    subprocess.run(["magick"] + [os.path.join(LOGO, f"icon-{s}.png") for s in (16, 32, 48)] + [os.path.join(LOGO, "favicon.ico")], check=True)
    print("logo set written")


# ---------------------------------------------------------------- the wordmark: monoline strokes, no font. Letters of the name only: o m a h p
MONO = {
    "o": (44, ["M 20 3 A 17 17 0 1 1 19.99 3 Z"]),
    "m": (68, ["M 4 40 V 4", "M 4 24 A 14 14 0 0 1 32 24 V 40", "M 32 24 A 14 14 0 0 1 60 24 V 40"]),
    "a": (44, ["M 20 6 A 16 16 0 1 0 20.01 6 Z", "M 36 6 V 40"]),
    "h": (44, ["M 4 -10 V 40", "M 4 24 A 16 16 0 0 1 36 24 V 40"]),
    "p": (44, ["M 20 6 A 16 16 0 1 0 20.01 6 Z", "M 4 6 V 62"]),
}


def wordmark(color, accent, weight=8, text="omahop"):
    x, parts = 0, []
    for i, ch in enumerate(text):
        adv, paths = MONO[ch]
        parts.append(f'<path transform="translate({x} 0)" d="{" ".join(paths)}" stroke="{accent if i == 0 else color}" fill="none"/>')
        x += adv
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-8 -22 {x + 16} 100" height="100" fill="none" '
            f'stroke-width="{weight}" stroke-linecap="round" stroke-linejoin="round">' + "".join(parts) + '</svg>\n')


def inner(svg_text):
    m = re.search(r"<svg[^>]*>", svg_text)
    vb = [float(v) for v in re.search(r'viewBox="([^"]+)"', m.group(0)).group(1).split()]
    return svg_text[m.end():svg_text.rindex("</svg>")], vb


def lockup(icon_svg, word_svg, icon_px=160, gap=40, word_h=72):
    ibody, (_, _, iw, ih) = inner(icon_svg)
    wbody, (wx, wy, ww, wh) = inner(word_svg)
    si, sw = icon_px / ih, word_h / wh
    total = icon_px + gap + ww * sw
    attrs = " ".join(re.findall(r'((?:fill|stroke|stroke-width|stroke-linecap|stroke-linejoin)="[^"]*")', re.search(r"<svg[^>]*>", word_svg).group(0)))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total:.0f} {icon_px}" height="{icon_px}">'
            f'<g transform="scale({si:.5f})">{ibody}</g>'
            f'<g transform="translate({icon_px + gap} {(icon_px - word_h) / 2:.1f}) scale({sw:.5f}) translate({-wx} {-wy})" {attrs}>{wbody}</g></svg>\n')


def build_wordmark():
    rd = lambda n: open(os.path.join(LOGO, n)).read()
    dark, light = wordmark(C["main"], C["accent"]), wordmark(C["ink"], C["accent_light"])
    write(LOGO, "wordmark.svg", dark)
    write(LOGO, "wordmark-light.svg", light)
    write(LOGO, "lockup.svg", lockup(rd("glyph.svg"), dark))
    write(LOGO, "lockup-light.svg", lockup(rd("glyph-light.svg"), light))
    for n in ("wordmark", "wordmark-light", "lockup", "lockup-light"):
        subprocess.run(["rsvg-convert", "-h", "256" if "lockup" in n else "160", os.path.join(LOGO, n + ".svg"), "-o", os.path.join(LOGO, n + ".png")], check=True)
    print("wordmark and lockups written")


# ---------------------------------------------------------------- social images
TAG = "Fast window switching for Omarchy floating workspaces"
SUB = "Alt+Tab list or cards. Type to search. Pure Lua."
KEYS = ["ALT + TAB", "SHIFT + TAB", "ALT + type"]
THEMES = {"dark": dict(bg=C["ground"], fg=C["main"], mute=C["mute"], chip=C["chip"], lockup="lockup.svg"),
          "light": dict(bg=C["paper"], fg=C["ink"], mute=C["mute_light"], chip=C["chip_light"], lockup="lockup-light.svg")}


def chrome(html, w, h, out):
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as f:
        f.write(html)
    subprocess.run(["chromium", "--headless", "--no-sandbox", "--hide-scrollbars", "--force-device-scale-factor=1", f"--window-size={w},{h}", f"--screenshot={out}", "file://" + f.name], check=True, capture_output=True)
    os.unlink(f.name)


def page(w, h, th, layout):
    t = THEMES[th]
    lk = open(os.path.join(LOGO, t["lockup"])).read()
    chips = "".join(f'<span class="chip">{k}</span>' for k in KEYS)
    big = layout == "square"
    lh = int(h * (0.22 if big else 0.30))
    return f"""<!doctype html><meta charset="utf-8"><style>
*{{box-sizing:border-box;margin:0}}
body{{width:{w}px;height:{h}px;background:{t['bg']};color:{t['fg']};font-family:'JetBrainsMono Nerd Font','JetBrains Mono',monospace;
 display:flex;flex-direction:column;justify-content:center;padding:0 {int(w * 0.08)}px;gap:{int(h * 0.05)}px;overflow:hidden}}
.lk svg{{height:{lh}px;width:auto;display:block;margin-left:-{int(lh * 0.203)}px}}
.tag{{font-size:{int(h * (0.045 if big else 0.07))}px;font-weight:700;line-height:1.25}}
.sub{{font-size:{int(h * (0.028 if big else 0.042))}px;color:{t['mute']};line-height:1.4}}
.chips{{display:flex;gap:14px;flex-wrap:wrap}}
.chip{{background:{t['chip']};color:{t['fg']};border-radius:10px;padding:10px 18px;font-size:{int(h * (0.026 if big else 0.038))}px}}
.url{{position:absolute;right:{int(w * 0.04)}px;bottom:{int(h * 0.05)}px;font-size:{int(h * 0.03)}px;color:{t['mute']}}}
</style><div class="lk">{lk}</div><div class="tag">{TAG}</div>
{'' if layout == 'banner' else f'<div class="sub">{SUB}</div><div class="chips">{chips}</div>'}
<div class="url">github.com/felipecpaiva/omahop</div>"""


def build_social():
    for name, w, h, th, layout in (("github-social-preview.png", 1280, 640, "dark", "wide"), ("card-wide.png", 1200, 630, "dark", "wide"),
                                   ("card-wide-light.png", 1200, 630, "light", "wide"), ("card-square.png", 1080, 1080, "dark", "square"),
                                   ("banner-dark.png", 1600, 400, "dark", "banner"), ("banner-light.png", 1600, 400, "light", "banner"),
                                   ("card-linkedin.png", 1200, 627, "dark", "wide"), ("card-x.png", 1600, 900, "dark", "wide")):
        chrome(page(w, h, th, layout), w, h, os.path.join(SOCIAL, name))
    subprocess.run(["rsvg-convert", "-w", "400", os.path.join(LOGO, "icon.svg"), "-o", os.path.join(SOCIAL, "avatar-400.png")], check=True)
    # the marketplace preview (repo root): lockup and tagline beside the real settings window
    shot = os.path.join(ROOT, "screens", "settings-top.png")
    if os.path.exists(shot):
        t = THEMES["dark"]
        lk = open(os.path.join(LOGO, t["lockup"])).read()
        html = f"""<!doctype html><meta charset="utf-8"><style>*{{box-sizing:border-box;margin:0}}
body{{width:1280px;height:640px;background:{t['bg']};color:{t['fg']};font-family:'JetBrainsMono Nerd Font',monospace;display:flex;align-items:center;padding:0 64px;gap:48px;overflow:hidden}}
.l{{flex:1}} .lk svg{{height:130px;width:auto;display:block;margin-left:-26px}}
.tag{{font-size:34px;font-weight:700;line-height:1.3;margin-top:32px}} .sub{{font-size:20px;color:{t['mute']};margin-top:20px;line-height:1.5}}
img{{height:560px;border-radius:14px;box-shadow:0 12px 40px #0008}}</style>
<div class="l"><div class="lk">{lk}</div><div class="tag">{TAG}</div><div class="sub">{SUB}</div></div><img src="file://{shot}">"""
        chrome(html, 1280, 640, os.path.join(os.path.dirname(ROOT), "preview.png"))
    print("social images written")


# ---------------------------------------------------------------- brand sheet
def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def cr(a, b):
    x, y = sorted((lum(a), lum(b)), reverse=True)
    return (x + 0.05) / (y + 0.05)


def build_sheet():
    G, P = C["ground"], C["paper"]
    pal = [("Ground", G, "Dark background, icon tile", C["main"]), ("Cream", C["main"], "Main shapes and text on dark", G),
           ("Citrus", C["accent"], "The tile that is hopped to, the o, accents on dark", G), ("Tick", C["tick"], "Three small ticks (decoration only)", G),
           ("Paper", P, "Light background", G), ("Ink", C["ink"], "Shapes and text on light", P),
           ("Citrus deep", C["accent_light"], "Citrus on light backgrounds", P), ("Muted", C["mute_light"], "Secondary text on light", P)]

    def swatch(n, h, role, on):
        r = cr(h, on)
        grade = "AAA" if r >= 7 else "AA" if r >= 4.5 else "graphics only, not body text" if r >= 3 else "decoration only"
        ink = G if lum(h) > 0.4 else P
        return f'<div class="sw"><div class="chip" style="background:{h};color:{ink}">{n}</div><b>{h}</b><span>{role}</span><i>{r:.1f}:1 on {on} ({grade})</i></div>'
    rd = lambda n: open(os.path.join(LOGO, n)).read()
    html = f"""<!doctype html><meta charset="utf-8"><title>omahop brand sheet</title><style>
*{{box-sizing:border-box;margin:0}} body{{width:1600px;background:{P};color:{G};font-family:'JetBrainsMono Nerd Font','JetBrains Mono',monospace;padding:64px;font-size:17px;line-height:1.5}}
h2{{font-size:15px;letter-spacing:.12em;text-transform:uppercase;color:{C['mute_light']};margin:48px 0 18px;border-top:2px solid {G};padding-top:14px}}
.top{{display:flex;align-items:center;justify-content:space-between}} .top svg{{height:120px;width:auto}} .top p{{max-width:640px;font-size:19px}}
.row{{display:flex;gap:28px;align-items:flex-end;flex-wrap:wrap}} .tile{{border-radius:18px;padding:26px;display:flex;align-items:center;justify-content:center}}
.cap{{font-size:14px;color:{C['mute_light']};margin-top:8px}}
.pal{{display:grid;grid-template-columns:repeat(4,1fr);gap:22px}} .sw{{display:flex;flex-direction:column;gap:4px}} .sw .chip{{height:84px;border-radius:12px;padding:12px 14px;font-weight:700;border:1px solid #0002}}
.sw span{{font-size:14px;color:{C['mute_light']}}} .sw i{{font-size:13px;font-style:normal}}
.two{{display:grid;grid-template-columns:1fr 1fr;gap:48px}} ul{{padding-left:22px}} li{{margin:6px 0}} .do li::marker{{content:"+ ";color:#2f9e6b;font-weight:700}} .dont li::marker{{content:"x ";color:#c0392b;font-weight:700}}
.mono{{font-size:15px}} code{{background:#0001;padding:1px 6px;border-radius:5px}}
</style>
<div class="top"><div>{rd('lockup-light.svg')}</div><p><b>omahop</b> is fast window switching for Omarchy floating workspaces. The mark: two window tiles and an arc that hops from the first to the second, with three ticks for the departure. The tile you hop to is citrus. Plain, quick, small.</p></div>

<h2>1. The mark</h2>
<div class="row">
 <div><div class="tile" style="background:{G}"><img src="logo/icon-256.png" width="200"></div><div class="cap">App icon (dark tile). Files: icon.svg, icon-*.png</div></div>
 <div><div class="tile" style="background:{G}"><img src="logo/glyph-512.png" width="200"></div><div class="cap">Glyph on dark: glyph.svg</div></div>
 <div><div class="tile" style="background:#fff;border:1px solid #0002"><img src="logo/glyph-light-512.png" width="200"></div><div class="cap">Glyph on light: glyph-light.svg</div></div>
 <div><div class="tile" style="background:#fff;border:1px solid #0002"><img src="logo/stencil-512.png" width="200"></div><div class="cap">One colour: stencil.svg, stencil-white.svg</div></div>
 <div><div class="tile" style="background:{G}"><img src="logo/icon-64.png" width="64"><img src="logo/icon-32.png" width="32" style="margin-left:16px"><img src="logo/icon-16.png" width="16" style="margin-left:16px"></div><div class="cap">64, 32, 16 px. Below 64 px use icon-small.svg (no ticks, bigger tiles)</div></div>
</div>

<h2>2. Palette and contrast (WCAG, computed from the hex values)</h2>
<div class="pal">{''.join(swatch(*p) for p in pal)}</div>
<p class="cap">Body text uses Ink and Muted (AA or better). Citrus and the ticks are graphic colours: 3:1 is the bar for graphics, so never set body text in them. The ticks are decoration, never the only carrier of meaning. No gradients, shadows or glows in the mark.</p>

<h2>3. Type</h2>
<div class="two"><div><p style="font-size:34px;font-weight:700">JetBrains Mono</p><p>Bold for headings, regular for body. It is Omarchy's own default font (SIL OFL licence), so the project looks at home on the desktop it targets. Fallback: any monospace.</p></div>
<div><p>The wordmark <b>omahop</b> is drawn as vector strokes, not set in a font. Always lowercase, one word, the <code>o</code> in citrus. Say it "oh-ma-hop".</p>{rd('wordmark-light.svg').replace('height="100"','height="90"')}</div></div>

<h2>4. Spacing and shape</h2>
<ul class="mono"><li>Base unit 8 px. Card padding 8% of the width, gaps 16 or 24 px.</li><li>Clear space around the mark: the height of one tile (about a quarter of the glyph width) on every side.</li><li>Minimum size: 16 px for the icon (the small variant), 96 px wide for the lockup.</li><li>Rounded corners everywhere, like the mark: tile radius 19% of its width, chips 10 to 14 px.</li></ul>

<h2>5. Do and do not</h2>
<div class="two">
<ul class="do"><li>Use the dark icon tile for app and avatar slots, the glyph for flat backgrounds.</li><li>Use the light-background files on light pages (<code>*-light.*</code>).</li><li>Write the name in lowercase: omahop.</li><li>Say "fast window switching for Omarchy floating workspaces" and keep the not-affiliated line near it.</li><li>Keep text short and plain: key names, not hype.</li></ul>
<ul class="dont"><li>Recolour the mark, stretch it, rotate it, or add a glow or shadow.</li><li>Use omagnet's violet for omahop, or Omarchy's logo or green.</li><li>Put the dark-ground glyph on a light or busy background (use the light glyph).</li><li>Write OMaHop, Omahop or O-ma-hop.</li><li>Imply that Omarchy endorses the project.</li><li>Use an em-dash or en-dash in any text.</li></ul></div>
<p class="cap" style="margin-top:36px">Source: branding/tools (kit.py). Artwork released with the project under MIT. Colours checked {len(pal)} pairs.</p>"""
    out = os.path.join(ROOT, "brand-sheet.html")
    open(out, "w").write(html)
    subprocess.run(["chromium", "--headless", "--no-sandbox", "--hide-scrollbars", "--force-device-scale-factor=1", "--window-size=1600,2150", f"--screenshot={os.path.join(ROOT, 'brand-sheet.png')}", "file://" + out], check=True, capture_output=True)
    print("brand sheet written")


if __name__ == "__main__":
    build_logo(); build_wordmark(); build_social(); build_sheet()

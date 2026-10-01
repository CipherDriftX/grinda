"""Steppie identity: Stride S symbol, wordmark, lockups, app icons, fonts.

Needs fontTools (and shapely for stride.py, which writes logo/stride-s.json):
    pip install fonttools shapely
    python3 brand/tools/stride.py      # only when the mark's geometry changes
    python3 brand/tools/brand.py <path to Archivo[wdth,wght].ttf>

Archivo: https://github.com/google/fonts/tree/main/ofl/archivo (SIL OFL 1.1).
"""
import json, math, os, subprocess, sys

from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "../.."))
LOGO = os.path.join(ROOT, "brand/logo")
ICON = os.path.join(ROOT, "brand/icon")
FONTS = os.path.join(ROOT, "brand/fonts")
sys.path.insert(0, os.path.join(ROOT, "brand/mascot/tools"))

COBALT, COBALT_HI, COBALT_LO = "#1F4FD8", "#3A6AF2", "#1638A8"
INK, WHITE, VOLT, TYVEK = "#0E1116", "#FFFFFF", "#C8F03C", "#F4F6F8"

M = json.load(open(os.path.join(LOGO, "stride-s.json")))
ANGLE = M["angle"]


def stride(cx, cy, h, fill):
    d = ""
    for ring in M["rings"]:
        d += "M" + " L".join(f"{cx + x * h:.2f},{cy + y * h:.2f}" for x, y in ring) + " Z "
    return f'<path d="{d.strip()}" fill="{fill}"/>'


def svg(w, h, body, bg=None):
    b = f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h:.0f}" viewBox="0 0 {w:.2f} {h:.2f}">{b}{body}</svg>\n'


def write(name, content, png=None, folder=LOGO):
    p = os.path.join(folder, name)
    open(p + ".svg", "w").write(content)
    if png:
        subprocess.run(["rsvg-convert", "-w", str(png), p + ".svg", "-o", p + ".png"], check=True)


# ----------------------------------------------------------------------------- fonts
def make_fonts(src):
    """Steppie Bib Black (w62/900), Bib Bold (w75/750), Steppie Wide Black (w112/900)."""
    specs = [("SteppieBib", "Black", 900, 62), ("SteppieBib", "Bold", 750, 75), ("SteppieWide", "Black", 900, 112)]
    for fam, style, wght, wdth in specs:
        f = instantiateVariableFont(TTFont(src), {"wght": wght, "wdth": wdth})
        name = f["name"]
        ps = f"{fam}-{style}"
        for rec in list(name.names):
            if rec.nameID in (1, 4, 6, 16, 17, 3):
                name.removeNames(nameID=rec.nameID)
        for pid, eid, lid in ((3, 1, 0x409), (1, 0, 0)):
            name.setName(fam if style in ("Regular",) else f"{fam} {style}", 1, pid, eid, lid)
            name.setName("Regular", 2, pid, eid, lid)
            name.setName(f"{ps};Archivo-derived", 3, pid, eid, lid)
            name.setName(f"{fam} {style}", 4, pid, eid, lid)
            name.setName(ps, 6, pid, eid, lid)
            name.setName(fam, 16, pid, eid, lid)
            name.setName(style, 17, pid, eid, lid)
        f.save(os.path.join(FONTS, f"{ps}.ttf"))
        print("font", ps)


# ----------------------------------------------------------------------------- wordmark
def wordmark_paths():
    """`steppie` in Steppie Wide Black, tracked -1%, with the i's dot cut on the stride angle."""
    f = TTFont(os.path.join(FONTS, "SteppieWide-Black.ttf"))
    gs, cmap, upm = f.getGlyphSet(), f.getBestCmap(), f["head"].unitsPerEm
    xh = f["OS/2"].sxHeight
    x, letters, dot = 0, [], None
    for ch in "steppie":
        g = gs[cmap[ord(ch)]]
        if ch == "i":
            rec = RecordingPen(); g.draw(rec)
            # split into contours; the dot is the contour sitting above the x-height
            contours, cur = [], []
            for op, args in rec.value:
                cur.append((op, args))
                if op in ("closePath", "endPath"):
                    contours.append(cur); cur = []
            stem, top = [], None
            for c in contours:
                ys = [pt[1] for op, args in c for pt in args]
                if ys and min(ys) > xh * 0.95:
                    top = (min(pt[0] for op, args in c for pt in args), min(ys), max(pt[0] for op, args in c for pt in args), max(ys))
                else:
                    stem.append(c)
            pen = SVGPathPen(gs); tp = TransformPen(pen, (1, 0, 0, -1, x, 0))
            for c in stem:
                for op, args in c:
                    getattr(tp, op)(*args)
            letters.append(pen.getCommands())
            # stride dot: a parallelogram the height of the original dot, leaning at the stride angle
            x0, y0, x1, y1 = top
            hgt = y1 - y0; lean = hgt / math.tan(math.radians(ANGLE))
            wdt = (x1 - x0) * 1.04
            cxd = x + (x0 + x1) / 2
            dot = [(cxd - wdt / 2 - lean / 2, -y0), (cxd + wdt / 2 - lean / 2, -y0), (cxd + wdt / 2 + lean / 2, -y1), (cxd - wdt / 2 + lean / 2, -y1)]
        else:
            pen = SVGPathPen(gs); g.draw(TransformPen(pen, (1, 0, 0, -1, x, 0)))
            letters.append(pen.getCommands())
        x += g.width - 0.01 * upm
    width = x + 0.01 * upm
    asc = max(-p[1] for p in dot)
    return " ".join(letters), "M" + " L".join(f"{a:.1f},{b:.1f}" for a, b in dot) + " Z", width, xh, asc, f


def wordmark_group(x, y, height_x, letters_fill, dot_fill):
    """Places the wordmark with its x-height = height_x, baseline at y."""
    letters, dot, width, xh, asc, _ = wordmark_paths()
    s = height_x / xh
    return (f'<g transform="translate({x:.2f} {y:.2f}) scale({s:.5f})"><path d="{letters}" fill="{letters_fill}"/>'
            f'<path d="{dot}" fill="{dot_fill}"/></g>'), width * s


def build_logos():
    letters, dot, width, xh, asc, f = wordmark_paths()
    desc = -f["OS/2"].sTypoDescender
    # wordmark alone: x-height 200
    s = 200 / xh
    top = asc * s; bottom = desc * s * 0.7
    for name, lf, df in (("wordmark-ink", INK, COBALT), ("wordmark-white", WHITE, VOLT), ("wordmark-cobalt", COBALT, COBALT)):
        g, w = wordmark_group(0, top, 200, lf, df)
        write(name, svg(w, top + bottom + 10, g), png=1600 if name == "wordmark-ink" else None)
    # symbol alone (square artboard, mark 80% tall)
    for name, c in (("symbol-cobalt", COBALT), ("symbol-ink", INK), ("symbol-white", WHITE)):
        write(name, svg(1000, 1000, stride(500, 500, 800, c)), png=1024 if name == "symbol-cobalt" else None)
    # lockup: symbol height = 1, wordmark x-height = 0.5, gap = 0.3
    def lockup(name, sc, lf, df, bg=None, pad=0):
        sh = 400
        hx = sh * 0.5
        g, w = wordmark_group(0, 0, hx, lf, df)
        sw = sh * M["aspect"]; gap = sh * 0.3
        W = pad * 2 + sw + gap + w
        H = pad * 2 + sh
        # align wordmark baseline to the bottom of the symbol's lower bowl, x-height centred
        base = pad + sh / 2 + hx / 2
        body = stride(pad + sw / 2, pad + sh / 2, sh, sc) + g.replace("translate(0.00 0.00)", f"translate({pad + sw + gap:.2f} {base:.2f})")
        write(name, svg(W, H, body, bg), png=1800 if bg or name == "lockup-ink" else None)
    lockup("lockup-ink", COBALT, INK, COBALT)
    lockup("lockup-white", WHITE, WHITE, VOLT)
    lockup("lockup-on-cobalt", WHITE, WHITE, VOLT, COBALT, pad=240)
    lockup("lockup-on-ink", COBALT_HI, WHITE, VOLT, INK, pad=240)
    print("logos")


# ----------------------------------------------------------------------------- app icons
def rays(cx, cy, n=16, r=900, color=WHITE, op=0.07):
    out = []
    for i in range(n):
        a0 = 2 * math.pi * i / n; a1 = a0 + math.pi / n * 0.8
        out.append(f'M{cx:.1f},{cy:.1f} L{cx + r * math.cos(a0):.1f},{cy + r * math.sin(a0):.1f} L{cx + r * math.cos(a1):.1f},{cy + r * math.sin(a1):.1f} Z')
    return f'<path d="{" ".join(out)}" fill="{color}" opacity="{op}"/>'


def build_icons():
    import steppie
    grad = (f'<defs><radialGradient id="g" cx="0.5" cy="0.38" r="0.75"><stop offset="0" stop-color="{COBALT_HI}"/>'
            f'<stop offset="1" stop-color="{COBALT_LO}"/></radialGradient></defs>')
    # Primary: Steppie's face on a floodlit cobalt field, the stride slash behind him
    s = 2.85
    head = steppie.head_group("happy", 3, tx=512 - 200 * s, ty=548 - 150 * s, scale=s)
    slash = (f'<path d="M700,1024 L930,1024 L1024,860 L1024,600 Z" fill="{VOLT}"/>')
    icon = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{grad}'
            f'<rect width="1024" height="1024" fill="url(#g)"/>{rays(512, 470)}{slash}{head}</svg>\n')
    write("appicon", icon, png=1024, folder=ICON)
    dark = icon.replace('fill="url(#g)"', f'fill="{INK}"').replace(f'fill="{WHITE}" opacity="0.07"', f'fill="{COBALT}" opacity="0.18"')
    write("appicon-dark", dark, png=1024, folder=ICON)
    tinted = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
              f'<rect width="1024" height="1024" fill="#000"/>{stride(512, 512, 700, WHITE)}</svg>\n')
    write("appicon-tinted", tinted, png=1024, folder=ICON)
    # Alternate (Pro): the Stride S
    alt = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{grad}'
           f'<rect width="1024" height="1024" fill="url(#g)"/>{stride(512, 512, 640, WHITE)}</svg>\n')
    write("appicon-stride", alt, png=1024, folder=ICON)
    print("icons")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        make_fonts(sys.argv[1])
    build_logos()
    build_icons()

"""Renders Steppie + cast marketing assets into brand/mascot/renders/.  python3 render_assets.py
Needs the Steppie fonts installed (brand/fonts) and rsvg-convert."""
import math, os, subprocess
import cast
import steppie

OUT = os.path.join(os.path.dirname(__file__), "..", "renders")
os.makedirs(OUT, exist_ok=True)
COBALT, COBALT_HI, COBALT_LO, INK, VOLT = "#1F4FD8", "#3A6AF2", "#1638A8", "#0E1116", "#C8F03C"
LOGO = os.path.join(os.path.dirname(__file__), "../../logo")


def _inner(path):
    s = open(path).read()
    vb = [float(x) for x in s.split('viewBox="0 0 ')[1].split('"')[0].split()]
    return s[s.index(">", s.index("<svg")) + 1:s.rindex("</svg>")], vb


LOCKUP, (LW, LH) = _inner(os.path.join(LOGO, "lockup-white.svg"))


def lockup(x, y, h):
    s = h / LH
    return f'<g transform="translate({x} {y}) scale({s})">{LOCKUP}</g>'


def text(x, y, s, size, fill="#fff", family="SteppieWide", weight=900, anchor="start", spacing=0, opacity=1):
    esc = s.replace("&", "&amp;").replace("<", "&lt;")
    return (f'<text x="{x}" y="{y}" font-family="{family}" font-weight="{weight}" font-size="{size}" fill="{fill}" '
            f'text-anchor="{anchor}" letter-spacing="{spacing}" opacity="{opacity}">{esc}</text>')


def ui(x, y, s, size, fill="#fff", weight=600, anchor="start", opacity=1):
    return text(x, y, s, size, fill, family="Inter, Helvetica, Arial, sans-serif", weight=weight, anchor=anchor, opacity=opacity)


def bg(w, h, cy=0.35):
    return (f'<defs><radialGradient id="bg" cx="0.5" cy="{cy}" r="0.9"><stop offset="0" stop-color="{COBALT_HI}"/>'
            f'<stop offset="1" stop-color="{COBALT_LO}"/></radialGradient></defs><rect width="{w}" height="{h}" fill="url(#bg)"/>')


def rays(cx, cy, r, n=20, op=0.06):
    d = []
    for i in range(n):
        a0 = 2 * math.pi * i / n; a1 = a0 + math.pi / n * 0.9
        d.append(f"M{cx:.0f},{cy:.0f} L{cx + r * math.cos(a0):.0f},{cy + r * math.sin(a0):.0f} L{cx + r * math.cos(a1):.0f},{cy + r * math.sin(a1):.0f} Z")
    return f'<path d="{" ".join(d)}" fill="#fff" opacity="{op}"/>'


def sparkles(pts, color="#fff"):
    out = []
    for x, y, r in pts:
        out.append(f'<path d="M{x},{y-r} Q{x},{y} {x+r},{y} Q{x},{y} {x},{y+r} Q{x},{y} {x-r},{y} Q{x},{y} {x},{y-r} Z" fill="{color}" opacity="0.85"/>')
    return "".join(out)


def stride_slash(x, y, h, color=VOLT):
    t = h / math.tan(math.radians(58))
    return f'<path d="M{x},{y+h} L{x+h*0.3},{y+h} L{x+h*0.3+t},{y} L{x+t},{y} Z" fill="{color}"/>'


def save(name, w, h, body):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'
    p = os.path.join(OUT, name)
    open(p + ".svg", "w").write(svg)
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), p + ".svg", "-o", p + ".png"], check=True)
    print("rendered", name)


def st(mood, pose, mane, cx, bottom, height, **kw):
    s = height / 460
    return steppie.svg_group(mood, pose, mane, tx=cx - 200 * s, ty=bottom - 460 * s, scale=s, **kw)


def cm(who, mood, cx, bottom, height, arms=(0, 0)):
    s = height / 460
    return cast.svg_group(who, mood, tx=cx - 200 * s, ty=bottom - 460 * s, scale_=s, arms=arms)


# 1. Character sheet -----------------------------------------------------------
def character_sheet():
    W, H = 2400, 1600
    b = [bg(W, H), rays(1200, 520, 1600, op=0.04)]
    b.append(lockup(90, 80, 74))
    b.append(text(90, 270, "MEET THE CREW.", 112))
    b.append(ui(94, 330, "Steppie leads. Everyone else has one job.", 40, "#C9D6FF", 500))
    # lead + cast line-up
    b.append(st("cheer", "cheer", 3, 1200, 1010, 620))
    for i, (who, mood, arms, x) in enumerate([("dash", "wink", (0, -100), 420), ("shelly", "cheer", (0, 0), 780), ("pip", "cheer", (0, -30), 1620), ("bo", "happy", (0, -120), 1980)]):
        b.append(cm(who, mood, x, 1000, 440, arms))
    names = [("Dash", "The pacer", 420), ("Shelly", "Keeper of Shields", 780), ("Steppie", "Your running buddy", 1200), ("Pip", "Brings the news", 1620), ("Bo", "Guards the Vault", 1980)]
    for n, role, x in names:
        b.append(f'<rect x="{x-170}" y="1040" width="340" height="120" rx="28" fill="#fff" opacity="0.1"/>')
        b.append(text(x, 1098, n.upper(), 46, VOLT if n == "Steppie" else "#fff", anchor="middle"))
        b.append(ui(x, 1140, role, 28, "#C9D6FF", 600, "middle"))
    b.append(text(90, 1300, "THE MANE GROWS WITH YOU", 50, VOLT, spacing=2))
    for i, (lvl, name) in enumerate([(0, "Cub"), (1, "Young lion"), (2, "Lion"), (3, "King of the track")]):
        cx = 1150 + i * 330
        b.append(st("happy" if lvl < 3 else "proud", "idle", lvl, cx, 1540, 260))
        b.append(ui(cx, 1580, name, 26, "#fff", 700, "middle"))
    b.append(ui(94, 1356, "Hit your goal and Steppie's mane fills out.", 32, "#C9D6FF", 500))
    b.append(ui(94, 1400, "Finish races, earn Shoe Boxes, collect his trainers.", 32, "#C9D6FF", 500))
    b.append(sparkles([(300, 520, 14), (2100, 420, 18), (1700, 300, 10), (640, 700, 12)]))
    save("cast-character-sheet", W, H, "".join(b))


# 2. X header 1500x500 -----------------------------------------------------------
def x_header():
    W, H = 1500, 500
    b = [bg(W, H, 0.5), rays(1150, 300, 1100, op=0.05)]
    b.append(text(80, 200, "BACK YOURSELF.", 86))
    b.append(text(80, 296, "KEEP YOUR MONEY.", 86, VOLT))
    b.append(ui(84, 356, "Put money on your daily walk. Finish and every cent comes back.", 28, "#C9D6FF", 500))
    b.append(lockup(84, 400, 50))
    b.append(cm("dash", "wink", 1010, 492, 260, (0, -90)))
    b.append(cm("shelly", "cheer", 1390, 492, 250))
    b.append(st("cheer", "cheer", 3, 1200, 498, 440))
    b.append(sparkles([(940, 120, 12), (1440, 90, 16), (1300, 60, 9)]))
    save("x-header", W, H, "".join(b))


# 3. Social posts 1080x1350 --------------------------------------------------------
def post(name, l1, l2, sub, art, accent=VOLT):
    W, H = 1080, 1350
    b = [bg(W, H, 0.65), rays(540, 980, 1300, op=0.05)]
    size = min(112, 900 / (max(len(l1), len(l2)) * 0.74))
    b.append(text(80, 210, l1, size))
    b.append(text(80, 210 + size * 1.07, l2, size, accent))
    b.append(ui(84, 404, sub, 34, "#C9D6FF", 500))
    b.append(art)
    b.append(lockup(80, 1236, 58))
    b.append(ui(1000, 1276, "#BackYourself", 30, "#C9D6FF", 600, "end"))
    save(name, W, H, "".join(b))


def chip(cx, cy, r, color, label):
    teeth = "".join(
        f'<path d="M{cx + (r-1) * math.cos(a - 0.12):.1f},{cy + (r-1) * math.sin(a - 0.12):.1f} A{r-1},{r-1} 0 0 1 {cx + (r-1) * math.cos(a + 0.12):.1f},{cy + (r-1) * math.sin(a + 0.12):.1f}" stroke="#fff" stroke-width="{r*0.18:.1f}" fill="none"/>'
        for a in [i * math.pi / 4 for i in range(8)])
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}"/>{teeth}<circle cx="{cx}" cy="{cy}" r="{r*0.7}" fill="{color}" stroke="#fff" stroke-opacity="0.7" stroke-width="3"/>'
            + text(cx, cy + r * 0.18, label, r * 0.5, "#fff", family="SteppieBib", anchor="middle"))


def posts():
    post("post-back-yourself", "BACK", "YOURSELF.", "Put money on your walk. Finish and it all comes back.",
         st("roar", "flex", 3, 540, 1190, 720) + sparkles([(200, 700, 18), (880, 620, 14), (840, 980, 10)]))
    post("post-keep-your-money", "FINISH.", "KEEP EVERY CENT.", "Short races are only a hold on your card.",
         st("cheer", "cheer", 2, 600, 1190, 690) + cm("bo", "cheer", 230, 1190, 380, (0, -120)))
    post("post-shelly-shields", "BAD DAY?", "SHELLY'S GOT IT.", "Shields cover a missed day. Unused ones come back.",
         cm("shelly", "cheer", 540, 1190, 680))
    post("post-dash-pacer", "DASH IS", "AHEAD OF YOU.", "Your pacer runs the track all day. Catch him.",
         cm("dash", "wink", 340, 1190, 600, (0, -90)) + st("focus", "run", 2, 780, 1190, 560, lean=6))
    chips = "".join(chip(180 + i * 180, 560, 72, c, l) for i, (c, l) in enumerate([("#9AA3B2", "€5"), ("#22B37A", "€10"), ("#1F4FD8", "€20"), ("#7C5CFF", "€50"), ("#FFB020", "€100")]))
    post("post-tables", "PICK YOUR", "TABLE.", "Bigger stake, more Grit. Climb the weekly league.",
         chips + st("proud", "point", 3, 560, 1190, 560))
    post("post-comeback", "MISSED?", "COME BACK.", "Finish a Comeback and win back half your stake.",
         st("focus", "flex", 2, 540, 1190, 700) + sparkles([(220, 640, 16), (860, 720, 12)]))


# 4. Emoji / avatars 512x512 (transparent) ----------------------------------------
def emoji():
    for mood in ["happy", "cheer", "roar", "worried", "sleep", "wink", "proud", "focus"]:
        s = 500 / 330
        g = steppie.head_group(mood, 3 if mood in ("roar", "proud") else 2, tx=256 - 200 * s, ty=256 - 152 * s, scale=s)
        p = os.path.join(OUT, f"emoji-steppie-{mood}")
        open(p + ".svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">{g}</svg>')
        subprocess.run(["rsvg-convert", "-w", "512", "-h", "512", p + ".svg", "-o", p + ".png"], check=True)
    for who in cast.CAST:
        g = cm(who, "cheer", 256, 500, 480)
        p = os.path.join(OUT, f"emoji-{who}")
        open(p + ".svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">{g}</svg>')
        subprocess.run(["rsvg-convert", "-w", "512", "-h", "512", p + ".svg", "-o", p + ".png"], check=True)
    s = 740 / 330
    g = steppie.head_group("happy", 3, tx=512 - 200 * s, ty=540 - 152 * s, scale=s)
    save("avatar-steppie", 1024, 1024, f'<clipPath id="c"><circle cx="512" cy="512" r="512"/></clipPath><g clip-path="url(#c)">{bg(1024, 1024)}{rays(512, 512, 900)}{g}</g>')
    print("rendered emoji")


if __name__ == "__main__":
    character_sheet(); x_header(); posts(); emoji()

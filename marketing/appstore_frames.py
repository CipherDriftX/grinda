"""Composes App Store marketing screenshots (1320 x 2868, the 6.9" class):
headline + real Simulator capture + a member of the cast. Output: ios/fastlane/screenshots/en-US/.

    python3 marketing/appstore_frames.py
"""
import base64, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "brand/mascot/tools"))
import cast  # noqa: E402
import steppie  # noqa: E402
import math  # noqa: E402

SHOTS = os.path.join(ROOT, "screenshots/light")
OUT = os.path.join(ROOT, "ios/fastlane/screenshots/en-US")
os.makedirs(OUT, exist_ok=True)
W, H = 1320, 2868
COBALT, VOLT = "#1F4FD8", "#C8F03C"

FRAMES = [
    # file, line 1, line 2 (volt), who pops out of the frame (None when the screen already shows them), mood, side
    ("today", "STEPPIE RUNS", "YOUR LAPS.", None, None, "left"),
    ("contract", "BACK YOURSELF.", "PICK YOUR TABLE.", "steppie", "focus", "right"),
    ("entered", "BIB PINNED.", "GAME ON.", None, None, "left"),
    ("finish", "FINISH.", "KEEP EVERY CENT.", None, None, "left"),
    ("comeback", "MISSED A DAY?", "COME BACK.", "steppie", "focus", "right"),
    ("league", "CLIMB THE", "WEEKLY LEAGUE.", None, None, "left"),
    ("shields", "BAD DAY?", "SHELLY'S GOT IT.", None, None, "right"),
    ("shoebox-open", "EVERY FINISH:", "NEW KICKS.", None, None, "left"),
    ("wallet", "EVERY CENT.", "IN THE VAULT.", None, None, "right"),
]


def rays(cx, cy, r, n=22, op=0.05):
    d = []
    for i in range(n):
        a0 = 2 * math.pi * i / n; a1 = a0 + math.pi / n * 0.9
        d.append(f"M{cx:.0f},{cy:.0f} L{cx + r * math.cos(a0):.0f},{cy + r * math.sin(a0):.0f} L{cx + r * math.cos(a1):.0f},{cy + r * math.sin(a1):.0f} Z")
    return f'<path d="{" ".join(d)}" fill="#fff" opacity="{op}"/>'


def text(x, y, s, size, fill):
    return (f'<text x="{x}" y="{y}" font-family="SteppieWide" font-weight="900" font-size="{size}" '
            f'fill="{fill}" text-anchor="middle">{s}</text>')


def frame(name, l1, l2, who, mood, side, idx):
    src = os.path.join(SHOTS, f"{name}.png")
    if not os.path.exists(src):
        print("skip", name)
        return
    data = base64.b64encode(open(src, "rb").read()).decode()
    sw = 1000
    sh = sw * 2868 / 1320
    sx, sy = (W - sw) / 2, 640
    r = 96
    size = min(150, 1180 / (max(len(l1), len(l2)) * 0.74))
    gh = 560
    gs = gh / 460
    gx = (sx - 120) if side == "left" else (sx + sw - 400 * gs + 120)
    gy = H - gh - 70
    art = ""
    if who == "steppie":
        art = steppie.svg_group(mood, "flex", 3, tx=gx, ty=gy, scale=gs)
    elif who:
        art = cast.svg_group(who, mood, tx=gx, ty=gy, scale_=gs)
    body = f'''
    <defs>
      <clipPath id="c"><rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="{r}"/></clipPath>
      <filter id="s" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="30" stdDeviation="40" flood-color="#0E1116" flood-opacity="0.35"/></filter>
      <radialGradient id="bg" cx="0.5" cy="0.2" r="0.9"><stop offset="0" stop-color="#3A6AF2"/><stop offset="1" stop-color="#1638A8"/></radialGradient>
    </defs>
    <rect width="{W}" height="{H}" fill="url(#bg)"/>
    {rays(W/2, 380, 2600)}
    {text(W/2, 300, l1, size, "#fff")}
    {text(W/2, 300 + size * 1.08, l2, size, VOLT)}
    <rect x="{sx-14}" y="{sy-14}" width="{sw+28}" height="{sh+28}" rx="{r+14}" fill="#0E1116" filter="url(#s)"/>
    <image x="{sx}" y="{sy}" width="{sw}" height="{sh}" href="data:image/png;base64,{data}" clip-path="url(#c)" preserveAspectRatio="xMidYMin slice"/>
    {art}
    '''
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{body}</svg>'
    tmp = os.path.join(OUT, f"_{name}.svg")
    open(tmp, "w").write(svg)
    dst = os.path.join(OUT, f"{idx:02d}_{name}.png")
    subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), tmp, "-o", dst], check=True)
    os.remove(tmp)
    print("framed", dst)


if __name__ == "__main__":
    for i, f in enumerate(FRAMES, 1):
        frame(*f, idx=i)

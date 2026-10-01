"""Composes App Store marketing screenshots (1320 x 2868, the 6.9" class):
headline + real Simulator capture + Grin. Output: ios/fastlane/screenshots/en-US/.

    python3 marketing/appstore_frames.py
"""
import base64, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "brand/mascot/tools"))
import grin  # noqa: E402

SHOTS = os.path.join(ROOT, "screenshots/light")
OUT = os.path.join(ROOT, "ios/fastlane/screenshots/en-US")
os.makedirs(OUT, exist_ok=True)
W, H = 1320, 2868
COBALT, VOLT = "#1F4FD8", "#C8F03C"

FRAMES = [
    # file, line 1, line 2 (volt), grin mood (None when Grin is already on screen), pose, mane, side
    ("today", "YOUR STEPS.", "ON A TRACK.", None, None, 2, "left"),
    ("pinning", "PUT MONEY", "ON YOUR WALK.", None, None, 2, "right"),
    ("finish", "FINISH.", "GET IT ALL BACK.", None, None, 3, "left"),
    ("wallet", "EVERY CENT.", "IN PLAIN SIGHT.", "wink", "wave", 2, "right"),
    ("progress", "GROW YOUR MANE.", "LOSE THE WEIGHT.", None, None, 3, "left"),
    ("races", "PICK A RACE.", "START SMALL.", "happy", "idle", 1, "right"),
]


def text(x, y, s, size, fill):
    return (f'<text x="{x}" y="{y}" font-family="Grinda Bib" font-weight="900" font-size="{size}" '
            f'fill="{fill}" text-anchor="middle">{s}</text>')


def frame(name, l1, l2, mood, pose, mane, side, idx):
    src = os.path.join(SHOTS, f"{name}.png")
    if not os.path.exists(src):
        print("skip", name)
        return
    data = base64.b64encode(open(src, "rb").read()).decode()
    sw = 1000
    sh = sw * 2868 / 1320
    sx, sy = (W - sw) / 2, 640
    r = 96
    gh = 520
    gs = gh / 460
    gx = (sx - 120) if side == "left" else (sx + sw - 400 * gs + 120)
    gy = H - gh - 70
    body = f'''
    <defs>
      <clipPath id="c"><rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="{r}"/></clipPath>
      <filter id="s" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="30" stdDeviation="40" flood-color="#0E1116" flood-opacity="0.35"/></filter>
    </defs>
    <rect width="{W}" height="{H}" fill="{COBALT}"/>
    <rect x="-200" y="{H*0.58}" width="{W+400}" height="1500" rx="750" fill="none" stroke="#fff" stroke-width="140" opacity="0.06"/>
    {text(W/2, 300, l1, 150, "#fff")}
    {text(W/2, 460, l2, 150, VOLT)}
    <rect x="{sx-14}" y="{sy-14}" width="{sw+28}" height="{sh+28}" rx="{r+14}" fill="#0E1116" filter="url(#s)"/>
    <image x="{sx}" y="{sy}" width="{sw}" height="{sh}" href="data:image/png;base64,{data}" clip-path="url(#c)" preserveAspectRatio="xMidYMin slice"/>
    {grin.group(mood, pose, mane, tx=gx, ty=gy, scale=gs) if mood else ''}
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

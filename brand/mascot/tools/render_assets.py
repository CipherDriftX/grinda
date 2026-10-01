"""Renders Steppie marketing assets into brand/mascot/renders/.  python3 render_assets.py"""
import os, subprocess
import grin

OUT = os.path.join(os.path.dirname(__file__), "..", "renders")
os.makedirs(OUT, exist_ok=True)
COBALT, INK, TYVEK, VOLT, GROUND = "#1F4FD8", "#0E1116", "#F4F6F8", "#C8F03C", "#E9ECF1"
LOCKUP = open(os.path.join(os.path.dirname(__file__), "../../logo/lockup-white.svg")).read()
LOCKUP_INNER = LOCKUP[LOCKUP.index(">", LOCKUP.index("<svg")) + 1:LOCKUP.rindex("</svg>")]
LW, LH = [float(x) for x in LOCKUP.split('viewBox="0 0 ')[1].split('"')[0].split()]


def lockup(x, y, h):
    s = h / LH
    return f'<g transform="translate({x} {y}) scale({s})">{LOCKUP_INNER}</g>'


def text(x, y, s, size, fill="#fff", family="Steppie Bib", weight=900, anchor="start", spacing=0, opacity=1):
    esc = s.replace("&", "&amp;").replace("<", "&lt;")
    return (f'<text x="{x}" y="{y}" font-family="{family}" font-weight="{weight}" font-size="{size}" fill="{fill}" '
            f'text-anchor="{anchor}" letter-spacing="{spacing}" opacity="{opacity}">{esc}</text>')


def ui(x, y, s, size, fill="#fff", weight=600, anchor="start", opacity=1):
    return text(x, y, s, size, fill, family="Inter, Helvetica, Arial, sans-serif", weight=weight, anchor=anchor, opacity=opacity)


def track(cx, cy, w, h, lane=60, op=0.1):
    return (f'<rect x="{cx-w/2}" y="{cy-h/2}" width="{w}" height="{h}" rx="{h/2}" fill="none" stroke="#fff" '
            f'stroke-width="{lane}" opacity="{op}"/>')


def save(name, w, h, body, bg=COBALT):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><rect width="{w}" height="{h}" fill="{bg}"/>{body}</svg>'
    p = os.path.join(OUT, name)
    open(p + ".svg", "w").write(svg)
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), p + ".svg", "-o", p + ".png"], check=True)
    print("rendered", name)


def grin_at(mood, pose, mane, cx, bottom, height, tilt=0):
    s = height / 460
    return grin.group(mood, pose, mane, tx=cx - 200 * s, ty=bottom - 460 * s, scale=s, head_tilt=tilt)


# 1. Character sheet ---------------------------------------------------------
def character_sheet():
    W, H = 2400, 1500
    b = [track(1700, 360, 1500, 560, 90, 0.06)]
    b.append(lockup(90, 80, 70))
    b.append(text(90, 260, "MEET GRIN.", 120))
    b.append(ui(94, 320, "The Steppie lion. Walks with you, grows with you.", 40, "#C9D6FF", 500))
    moods = [("happy", "idle", "Happy"), ("cheer", "cheer", "Goal hit"), ("roar", "flex", "Roar"), ("worried", "idle", "Behind pace"),
             ("sleep", "idle", "Night"), ("wink", "wave", "Hey!"), ("proud", "hold", "Proud")]
    for i, (m, p, label) in enumerate(moods):
        cx = 190 + i * 320
        b.append(f'<rect x="{cx-145}" y="420" width="290" height="440" rx="36" fill="#fff" opacity="0.08"/>')
        b.append(grin_at(m, p, 2, cx, 800, 340))
        b.append(ui(cx, 840, label, 30, "#fff", 700, "middle"))
    b.append(text(90, 980, "THE MANE GROWS WITH YOU", 54, VOLT, spacing=2))
    b.append(ui(94, 1030, "Hit your goal and Steppie's mane fills out: goal days in the last 14.", 34, "#C9D6FF", 500))
    for i, (lvl, name, rng) in enumerate([(0, "Cub", "0-3 days"), (1, "Young lion", "4-7 days"), (2, "Lion", "8-11 days"), (3, "King of the track", "12-14 days")]):
        cx = 300 + i * 560
        b.append(grin_at("happy" if lvl < 3 else "proud", "idle", lvl, cx, 1390, 300))
        b.append(ui(cx, 1430, name, 34, "#fff", 700, "middle"))
        b.append(ui(cx, 1468, rng, 26, "#C9D6FF", 500, "middle"))
    # palette chips
    for i, (c, n) in enumerate([("#FFBE3D", "Fur"), ("#F0781E", "Mane"), (COBALT, "Band"), (VOLT, "Stripe")]):
        x = 1700 + i * 170
        b.append(f'<circle cx="{x}" cy="230" r="44" fill="{c}" stroke="#fff" stroke-width="4"/>')
        b.append(ui(x, 310, n, 26, "#fff", 600, "middle"))
    save("grin-character-sheet", W, H, "".join(b))


# 2. X header 1500x500 ----------------------------------------------------------
def x_header():
    W, H = 1500, 500
    b = [track(1150, 250, 900, 380, 70, 0.08)]
    b.append(text(80, 205, "MONEY ON THE LINE.", 92))
    b.append(text(80, 300, "LION AT YOUR SIDE.", 92, VOLT))
    b.append(ui(84, 362, "Stake money on your daily walk. Finish and get every cent back.", 30, "#C9D6FF", 500))
    b.append(lockup(84, 405, 44))
    b.append(grin_at("cheer", "cheer", 3, 1230, 490, 450, tilt=-4))
    save("x-header", W, H, "".join(b))


# 3. Social posts 1080x1350 -------------------------------------------------------
def post(name, l1, l2, mood, pose, mane, sub, accent=VOLT, extra=""):
    W, H = 1080, 1350
    b = [track(540, 980, 1200, 760, 110, 0.07)]
    b.append(text(80, 200, l1, 132))
    b.append(text(80, 330, l2, 132, accent))
    b.append(ui(84, 410, sub, 36, "#C9D6FF", 500))
    b.append(extra or grin_at(mood, pose, mane, 540, 1190, 700))
    b.append(lockup(80, 1240, 52))
    b.append(ui(1000, 1278, "#BackYourself", 30, "#C9D6FF", 600, "end"))
    save(name, W, H, "".join(b))


def posts():
    post("post-mane-goal", "MANE GOAL:", "WALK.", "roar", "flex", 3, "Every goal day grows Steppie's mane.")
    post("post-keep-your-money", "WALK IT OFF.", "KEEP YOUR MONEY.", "happy", "wave", 2, "Hit your steps and every cent comes back.")
    post("post-hold-it", "HOLD IT. WALK IT.", "GET IT BACK.", "proud", "hold", 2, "Short races are only a hold. Never a charge if you finish.")
    evo = "".join(grin_at("happy" if l < 3 else "proud", "idle", l, 170 + l * 247, 1150, 300 + l * 40) for l in range(4))
    post("post-grow-your-mane", "GROW", "YOUR MANE.", None, None, None, "Cub to King of the track, one goal day at a time.", extra=evo)
    medal = ('<circle cx="760" cy="700" r="120" fill="#F0A21E"/><circle cx="760" cy="700" r="104" fill="#FFD25A"/>'
             + text(760, 735, "OCT", 92, "#7A3E00", anchor="middle"))
    post("post-walktober", "WALKTOBER", "IS ON.", "cheer", "cheer", 2, "Finish a race in October. Limited-edition medal.",
         extra=medal + grin_at("cheer", "cheer", 2, 400, 1190, 640))


# 4. Discord emoji / avatars 512x512 (transparent) --------------------------------
def emoji():
    for mood in ["happy", "cheer", "roar", "worried", "sleep", "wink", "proud"]:
        s = 500 / 330
        g = grin.head_group(mood, 3 if mood in ("roar", "proud") else 2, tx=256 - 200 * s, ty=256 - 178 * s, scale=s)
        p = os.path.join(OUT, f"emoji-grin-{mood}")
        open(p + ".svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">{g}</svg>')
        subprocess.run(["rsvg-convert", "-w", "512", "-h", "512", p + ".svg", "-o", p + ".png"], check=True)
    # Discord/X avatar: head on cobalt circle
    s = 760 / 330
    g = grin.head_group("happy", 3, tx=512 - 200 * s, ty=530 - 178 * s, scale=s)
    save("avatar-grin", 1024, 1024, f'<circle cx="512" cy="512" r="512" fill="{COBALT}"/>{g}', bg="none")
    print("rendered emoji")


if __name__ == "__main__":
    character_sheet(); x_header(); posts(); emoji()

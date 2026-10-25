"""Steppie, the Steppie lion. Single source of truth for the mascot's geometry.

A chibi lion runner: sweatband, cobalt singlet with a race bib, navy shorts and
chunky running shoes with a volt midsole. Built only from ellipses, capsules
and béziers (absolute M/L/C/Q/Z), so the same data renders as SVG here and as
native SwiftUI paths in the app.

Canvas: 400 x 460 units, y down. Parts belong to rig groups with pivots:
arms swing from the shoulders, legs lift from the hips, the head tilts from the
neck, the tail swishes from its base and the eyes blink about the eye line.
"""
import math
from geom import Builder, capsule, circle, curve, el, ellipse, mirror, move, poly, rrect, scale, soft_star, taper

W, H = 400, 460

C = {
    "mane": "#F0781E", "maneLight": "#FF9A3C", "maneShade": "#D9601A",
    "fur": "#FFBE3D", "furShade": "#F2A12A", "furLight": "#FFD677", "muzzle": "#FFEBC2",
    "ink": "#0E1116", "nose": "#4A2814", "white": "#FFFFFF", "blush": "#FF8F6B",
    "tongue": "#FF6F61", "mouth": "#5A1E14",
    "cobalt": "#1F4FD8", "cobaltDeep": "#1638A8", "cobaltLight": "#4A76F0",
    "volt": "#C8F03C", "bib": "#F4F6F8", "pin": "#B9C0CC",
    "shorts": "#172554", "shortsShade": "#0F1A3D",
    "shoe": "#FFFFFF", "shoeShade": "#D9E0EC", "sole": "#0E1116",
    "shadow": "#0E1116",
}

# Rig pivots
HEAD_DY = -30                     # the head is the classic Steppie-era head, lifted onto a taller body
NECK = (200, 232)
SHOULDER_L, SHOULDER_R = (150, 258), (250, 258)
HIP_L, HIP_R = (178, 346), (222, 346)
TAIL_BASE = (236, 332)
HEAD_SCALE = 0.92
EYE_Y = 262 + HEAD_DY - (262 - 182) * HEAD_SCALE
EYE_L, EYE_R = (160, EYE_Y), (240, EYE_Y)
GROUND = 452

MANE_LEVELS = {  # cub → king of the track
    0: dict(r=100, tuft=14, n=11),
    1: dict(r=108, tuft=22, n=13),
    2: dict(r=116, tuft=29, n=14),
    3: dict(r=124, tuft=38, n=15),
}

MOODS = ["happy", "calm", "cheer", "roar", "worried", "sleep", "wink", "proud", "focus"]
POSES = ["idle", "cheer", "wave", "hold", "flex", "point", "run"]


def stride_s(cx, cy, h):
    """The Steppie Stride S, simplified for small print (bib, shirt)."""
    from stride import mark_d
    return mark_d(cx, cy, h)


def head_parts(b, mane, mood):
    """The head in its original 400x460 coordinates, then lifted by HEAD_DY."""
    hb = Builder()
    hc = (200, 172)
    m = MANE_LEVELS[mane]
    hb.add("mane", "maneBack", soft_star(hc[0], hc[1] + 14, m["r"] + m["tuft"] * 0.25, m["r"] + m["tuft"], m["n"], -math.pi / 2 + math.pi / m["n"],
                                          squash=0.94, bottom_boost=m["tuft"] * 0.1, top_cut=m["tuft"] * 0.3), fill=C["maneShade"])
    hb.add("mane", "mane", soft_star(hc[0], hc[1] + 10, m["r"] - 6, m["r"] + m["tuft"] * 0.7, m["n"], -math.pi / 2,
                                      squash=0.94, bottom_boost=m["tuft"] * 0.06, top_cut=m["tuft"] * 0.4), fill=C["mane"])
    hb.add("mane", "maneLight", soft_star(hc[0], hc[1] - 4, m["r"] - 16, m["r"] + m["tuft"] * 0.35, m["n"], -math.pi / 2 + math.pi / (2 * m["n"]),
                                           squash=0.9, top_cut=m["tuft"] * 0.2), fill=C["maneLight"], opacity=0.55)
    for ex in (128, 272):
        hb.add("head", f"ear{ex}", ellipse(ex, 100, 22, 21), fill=C["fur"])
        hb.add("head", f"earIn{ex}", ellipse(ex, 103, 12, 11), fill=C["blush"], opacity=0.75)
    hb.add("head", "face", "M200,90 C266,90 302,130 302,180 C302,232 258,262 200,262 C142,262 98,232 98,180 C98,130 134,90 200,90 Z", fill=C["fur"])
    hb.add("head", "faceLight", ellipse(160, 128, 38, 20), fill=C["furLight"], opacity=0.55)
    hb.add("head", "faceShade", "M102,196 C110,236 150,262 200,262 C250,262 290,236 298,196 C282,236 246,250 200,250 C154,250 118,236 102,196 Z", fill=C["furShade"], opacity=0.5)
    hb.add("head", "muzzleL", ellipse(180, 228, 30, 24), fill=C["muzzle"])
    hb.add("head", "muzzleR", ellipse(220, 228, 30, 24), fill=C["muzzle"])
    hb.add("head", "chin", ellipse(200, 246, 16, 10), fill=C["muzzle"])
    hb.add("head", "cheekL", ellipse(122, 212, 15, 10), fill=C["blush"], opacity=0.55)
    hb.add("head", "cheekR", ellipse(278, 212, 15, 10), fill=C["blush"], opacity=0.55)
    for (x, y) in ((166, 228), (158, 236), (170, 240), (234, 228), (242, 236), (230, 240)):
        hb.add("head", f"dot{x}{y}", ellipse(x, y, 2.2, 2.2), fill=C["furShade"])
    # Sweatband: cobalt with a volt stripe
    hb.add("head", "band", "M108,136 C146,112 254,112 292,136 L289,152 C252,130 148,130 111,152 Z", fill=C["cobalt"])
    hb.add("head", "bandStripe", "M110,143 C148,120 252,120 290,143 L289.5,147 C251,125 149,125 110.5,147 Z", fill=C["volt"])
    hb.add("head", "forelock", "M150,128 C150,96 172,74 204,70 C190,84 188,96 192,104 C200,82 222,72 246,76 C230,86 226,98 228,108 C238,98 252,96 262,100 C250,108 246,122 248,134 C232,118 214,114 200,122 C186,112 166,114 150,128 Z", fill=C["mane"])
    hb.add("head", "forelockLight", "M162,118 C166,98 180,86 196,82 C186,94 184,104 186,112 C178,110 170,112 162,118 Z", fill=C["maneLight"], opacity=0.7)

    # Eyes: big, glossy, two highlights
    ex_l, ex_r = (160, 182), (240, 182)
    if mood == "sleep":
        for (ex, ey) in (ex_l, ex_r):
            hb.add("eyes", f"lid{ex}", curve((ex - 18, ey), (ex - 8, ey + 11), (ex + 8, ey + 11), (ex + 18, ey)), stroke=C["ink"], width=6)
    else:
        look = {"worried": (-4, 3), "proud": (0, -1), "roar": (0, 2), "focus": (4, 0)}.get(mood, (2, 2))
        for side, (ex, ey) in (("L", ex_l), ("R", ex_r)):
            if mood == "wink" and side == "R":
                hb.add("eyeR", "lidR", curve((ex - 18, ey + 4), (ex - 8, ey - 8), (ex + 8, ey - 8), (ex + 18, ey + 4)), stroke=C["ink"], width=6)
                continue
            hb.add(f"eye{side}", f"eyeWhite{side}", ellipse(ex, ey, 27, 31), fill=C["white"])
            hb.add(f"eye{side}", f"pupil{side}", ellipse(ex + look[0], ey + look[1], 18, 21), fill=C["ink"])
            hb.add(f"eye{side}", f"iris{side}", ellipse(ex + look[0], ey + look[1] + 7, 11, 9), fill="#2B1A10", opacity=0.9)
            hb.add(f"eye{side}", f"glint{side}", ellipse(ex + look[0] + 6, ey + look[1] - 8, 7, 7), fill=C["white"])
            hb.add(f"eye{side}", f"glint2{side}", ellipse(ex + look[0] - 6, ey + look[1] + 9, 3, 3), fill=C["white"])
            if mood in ("happy", "cheer", "proud"):
                hb.add(f"eye{side}", f"lid{side}", f"M{ex-30},{ey+24} C{ex-14},{ey+15} {ex+14},{ey+15} {ex+30},{ey+24} L{ex+30},{ey+36} L{ex-30},{ey+36} Z", fill=C["fur"])
            if mood == "focus":
                inner = 1 if side == "L" else -1
                hb.add(f"eye{side}", f"lidTop{side}", f"M{ex-30},{ey-34} L{ex+30},{ey-34} L{ex+30},{ey-12 + (8 if inner < 0 else -2)} L{ex-30},{ey-12 + (8 if inner > 0 else -2)} Z", fill=C["fur"])

    brows = {
        "worried": [(138, 152, 178, 146), (222, 146, 262, 152)],
        "roar": [(140, 146, 178, 156), (222, 156, 260, 146)],
        "focus": [(140, 148, 180, 158), (220, 158, 260, 148)],
        "proud": [(140, 150, 178, 146), (222, 146, 260, 150)],
        "sleep": [(140, 156, 178, 156), (222, 156, 260, 156)],
    }.get(mood, [(140, 154, 178, 150), (222, 150, 260, 154)])
    for i, (x1, y1, x2, y2) in enumerate(brows):
        hb.add("brows", f"brow{i}", capsule(x1, y1, x2, y2, 4.5), fill=C["maneShade"])

    hb.add("head", "nose", "M200,222 C190,222 181,212 185,205 C188,200 195,199 200,199 C205,199 212,200 215,205 C219,212 210,222 200,222 Z", fill=C["nose"])
    hb.add("head", "noseGlint", ellipse(194, 205, 4.5, 2.6), fill=C["white"], opacity=0.55)

    if mood in ("happy", "cheer", "roar", "proud", "focus"):
        h = {"happy": 16, "proud": 12, "cheer": 26, "roar": 36, "focus": 10}[mood]
        w = {"happy": 18, "proud": 15, "cheer": 22, "roar": 24, "focus": 20}[mood]
        top = 230
        hb.add("mouth", "mouthOpen", f"M{200-w},{top} C{200-w*0.5},{top+5} {200+w*0.5},{top+5} {200+w},{top} C{200+w},{top+h*0.75} {200+w*0.55},{top+h} 200,{top+h} C{200-w*0.55},{top+h} {200-w},{top+h*0.75} {200-w},{top} Z", fill=C["mouth"])
        if mood == "focus":
            hb.add("mouth", "teeth", f"M{200-w+4},{top+1.5} C{200-w*0.5},{top+5.5} {200+w*0.5},{top+5.5} {200+w-4},{top+1.5} L{200+w-6},{top+5} C{200+w*0.4},{top+8} {200-w*0.4},{top+8} {200-w+6},{top+5} Z", fill=C["white"])
        else:
            hb.add("mouth", "tongue", ellipse(200, top + h * 0.78, w * 0.55, h * 0.24), fill=C["tongue"])
        if mood == "roar":
            hb.add("mouth", "fangL", f"M186,{top+2} L192,{top+3} L189,{top+12} Z", fill=C["white"])
            hb.add("mouth", "fangR", f"M208,{top+3} L214,{top+2} L211,{top+12} Z", fill=C["white"])
    elif mood == "worried":
        hb.add("mouth", "mouth", curve((186, 240), (194, 233), (206, 233), (214, 240)), stroke=C["mouth"], width=5)
    elif mood == "sleep":
        hb.add("mouth", "mouth", ellipse(200, 236, 6, 5), fill=C["mouth"], opacity=0.8)
    else:
        hb.add("mouth", "mouth", curve((200, 222), (200, 230), (192, 238), (182, 234)), stroke=C["mouth"], width=5)
        hb.add("mouth", "mouth2", curve((200, 222), (200, 230), (208, 238), (218, 234)), stroke=C["mouth"], width=5)

    for p in hb.parts:
        p["d"] = scale(move(p["d"], 0, HEAD_DY), HEAD_SCALE, 200, 262 + HEAD_DY)
        b.parts.append(p)


def shoe(b, group, side, pal=None):
    """Chunky trainer under the ankle. Drawn for the left foot, mirrored for the right."""
    P = dict(sole=C["sole"], mid=C["volt"], upper=C["shoe"], shade=C["shoeShade"], stripe=C["cobalt"], lace=C["ink"])
    P.update(pal or {})
    parts = []

    def add(id_, d, **kw):
        parts.append((id_, d, kw))

    # left shoe: toe points out to the left
    add("outsole", "M126,434 C126,428 132,426 140,426 L196,426 C204,426 208,430 208,436 L208,440 C208,446 204,448 198,448 L136,448 C129,448 126,444 126,440 Z", fill=P["sole"])
    add("midsole", "M128,424 C128,418 134,416 142,416 L196,416 C203,416 206,420 206,425 L206,432 C206,436 203,438 198,438 L136,438 C131,438 128,435 128,431 Z", fill=P["mid"])
    add("upper", "M132,418 C130,404 142,392 162,388 C170,386 176,380 180,374 L198,374 C204,378 208,388 208,402 L208,418 Z", fill=P["upper"])
    add("upperShade", "M132,418 C134,412 142,408 152,408 L208,408 L208,418 Z", fill=P["shade"])
    add("toeCap", "M132,418 C131,408 138,398 150,394 C146,402 145,410 147,418 Z", fill=P["shade"])
    # two stride slashes on the side panel: the logo's cut, worn on the foot
    add("stripe1", poly((160, 414), (170, 414), (182, 392), (172, 392)), fill=P["stripe"])
    add("stripe2", poly((174, 414), (184, 414), (196, 392), (186, 392)), fill=P["stripe"])
    add("collar", ellipse(190, 376, 13, 4.5), fill=P["shade"])
    for i, (x, y) in enumerate(((170, 386), (178, 381), (186, 379))):
        add(f"lace{i}", capsule(x - 5, y + 2, x + 5, y - 2, 1.8), fill=P["lace"], opacity=0.8)
    for id_, d, kw in parts:
        d = move(scale(d, 0.86, 167, 448), -7, 0)
        d2 = d if side == "L" else mirror(d)
        b.add(group, f"{id_}{side}", d2, **kw)


def body_parts(b):
    # Ground shadow (its own group so it can shrink while Steppie is airborne)
    b.add("shadow", "shadow", ellipse(200, GROUND - 2, 92, 9), fill=C["shadow"], opacity=0.16)

    # Tail
    tb = TAIL_BASE
    b.add("tail", "tail", curve(tb, (290, 344), (330, 318), (318, 270)), stroke=C["fur"], width=13)
    b.add("tail", "tailTuft", soft_star(318, 260, 10, 21, 5, -math.pi / 2), fill=C["mane"])

    # Legs (fur, from under the shorts) + shoes
    for side, hip in (("L", HIP_L), ("R", HIP_R)):
        ankle = (hip[0] + (-10 if side == "L" else 10), 408)
        g = f"leg{side}"
        b.add(g, f"leg{side}", taper(hip[0], hip[1], ankle[0], ankle[1], 18, 14), fill=C["fur"])
        b.add(g, f"legShade{side}", taper(hip[0] + (6 if side == "L" else -6), hip[1] + 6, ankle[0] + (5 if side == "L" else -5), ankle[1], 7, 5), fill=C["furShade"], opacity=0.55)
        b.add(g, f"sock{side}", capsule(ankle[0] - 1, ankle[1] - 18, ankle[0], ankle[1] - 4, 14.5), fill=C["white"])
        b.add(g, f"sockStripe{side}", capsule(ankle[0] - 1, ankle[1] - 14, ankle[0], ankle[1] - 13, 14.6), fill=C["cobalt"])
        shoe(b, g, side)

    # Torso fur + cobalt singlet + race bib
    b.add("body", "torso", "M200,226 C236,226 256,240 258,262 L262,322 C262,338 236,348 200,348 C164,348 138,338 138,322 L142,262 C144,240 164,226 200,226 Z", fill=C["fur"])
    b.add("body", "singlet", "M162,232 C176,248 224,248 238,232 C250,236 256,246 256,262 L258,328 C258,338 236,344 200,344 C164,344 142,338 142,328 L144,262 C144,246 150,236 162,232 Z", fill=C["cobalt"])
    b.add("body", "singletShade", "M236,236 C250,242 256,252 256,264 L258,328 C258,336 248,340 236,342 C246,320 248,276 236,236 Z", fill=C["cobaltDeep"], opacity=0.8)
    b.add("body", "singletLight", "M152,250 C156,242 160,238 164,236 C160,262 158,296 160,326 C152,322 146,318 146,310 L147,266 C147,260 149,254 152,250 Z", fill=C["cobaltLight"], opacity=0.6)
    b.add("body", "neckTrim", curve((162, 233), (176, 250), (224, 250), (238, 233)), stroke=C["volt"], width=4)
    b.add("body", "bib", rrect(168, 266, 64, 52, 6), fill=C["bib"])
    b.add("body", "bibBand", "M168,308 L232,308 L232,312 C232,315.3 229.3,318 226,318 L174,318 C170.7,318 168,315.3 168,312 Z", fill=C["volt"])
    b.add("body", "bibMark", stride_s(200, 287, 30), fill=C["cobalt"])
    for x in (174, 226):
        b.add("body", f"pin{x}", ellipse(x, 272, 2.6, 2.6), fill=C["pin"])
    # Shorts with a volt side stripe
    b.add("body", "shorts", "M142,322 L258,322 L264,356 C265,361 262,364 257,364 L210,364 L200,348 L190,364 L143,364 C138,364 135,361 136,356 Z", fill=C["shorts"])
    b.add("body", "shortsShade", "M200,348 L210,364 L222,364 L206,342 Z", fill=C["shortsShade"])
    b.add("body", "shortsStripeL", poly((140, 334), (145, 334), (140, 362), (135, 360)), fill=C["volt"])
    b.add("body", "shortsStripeR", poly((255, 334), (260, 334), (265, 360), (260, 362)), fill=C["volt"])
    b.add("body", "waistband", rrect(142, 320, 116, 8, 4), fill=C["shortsShade"])

    # Arms (hanging; the app rotates them about the shoulders) with wristbands
    for side, sh in (("L", SHOULDER_L), ("R", SHOULDER_R)):
        sgn = -1 if side == "L" else 1
        hand = (sh[0] + 8 * sgn, sh[1] + 62)
        g = f"arm{side}"
        b.add(g, f"arm{side}", taper(sh[0], sh[1], hand[0], hand[1], 17, 14), fill=C["fur"])
        b.add(g, f"wrist{side}", capsule(hand[0] - 0.5 * sgn, hand[1] - 12, hand[0], hand[1] - 3, 15.5), fill=C["cobalt"])
        b.add(g, f"wristStripe{side}", capsule(hand[0] - 0.5 * sgn, hand[1] - 8, hand[0], hand[1] - 7, 15.6), fill=C["volt"])
        b.add(g, f"paw{side}", ellipse(hand[0], hand[1] + 8, 19, 17), fill=C["fur"])
        b.add(g, f"pawShade{side}", ellipse(hand[0] + 3 * sgn, hand[1] + 12, 13, 10), fill=C["furShade"], opacity=0.6)
        for k in (-7, 0, 7):
            b.add(g, f"pawToe{side}{k}", curve((hand[0] + k, hand[1] + 16), (hand[0] + k, hand[1] + 18), (hand[0] + k, hand[1] + 20), (hand[0] + k, hand[1] + 22)),
                  stroke=C["maneShade"], width=2.4, opacity=0.6)


def parts(mood="happy", pose="idle", mane=2):
    b = Builder()
    body_parts(b)
    head_parts(b, mane, mood)
    return b.parts


def arm_rotations(pose):
    """Degrees, clockwise-positive (y-down). Left arm swings out to the left with +."""
    return {"idle": (0, 0), "cheer": (150, -150), "wave": (8, -160), "hold": (-30, 30), "flex": (105, -105),
            "point": (6, -92), "run": (38, 30)}.get(pose, (0, 0))


def leg_lifts(pose):
    """Vertical knee lift per leg, in units (negative = up)."""
    return {"run": (-26, 0), "cheer": (0, 0)}.get(pose, (0, 0))


DRAW = ["shadow", "tail", "legL", "legR", "body", "armL", "armR", "mane", "head", "eyeL", "eyeR", "eyes", "brows", "mouth"]
HEAD_GROUPS = {"mane", "head", "eyeL", "eyeR", "eyes", "brows", "mouth"}


def svg_group(mood="happy", pose="idle", mane=2, tx=0, ty=0, scale=1.0, head_tilt=0, lean=0, hop=0):
    ps = parts(mood, pose, mane)
    rl, rr = arm_rotations(pose)
    ll, lr = leg_lifts(pose)
    groups = {}
    for p in ps:
        groups.setdefault(p["group"], []).append(p)
    chunks = []
    head_buf = []

    def flush_head():
        if head_buf:
            chunks.append(f'<g transform="rotate({head_tilt} {NECK[0]} {NECK[1]})">{"".join(head_buf)}</g>')
            head_buf.clear()

    for g in DRAW:
        if g not in groups:
            continue
        body = "".join(el(p) for p in groups[g])
        if g == "armL":
            body = f'<g transform="rotate({rl} {SHOULDER_L[0]} {SHOULDER_L[1]})">{body}</g>'
        elif g == "armR":
            body = f'<g transform="rotate({rr} {SHOULDER_R[0]} {SHOULDER_R[1]})">{body}</g>'
        elif g == "legL" and ll:
            body = f'<g transform="translate(0 {ll}) rotate(-8 {HIP_L[0]} {HIP_L[1]})">{body}</g>'
        elif g == "legR" and lr:
            body = f'<g transform="translate(0 {lr})">{body}</g>'
        if g in HEAD_GROUPS:
            head_buf.append(body)
        else:
            flush_head()
            if g == "shadow":
                chunks.append(body)
            else:
                chunks.append(f'<g transform="translate(0 {-hop})">{body}</g>' if hop else body)
    flush_head()
    inner = "".join(chunks)
    if lean:
        inner = f'<g transform="rotate({lean} 200 {GROUND})">{inner}</g>'
    return f'<g transform="translate({tx} {ty}) scale({scale})">{inner}</g>'


def svg(mood="happy", pose="idle", mane=2, size=None, bg=None, **kw):
    sw, sh = size or (W, H)
    b = f'<rect width="{sw}" height="{sh}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{sw}" height="{sh}" viewBox="0 0 {sw} {sh}">{b}'
            f'{svg_group(mood, pose, mane, **kw)}</svg>')


def head_group(mood="happy", mane=2, tx=0, ty=0, scale=1.0):
    """Head only (mane, face, expression): app icon, emoji, avatars."""
    ps = [p for p in parts(mood, "idle", mane) if p["group"] in HEAD_GROUPS]
    order = ["mane", "head", "eyeL", "eyeR", "eyes", "brows", "mouth"]
    ps = sorted(ps, key=lambda p: order.index(p["group"]))
    return f'<g transform="translate({tx} {ty}) scale({scale})">{"".join(el(p) for p in ps)}</g>'


if __name__ == "__main__":
    import sys
    open(sys.argv[1] if len(sys.argv) > 1 else "steppie.svg", "w").write(svg())

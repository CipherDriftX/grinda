"""Grin, the Grinda lion. Single source of truth for the mascot's geometry.

Everything is built from ellipses, capsules and béziers using only absolute
M / L / C / Q / Z path commands, so the same data renders here as SVG and in
the iOS app (Mascot.swift parses these strings into SwiftUI Paths).

Canvas: 400 x 460 units, y down. Each part belongs to a group with an anchor
so the app can rotate/scale it (arms swing from shoulders, head tilts from the
neck, tail swishes from its base, eyes blink about their centres).
"""
import json
import math

W, H = 400, 460

C = {
    "mane": "#F0781E",
    "maneLight": "#FF9A3C",
    "maneShade": "#D9601A",
    "fur": "#FFBE3D",
    "furShade": "#F2A12A",
    "muzzle": "#FFEBC2",
    "ink": "#0E1116",
    "nose": "#4A2814",
    "white": "#FFFFFF",
    "blush": "#FF8F6B",
    "tongue": "#FF6F61",
    "mouth": "#5A1E14",
    "bib": "#F4F6F8",
    "cobalt": "#1F4FD8",
    "volt": "#C8F03C",
    "pin": "#B9C0CC",
}

K = 0.5522847498  # circle-to-bezier constant


def f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")


def ellipse(cx, cy, rx, ry):
    kx, ky = rx * K, ry * K
    return (f"M{f(cx)},{f(cy-ry)} "
            f"C{f(cx+kx)},{f(cy-ry)} {f(cx+rx)},{f(cy-ky)} {f(cx+rx)},{f(cy)} "
            f"C{f(cx+rx)},{f(cy+ky)} {f(cx+kx)},{f(cy+ry)} {f(cx)},{f(cy+ry)} "
            f"C{f(cx-kx)},{f(cy+ry)} {f(cx-rx)},{f(cy+ky)} {f(cx-rx)},{f(cy)} "
            f"C{f(cx-rx)},{f(cy-ky)} {f(cx-kx)},{f(cy-ry)} {f(cx)},{f(cy-ry)} Z")


def rot(p, c, deg):
    a = math.radians(deg)
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a))


def capsule(x1, y1, x2, y2, r):
    """Rounded bar from (x1,y1) to (x2,y2) with radius r."""
    ang = math.atan2(y2 - y1, x2 - x1)
    nx, ny = -math.sin(ang) * r, math.cos(ang) * r
    dx, dy = math.cos(ang) * r, math.sin(ang) * r
    a = (x1 + nx, y1 + ny); b = (x2 + nx, y2 + ny)
    c_ = (x2 - nx, y2 - ny); d = (x1 - nx, y1 - ny)
    return (f"M{f(a[0])},{f(a[1])} L{f(b[0])},{f(b[1])} "
            f"C{f(b[0]+dx*K*1.8)},{f(b[1]+dy*K*1.8)} {f(c_[0]+dx*K*1.8)},{f(c_[1]+dy*K*1.8)} {f(c_[0])},{f(c_[1])} "
            f"L{f(d[0])},{f(d[1])} "
            f"C{f(d[0]-dx*K*1.8)},{f(d[1]-dy*K*1.8)} {f(a[0]-dx*K*1.8)},{f(a[1]-dy*K*1.8)} {f(a[0])},{f(a[1])} Z")


def scallops(cx, cy, r, bumps, depth, phase=0.0, squash=1.0):
    """Closed flower outline: `bumps` rounded lobes bulging `depth` outside radius r."""
    pts = []
    for i in range(bumps):
        a0 = phase + 2 * math.pi * i / bumps
        a1 = phase + 2 * math.pi * (i + 1) / bumps
        am = (a0 + a1) / 2
        p0 = (cx + r * math.cos(a0), cy + r * math.sin(a0) * squash)
        p1 = (cx + r * math.cos(a1), cy + r * math.sin(a1) * squash)
        rr = r + depth
        c0 = (cx + rr * 1.06 * math.cos(am - (a1 - a0) * 0.32), cy + rr * 1.06 * math.sin(am - (a1 - a0) * 0.32) * squash)
        c1 = (cx + rr * 1.06 * math.cos(am + (a1 - a0) * 0.32), cy + rr * 1.06 * math.sin(am + (a1 - a0) * 0.32) * squash)
        pts.append((p0, c0, c1, p1))
    d = f"M{f(pts[0][0][0])},{f(pts[0][0][1])} "
    for p0, c0, c1, p1 in pts:
        d += f"C{f(c0[0])},{f(c0[1])} {f(c1[0])},{f(c1[1])} {f(p1[0])},{f(p1[1])} "
    return d + "Z"


def curve(*pts):
    """Open stroke path: M p0 then cubic segments (p1,p2,p3)..."""
    d = f"M{f(pts[0][0])},{f(pts[0][1])} "
    for i in range(1, len(pts), 3):
        a, b, c_ = pts[i], pts[i + 1], pts[i + 2]
        d += f"C{f(a[0])},{f(a[1])} {f(b[0])},{f(b[1])} {f(c_[0])},{f(c_[1])} "
    return d.strip()


# ----------------------------------------------------------------------------
# Anchors

HEAD_C = (200, 172)      # face centre
NECK = (200, 262)        # head pivot
SHOULDER_L = (140, 318)
SHOULDER_R = (260, 318)
TAIL_BASE = (258, 392)
EYE_L = (160, 182)
EYE_R = (240, 182)

MANE_LEVELS = {  # cub → king: how much mane Grin has grown
    0: dict(r=100, tuft=14, n=11),
    1: dict(r=108, tuft=22, n=13),
    2: dict(r=116, tuft=29, n=14),
    3: dict(r=124, tuft=38, n=15),
}


def soft_star(cx, cy, r_in, r_out, n, phase, squash=1.0, bottom_boost=0.0, top_cut=0.0):
    """Rounded flame-tuft outline. Vertices alternate between r_out (tips) and r_in;
    each vertex becomes a quadratic control point with anchors at segment midpoints,
    so tips are soft. bottom_boost swells the cheek ruff, top_cut flattens the crown."""
    v = []
    for i in range(2 * n):
        a = phase + math.pi * i / n
        r = r_out if i % 2 == 0 else r_in
        s = math.sin(a)
        if i % 2 == 0:
            r += bottom_boost * max(0.0, s) ** 2 - top_cut * max(0.0, -s) ** 3
        v.append((cx + r * math.cos(a), cy + r * s * squash))
    mids = [((v[i][0] + v[(i + 1) % len(v)][0]) / 2, (v[i][1] + v[(i + 1) % len(v)][1]) / 2) for i in range(len(v))]
    d = f"M{f(mids[-1][0])},{f(mids[-1][1])} "
    for i in range(len(v)):
        d += f"Q{f(v[i][0])},{f(v[i][1])} {f(mids[i][0])},{f(mids[i][1])} "
    return d + "Z"


def gtrack(cx, cy, w):
    """The Grinda G-Track mark as a filled outline-free stroke path (centreline) scaled to width w."""
    s = w / 870
    r, half, bar = 210 * s, 150 * s, 190 * s
    xr, xl = cx + half, cx - half
    def arc(c, a0, a1, n=10):
        out = []
        for i in range(n + 1):
            a = math.radians(a0 + (a1 - a0) * i / n)
            out.append((c[0] + r * math.cos(a), c[1] - r * math.sin(a)))
        return out
    pts = arc((xr, cy), 42, 90) + [(xl, cy - r)] + arc((xl, cy), 90, 270) + [(xr, cy + r)] + arc((xr, cy), 270, 360) + [(xr + r - bar, cy)]
    return "M" + " L".join(f"{f(x)},{f(y)}" for x, y in pts), 150 * s


def parts(mood="happy", pose="idle", mane=2, bib_text="1"):
    """Returns a list of dicts: {group, id, d, fill?, stroke?, width?, opacity?}"""
    P = []

    def add(group, id_, d, fill=None, stroke=None, width=None, opacity=None):
        P.append({k: v for k, v in dict(group=group, id=id_, d=d, fill=fill, stroke=stroke,
                                         width=width, opacity=opacity).items() if v is not None})

    # --- Tail (behind body) ------------------------------------------------
    tb = TAIL_BASE
    add("tail", "tail", curve(tb, (300, 404), (334, 380), (326, 338)), stroke=C["fur"], width=13)
    add("tail", "tailTuft", soft_star(326, 326, 9, 19, 5, -math.pi / 2), fill=C["mane"])

    # --- Hind feet + body ------------------------------------------------------
    add("body", "footL", ellipse(158, 430, 34, 19), fill=C["furShade"])
    add("body", "footR", ellipse(242, 430, 34, 19), fill=C["furShade"])
    add("body", "body", "M200,276 C252,276 276,318 276,362 C276,408 244,436 200,436 C156,436 124,408 124,362 C124,318 148,276 200,276 Z", fill=C["fur"])
    add("body", "bodyShade", "M124,370 C130,412 160,436 200,436 C240,436 270,412 276,370 C262,404 236,420 200,420 C164,420 138,404 124,370 Z", fill=C["furShade"], opacity=0.55)
    add("body", "belly", ellipse(200, 380, 50, 48), fill=C["muzzle"])
    # Race bib, with the G-Track mark printed on it
    add("body", "bib", "M166,340 L234,340 C238,340 240,342 240,346 L240,400 C240,404 238,406 234,406 L166,406 C162,406 160,404 160,400 L160,346 C160,342 162,340 166,340 Z", fill=C["bib"])
    add("body", "bibBand", "M160,394 L240,394 L240,400 C240,404 238,406 234,406 L166,406 C162,406 160,404 160,400 Z", fill=C["cobalt"])
    g, gw = gtrack(200, 368, 46)
    add("body", "bibMark", g, stroke=C["cobalt"], width=gw)
    for x in (167, 233):
        add("body", f"pin{x}", ellipse(x, 347, 2.6, 2.6), fill=C["pin"])

    # --- Arms (drawn hanging; the app rotates them about the shoulders) --------
    for side, sh in (("L", SHOULDER_L), ("R", SHOULDER_R)):
        hand = (sh[0] + (-6 if side == "L" else 6), sh[1] + 66)
        add(f"arm{side}", f"arm{side}", capsule(sh[0], sh[1], hand[0], hand[1], 19), fill=C["fur"])
        add(f"arm{side}", f"paw{side}", ellipse(hand[0], hand[1] + 6, 22, 18), fill=C["furShade"])
        for k in (-8, 0, 8):
            add(f"arm{side}", f"pawToe{side}{k}", curve((hand[0] + k, hand[1] + 13), (hand[0] + k, hand[1] + 15), (hand[0] + k, hand[1] + 17), (hand[0] + k, hand[1] + 19)),
                stroke=C["maneShade"], width=2.4, opacity=0.6)

    # --- Head -------------------------------------------------------------------
    m = MANE_LEVELS[mane]
    add("head", "maneBack", soft_star(HEAD_C[0], HEAD_C[1] + 14, m["r"] + m["tuft"] * 0.25, m["r"] + m["tuft"], m["n"], -math.pi / 2 + math.pi / m["n"],
                                       squash=0.98, bottom_boost=m["tuft"] * 0.32, top_cut=m["tuft"] * 0.3), fill=C["maneShade"])
    add("head", "mane", soft_star(HEAD_C[0], HEAD_C[1] + 10, m["r"] - 6, m["r"] + m["tuft"] * 0.7, m["n"], -math.pi / 2,
                                   squash=0.98, bottom_boost=m["tuft"] * 0.28, top_cut=m["tuft"] * 0.4), fill=C["mane"])
    add("head", "maneLight", soft_star(HEAD_C[0], HEAD_C[1] - 4, m["r"] - 16, m["r"] + m["tuft"] * 0.35, m["n"], -math.pi / 2 + math.pi / (2 * m["n"]),
                                        squash=0.9, top_cut=m["tuft"] * 0.2), fill=C["maneLight"], opacity=0.55)
    for ex in (128, 272):
        add("head", f"ear{ex}", ellipse(ex, 100, 22, 21), fill=C["fur"])
        add("head", f"earIn{ex}", ellipse(ex, 103, 12, 11), fill=C["blush"], opacity=0.75)
    # Face: wide cheeks, soft crown
    add("head", "face", "M200,90 C266,90 302,130 302,180 C302,232 258,262 200,262 C142,262 98,232 98,180 C98,130 134,90 200,90 Z", fill=C["fur"])
    add("head", "faceShade", "M102,196 C110,236 150,262 200,262 C250,262 290,236 298,196 C282,236 246,250 200,250 C154,250 118,236 102,196 Z", fill=C["furShade"], opacity=0.5)
    # Two-puff muzzle
    add("head", "muzzleL", ellipse(180, 228, 30, 24), fill=C["muzzle"])
    add("head", "muzzleR", ellipse(220, 228, 30, 24), fill=C["muzzle"])
    add("head", "chin", ellipse(200, 246, 16, 10), fill=C["muzzle"])
    add("head", "cheekL", ellipse(122, 212, 15, 10), fill=C["blush"], opacity=0.55)
    add("head", "cheekR", ellipse(278, 212, 15, 10), fill=C["blush"], opacity=0.55)
    for (x, y) in ((166, 228), (158, 236), (170, 240), (234, 228), (242, 236), (230, 240)):
        add("head", f"dot{x}{y}", ellipse(x, y, 2.2, 2.2), fill=C["furShade"])

    # Sweatband across the forehead (brand cobalt, volt stripe)
    add("head", "band", "M108,136 C146,112 254,112 292,136 L289,152 C252,130 148,130 111,152 Z", fill=C["cobalt"])
    add("head", "bandStripe", "M110,143 C148,120 252,120 290,143 L289.5,147 C251,125 149,125 110.5,147 Z", fill=C["volt"])
    # Forelock: three swept tufts falling over the band (the silhouette's signature)
    add("head", "forelock", "M150,128 C150,96 172,74 204,70 C190,84 188,96 192,104 C200,82 222,72 246,76 C230,86 226,98 228,108 C238,98 252,96 262,100 C250,108 246,122 248,134 C232,118 214,114 200,122 C186,112 166,114 150,128 Z", fill=C["mane"])

    # Eyes
    if mood == "sleep":
        for (ex, ey) in (EYE_L, EYE_R):
            add("eyes", f"lid{ex}", curve((ex - 18, ey), (ex - 8, ey + 11), (ex + 8, ey + 11), (ex + 18, ey)), stroke=C["ink"], width=6)
    else:
        look = {"worried": (-4, 3), "proud": (0, -1), "roar": (0, 2)}.get(mood, (2, 2))
        for side, (ex, ey) in (("L", EYE_L), ("R", EYE_R)):
            if mood == "wink" and side == "R":
                add("eyeR", "lidR", curve((ex - 18, ey + 4), (ex - 8, ey - 8), (ex + 8, ey - 8), (ex + 18, ey + 4)), stroke=C["ink"], width=6)
                continue
            add(f"eye{side}", f"eyeWhite{side}", ellipse(ex, ey, 26, 30), fill=C["white"])
            add(f"eye{side}", f"pupil{side}", ellipse(ex + look[0], ey + look[1], 17, 20), fill=C["ink"])
            add(f"eye{side}", f"glint{side}", ellipse(ex + look[0] + 6, ey + look[1] - 8, 6, 6), fill=C["white"])
            add(f"eye{side}", f"glint2{side}", ellipse(ex + look[0] - 6, ey + look[1] + 9, 2.5, 2.5), fill=C["white"])
            if mood in ("happy", "cheer", "proud"):
                add(f"eye{side}", f"lid{side}", f"M{ex-28},{ey+24} C{ex-14},{ey+15} {ex+14},{ey+15} {ex+28},{ey+24} L{ex+28},{ey+34} L{ex-28},{ey+34} Z", fill=C["fur"])

    # Brows (short and thick, sit between band and eyes)
    brows = {
        "worried": [(138, 152, 178, 146), (222, 146, 262, 152)],
        "roar": [(140, 146, 178, 156), (222, 156, 260, 146)],
        "proud": [(140, 150, 178, 146), (222, 146, 260, 150)],
        "sleep": [(140, 156, 178, 156), (222, 156, 260, 156)],
    }.get(mood, [(140, 154, 178, 150), (222, 150, 260, 154)])
    for i, (x1, y1, x2, y2) in enumerate(brows):
        add("brows", f"brow{i}", capsule(x1, y1, x2, y2, 4.5), fill=C["maneShade"])

    # Nose
    add("head", "nose", "M200,222 C190,222 181,212 185,205 C188,200 195,199 200,199 C205,199 212,200 215,205 C219,212 210,222 200,222 Z", fill=C["nose"])
    add("head", "noseGlint", ellipse(194, 205, 4.5, 2.6), fill=C["white"], opacity=0.55)

    # Mouth
    if mood in ("happy", "cheer", "roar", "proud"):
        h = {"happy": 16, "proud": 12, "cheer": 26, "roar": 36}[mood]
        w = {"happy": 18, "proud": 15, "cheer": 22, "roar": 24}[mood]
        top = 230
        add("mouth", "mouthOpen", f"M{200-w},{top} C{200-w*0.5},{top+5} {200+w*0.5},{top+5} {200+w},{top} C{200+w},{top+h*0.75} {200+w*0.55},{top+h} 200,{top+h} C{200-w*0.55},{top+h} {200-w},{top+h*0.75} {200-w},{top} Z", fill=C["mouth"])
        add("mouth", "tongue", ellipse(200, top + h * 0.78, w * 0.55, h * 0.24), fill=C["tongue"])
        if mood == "roar":
            add("mouth", "fangL", f"M{186},{top+2} L{192},{top+3} L{189},{top+12} Z", fill=C["white"])
            add("mouth", "fangR", f"M{208},{top+3} L{214},{top+2} L{211},{top+12} Z", fill=C["white"])
    elif mood == "worried":
        add("mouth", "mouth", curve((186, 240), (194, 233), (206, 233), (214, 240)), stroke=C["mouth"], width=5)
    elif mood == "sleep":
        add("mouth", "mouth", ellipse(200, 236, 6, 5), fill=C["mouth"], opacity=0.8)
    else:  # calm / wink: closed cat smile
        add("mouth", "mouth", curve((200, 222), (200, 230), (192, 238), (182, 234)), stroke=C["mouth"], width=5)
        add("mouth", "mouth2", curve((200, 222), (200, 230), (208, 238), (218, 234)), stroke=C["mouth"], width=5)

    return P


def arm_rotations(pose):
    """Degrees, clockwise-positive (SVG/SwiftUI y-down). Left arm swings out to the left with +."""
    return {"idle": (0, 0), "cheer": (145, -145), "wave": (8, -160), "hold": (-28, 28), "flex": (100, -100)}.get(pose, (0, 0))


def svg(mood="happy", pose="idle", mane=2, size=None, bg=None, bib_text="1", tx=0, ty=0, scale=1.0, head_tilt=0):
    ps = parts(mood, pose, mane, bib_text)
    rl, rr = arm_rotations(pose)
    groups = {}
    order = []
    for p in ps:
        g = p["group"]
        if g not in groups:
            groups[g] = []
            order.append(g)
        groups[g].append(p)

    def el(p):
        if "stroke" in p:
            return (f'<path d="{p["d"]}" fill="none" stroke="{p["stroke"]}" stroke-width="{p["width"]}" '
                    f'stroke-linecap="round" stroke-linejoin="round"' + (f' opacity="{p["opacity"]}"' if "opacity" in p else "") + "/>")
        return f'<path d="{p["d"]}" fill="{p["fill"]}"' + (f' opacity="{p["opacity"]}"' if "opacity" in p else "") + "/>"

    # Draw order: tail, armR/L behind body when raised? Keep arms in front of body.
    draw = ["tail", "body", "head", "eyeL", "eyeR", "eyes", "brows", "mouth", "armL", "armR"]
    out = []
    for g in draw:
        if g not in groups:
            continue
        body = "".join(el(p) for p in groups[g])
        if g == "armL":
            body = f'<g transform="rotate({rl} {SHOULDER_L[0]} {SHOULDER_L[1]})">{body}</g>'
        elif g == "armR":
            body = f'<g transform="rotate({rr} {SHOULDER_R[0]} {SHOULDER_R[1]})">{body}</g>'
        out.append(body)
    # the head (with its face parts) tilts together
    head_groups = {"head", "eyeL", "eyeR", "eyes", "brows", "mouth"}
    inner = []
    head_buf = []
    for g, chunk in zip([g for g in draw if g in groups], out):
        if g in head_groups:
            head_buf.append(chunk)
        else:
            if head_buf:
                inner.append(f'<g transform="rotate({head_tilt} {NECK[0]} {NECK[1]})">{"".join(head_buf)}</g>')
                head_buf = []
            inner.append(chunk)
    if head_buf:
        inner.append(f'<g transform="rotate({head_tilt} {NECK[0]} {NECK[1]})">{"".join(head_buf)}</g>')
    content = "".join(inner)
    sw, sh = size or (W, H)
    b = f'<rect width="{sw}" height="{sh}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{sw}" height="{sh}" viewBox="0 0 {sw} {sh}">{b}'
            f'<g transform="translate({tx} {ty}) scale({scale})">{content}</g></svg>')


def group(mood="happy", pose="idle", mane=2, tx=0, ty=0, scale=1.0, head_tilt=0):
    """Just the <g> for compositing into larger artwork."""
    s = svg(mood, pose, mane, tx=tx, ty=ty, scale=scale, head_tilt=head_tilt)
    return s[s.index("<g transform"):s.rindex("</svg>")]


if __name__ == "__main__":
    import sys
    open(sys.argv[1] if len(sys.argv) > 1 else "grin.svg", "w").write(svg())


def _el(p):
    if "stroke" in p:
        return (f'<path d="{p["d"]}" fill="none" stroke="{p["stroke"]}" stroke-width="{p["width"]}" '
                f'stroke-linecap="round" stroke-linejoin="round"' + (f' opacity="{p["opacity"]}"' if "opacity" in p else "") + "/>")
    return f'<path d="{p["d"]}" fill="{p["fill"]}"' + (f' opacity="{p["opacity"]}"' if "opacity" in p else "") + "/>"


def head_group(mood="happy", mane=2, tx=0, ty=0, scale=1.0):
    """Head only (mane, face, expression): app icon, emoji, avatars."""
    ps = [p for p in parts(mood, "idle", mane) if p["group"] in ("head", "eyeL", "eyeR", "eyes", "brows", "mouth")]
    ps = [p for p in ps if p["group"] == "head"] + [p for p in ps if p["group"] != "head"]
    return f'<g transform="translate({tx} {ty}) scale({scale})">{"".join(_el(p) for p in ps)}</g>'

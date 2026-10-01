"""Shared vector primitives for the Steppie cast.

Every shape is emitted as an absolute M / L / C / Q / Z path string so the same
data renders as SVG here and as SwiftUI Paths in the app (Mascot.swift parses
these strings). Coordinates are y-down.
"""
import math
import re

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


def circle(cx, cy, r):
    return ellipse(cx, cy, r, r)


def capsule(x1, y1, x2, y2, r):
    """Rounded bar from (x1,y1) to (x2,y2) with radius r."""
    ang = math.atan2(y2 - y1, x2 - x1)
    nx, ny = -math.sin(ang) * r, math.cos(ang) * r
    dx, dy = math.cos(ang) * r, math.sin(ang) * r
    a = (x1 + nx, y1 + ny); b = (x2 + nx, y2 + ny)
    c_ = (x2 - nx, y2 - ny); d = (x1 - nx, y1 - ny)
    k = K * 1.8
    return (f"M{f(a[0])},{f(a[1])} L{f(b[0])},{f(b[1])} "
            f"C{f(b[0]+dx*k)},{f(b[1]+dy*k)} {f(c_[0]+dx*k)},{f(c_[1]+dy*k)} {f(c_[0])},{f(c_[1])} "
            f"L{f(d[0])},{f(d[1])} "
            f"C{f(d[0]-dx*k)},{f(d[1]-dy*k)} {f(a[0]-dx*k)},{f(a[1]-dy*k)} {f(a[0])},{f(a[1])} Z")


def taper(x1, y1, x2, y2, r1, r2):
    """Limb that narrows from r1 at (x1,y1) to r2 at (x2,y2), with round ends."""
    ang = math.atan2(y2 - y1, x2 - x1)
    nx, ny = -math.sin(ang), math.cos(ang)
    dx, dy = math.cos(ang), math.sin(ang)
    a = (x1 + nx * r1, y1 + ny * r1); b = (x2 + nx * r2, y2 + ny * r2)
    c_ = (x2 - nx * r2, y2 - ny * r2); d = (x1 - nx * r1, y1 - ny * r1)
    k = K * 1.8
    return (f"M{f(a[0])},{f(a[1])} L{f(b[0])},{f(b[1])} "
            f"C{f(b[0]+dx*r2*k)},{f(b[1]+dy*r2*k)} {f(c_[0]+dx*r2*k)},{f(c_[1]+dy*r2*k)} {f(c_[0])},{f(c_[1])} "
            f"L{f(d[0])},{f(d[1])} "
            f"C{f(d[0]-dx*r1*k)},{f(d[1]-dy*r1*k)} {f(a[0]-dx*r1*k)},{f(a[1]-dy*r1*k)} {f(a[0])},{f(a[1])} Z")


def rrect(x, y, w, h, r):
    k = r * (1 - K)
    return (f"M{f(x+r)},{f(y)} L{f(x+w-r)},{f(y)} C{f(x+w-k)},{f(y)} {f(x+w)},{f(y+k)} {f(x+w)},{f(y+r)} "
            f"L{f(x+w)},{f(y+h-r)} C{f(x+w)},{f(y+h-k)} {f(x+w-k)},{f(y+h)} {f(x+w-r)},{f(y+h)} "
            f"L{f(x+r)},{f(y+h)} C{f(x+k)},{f(y+h)} {f(x)},{f(y+h-k)} {f(x)},{f(y+h-r)} "
            f"L{f(x)},{f(y+r)} C{f(x)},{f(y+k)} {f(x+k)},{f(y)} {f(x+r)},{f(y)} Z")


def poly(*pts):
    return "M" + " L".join(f"{f(x)},{f(y)}" for x, y in pts) + " Z"


def curve(*pts):
    """Open stroke path: M p0 then cubic segments (p1,p2,p3)..."""
    d = f"M{f(pts[0][0])},{f(pts[0][1])} "
    for i in range(1, len(pts), 3):
        a, b, c_ = pts[i], pts[i + 1], pts[i + 2]
        d += f"C{f(a[0])},{f(a[1])} {f(b[0])},{f(b[1])} {f(c_[0])},{f(c_[1])} "
    return d.strip()


def soft_star(cx, cy, r_in, r_out, n, phase, squash=1.0, bottom_boost=0.0, top_cut=0.0):
    """Rounded flame-tuft outline (manes, tufts, bursts)."""
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


_NUM = re.compile(r"-?\d+(?:\.\d+)?")
_TOK = re.compile(r"[MLCQZ]|-?\d+(?:\.\d+)?")


def xf(d, fn):
    """Applies fn(x, y) -> (x, y) to every coordinate pair of an absolute path."""
    out, nums, cmd = [], [], None

    def flush():
        pts = []
        for i in range(0, len(nums) - 1, 2):
            x, y = fn(nums[i], nums[i + 1])
            pts.append(f"{f(x)},{f(y)}")
        return " ".join(pts)

    for tok in _TOK.findall(d):
        if tok in "MLCQZ":
            if cmd is not None:
                out.append(cmd + flush())
            nums = []
            cmd = tok
        else:
            nums.append(float(tok))
    if cmd is not None:
        out.append(cmd + flush())
    return " ".join(out).replace("Z ", "Z ").strip()


def move(d, dx, dy):
    return xf(d, lambda x, y: (x + dx, y + dy))


def scale(d, s, cx, cy):
    return xf(d, lambda x, y: (cx + (x - cx) * s, cy + (y - cy) * s))


def mirror(d, axis=200):
    return xf(d, lambda x, y: (2 * axis - x, y))


def rotate(d, deg, cx, cy):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    return xf(d, lambda x, y: (cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca))


class Builder:
    """Collects parts: {group, id, d, fill?, stroke?, width?, opacity?}."""

    def __init__(self):
        self.parts = []

    def add(self, group, id_, d, fill=None, stroke=None, width=None, opacity=None):
        self.parts.append({k: v for k, v in dict(group=group, id=id_, d=d, fill=fill, stroke=stroke,
                                                 width=width, opacity=opacity).items() if v is not None})


def el(p):
    if "stroke" in p:
        return (f'<path d="{p["d"]}" fill="none" stroke="{p["stroke"]}" stroke-width="{p["width"]}" '
                f'stroke-linecap="round" stroke-linejoin="round"' + (f' opacity="{p["opacity"]}"' if "opacity" in p else "") + "/>")
    return f'<path d="{p["d"]}" fill="{p["fill"]}"' + (f' opacity="{p["opacity"]}"' if "opacity" in p else "") + "/>"

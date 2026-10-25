import math, subprocess
from shapely.geometry import LineString, Polygon, Point
COB = "#1F4FD8"


def arcpts(c, r, a0, a1, n=160):
    return [(c[0] + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             c[1] - r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def strip(ang, half, length=5000):
    """Band centred on the origin, long axis leaning forward at `ang` deg (y-down coords), half-width `half`."""
    t = math.radians(ang)
    d = (math.cos(t), -math.sin(t))      # along the band (up-right on screen)
    n = (math.sin(t), math.cos(t))       # across
    pts = [(d[0] * s * length + n[0] * h * half, d[1] * s * length + n[1] * h * half)
           for s, h in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    return Polygon(pts), n


def halfplane(p, ang, toward, size=5000):
    """Half-plane bounded by the line through p at `ang`, on the side containing `toward`."""
    t = math.radians(ang)
    d = (math.cos(t), -math.sin(t)); n = (math.sin(t), math.cos(t))
    side = 1 if (toward[0] - p[0]) * n[0] + (toward[1] - p[1]) * n[1] > 0 else -1
    a = (p[0] - d[0] * size, p[1] - d[1] * size); b = (p[0] + d[0] * size, p[1] + d[1] * size)
    return Polygon([a, b, (b[0] + side * n[0] * size, b[1] + side * n[1] * size), (a[0] + side * n[0] * size, a[1] + side * n[1] * size)])


def mark(R=100, W=80, gap=20, ang=60, term=28, over=40):
    top = arcpts((0, -R), R, term - over, 270)
    bot = arcpts((0, R), R, 90, -180 + term - over)
    s = LineString(top + bot[1:]).buffer(W / 2, cap_style=2, join_style=1, resolution=64)
    g, _ = strip(ang, gap / 2)
    s = s.difference(g)
    for c, a_cut, a_far in (((0, -R), term, term - over), ((0, R), -180 + term, -180 + term - over)):
        p = (c[0] + R * math.cos(math.radians(a_cut)), c[1] - R * math.sin(math.radians(a_cut)))
        far = (c[0] + R * math.cos(math.radians(a_far)), c[1] - R * math.sin(math.radians(a_far)))
        s = s.difference(halfplane(p, ang, far).intersection(Point(p).buffer(W * 0.75)))
    polys = [s] if s.geom_type == "Polygon" else sorted(s.geoms, key=lambda p: -p.area)[:2]
    return polys


def to_d(polys):
    d = ""
    for p in polys:
        for ring in [p.exterior] + list(p.interiors):
            cs = list(ring.coords)
            d += "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in cs[:-1]) + " Z "
    return d


def _preview():
    vs = [dict(), dict(term=40), dict(term=40, ang=58, W=84, gap=22), dict(W=90, ang=64, term=15)]
    B = []
    for i, v in enumerate(vs):
        P = mark(**v)
        d = to_d(P)
        B.append(f'<path transform="translate({160+i*300} 270) scale(0.9)" d="{d}" fill="{COB}"/>')
        for j, s in enumerate([20, 40, 80]):
            sc = s * 0.6 / 420
            B.append(f'<rect x="{60+i*300+j*70}" y="520" width="{s}" height="{s}" rx="{s*.225}" fill="{COB}"/>'
                     f'<path transform="translate({60+i*300+j*70+s/2} {520+s/2}) scale({sc})" d="{d}" fill="#fff"/>')
    open("s3.svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="1250" height="640"><rect width="1250" height="640" fill="#fff"/>{"".join(B)}</svg>')
    subprocess.run(["rsvg-convert", "s3.svg", "-o", "s3.png"], check=True)


# Master: the chosen proportions. Writes brand/logo/stride-s.json (unit height, centred on 0,0).
MASTER = dict(R=100, W=84, gap=22, ang=58, term=40)


def master_polys():
    return [p.simplify(0.25, preserve_topology=True) for p in mark(**MASTER)]


def write_master():
    import json, os
    polys = master_polys()
    minx = min(p.bounds[0] for p in polys); maxx = max(p.bounds[2] for p in polys)
    miny = min(p.bounds[1] for p in polys); maxy = max(p.bounds[3] for p in polys)
    h = maxy - miny; cx = (minx + maxx) / 2; cy = (miny + maxy) / 2
    rings = [[[round((x - cx) / h, 5), round((y - cy) / h, 5)] for x, y in list(p.exterior.coords)[:-1]] for p in polys]
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../logo/stride-s.json")
    json.dump({"aspect": round((maxx - minx) / h, 5), "angle": MASTER["ang"], "rings": rings}, open(out, "w"))
    print("wrote", os.path.normpath(out), sum(len(r) for r in rings), "points")


if __name__ == "__main__":
    write_master()

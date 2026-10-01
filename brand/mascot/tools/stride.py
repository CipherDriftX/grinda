"""Loads the Stride S master (brand/logo/stride-s.json, made by brand/tools/stride.py)."""
import json, os

_M = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../logo/stride-s.json")))
ASPECT = _M["aspect"]
ANGLE = _M["angle"]


def mark_d(cx, cy, h):
    """The Stride S as one filled path, centred on (cx, cy), h units tall."""
    d = ""
    for ring in _M["rings"]:
        d += "M" + " L".join(f"{cx + x * h:.1f},{cy + y * h:.1f}" for x, y in ring) + " Z "
    return d.strip()

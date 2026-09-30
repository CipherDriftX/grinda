#!/usr/bin/env bash
# Prints the UDID of the newest large iPhone simulator (6.9" App Store class).
set -euo pipefail
xcrun simctl list devices available -j | python3 -c '
import json, sys, re
data = json.load(sys.stdin)["devices"]
best = None
for runtime, devs in data.items():
    if "iOS" not in runtime:
        continue
    ver = tuple(int(x) for x in re.findall(r"(\d+)", runtime.split("iOS")[-1])[:2])
    for d in devs:
        n = d["name"]
        if not n.startswith("iPhone"):
            continue
        score = (ver, "Pro Max" in n, "Pro" in n, n)
        if best is None or score > best[0]:
            best = (score, d["udid"], n, runtime)
print(best[1])
print(best[2], best[3], file=sys.stderr)
'

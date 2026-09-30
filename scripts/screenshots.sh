#!/usr/bin/env bash
# Captures App Store-sized screenshots of Grinda from the iOS Simulator.
# Usage: scripts/screenshots.sh <path/to/Grinda.app> <out-dir>
# The app runs in demo mode (-demo YES) with synthetic data; -screen picks the scene.
set -euo pipefail

APP="$1"
OUT="$2"
BUNDLE="com.cipherdriftx.grinda"
SCREENS="${SCREENS:-onboarding-welcome onboarding-baseline today races contract pinning progress wallet finish paywall}"
mkdir -p "$OUT"

# Prefer the largest current iPhone (6.9" App Store class).
UDID=$(xcrun simctl list devices available -j | python3 -c '
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
')
echo "Simulator: $UDID"

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork 5g --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$UDID" "$APP"

for appearance in light dark; do
  xcrun simctl ui "$UDID" appearance "$appearance"
  mkdir -p "$OUT/$appearance"
  for screen in $SCREENS; do
    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
    xcrun simctl launch "$UDID" "$BUNDLE" -demo YES -screen "$screen" >/dev/null
    sleep "${SETTLE:-5}"
    xcrun simctl io "$UDID" screenshot --type=png "$OUT/$appearance/$screen.png" >/dev/null
    echo "captured $appearance/$screen"
  done
done

# A short screen recording of the signature interaction (hold-to-pin) for the README.
xcrun simctl ui "$UDID" appearance light
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" "$BUNDLE" -demo YES -screen pinning-demo >/dev/null
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/pinning.mp4" &
REC=$!
sleep 9
kill -INT "$REC" || true
wait "$REC" || true
echo "done"

#!/usr/bin/env bash
# Captures App Store-sized screenshots of Grinda from the iOS Simulator.
# Usage: scripts/screenshots.sh <path/to/Grinda.app> <out-dir>
# The app runs in demo mode (-demo YES) with synthetic data; -screen picks the scene.
set -euo pipefail

APP="$1"
OUT="$2"
BUNDLE="com.cipherdriftx.grinda"
SCREENS="${SCREENS:-onboarding-welcome onboarding-baseline today races contract pinning entered progress wallet finish milestone}"
mkdir -p "$OUT"

UDID="${SIM_UDID:-$(bash "$(dirname "$0")/sim-pick.sh")}"
echo "Simulator: $UDID"

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork 5g --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$UDID" "$APP"

# Warm-up launch: the first cold start after install can take several seconds,
# and a capture taken during it shows only the launch screen.
xcrun simctl launch "$UDID" "$BUNDLE" -demo YES -screen today >/dev/null
sleep 12
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true

for appearance in light dark; do
  xcrun simctl ui "$UDID" appearance "$appearance"
  mkdir -p "$OUT/$appearance"
  for screen in $SCREENS; do
    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
    xcrun simctl launch "$UDID" "$BUNDLE" -demo YES -screen "$screen" >/dev/null
    sleep "${SETTLE:-6}"
    xcrun simctl io "$UDID" screenshot --type=png "$OUT/$appearance/$screen.png" >/dev/null
    echo "captured $appearance/$screen"
  done
done

# A screen recording of the signature interaction (hold-to-pin) for the README.
xcrun simctl ui "$UDID" appearance light
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/pinning.mp4" &
REC=$!
sleep 2
xcrun simctl launch "$UDID" "$BUNDLE" -demo YES -screen pinning-demo >/dev/null
sleep 8
kill -INT "$REC" || true
wait "$REC" || true
echo "done"

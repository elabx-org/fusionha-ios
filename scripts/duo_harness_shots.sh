#!/bin/bash
# iPhone Duo harness screenshots (Spread, S1). CI cannot fold a Duo, so the
# DEBUG app renders itself inside a Duo-sized frame with a fake flat fold
# (App/Debug/DuoHarness.swift) on a large iPad simulator, and each shot is
# cropped to that frame. Files: duo-harness-<frame>-<layout>-<screen>.png.
#
#   scripts/duo_harness_shots.sh <app-path> <out-dir> <server-url> [name-regex]
#
# Frames: open 951x669 (fold top to bottom at x 475.5, the device kit's),
# portrait 669x951, folded 466x678. A red hairline marks the fold.
set -u
APP=$1
OUT=$2
S=$3
ONLY=${4:-}
mkdir -p "$OUT"

# The iPad must be wider than 951 pt in portrait: a 13-inch iPad (1032 x 1376).
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for rt, ds in sorted(json.load(sys.stdin)["devices"].items(), reverse=True) if "iOS-2" in rt for d in ds]
pick = next((d for d in devices if "13-inch" in d["name"]), None) or next((d for d in devices if "12.9-inch" in d["name"]), None)
print(pick["udid"] if pick else "")')
if [ -z "$UDID" ]; then echo "::warning::No 13-inch iPad simulator for the Duo harness"; exit 0; fi
echo "Duo harness device: $UDID"
xcrun simctl boot "$UDID" 2> /dev/null || true
xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"

size() {  # size <frame> -> "<width> <height>" in points
  case $1 in
    open) echo "951 669" ;;
    portrait) echo "669 951" ;;
    folded) echo "466 678" ;;
  esac
}

shoot() {  # shoot <name> <frame> [env…]
  local name=$1 frame=$2; shift 2
  if [ -n "$ONLY" ] && ! echo "$name" | grep -qE "$ONLY"; then return 0; fi
  env SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER="$S" SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_FRAME="$frame" "$@" \
    xcrun simctl launch --terminate-running-process "$UDID" org.elabx.fusionha > /dev/null
  sleep 10
  local raw="$OUT/.raw-$name.png"
  xcrun simctl io "$UDID" screenshot "$raw" > /dev/null
  # Crop the centred frame: points x the screenshot's scale (screen pixels / 1032 or 1024 points wide).
  read -r w h <<< "$(size "$frame")"
  local px scale
  px=$(sips -g pixelWidth "$raw" | awk '/pixelWidth/{print $2}')
  scale=$(python3 -c "import sys; px=int(sys.argv[1]); print(round(px / (1032 if px % 1032 == 0 else 1024)))" "$px")
  sips --cropToHeightWidth $((h * scale)) $((w * scale)) "$raw" --out "$OUT/$name.png" > /dev/null
  rm -f "$raw"
  echo "$name: $(sips -g pixelWidth -g pixelHeight "$OUT/$name.png" | awk '/pixel/{printf "%s ", $2}')"
}

L="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library"
SP="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LAYOUT=spread"
WEB="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LAYOUT=web"
# Warm-up: the first launch against a fresh mock is still loading at 10s.
shoot duo-harness-warmup open $L $SP && rm -f "$OUT/duo-harness-warmup.png"
# Spread, Library: nothing picked (the grid spans both pages), then a title open.
shoot duo-harness-open-spread-library open $L $SP
shoot duo-harness-open-spread-library-title open $L $SP SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=8
# Again from a cold launch: the title's hero must render every time (S1 review blocker).
shoot duo-harness-open-spread-library-title-2 open $L $SP SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=8
# Web layout with the same fold: the web-parity wide layout (fold-gutter fixes only).
shoot duo-harness-open-web-library open $L $WEB
shoot duo-harness-open-web-library-title open $L $WEB SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=8
# A work screen in Spread: list on the left page, the right page's default.
shoot duo-harness-open-spread-activity open SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=activity $SP
# No top-to-bottom fold: Spread does not apply (inner portrait, folded).
shoot duo-harness-portrait-library portrait $L $SP
shoot duo-harness-folded-library folded $L $SP
xcrun simctl shutdown "$UDID" || true
ls -l "$OUT"/duo-harness-* 2> /dev/null || true

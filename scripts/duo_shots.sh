#!/bin/bash
# iPhone Duo screenshots: the main screens in every pose the simulator offers.
#
#   scripts/duo_shots.sh <udid> <out-dir>
#
# Needs the mock server on :8765, the app installed on the booted iPhone Duo
# simulator and Simulator.app in the foreground (poses are Device Hub buttons,
# pressed by scripts/duo_pose.js; `simctl` has no pose command).
#
# The Duo boots closed: the outer display is `primary`, the inner display
# (open, book) is `primary-1`. Files are named duo-<pose>-<screen>.png.
set -u
UDID=$1
OUT=$2
mkdir -p "$OUT"
S=http://127.0.0.1:8765
HERE=$(cd "$(dirname "$0")" && pwd)
LOG="$OUT/duo-poses.log"
# Optional: a command run after each pose to publish what we have so far.
PUBLISH=${DUO_PUBLISH:-true}

# osascript with a time limit: a stuck accessibility walk must not hang CI.
limited() { perl -e 'alarm shift; exec @ARGV' "$@"; }

pose() {
  if limited 90 osascript -l JavaScript "$HERE/duo_pose.js" press "$1" >> "$LOG" 2>&1; then
    echo "pose $1: pressed" | tee -a "$LOG"
    sleep 8
    return 0
  fi
  echo "pose $1: NOT AVAILABLE" | tee -a "$LOG"
  return 1
}

snap() {  # snap <file> <display>
  if ! xcrun simctl io "$UDID" screenshot --display="$2" "$OUT/$1.png" > /dev/null 2>&1; then
    xcrun simctl io "$UDID" screenshot "$OUT/$1.png" > /dev/null 2>&1
  fi
  [ -f "$OUT/$1.png" ] && echo "$1: $(sips -g pixelWidth -g pixelHeight "$OUT/$1.png" | awk '/pixel/{printf "%s ", $2}')" | tee -a "$LOG"
}

launch() {
  env "$@" xcrun simctl launch --terminate-running-process "$UDID" org.elabx.fusionha > /dev/null
  sleep 9
}

# The five main screens in the current pose. Extra env (the landscape
# fallback) is passed through to every launch.
screens() {  # screens <pose> <display> [env…]
  local P=$1 D=$2; shift 2
  local B="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER=$S"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library "$@";  snap "duo-$P-library" "$D"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=8 "$@"; snap "duo-$P-detail" "$D"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=activity "$@"; snap "duo-$P-activity" "$D"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=discover "$@"; snap "duo-$P-discover" "$D"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SETTINGS=list "$@"; snap "duo-$P-settings" "$D"
}

# Rotation: the Device Hub's Rotate Right button, else ask the app to rotate
# itself (DEBUG hook, honoured on the outer display only).
rotated_env=""
rotate_right() {
  if pose "Rotate Right"; then rotated_env=""; else rotated_env="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ORIENTATION=landscape"; fi
}
rotate_back() {
  if [ -z "$rotated_env" ]; then
    pose "Rotate Left" || { pose "Rotate Right"; pose "Rotate Right"; pose "Rotate Right"; }
  fi
  rotated_env=""
}

# Warm-up: the first launch against a fresh mock is still loading at 9s.
launch SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER=$S SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library

# 1. Folded (closed), portrait, on the outer display: the Duo boots closed,
# so this needs no simulator UI.
screens folded-portrait primary
xcrun simctl io "$UDID" enumerate > "$OUT/duo-displays.txt" 2>&1
$PUBLISH

# The poses are buttons in the simulator UI: open it on this device and list
# its controls (time-limited; a slow accessibility walk must not hang CI).
XC=$(dirname "$(dirname "$(xcode-select -p)")")
APP=$(find "$XC" /Applications -maxdepth 5 -name "*.app" 2>/dev/null | grep -i -E "/(simulator|device ?hub)\.app$" | head -1)
echo "simulator UI: ${APP:-com.apple.iphonesimulator}" | tee -a "$LOG"
if [ -n "$APP" ]; then open "$APP" --args -CurrentDeviceUDID "$UDID"; else open -b com.apple.iphonesimulator --args -CurrentDeviceUDID "$UDID"; fi >> "$LOG" 2>&1
sleep 30
limited 180 osascript -l JavaScript "$HERE/duo_pose.js" dump > "$OUT/duo-ui-tree.txt" 2>&1
echo "ui dump exit $?" | tee -a "$LOG"
$PUBLISH

# 1b. Folded, landscape.
rotate_right
screens folded-landscape primary $rotated_env
rotate_back
$PUBLISH

# 2. Unfolded (open), portrait and landscape, on the inner display.
if pose "Open"; then
  screens unfolded-portrait primary-1
  rotate_right
  screens unfolded-landscape primary-1 $rotated_env
  rotate_back
  $PUBLISH
fi

# 3. Book (half open), both orientations.
if pose "Book"; then
  screens book-portrait primary-1
  rotate_right
  screens book-landscape primary-1 $rotated_env
  rotate_back
  $PUBLISH
fi

# 4. Continuity: open a title folded, scroll it, then unfold without relaunching.
if pose "Closed"; then
  launch SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER=$S SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=8
  snap duo-continuity-1-folded-detail primary
  if pose "Open"; then
    snap duo-continuity-2-unfolded-detail primary-1
    pose "Closed" && snap duo-continuity-3-folded-again primary
  fi
fi
$PUBLISH
ls -l "$OUT"

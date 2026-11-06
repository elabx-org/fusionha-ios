#!/bin/bash
# v2 windows on an iPad simulator: launching the app again from the Home Screen
# returns to its window (no new scene), and "Open in New Window" still adds one.
# Reads the DEBUG scene probe (App/V2/Windows/V2SceneProbe.swift) from
# Library/Caches/deeplink-log.txt in the app's container. Exits 1 on a miss.
#   scripts/v2_scene_check.sh <udid> <FusionhaV2.app> <shots dir>
set -u
UDID=$1
APP_PATH=$2
SHOTS=$3
APP=org.elabx.fusionha.v2
failed=0
report=""
mkdir -p "$SHOTS"

log_file() {
  echo "$(xcrun simctl get_app_container "$UDID" "$APP" data)/Library/Caches/deeplink-log.txt"
}

# A fresh install: no scene sessions left from an earlier case.
fresh_install() {
  xcrun simctl terminate "$UDID" "$APP" 2> /dev/null
  xcrun simctl uninstall "$UDID" "$APP" 2> /dev/null
  xcrun simctl install "$UDID" "$APP_PATH"
}

# check <name> <expected scene count>: the last probe line after a launch.
check() {
  local name=$1 expected=$2 line count
  xcrun simctl io "$UDID" screenshot "$SHOTS/$name.png" > /dev/null 2>&1
  line=$(grep "^scenes " "$(log_file)" 2>/dev/null | tail -1)
  count=$(echo "$line" | awk '{print $2}')
  echo "== $name: expect $expected scene(s), probe: ${line:-none}"
  if [ "$count" = "$expected" ]; then
    report+="| $name | ok | $expected | ${line} |"$'\n'
  else
    report+="| $name | **failed** | $expected | ${line:-none} |"$'\n'
    echo "::error::$name: expected $expected connected scene(s), probe says '${line:-none}'"
    failed=1
  fi
}

# The Home Screen icon: put another app in front, then launch fusionha v2
# again while it is still running (simctl launch without terminating it).
home_screen_relaunch() {
  xcrun simctl launch "$UDID" com.apple.Preferences > /dev/null
  sleep 4
  xcrun simctl launch "$UDID" "$APP" | sed 's/^/launch: /'
  sleep 6
}

# 1. One window: every relaunch from the icon comes back to it.
fresh_install
SIMCTL_CHILD_FUSIONHA_SCENE_PROBE=1 xcrun simctl launch "$UDID" "$APP" | sed 's/^/launch: /'
sleep 10
check scenes-1-first-launch 1
home_screen_relaunch
check scenes-2-relaunch 1
home_screen_relaunch
check scenes-3-relaunch-again 1

# 2. Open in New Window adds a second window; a relaunch adds none.
fresh_install
SIMCTL_CHILD_FUSIONHA_SCENE_PROBE=1 SIMCTL_CHILD_FUSIONHA_SCENE_PROBE_NEW_WINDOW=1 \
  xcrun simctl launch "$UDID" "$APP" | sed 's/^/launch: /'
sleep 16
check scenes-4-open-in-new-window 2
home_screen_relaunch
check scenes-5-relaunch-two-windows 2

echo "-- probe log:"; cat "$(log_file)" 2>/dev/null || echo "(none)"
xcrun simctl terminate "$UDID" "$APP" 2> /dev/null

{
  echo "## v2 windows (iPad simulator)"
  echo "| case | result | expected scenes | probe |"
  echo "|---|---|---|---|"
  printf '%s' "$report"
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
exit $failed

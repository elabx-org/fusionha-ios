#!/bin/bash
# v2 windows on an iPad simulator. A UI-test driver (UITests/SceneRelaunchDriver)
# launches fusionha v2, goes to the Home Screen and taps its icon twice, then
# opens a fusionha2:// link; the app's DEBUG scene probe
# (App/V2/Windows/V2SceneProbe.swift) logs its connected scenes each time a
# window comes forward, in Library/Caches/deeplink-log.txt in its container.
#   1. one window: every line must say 1 scene;
#   2. after Open in New Window: 2 scenes, and never a third.
# Exits 1 on a miss.
#   scripts/v2_scene_check.sh <udid> <FusionhaV2.app>
set -u
UDID=$1
APP_PATH=$2
APP=org.elabx.fusionha.v2
failed=0
report=""

log_file() {
  echo "$(xcrun simctl get_app_container "$UDID" "$APP" data)/Library/Caches/deeplink-log.txt"
}

# case <name> <expected scenes> [new-window]
run_case() {
  local name=$1 expected=$2 new_window=${3:-} out lines max last count
  # A fresh install: no scene sessions or probe lines left from an earlier case.
  xcrun simctl terminate "$UDID" "$APP" 2> /dev/null
  xcrun simctl uninstall "$UDID" "$APP" 2> /dev/null
  xcrun simctl install "$UDID" "$APP_PATH"
  out=$(mktemp)
  env ${new_window:+TEST_RUNNER_SCENE_NEW_WINDOW=1} \
    xcodebuild test-without-building -project Fusionha.xcodeproj -scheme Fusionha \
    -destination "id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
    -only-testing:FusionhaUITests/SceneRelaunchDriver/testRelaunchFromHomeScreen > "$out" 2>&1
  echo "== $name (expect $expected scene(s))"
  grep "SCENES" "$out" | grep -v "^Test" || { echo "driver output:"; tail -40 "$out"; }
  echo "-- probe log:"; cat "$(log_file)" 2>/dev/null || echo "(none)"
  lines=$(grep "^scenes " "$(log_file)" 2>/dev/null | awk '{print $2}')
  count=$(echo "$lines" | grep -c . || true)
  max=$(echo "$lines" | sort -n | tail -1)
  last=$(echo "$lines" | tail -1)
  # A probe line per window coming forward: launch, two icon taps, the link.
  if [ "$count" -ge 3 ] && [ "$max" = "$expected" ] && [ "$last" = "$expected" ]; then
    report+="| $name | ok | $expected | $(echo $lines) |"$'\n'
  else
    report+="| $name | **failed** | $expected | $(echo $lines) |"$'\n'
    echo "::error::$name: expected $expected connected scene(s) after every launch, probe saw: $(echo $lines)"
    failed=1
  fi
}

run_case relaunch-one-window 1
run_case relaunch-after-open-in-new-window 2 new-window
xcrun simctl terminate "$UDID" "$APP" 2> /dev/null

{
  echo "## v2 windows (iPad simulator)"
  echo "| case | result | expected scenes | scenes seen per window shown |"
  echo "|---|---|---|---|"
  printf '%s' "$report"
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
exit $failed

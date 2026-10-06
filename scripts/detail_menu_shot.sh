#!/bin/bash
# Screenshots the detail page's open Refresh menu: a SwiftUI Menu no launch
# flag can open, so the UI-test helper RefreshMenuOpener launches the app on
# the mock server, taps the caret and holds the menu while we capture it.
# Best effort: a helper that never opens the menu leaves no screenshot.
#   scripts/detail_menu_shot.sh <udid> <mock server url> <shots dir> <name> [item]
set -u
UDID=$1
SERVER=$2
SHOTS=$3
NAME=$4
ITEM=${5:-1}
LOG=$(mktemp)
TEST_RUNNER_MENU_SHOT_SERVER="$SERVER" TEST_RUNNER_MENU_SHOT_ITEM="$ITEM" \
  xcodebuild test-without-building -project Fusionha.xcodeproj -scheme Fusionha \
  -destination "id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
  -only-testing:FusionhaUITests/RefreshMenuOpener/testOpenRefreshMenu > "$LOG" 2>&1 &
PID=$!
for _ in $(seq 1 240); do
  grep -q "MENU OPEN" "$LOG" && break
  kill -0 "$PID" 2> /dev/null || break
  sleep 1
done
if grep -q "MENU OPEN" "$LOG"; then
  sleep 1.5
  xcrun simctl io "$UDID" screenshot "$SHOTS/$NAME.png" > /dev/null
  grep "MENU OPEN" "$LOG"
else
  echo "menu helper did not open the menu:"; tail -40 "$LOG"
fi
kill "$PID" 2> /dev/null
wait "$PID" 2> /dev/null
exit 0

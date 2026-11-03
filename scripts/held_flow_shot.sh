#!/bin/bash
# Screenshots a held-download state no launch flag reaches (the downloads
# bar's menu, Manual Import's Decide menu, a bulk Import answered): the
# UI-test helper HeldFlowOpener launches the app, runs the steps and holds the
# state while we capture it. Best effort: no SHOT READY, no screenshot.
#   scripts/held_flow_shot.sh <udid> <shots dir> <name> <launch env> <steps> <expect> [crop "w h"]
# <launch env> is `KEY=VALUE;…` (no SIMCTL_CHILD_ prefix). With a crop (points),
# the centred frame is cut out, as scripts/duo_harness_shots.sh does.
set -u
UDID=$1
SHOTS=$2
NAME=$3
LAUNCH=$4
STEPS=$5
EXPECT=$6
CROP=${7:-}
if [ -n "${ONLY:-}" ] && ! echo "$NAME" | grep -qE "$ONLY"; then exit 0; fi
LOG=$(mktemp)
xcrun simctl terminate "$UDID" org.elabx.fusionha 2> /dev/null || true
TEST_RUNNER_HELD_SHOT_ENV="$LAUNCH" TEST_RUNNER_HELD_SHOT_STEPS="$STEPS" TEST_RUNNER_HELD_SHOT_EXPECT="$EXPECT" \
  xcodebuild test-without-building -project Fusionha.xcodeproj -scheme Fusionha \
  -destination "id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
  -only-testing:FusionhaUITests/HeldFlowOpener/testHeldFlowState > "$LOG" 2>&1 &
PID=$!
for _ in $(seq 1 300); do
  grep -q "SHOT READY" "$LOG" && break
  kill -0 "$PID" 2> /dev/null || break
  sleep 1
done
if grep -q "SHOT READY" "$LOG"; then
  sleep 1.5
  OUTFILE="$SHOTS/$NAME.png"
  [ -n "$CROP" ] && OUTFILE="$SHOTS/.raw-$NAME.png"
  xcrun simctl io "$UDID" screenshot "$OUTFILE" > /dev/null
  if [ -n "$CROP" ]; then
    read -r w h <<< "$CROP"
    px=$(sips -g pixelWidth "$OUTFILE" | awk '/pixelWidth/{print $2}')
    scale=$(python3 -c "import sys; px=int(sys.argv[1]); print(round(px / (1032 if px % 1032 == 0 else 1024)))" "$px")
    sips --cropToHeightWidth $((h * scale)) $((w * scale)) "$OUTFILE" --out "$SHOTS/$NAME.png" > /dev/null
    rm -f "$OUTFILE"
  fi
  echo "$NAME: $(grep "SHOT READY" "$LOG" | head -1)"
  grep -E "not found" "$LOG" | head -5
else
  echo "$NAME: helper never reached the state:"; tail -40 "$LOG"
fi
kill "$PID" 2> /dev/null
wait "$PID" 2> /dev/null
xcrun simctl terminate "$UDID" org.elabx.fusionha 2> /dev/null || true
exit 0

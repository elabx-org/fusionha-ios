#!/bin/bash
# The v2 owner-session perf run on the iPhone Duo's flat open inner display
# (the CI "Perf" job, perf_scope v2session; App/Debug/PerfProbe+Session.swift).
# Same harness as perf_v2_open.sh, with the simulator's hardware keyboard off
# as on the phone (PERF_HW_KEYBOARD=1 keeps it on: UIKit's focus system is then
# active, and its focus-map walks show up in the samples). Like scripts/perf_library.sh: the DEBUG
# FusionhaV2 app renders itself in a Duo-sized frame on a 13-inch iPad
# simulator, against the mock's 3,785-title library (one poster URL per title,
# 20 live downloads).
#
#   [PERF_SCRIPT=v2frames] scripts/perf_v2_session.sh <app-path> <out-dir>
#
# Writes <out-dir>/<script>.log (stderr: the PERF lines) and <script>.png;
# v2frames (App/Debug/PerfProbe+Frames.swift) records the screen
# (<out-dir>/v2frames.mp4, stopped at the unix time in v2frames-stop.txt).
set -u
APP=$1
OUT=$2
BUNDLE=org.elabx.fusionha.v2
PORT=${PERF_PORT:-8768}
SCRIPT=${PERF_SCRIPT:-v2session}
S=http://127.0.0.1:$PORT
mkdir -p "$OUT"

python3 scripts/mock_server.py $PORT perf > "$OUT/v2session-mock.log" 2>&1 &
MOCK=$!
trap 'kill $MOCK 2> /dev/null' EXIT
# The big library must be on before the app launches (a second session in
# the same job once measured an almost empty one): wait for the mock.
for _ in $(seq 1 20); do
  curl -sf -X POST "$S/__mock/big-library?on=1&art=unique" && break
  sleep 1
done
echo

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for rt, ds in sorted(json.load(sys.stdin)["devices"].items(), reverse=True) if "iOS-2" in rt for d in ds]
pick = next((d for d in devices if "13-inch" in d["name"]), None) or next((d for d in devices if "12.9-inch" in d["name"]), None)
print(pick["udid"] if pick else "")')
if [ -z "$UDID" ]; then echo "::error::No 13-inch iPad simulator for the Duo harness"; exit 1; fi
echo "v2 session perf device: $UDID"
if [ "${PERF_HW_KEYBOARD:-0}" = 0 ]; then
  defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
fi
xcrun simctl boot "$UDID" 2> /dev/null || true
xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl install "$UDID" "$APP"
# Let the freshly booted simulator settle before measuring.
sleep 20

log="$OUT/$SCRIPT.log"
# v2frames: the screen is recorded (frames are pulled per PERF-MARK off the runner).
REC=""
if [ "$SCRIPT" = v2frames ]; then
  xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/v2frames.mp4" 2> "$OUT/record.log" &
  REC=$!
  sleep 2
fi
env SIMCTL_CHILD_FUSIONHA_PERF=1 SIMCTL_CHILD_FUSIONHA_PERF_SCRIPT="$SCRIPT" \
  SIMCTL_CHILD_FUSIONHA_PERF_DELAY=8 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER="$S" \
  SIMCTL_CHILD_FUSIONHA_PERF_POSTER="${PERF_POSTER:-0}" \
  SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_FRAME=open \
  SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LAYOUT=spread \
  xcrun simctl launch --terminate-running-process --stderr="$PWD/$log" --stdout="$PWD/$OUT/$SCRIPT.out" \
  "$UDID" "$BUNDLE"
for _ in $(seq 1 600); do
  grep -q "PERF DONE" "$log" 2> /dev/null && break
  sleep 1
done
xcrun simctl io "$UDID" screenshot "$OUT/$SCRIPT.png" > /dev/null 2>&1 || true
grep "PERF" "$log" | grep -v '"event":"stacks"' || true
if [ -n "$REC" ]; then
  # The recording's start in unix time is its stop time minus its length;
  # frames are pulled from it per PERF-MARK off the runner.
  python3 -c 'import time; print(time.time())' > "$OUT/v2frames-stop.txt"
  kill -INT "$REC" 2> /dev/null; wait "$REC" 2> /dev/null || true
fi
status=0
if ! grep -q "PERF DONE" "$log"; then
  echo "::error::v2 session perf did not finish"; tail -40 "$log"; status=1
fi
xcrun simctl terminate "$UDID" "$BUNDLE" 2> /dev/null || true
xcrun simctl shutdown "$UDID" 2> /dev/null || true
exit $status

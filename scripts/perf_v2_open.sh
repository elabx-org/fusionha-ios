#!/bin/bash
# v2 title-open perf on the iPhone Duo's flat open inner display (the CI
# "Perf" job, perf_scope v2open). Like scripts/perf_library.sh: the DEBUG
# FusionhaV2 app renders itself in a Duo-sized frame on a 13-inch iPad
# simulator, against the mock's 3,785-title library (one poster URL per title,
# 20 live downloads). The perf probe (FUSIONHA_PERF_SCRIPT=v2open,
# App/Debug/PerfProbe+Open.swift) opens titles from the Library the way a
# poster tap does, lets each settle and closes it the way Close does.
#
#   scripts/perf_v2_open.sh <app-path> <out-dir>
#
# Writes <out-dir>/v2open.log (stderr: the PERF lines) and v2open.png.
set -u
APP=$1
OUT=$2
BUNDLE=org.elabx.fusionha.v2
PORT=8767
S=http://127.0.0.1:$PORT
mkdir -p "$OUT"

python3 scripts/mock_server.py $PORT perf > "$OUT/v2open-mock.log" 2>&1 &
MOCK=$!
trap 'kill $MOCK 2> /dev/null' EXIT
sleep 2
curl -s -X POST "$S/__mock/big-library?on=1&art=unique"; echo

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for rt, ds in sorted(json.load(sys.stdin)["devices"].items(), reverse=True) if "iOS-2" in rt for d in ds]
pick = next((d for d in devices if "13-inch" in d["name"]), None) or next((d for d in devices if "12.9-inch" in d["name"]), None)
print(pick["udid"] if pick else "")')
if [ -z "$UDID" ]; then echo "::error::No 13-inch iPad simulator for the Duo harness"; exit 1; fi
echo "v2 open perf device: $UDID"
xcrun simctl boot "$UDID" 2> /dev/null || true
xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl install "$UDID" "$APP"
# Let the freshly booted simulator settle before measuring.
sleep 20

log="$OUT/v2open.log"
env SIMCTL_CHILD_FUSIONHA_PERF=1 SIMCTL_CHILD_FUSIONHA_PERF_SCRIPT=v2open \
  SIMCTL_CHILD_FUSIONHA_PERF_DELAY=8 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER="$S" \
  SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_FRAME=open \
  SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LAYOUT=spread \
  xcrun simctl launch --terminate-running-process --stderr="$PWD/$log" --stdout="$PWD/$OUT/v2open.out" \
  "$UDID" "$BUNDLE"
for _ in $(seq 1 300); do
  grep -q "PERF DONE" "$log" 2> /dev/null && break
  sleep 1
done
xcrun simctl io "$UDID" screenshot "$OUT/v2open.png" > /dev/null 2>&1 || true
grep "PERF" "$log" | grep -v '"event":"stacks"' || true
status=0
if ! grep -q "PERF DONE" "$log"; then
  echo "::error::v2 open perf did not finish"; tail -40 "$log"; status=1
fi
xcrun simctl terminate "$UDID" "$BUNDLE" 2> /dev/null || true
xcrun simctl shutdown "$UDID" 2> /dev/null || true
exit $status

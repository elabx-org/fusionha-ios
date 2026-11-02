#!/bin/bash
# Library scroll perf on the iPhone Duo's open inner display (the CI "Perf" job).
# CI cannot unfold an iPhone Duo simulator, so, like the Duo harness shots
# (scripts/duo_harness_shots.sh), the DEBUG app renders itself in a Duo-sized
# frame (951 x 669, the fold at x 475.5) on a 13-inch iPad simulator. The mock
# serves the owner's 3,785-title library with one poster URL per title and 20
# live downloads; the perf probe (FUSIONHA_PERF_SCRIPT=library) sits idle,
# scrolls down, back up and in a fast fling, once per layout:
#
#   span   Spread, nothing open: the grid spans both pages (3 + 3 columns)
#   title  Spread with a title open: the grid on the left page, the title right
#   web    the Web layout: one wide grid with letter headers and the A–Z rail
#
#   scripts/perf_library.sh <app-path> <out-dir> [labels…]
#
# Writes <out-dir>/library-<label>.log and all of them in <out-dir>/library.log.
set -u
APP=$1
OUT=$2
shift 2
LABELS=${*:-span title web}
PORT=8766
S=http://127.0.0.1:$PORT
mkdir -p "$OUT"

python3 scripts/mock_server.py $PORT perf > "$OUT/library-mock.log" 2>&1 &
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
echo "Library perf device: $UDID"
xcrun simctl boot "$UDID" 2> /dev/null || true
xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl install "$UDID" "$APP"
# Let the freshly booted simulator settle before measuring.
sleep 20

: > "$OUT/library.log"
status=0
for label in $LABELS; do
  layout=spread; item=
  case $label in
    title) item=8 ;;
    web) layout=web ;;
  esac
  log="$OUT/library-$label.log"
  env SIMCTL_CHILD_FUSIONHA_PERF=1 SIMCTL_CHILD_FUSIONHA_PERF_SCRIPT=library SIMCTL_CHILD_FUSIONHA_PERF_LABEL="$label" \
    SIMCTL_CHILD_FUSIONHA_PERF_DELAY=8 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER="$S" \
    SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_FRAME=open \
    SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LAYOUT=$layout ${item:+SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=$item} \
    xcrun simctl launch --terminate-running-process --stderr="$PWD/$log" --stdout="$PWD/$OUT/library-$label.out" \
    "$UDID" org.elabx.fusionha
  for _ in $(seq 1 240); do
    grep -q "PERF DONE" "$log" 2> /dev/null && break
    sleep 1
  done
  xcrun simctl io "$UDID" screenshot "$OUT/library-$label.png" > /dev/null 2>&1 || true
  grep "PERF" "$log" | grep -v '"event":"stacks"' || true
  if ! grep -q "PERF DONE" "$log"; then
    echo "::error::library perf ($label) did not finish"; tail -40 "$log"; status=1
  fi
  cat "$log" >> "$OUT/library.log"
  xcrun simctl terminate "$UDID" org.elabx.fusionha 2> /dev/null || true
done
xcrun simctl shutdown "$UDID" 2> /dev/null || true
exit $status

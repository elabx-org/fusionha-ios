#!/bin/bash
# v2 screenshots on the iPhone Duo's flat open inner display (the CI "Perf"
# job, perf_scope v2shots): the optimised FusionhaV2 app renders itself in a
# Duo-sized frame on a 13-inch iPad simulator against the default mock (live
# downloads, the held Interstellar = 103). Each shot is one launch with its
# own screenshot hooks, in the Web layout unless LAYOUT=spread.
#
#   scripts/v2_duo_shots.sh <app-path> <out-dir>
#
# Writes <out-dir>/v2-<name>.png.
set -u
APP=$1
OUT=$2
BUNDLE=org.elabx.fusionha.v2
PORT=8769
S=http://127.0.0.1:$PORT
mkdir -p "$OUT"

python3 scripts/mock_server.py $PORT > "$OUT/v2shots-mock.log" 2>&1 &
MOCK=$!
trap 'kill $MOCK 2> /dev/null' EXIT
sleep 2

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for rt, ds in sorted(json.load(sys.stdin)["devices"].items(), reverse=True) if "iOS-2" in rt for d in ds]
pick = next((d for d in devices if "13-inch" in d["name"]), None) or next((d for d in devices if "12.9-inch" in d["name"]), None)
print(pick["udid"] if pick else "")')
if [ -z "$UDID" ]; then echo "::error::No 13-inch iPad simulator for the Duo harness"; exit 1; fi
xcrun simctl boot "$UDID" 2> /dev/null || true
xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl install "$UDID" "$APP"
sleep 15

# shoot <name> <seconds> [ENV=value ...]
shoot() {
  local name=$1 wait=$2; shift 2
  env SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER="$S" SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_FRAME=open \
    SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LAYOUT=${LAYOUT:-web} "$@" \
    xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" > /dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "$OUT/v2-$name.png" > /dev/null 2>&1 && echo "shot v2-$name"
}

# Activity is one full-width page in the Web layout (the owner's setting); the
# Spread puts it on the left page beside v1's ActivityRightPage.
A=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=activity
shoot activity-live 14 $A
shoot activity-held 14 $A SIMCTL_CHILD_FUSIONHA_SCREENSHOT_QUEUE_SCROLL=103
shoot activity-live-later 22 $A
LAYOUT=spread shoot activity-spread 14 $A

# S12: Requests (Discover › Requests, the approver's Inbox) and Account, open
# flat and folded, dark and Daylight.
RQ="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=discover SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DISCOVER_TAB=requests"
DAY=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_PALETTE=daylight
FOLD=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_FRAME=folded
shoot requests-inbox 16 $RQ
shoot requests-inbox-daylight 16 $RQ $DAY
shoot requests-inbox-folded 16 $RQ $FOLD
shoot requests-inbox-folded-daylight 16 $RQ $FOLD $DAY
shoot requests-details-folded 18 $RQ $FOLD SIMCTL_CHILD_FUSIONHA_SCREENSHOT_REQUESTS_DETAILS=1
shoot account 12 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ACCOUNT=1
LAYOUT=spread shoot account-spread 12 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ACCOUNT=1
shoot account-folded 12 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ACCOUNT=1 $FOLD
shoot account-folded-daylight 12 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ACCOUNT=1 $FOLD $DAY

xcrun simctl terminate "$UDID" "$BUNDLE" 2> /dev/null || true
xcrun simctl shutdown "$UDID" 2> /dev/null || true
ls "$OUT"/v2-*.png > /dev/null 2>&1

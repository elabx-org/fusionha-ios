#!/bin/bash
# v2 (FusionhaV2) screenshots on the iPhone Duo harness's flat open inner
# display (the CI "Perf" job, perf_scope v2shots): the DEBUG app renders
# itself in a Duo-sized frame on a 13-inch iPad simulator against the mock
# server, and each shot is cropped to that frame (as scripts/duo_harness_shots.sh
# does for v1). Files: <out-dir>/v2-<name>.png.
#
#   scripts/v2_duo_shots.sh <app-path> <out-dir> [name-regex]
set -u
APP=$1
OUT=$2
ONLY=${3:-}
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
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
xcrun simctl boot "$UDID" 2> /dev/null || true
xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"
sleep 15

shoot() {  # shoot <name> [env…]
  local name=$1; shift
  if [ -n "$ONLY" ] && ! echo "$name" | grep -qE "$ONLY"; then return 0; fi
  env SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER="$S" SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_FRAME=${FRAME:-open} \
    SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LAYOUT=${LAYOUT:-spread} SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library "$@" \
    xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" > /dev/null
  sleep "${WAIT:-12}"
  local raw="$OUT/.raw-$name.png"
  xcrun simctl io "$UDID" screenshot "$raw" > /dev/null
  local px scale
  px=$(sips -g pixelWidth "$raw" | awk '/pixelWidth/{print $2}')
  scale=$(python3 -c "import sys; px=int(sys.argv[1]); print(round(px / (1032 if px % 1032 == 0 else 1024)))" "$px")
  local w=951 h=669  # the open inner display; folded: the outer one
  [ "${FRAME:-open}" = folded ] && w=466 && h=678
  sips --cropToHeightWidth $((h * scale)) $((w * scale)) "$raw" --out "$OUT/v2-$name.png" > /dev/null
  rm -f "$raw"
  echo "v2-$name"
}

ADD=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ADD=1
for theme in dark daylight; do
  T=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_UNUSED=1; SUF=""
  [ "$theme" = daylight ] && T=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_PALETTE=daylight && SUF="-daylight"
  shoot "add-find$SUF" $ADD $T
  shoot "add-results$SUF" $ADD $T SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ADD_QUERY=dune
  shoot "add-configure$SUF" $ADD $T SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ADD_PICK=438631
  shoot "add-configure-versions$SUF" $ADD $T SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ADD_PICK=438631 \
    SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ADD_4K=1 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ADD_SCROLL=versions
  # Folded (outer display): the setup's footer tray and the top under the
  # grabber, a movie at rest and a series scrolled to What to monitor.
  FRAME=folded shoot "add-configure-folded$SUF" $ADD $T SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ADD_PICK=438631
  FRAME=folded shoot "add-configure-monitor-folded$SUF" $ADD $T SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ADD_PICK=63639 \
    SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ADD_SCROLL=monitor
  WAIT=18 shoot "add-after$SUF" $ADD $T SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ADD_PICK=438631 \
    SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ADD_COMMIT=1
  # Release groups on a title (series 8): the sheet, Block <GROUP>?, and the
  # search with its blocked rows (mock: FLUX for this title, EPSiLON everywhere).
  G=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_GROUPS; I=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=8
  WAIT=16 shoot "groups-list$SUF" $I $T $G=list
  WAIT=16 FRAME=folded shoot "groups-list-folded$SUF" $I $T $G=list
  WAIT=16 shoot "groups-block$SUF" $I $T $G=NTb
  WAIT=20 shoot "groups-search$SUF" $I $T $G=search
  WAIT=20 FRAME=folded shoot "groups-search-folded$SUF" $I $T $G=search
done
# Library A–Z: the grid runs to the page gutter and the scroll thumb floats
# over its trailing edge (thumb = resting mid-library, S = grabbed with the
# bubble). Folded (outer display), and open spanning both pages.
for theme in dark daylight; do
  T=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_UNUSED=1; SUF=""
  [ "$theme" = daylight ] && T=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_PALETTE=daylight && SUF="-daylight"
  FRAME=folded shoot "library-folded$SUF" $T
  FRAME=folded shoot "library-folded-thumb$SUF" $T SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SCRUB=thumb
  FRAME=folded shoot "library-folded-scrub$SUF" $T SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SCRUB=S
  shoot "library-open-thumb$SUF" $T SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SCRUB=thumb
  LAYOUT=web shoot "library-web-scrub$SUF" $T SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SCRUB=S
done
# Activity (live queue wide): the Web layout, the owner's setting; held Interstellar = 103.
A=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=activity
WAIT=14 LAYOUT=web shoot activity-live $A
WAIT=14 LAYOUT=web shoot activity-held $A SIMCTL_CHILD_FUSIONHA_SCREENSHOT_QUEUE_SCROLL=103
WAIT=14 shoot activity-spread $A

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

# S14 shell (sidebar and column minimize removed, owner 2026-11-06): the
# system column shows every tab and the screen's buttons, open (Library,
# Discover, Activity) and folded, dark and Daylight; and the downloads
# capsule on the left page in book pose (the tabs cross the fold).
for theme in dark daylight; do
  T=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_UNUSED=1; SUF=""
  [ "$theme" = daylight ] && T=SIMCTL_CHILD_FUSIONHA_SCREENSHOT_PALETTE=daylight && SUF="-daylight"
  WAIT=14 shoot "shell-column-library$SUF" $T
  WAIT=14 shoot "shell-column-discover$SUF" $T SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=discover
  WAIT=14 shoot "shell-column-activity$SUF" $T $A
  WAIT=14 FRAME=folded shoot "shell-column-folded$SUF" $T
done
WAIT=14 shoot shell-book-capsule SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_POSE=book
WAIT=14 shoot shell-book-capsule-daylight SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_POSE=book SIMCTL_CHILD_FUSIONHA_SCREENSHOT_PALETTE=daylight

xcrun simctl terminate "$UDID" "$BUNDLE" 2> /dev/null || true
xcrun simctl shutdown "$UDID" 2> /dev/null || true
ls "$OUT"/v2-*.png > /dev/null 2>&1 || { echo "::error::no v2 shots"; exit 1; }

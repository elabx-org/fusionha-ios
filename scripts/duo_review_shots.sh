#!/bin/bash
# The UI review matrix on the iPhone Duo simulator (.claude/skills/duo-ui-review):
# the owner's settings (Collapsed tabs and the Poster title page on), each pose,
# a fresh install per shot, one screen at a time. A pose that can't be pressed
# stops the run. Do not touch the simulator while it runs.
#   scripts/duo_review_shots.sh <app> <out-dir> [pose-regex] [name-regex]
# Extra env per shot: DUO_REVIEW_ENV (e.g. SIMCTL_CHILD_FUSIONHA_SCREENSHOT_PALETTE=daylight).
set -u
cd /Users/elmer/Documents/gh/fusionha/fusionha-ios
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
APP=$1 OUT=$2 POSES=${3:-.} ONLY=${4:-.}
U=${DUO_UDID:-D2D62502-921D-42C6-8432-28207642E783} B=org.elabx.fusionha
mkdir -p "$OUT"
python3 scripts/mock_server.py 8772 > "$OUT/mock.log" 2>&1 & MOCK=$!
trap 'kill $MOCK 2> /dev/null' EXIT
sleep 2
xcrun simctl boot $U 2> /dev/null; xcrun simctl bootstatus $U -b > /dev/null
xcrun simctl status_bar $U override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 2> /dev/null
xcrun simctl install $U "$APP"
S="${DUO_REVIEW_ENV:-} SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER=http://127.0.0.1:8772 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_COLLAPSED_TABS=1 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_POSTER=1"
SHOTS=(
  "home|"
  "home-recent|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_HOME_SCROLL=recent"
  "home-kinds|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_HOME_SCROLL=kinds"
  "alltitles|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ALLTITLES=1"
  "search|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=search"
  "discover|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=discover"
  "calendar|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=calendar"
  "activity|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=activity"
  "account|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ACCOUNT=1"
  "movie-split|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=1 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LIST=shown"
  "movie-wide|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=1 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LIST=hidden"
  "movie-wide-files|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=1 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DETAIL_TAB=files SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LIST=hidden"
  "series-split-seasons|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=8 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DETAIL_TAB=seasons SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LIST=shown"
  "series-wide-seasons|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=8 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DETAIL_TAB=seasons SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LIST=hidden"
  "series-scrolled|SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=8 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DETAIL_SCROLL=700 SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DUO_LIST=shown"
)
for pose in "Open" "Closed" "Partially Open"; do
  echo "$pose" | grep -qE "$POSES" || continue
  # Shots in the wrong pose mislead: a pose press is verified before any shot.
  r=$(osascript -l JavaScript scripts/duo_pose.js press "$pose" 2>&1)
  case "$r" in pressed*) ;; *)
    # Device Hub drops the device's window now and then (seen after fresh
    # installs): reopen it once (File › New Window) and try again.
    osascript -l JavaScript -e 'const p = Application("System Events").processes.byName("DeviceHub"); p.frontmost = true; delay(1);
      p.menuBars[0].menuBarItems.byName("File").menus[0].menuItems.byName("New Window").click(); delay(4);' > /dev/null 2>&1
    r=$(osascript -l JavaScript scripts/duo_pose.js press "$pose" 2>&1) ;;
  esac
  # A pose that can't be pressed (the Mac locked, or Device Hub in another
  # Space behind a full-screen app) is skipped, never shot in the wrong pose:
  # the run carries on with the poses it can reach and says what it skipped.
  case "$r" in pressed*) ;; *)
    echo "POSE SKIPPED: $pose ($r). Is the Mac locked, or an app in full screen? Device Hub's window must be in the current Space."
    SKIPPED="$SKIPPED $pose;"
    continue ;;
  esac
  sleep 4
  tag=$(echo "$pose" | tr 'A-Z ' 'a-z-')
  for entry in "${SHOTS[@]}"; do
    name=${entry%%|*} env=${entry#*|}
    echo "$name" | grep -qE "$ONLY" || continue
    # Like for like: a fresh install per shot (no remembered split, scroll or settings).
    xcrun simctl terminate $U $B 2> /dev/null
    xcrun simctl uninstall $U $B 2> /dev/null
    xcrun simctl install $U "$APP"
    eval "env $S $env xcrun simctl launch $U $B" > /dev/null
    sleep 18
    if [ "$pose" = Closed ]; then
      xcrun simctl io $U screenshot --display=primary "$OUT/$tag-$name.png" > /dev/null 2>&1
    else
      xcrun simctl io $U screenshot --display=primary-1 "$OUT/$tag-$name.png" > /dev/null 2>&1
    fi
    sips -Z 1100 "$OUT/$tag-$name.png" > /dev/null 2>&1
    echo "shot $tag-$name"
  done
done
osascript -l JavaScript scripts/duo_pose.js press Open > /dev/null
[ -n "${SKIPPED:-}" ] && echo "NOT COVERED (pose could not be pressed):$SKIPPED"

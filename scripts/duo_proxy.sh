#!/bin/bash
# Unfolded-layout PROXY for the iPhone Duo screenshots. The Duo's poses can
# only be changed in the Device Hub UI, which does not run on the hosted
# runner, so the inner display (669 x 951 pt, regular width and height) is
# stood in for by an iPad mini (744 x 1133 pt, also regular / regular).
# Files are named standin-unfolded-<orientation>-<screen>-ipadmini-not-real-unfold.png:
# a stand-in, not a real unfold.
#
#   scripts/duo_proxy.sh <app-path> <out-dir>
set -u
APP=$1
OUT=$2
mkdir -p "$OUT"
S=http://127.0.0.1:8765
PUBLISH=${DUO_PUBLISH:-true}

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for rt, ds in sorted(json.load(sys.stdin)["devices"].items(), reverse=True) if "iOS-2" in rt for d in ds]
pick = next((d for d in devices if d["name"].startswith("iPad mini")), None) or next(d for d in devices if d["name"].startswith("iPad"))
print(pick["udid"], pick["name"], sep="\t")')
NAME=${UDID#*$'\t'}
UDID=${UDID%%$'\t'*}
echo "proxy device: $NAME ($UDID)" | tee -a "$OUT/duo-poses.log"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"

launch() {
  env "$@" xcrun simctl launch --terminate-running-process "$UDID" org.elabx.fusionha > /dev/null
  sleep 9
}
snap() { xcrun simctl io "$UDID" screenshot "$OUT/$1.png" > /dev/null 2>&1; }

screens() {  # screens <orientation> [env…]
  local O=$1; shift
  local B="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER=$S"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library "$@";  snap "standin-unfolded-$O-library-ipadmini-not-real-unfold"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=8 "$@"; snap "standin-unfolded-$O-detail-ipadmini-not-real-unfold"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=activity SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=1 "$@"; snap "standin-unfolded-$O-activity-ipadmini-not-real-unfold"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=discover "$@"; snap "standin-unfolded-$O-discover-ipadmini-not-real-unfold"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SETTINGS=general "$@"; snap "standin-unfolded-$O-settings-ipadmini-not-real-unfold"
  # Requests wide layouts (D2a, DU1–DU5): Inbox panes, Board columns, History table, Threads and Issues splits, thread panel.
  local R="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=discover SIMCTL_CHILD_FUSIONHA_SCREENSHOT_DISCOVER_TAB=requests"
  for P in inbox board history threads issues; do
    launch $B $R SIMCTL_CHILD_FUSIONHA_SCREENSHOT_REQUESTS_PANE=$P "$@"; snap "standin-unfolded-$O-requests-$P-ipadmini-not-real-unfold"
  done
  launch $B $R SIMCTL_CHILD_FUSIONHA_SCREENSHOT_REQUESTS_PANE=history SIMCTL_CHILD_FUSIONHA_SCREENSHOT_REQUESTS_THREAD=3 "$@"; snap "standin-unfolded-$O-requests-thread-ipadmini-not-real-unfold"
  # D2c: Activity's desktop head and Tasks grid, Settings panels' wide layouts.
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=activity "$@"; snap "standin-unfolded-$O-activity-queue-ipadmini-not-real-unfold"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=activity SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ACTIVITY_TAB=tasks "$@"; snap "standin-unfolded-$O-activity-tasks-ipadmini-not-real-unfold"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SETTINGS=metadata "$@"; snap "standin-unfolded-$O-settings-metadata-ipadmini-not-real-unfold"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SETTINGS=defaultprofiles "$@"; snap "standin-unfolded-$O-settings-defaultprofiles-ipadmini-not-real-unfold"
  # D2b: Calendar month and week on their own width, sign-in side by side.
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=calendar SIMCTL_CHILD_FUSIONHA_SCREENSHOT_CALENDAR_VIEW=month "$@"; snap "standin-unfolded-$O-calendar-month-ipadmini-not-real-unfold"
  launch $B SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=calendar SIMCTL_CHILD_FUSIONHA_SCREENSHOT_CALENDAR_VIEW=week "$@"; snap "standin-unfolded-$O-calendar-week-ipadmini-not-real-unfold"
  launch SIMCTL_CHILD_FUSIONHA_SCREENSHOT_LOGIN=$S SIMCTL_CHILD_FUSIONHA_SCREENSHOT_LOGIN_LAYOUT=split SIMCTL_CHILD_FUSIONHA_SCREENSHOT_METHOD=fusionha "$@"; snap "standin-unfolded-$O-signin-split-ipadmini-not-real-unfold"
  launch SIMCTL_CHILD_FUSIONHA_SCREENSHOT_LOGIN=$S SIMCTL_CHILD_FUSIONHA_SCREENSHOT_LOGIN_LAYOUT=living SIMCTL_CHILD_FUSIONHA_SCREENSHOT_METHOD=fusionha "$@"; snap "standin-unfolded-$O-signin-living-ipadmini-not-real-unfold"
}

launch SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER=$S SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library
screens portrait
# One publish at the end: a contended push to the screenshots branch can take
# 20+ minutes and once ran the step out of time before the landscape shots.
# The orientation hook doesn't rotate the iPad mini stand-in (its "landscape"
# shots came out identical to portrait in D2a/D2b/D2c), so the second pass only
# cost time. Opt back in with DUO_STANDIN_LANDSCAPE=1 once rotation works.
if [ "${DUO_STANDIN_LANDSCAPE:-0}" = 1 ]; then
  screens landscape SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ORIENTATION=landscape
fi
$PUBLISH
xcrun simctl shutdown "$UDID" || true
ls -l "$OUT"

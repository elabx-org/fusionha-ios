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
}

launch SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER=$S SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library
screens portrait
$PUBLISH
screens landscape SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ORIENTATION=landscape
$PUBLISH
xcrun simctl shutdown "$UDID" || true
ls -l "$OUT"

#!/bin/bash
# Widget deep links on the simulator, cold and warm: opens fusionha:// URLs with
# `simctl openurl` the way a widget tap does, screenshots each, and checks the
# app's DEBUG probe log (Library/Caches/deeplink-log.txt in its container) for
# the expected step. Exits 1 if any case missed.
#   scripts/deeplink_check.sh <udid> <mock server url> <shots dir>
set -u
UDID=$1
SERVER=$2
SHOTS=$3
APP=org.elabx.fusionha
failed=0
report=""

log_file() {
  echo "$(xcrun simctl get_app_container "$UDID" "$APP" data)/Library/Caches/deeplink-log.txt"
}

clear_log() {
  local file
  file=$(log_file)
  echo "-- probe log before clearing:"; cat "$file" 2>/dev/null || echo "(none)"
  rm -f "$file"
}

# check <name> <expected text>
check() {
  local name=$1 expected=$2 file
  xcrun simctl io "$UDID" screenshot "$SHOTS/$name.png" > /dev/null
  file=$(log_file)
  echo "== $name (expect: $expected)"
  cat "$file" 2>/dev/null || echo "(no probe log)"
  ls "$(dirname "$file")" 2>/dev/null | head -5
  xcrun simctl spawn "$UDID" log show --last 15s --style compact \
    --predicate 'eventMessage CONTAINS[c] "fusionha://" OR eventMessage CONTAINS[c] "openURL" OR process == "Fusionha"' 2>/dev/null \
    | grep -i -E "probe|url|scene|crash|terminat|fault|error" | tail -25
  if grep -qF "$expected" "$file" 2>/dev/null; then
    report+="| $name | ok | \`$expected\` |"$'\n'
  else
    report+="| $name | **missed** | \`$expected\` |"$'\n'
    failed=1
  fi
}

launch() {
  env "$@" xcrun simctl launch --terminate-running-process "$UDID" "$APP" > /dev/null
  sleep 8
}

# What the built app declares and where its container is (for a failed run).
plutil -p "$(xcrun simctl get_app_container "$UDID" "$APP" app)/Info.plist" | grep -A6 CFBundleURLTypes
echo "data container: $(xcrun simctl get_app_container "$UDID" "$APP" data)"

# open <path>: as a widget tap does; prints simctl's answer and the system's log lines about it.
open_link() {
  xcrun simctl openurl "$UDID" "fusionha://$1" 2>&1 | sed 's/^/openurl: /'
}

# Cold: the link itself launches the app. A cold launch from openurl gets no
# SIMCTL_CHILD_ variables, so the mock server goes in launchd's environment.
xcrun simctl spawn "$UDID" launchctl setenv FUSIONHA_SCREENSHOT_SERVER "$SERVER"
for case in "item/8|detail 8 shown|deeplink-1-cold-item" "calendar|applied fusionha://calendar tab=calendar|deeplink-2-cold-calendar"; do
  IFS='|' read -r path expected name <<< "$case"
  xcrun simctl terminate "$UDID" "$APP" 2> /dev/null
  sleep 1
  clear_log
  open_link "$path"
  sleep 10
  check "$name" "$expected"
done
xcrun simctl spawn "$UDID" launchctl unsetenv FUSIONHA_SCREENSHOT_SERVER
xcrun simctl terminate "$UDID" "$APP" 2> /dev/null

# Warm: the app is running on Library, under the Account sheet, or on another title.
S="SIMCTL_CHILD_FUSIONHA_SCREENSHOT_SERVER=$SERVER"
warm() {
  local name=$1 path=$2 expected=$3; shift 3
  launch "$S" "$@"
  clear_log
  open_link "$path"
  sleep 5
  check "$name" "$expected"
}
warm deeplink-3-warm-item item/1 "detail 1 shown" SIMCTL_CHILD_FUSIONHA_SCREENSHOT_TAB=library
warm deeplink-4-warm-over-account item/8 "detail 8 shown" SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ACCOUNT=1
warm deeplink-5-warm-other-title item/8 "detail 8 shown" SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=1
warm deeplink-6-warm-calendar calendar "applied fusionha://calendar tab=calendar" SIMCTL_CHILD_FUSIONHA_SCREENSHOT_ITEM=1

{
  echo "## Widget deep links"
  echo "| case | result | probe |"
  echo "|---|---|---|"
  printf '%s' "$report"
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
if [ "$failed" = 1 ]; then echo "::error::A widget deep link did not open its screen (scripts/deeplink_check.sh)"; fi
exit $failed

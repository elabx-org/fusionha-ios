#!/bin/bash
# v2 windows on an iPad simulator. A UI-test driver (UITests/SceneRelaunchDriver)
# launches fusionha v2, goes to the Home Screen and taps its icon twice, then
# opens a fusionha2:// link; the app's DEBUG scene probe
# (App/V2/Windows/V2SceneProbe.swift) logs its connected scenes each time a
# window comes forward, in Library/Caches/deeplink-log.txt in its container.
#   1. one window: every line must say 1 scene;
#   2. after Open in New Window: 2 scenes, and never a third.
# Exits 1 on a miss. Every simctl and xcodebuild call is bounded, so a stuck
# simulator or test runner fails the case instead of hanging the job.
#   scripts/v2_scene_check.sh <udid> <FusionhaV2.app>
set -u
UDID=$1
APP_PATH=$2
APP=org.elabx.fusionha.v2
CASE_SECS=${V2_SCENE_CASE_SECS:-600}
failed=0
report=""

# bounded <seconds> <command...>: SIGALRM ends the command; exit 142 = timed out.
bounded() { perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "$@"; }
# Prefixes each line with the time, so the log shows where a case spends it.
stamp() { perl -MPOSIX -ne '$|=1; print strftime("%H:%M:%S ", localtime), $_'; }

# Every 30 s while the check runs: memory pressure and the biggest processes,
# so a starved runner shows up in the log before it stops answering.
watch_runner() {
  while sleep 30; do
    echo "[runner $(date +%T)] $(sysctl -n vm.loadavg) $(memory_pressure -Q 2> /dev/null | tail -1)"
    top -l 1 -o mem -n 5 -stats pid,command,mem,cpu 2> /dev/null | tail -6 | sed 's/^/[runner]   /'
  done
}
watch_runner &
WATCH_PID=$!
trap 'pkill -P $WATCH_PID 2> /dev/null; kill $WATCH_PID 2> /dev/null' EXIT

log_file() {
  echo "$(bounded 60 xcrun simctl get_app_container "$UDID" "$APP" data)/Library/Caches/deeplink-log.txt"
}

# case <name> <expected scenes> [new-window]
run_case() {
  local name=$1 expected=$2 new_window=${3:-} out lines max last count rc start
  echo "== $name (expect $expected scene(s))"
  # A fresh install: no scene sessions or probe lines left from an earlier case.
  bounded 60 xcrun simctl terminate "$UDID" "$APP" 2> /dev/null
  bounded 120 xcrun simctl uninstall "$UDID" "$APP" 2> /dev/null
  bounded 180 xcrun simctl install "$UDID" "$APP_PATH" || echo "::warning::$name: simctl install exited $?"
  out=$(mktemp)
  start=$SECONDS
  env ${new_window:+TEST_RUNNER_SCENE_NEW_WINDOW=1} \
    perl -e 'alarm shift; exec @ARGV' "$CASE_SECS" \
    xcodebuild test-without-building -project Fusionha.xcodeproj -scheme Fusionha \
    -destination "id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
    -test-timeouts-enabled YES -parallel-testing-enabled NO \
    -only-testing:FusionhaUITests/SceneRelaunchDriver/testRelaunchFromHomeScreen 2>&1 | stamp | tee "$out"
  rc=${PIPESTATUS[0]}
  echo "xcodebuild exited $rc after $((SECONDS - start))s"
  grep "SCENES" "$out" | grep -v " Test"
  [ "$rc" = 142 ] && echo "::error::$name: the UI-test driver did not finish within ${CASE_SECS}s (xcodebuild output above)"
  echo "-- probe log:"; cat "$(log_file)" 2> /dev/null || echo "(none)"
  lines=$(grep "^scenes " "$(log_file)" 2> /dev/null | awk '{print $2}')
  count=$(echo "$lines" | grep -c . || true)
  max=$(echo "$lines" | sort -n | tail -1)
  last=$(echo "$lines" | tail -1)
  # A probe line per window coming forward: launch, two icon taps, the link.
  if [ "$count" -ge 3 ] && [ "$max" = "$expected" ] && [ "$last" = "$expected" ]; then
    report+="| $name | ok | $expected | $(echo $lines) |"$'\n'
  else
    report+="| $name | **failed** | $expected | $(echo $lines) |"$'\n'
    echo "::error::$name: expected $expected connected scene(s) after every launch, probe saw: $(echo $lines)"
    failed=1
  fi
}

run_case relaunch-one-window 1
run_case relaunch-after-open-in-new-window 2 new-window
bounded 60 xcrun simctl terminate "$UDID" "$APP" 2> /dev/null

{
  echo "## v2 windows (iPad simulator)"
  echo "| case | result | expected scenes | scenes seen per window shown |"
  echo "|---|---|---|---|"
  printf '%s' "$report"
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
exit $failed

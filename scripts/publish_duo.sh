#!/bin/bash
# Publishes the iPhone Duo screenshots so far to the `screenshots` branch,
# under <dest>/ (replacing what was there). Called after every pose so a
# runner that dies mid-run still leaves what it captured.
#
#   scripts/publish_duo.sh <src-dir> <dest-dir>
set -u
SRC=$1
DEST=$2
[ -d "$SRC" ] || exit 0
WT="$RUNNER_TEMP/screenshots-wt"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
for i in 1 2 3 4 5; do
  git fetch -q origin screenshots:refs/remotes/origin/screenshots 2>/dev/null || true
  rm -rf "$WT"; git worktree prune
  if git rev-parse -q --verify refs/remotes/origin/screenshots > /dev/null; then
    git worktree add -q --detach "$WT" refs/remotes/origin/screenshots
  else
    git worktree add -q --detach "$WT" && (cd "$WT" && git checkout -q --orphan tmp && git rm -rqf . )
  fi
  rm -rf "${WT:?}/$DEST" && mkdir -p "$WT/$DEST"
  cp "$SRC"/* "$WT/$DEST/" 2>/dev/null || true
  (cd "$WT" && git add -A "$DEST" && { git commit -qm "iPhone Duo screenshots for $DEST (${GITHUB_SHA::7})" || exit 0; } \
    && git -c user.name="github-actions[bot]" push -q origin HEAD:screenshots) && exit 0
  sleep $((i * 3))
done
exit 1

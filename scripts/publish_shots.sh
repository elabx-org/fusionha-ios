#!/bin/bash
# Publishes screenshots to the `screenshots` branch under <dest-dir>/.
# Each attempt starts from a fresh checkout of the latest branch tip and
# copies the files in again, so runs publishing at the same time never hit
# a rebase conflict on binary files; a lost push race just retries.
# Publishing is a convenience for review: if every attempt fails it warns
# and exits 0 rather than failing the build.
#
#   scripts/publish_shots.sh <src-dir> <dest-dir> [--keep-subdirs]
#
# --keep-subdirs replaces only the top-level *.png in <dest-dir> (the main
# screenshots job keeps the iPhone Duo job's <dest>/duo/); without it the
# whole <dest-dir> is replaced.
set -u
SRC=$1
DEST=$2
MODE=${3:-}
[ -d "$SRC" ] || exit 0
WT="$RUNNER_TEMP/screenshots-wt-$$"
for i in 1 2 3 4 5 6 7 8; do
  git fetch -q origin screenshots:refs/remotes/origin/screenshots 2>/dev/null || true
  rm -rf "$WT"; git worktree prune
  if git rev-parse -q --verify refs/remotes/origin/screenshots > /dev/null; then
    git worktree add -q --detach "$WT" refs/remotes/origin/screenshots
  else
    git worktree add -q --detach "$WT" && (cd "$WT" && git checkout -q --orphan tmp && { git rm -rqf . 2>/dev/null || true; })
  fi
  if [ "$MODE" = --keep-subdirs ]; then
    mkdir -p "$WT/$DEST" && find "$WT/$DEST" -maxdepth 1 -name '*.png' -delete
  else
    rm -rf "${WT:?}/$DEST" && mkdir -p "$WT/$DEST"
  fi
  cp "$SRC"/* "$WT/$DEST/" 2>/dev/null || true
  (
    cd "$WT" || exit 1
    git add -A "$DEST"
    git diff --cached --quiet && exit 0
    git -c user.name="github-actions[bot]" \
        -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
        commit -qm "Screenshots for $DEST (${GITHUB_SHA::7})" &&
      git push -q origin HEAD:screenshots
  ) && { rm -rf "$WT"; git worktree prune; exit 0; }
  sleep $((i * 2 + RANDOM % 5))
done
rm -rf "$WT"; git worktree prune
echo "::warning::Could not publish screenshots to the screenshots branch after 8 attempts"
exit 0

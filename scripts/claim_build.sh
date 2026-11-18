#!/usr/bin/env bash
# Claims a release's build number: pushes the tag build-N at <sha>, and
# prints N. CI's release runs and scripts/local_release.sh both claim this
# way, so a number is handed out once, wherever the build runs.
#
#   scripts/claim_build.sh <sha>             the next free number (claimed)
#   scripts/claim_build.sh <sha> --dry-run   the number it would claim (nothing pushed)
#   scripts/claim_build.sh <sha> --exact N   N itself, or fail if it is taken
#
# The tags are the counter: N is one past the highest build-N on the remote.
# A push of a tag that already exists is refused by the server, so two runs
# that race for N cannot both get it; the loser moves on to N+1. A number
# whose build then fails keeps its tag and is skipped, never handed out again
# (an IPA built with it may already be around).
set -euo pipefail
sha=$1 mode=${2:-} exact=${3:-}
remote=${CLAIM_REMOTE:-origin}

highest() {
  git ls-remote --tags "$remote" 'refs/tags/build-*' \
    | sed -n 's#.*refs/tags/build-\([0-9][0-9]*\)$#\1#p' | sort -n | tail -1
}
taken() { [ -n "$(git ls-remote --tags "$remote" "refs/tags/build-$1")" ]; }
# Each claim is its own annotated tag object (who claimed it, when, a nonce).
# Pushing a plain tag that exists at the same commit is "up to date" and
# succeeds, so two claims on one commit (a CI run and a local release of the
# same main) would both win; a different tag object is always refused. The
# remote is then read back: the number is ours only if it holds our object.
claimer=${GITHUB_RUN_ID:+CI run $GITHUB_RUN_ID}
claimer=${claimer:-scripts/local_release.sh}
claim() {
  local n=$1 obj
  git -c user.name="fusionha release" -c user.email="release@users.noreply.github.com" \
    tag -f -a -m "build-$n, claimed by $claimer at $(date -u +%Y-%m-%dT%H:%M:%SZ) ($$-$RANDOM$RANDOM)" \
    "build-$n" "$sha" > /dev/null
  obj=$(git rev-parse "refs/tags/build-$n")
  if git push -q "$remote" "refs/tags/build-$n:refs/tags/build-$n" 2> /dev/null \
    && [ "$(git ls-remote "$remote" "refs/tags/build-$n" | cut -f1)" = "$obj" ]; then
    return 0
  fi
  git tag -d "build-$n" > /dev/null
  return 1
}

case "$mode" in
  --exact)
    if claim "$exact"; then echo "$exact"; exit 0; fi
    echo "claim_build.sh: build-$exact is taken (or the push failed)." >&2; exit 1 ;;
  --dry-run)
    last=$(highest); echo $(( ${last:-0} + 1 )); exit 0 ;;
  "") ;;
  *) echo "claim_build.sh: unknown option $mode" >&2; exit 2 ;;
esac

last=$(highest)
n=$(( ${last:-0} + 1 ))
for _ in $(seq 1 10); do
  if claim "$n"; then echo "$n"; exit 0; fi
  # Refused: someone else got there first, or the push itself failed.
  if ! taken "$n"; then
    echo "claim_build.sh: could not push build-$n to $remote." >&2; exit 1
  fi
  n=$(( n + 1 ))
done
echo "claim_build.sh: no free number after 10 tries." >&2
exit 1

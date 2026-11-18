#!/usr/bin/env bash
# Builds the unsigned IPA on this Mac and stages (or publishes) a GitHub
# release that Feather picks up, the way CI's release job does.
#
#   scripts/local_release.sh [--publish] [--build N] [--scheme Fusionha]
#
# Without --publish it is a dry run: it checks, tests, builds and stages
# build/local-release/<tag>/ (Fusionha.ipa + source.json) and prints the
# `gh release create` it would run, under the number it would claim. With
# --publish it claims the number, publishes, then fast-forwards main to the
# released commit.
#
# This is the release path (owner, 2026-11-18): about 4 minutes to Feather.
# Main moves last, so when CI runs on that push it finds the commit already
# released and only builds and tests it (the backstop), publishing nothing.
#
# Build number: claimed from the same counter as CI's release runs
# (scripts/claim_build.sh: the tag build-N pushed at HEAD, one past the
# highest), so a local release and a CI release never share a number. The
# claim comes after the tests and before the build, which bakes the number
# in; if the build then fails, that number is skipped. --build N claims N
# itself and stops if it is taken.
#
# Checks before anything is claimed (the stand-in for "green CI first"):
#   - a clean working tree (nothing uncommitted is ever released; CLAUDE.md aside);
#   - main can fast-forward to HEAD (HEAD contains origin/main);
#   - `swift test` on FusionhaKit passes.
# Needs Xcode (DEVELOPER_DIR is set to /Applications/Xcode.app when unset),
# xcodegen and gh.
set -euo pipefail
cd "$(dirname "$0")/.."

publish=0 build="" scheme=Fusionha
while [ $# -gt 0 ]; do
  case "$1" in
    --publish) publish=1 ;;
    --build) build=$2; shift ;;
    --scheme) scheme=$2; shift ;;
    *) echo "local_release.sh: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done

export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
repo=elabx-org/fusionha-ios
started=$SECONDS lap=$SECONDS first=1
# Each step's heading; the time the step before it took.
step() {
  if [ "$first" = 1 ]; then first=0; else printf '   (%ss)\n' $(( SECONDS - lap )); fi
  lap=$SECONDS
  printf '\n== %s\n' "$*"
}

step "Checks"
mkdir -p build
# CLAUDE.md is kept uncommitted on purpose (owner rule), so it does not count.
dirty=$(git status --porcelain --untracked-files=no -- . ':!CLAUDE.md')
if [ -n "$dirty" ]; then
  echo "Uncommitted changes: commit or stash them first." >&2
  echo "$dirty" >&2
  [ "$publish" = 1 ] && exit 1 || echo "(dry run: going on anyway)"
fi
sha=$(git rev-parse HEAD)
git fetch -q origin
if ! git merge-base --is-ancestor origin/main "$sha"; then
  echo "HEAD ${sha:0:8} does not contain origin/main: main could not fast-forward to it. Rebase or merge first." >&2
  [ "$publish" = 1 ] && exit 1 || echo "(dry run: going on anyway)"
fi

step "FusionhaKit tests"
swift test --package-path Packages/FusionhaKit > build/local-release-tests.log 2>&1 \
  || { tail -20 build/local-release-tests.log >&2; echo "Tests failed (build/local-release-tests.log)." >&2; exit 1; }
grep -E 'Executed [0-9]+ tests' build/local-release-tests.log | tail -1 | sed 's/^[[:space:]]*//'

step "Build number"
if [ "$publish" = 1 ]; then
  if [ -n "$build" ]; then build=$(bash scripts/claim_build.sh "$sha" --exact "$build")
  else build=$(bash scripts/claim_build.sh "$sha"); fi
  echo "claimed build-$build (tag pushed at ${sha:0:8})"
else
  [ -n "$build" ] || build=$(bash scripts/claim_build.sh "$sha" --dry-run)
  echo "would claim build-$build (dry run: nothing pushed)"
fi
tag="build-$build"
version=$(bash scripts/app_version.sh "$scheme" "$build")
echo "commit ${sha:0:8} · $tag · version $version"

step "Release build ($scheme, unsigned, device)"
xcodegen generate > /dev/null
xcodebuild -project Fusionha.xcodeproj -scheme "$scheme" -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  CURRENT_PROJECT_VERSION="$build" MARKETING_VERSION="$version" \
  build 2>&1 | tee build/local-release.log | grep -E ': error: |\*\* BUILD' || true
if ! grep -q '\*\* BUILD SUCCEEDED' build/local-release.log; then
  echo "Build failed (build/local-release.log)." >&2
  [ "$publish" = 1 ] && echo "build-$build stays claimed and is skipped." >&2
  exit 1
fi

step "Package IPA and source.json"
stage=build/local-release/$tag
rm -rf build/local-release
mkdir -p "$stage" build/local-release/ipas build/local-release/Payload
cp -R "build/Build/Products/Release-iphoneos/$scheme.app" build/local-release/Payload/
(cd build/local-release && zip -qry "ipas/$scheme.ipa" Payload)
outputs=build/local-release/outputs
# make_source.py names the commit from GITHUB_SHA, as on CI; the outputs say
# whether this release may be marked latest (not if a higher build-N is out).
GITHUB_SHA=$sha GITHUB_OUTPUT=$outputs bash scripts/release_source.sh build/local-release/ipas "$build" "$stage"
latest=$(sed -n 's/^latest=//p' "$outputs")
ls -lh "$stage"

title="fusionha $version (build $build)"
# The tag exists once claimed: --verify-tag publishes on it rather than making one.
cmd=(gh release create "$tag" "$stage"/Fusionha.ipa "$stage"/source.json --repo "$repo" --verify-tag
     --title "$title" --notes "Built locally from ${sha:0:8}." "--latest=$latest")
if [ "$publish" = 1 ]; then
  step "Publish"
  "${cmd[@]}"
  echo "Feather: https://github.com/$repo/releases/latest/download/source.json"
  step "Main"
  # Last: CI's run on this push finds the release and only checks the commit.
  if git push -q origin "$sha:refs/heads/main"; then
    echo "main is at ${sha:0:8}; CI checks it and publishes nothing."
  else
    echo "Released, but main did not move (it changed meanwhile?): fast-forward it to ${sha:0:8} by hand." >&2
  fi
else
  step "Dry run: would run"
  printf '%q ' "${cmd[@]}"; echo
  echo "git push origin ${sha:0:8}:main"
fi
printf '   (%ss)\n\nTotal: %ss\n' $(( SECONDS - lap )) $(( SECONDS - started ))

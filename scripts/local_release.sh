#!/usr/bin/env bash
# Builds the unsigned IPA on this Mac and stages (or publishes) a GitHub
# release that Feather picks up, the way CI's release job does.
#
#   scripts/local_release.sh [--publish] [--build N] [--scheme Fusionha]
#
# Without --publish it is a dry run: it checks, tests, builds and stages
# build/local-release/<tag>/ (Fusionha.ipa + source.json) and prints the
# `gh release create` it would run. With --publish it runs it.
#
# Build number: the latest `build-N` release + 1, unless --build is given.
# CI stamps github.run_number instead, so until CI takes the same counter a
# local number can collide with a later CI run: the tag is checked first and
# the script stops if it already exists.
#
# Checks before anything is built (the stand-in for "green CI first"):
#   - a clean working tree (nothing uncommitted is ever released);
#   - HEAD is on origin, so the release tag points at a pushed commit;
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
step() { printf '\n== %s\n' "$*"; }

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
if ! git branch -r --contains "$sha" | grep -q .; then
  echo "HEAD ${sha:0:8} is not on origin: push it first." >&2
  [ "$publish" = 1 ] && exit 1 || echo "(dry run: going on anyway)"
fi

if [ -z "$build" ]; then
  last=$(gh release list --repo "$repo" --limit 50 --json tagName -q '.[].tagName' \
    | sed -n 's/^build-\([0-9][0-9]*\)$/\1/p' | sort -n | tail -1)
  build=$(( ${last:-0} + 1 ))
fi
tag="build-$build"
if gh release view "$tag" --repo "$repo" > /dev/null 2>&1; then
  echo "Release $tag already exists: pass --build with a free number." >&2
  exit 1
fi
version=$(bash scripts/app_version.sh "$scheme" "$build")
echo "commit ${sha:0:8} · $tag · version $version"

step "FusionhaKit tests"
swift test --package-path Packages/FusionhaKit > build/local-release-tests.log 2>&1 \
  || { tail -20 build/local-release-tests.log >&2; echo "Tests failed (build/local-release-tests.log)." >&2; exit 1; }
grep -E 'Executed [0-9]+ tests' build/local-release-tests.log | tail -1 | sed 's/^[[:space:]]*//'

step "Release build ($scheme, unsigned, device)"
xcodegen generate > /dev/null
set -o pipefail
xcodebuild -project Fusionha.xcodeproj -scheme "$scheme" -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  CURRENT_PROJECT_VERSION="$build" MARKETING_VERSION="$version" \
  build 2>&1 | tee build/local-release.log | grep -E ': error: |\*\* BUILD' || true
grep -q '\*\* BUILD SUCCEEDED' build/local-release.log || { echo "Build failed (build/local-release.log)." >&2; exit 1; }

step "Package and stage"
stage=build/local-release/$tag
rm -rf "$stage" build/local-release/ipas build/local-release/Payload
mkdir -p "$stage" build/local-release/ipas build/local-release/Payload
cp -R "build/Build/Products/Release-iphoneos/$scheme.app" build/local-release/Payload/
(cd build/local-release && zip -qry "ipas/$scheme.ipa" Payload)
# make_source.py names the commit from GITHUB_SHA, as on CI.
GITHUB_SHA=$sha bash scripts/release_source.sh build/local-release/ipas "$build" "$stage"
ls -lh "$stage"

title="fusionha $version (build $build)"
cmd=(gh release create "$tag" "$stage"/* --repo "$repo" --target "$sha" --title "$title"
     --notes "Built locally from ${sha:0:8}." --latest)
if [ "$publish" = 1 ]; then
  step "Publish"
  "${cmd[@]}"
  echo "Feather: https://github.com/$repo/releases/latest/download/source.json"
else
  step "Dry run: would run"
  printf '%q ' "${cmd[@]}"; echo
fi

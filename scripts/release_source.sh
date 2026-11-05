#!/usr/bin/env bash
# Stages one GitHub release: the IPAs this run built plus one source.json.
# Usage: scripts/release_source.sh <ipa-dir> <build-number> <out-dir>
#
# Writes <out-dir>/Fusionha.ipa, FusionhaV2.ipa (when the v2 leg built it) and
# source.json, and the release's tag and name to $GITHUB_OUTPUT. v1 is required:
# without its IPA nothing is staged (no tag output, so nothing is published).
# Without a v2 IPA, the v2 entry is carried from the latest published release's
# source.json, if it has one and its IPA still downloads.
set -euo pipefail
ipas=$1 build=$2 out=$3
here=$(cd "$(dirname "$0")" && pwd)
output=${GITHUB_OUTPUT:-/dev/null}

if [[ "${GITHUB_REF:-}" == refs/tags/v* ]]; then tag="$GITHUB_REF_NAME"; else tag="build-$build"; fi

if [ ! -f "$ipas/Fusionha.ipa" ]; then
  echo "::warning::No Fusionha.ipa (the v1 build failed): nothing is released."
  exit 0
fi

mkdir -p "$out"
cp "$ipas/Fusionha.ipa" "$out/"
v1_version=$(bash "$here/app_version.sh" Fusionha "$build")
args=(--tag "$tag" --out "$out/source.json" --app "v1=$out/Fusionha.ipa:$v1_version:$build")

if [ -f "$ipas/FusionhaV2.ipa" ]; then
  cp "$ipas/FusionhaV2.ipa" "$out/"
  v2_version=$(bash "$here/app_version.sh" FusionhaV2 "$build")
  args+=(--app "v2=$out/FusionhaV2.ipa:$v2_version:$build")
else
  echo "::warning::No FusionhaV2.ipa this run: carrying the previous v2 entry, if any."
  prev=$(mktemp -d)
  # No tag: the latest published release (this run's isn't published yet).
  if gh release download --repo "${GITHUB_REPOSITORY:-elabx-org/fusionha-ios}" \
       --pattern source.json --dir "$prev" 2>/dev/null; then
    # Never fatal: an unreadable previous source.json only means no v2 carry.
    url=$(python3 - "$prev/source.json" <<'PY'
import json, sys
try:
    apps = json.load(open(sys.argv[1])).get("apps", [])
    print(next((a.get("downloadURL", "") for a in apps
                if isinstance(a, dict) and a.get("bundleIdentifier") == "org.elabx.fusionha.v2"), ""))
except Exception:
    print("")
PY
) || url=""
    if [ -z "$url" ]; then
      echo "No v2 entry in the previous source.json (first v2 release?)."
    # A 1-byte GET, not HEAD: the asset redirect's signed URL may only accept GET.
    elif curl -sfL -r 0-0 -o /dev/null "$url"; then
      args+=(--carry "$prev/source.json")
    else
      echo "::warning::The previous v2 IPA no longer downloads ($url): v2 left out."
    fi
  else
    echo "No previous release source.json to carry from."
  fi
fi

python3 "$here/make_source.py" "${args[@]}"
{
  echo "tag=$tag"
  echo "name=fusionha $v1_version (build $build)"
} >> "$output"

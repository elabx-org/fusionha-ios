#!/usr/bin/env bash
# Stages one GitHub release: the IPAs this run built plus one source.json.
# Usage: scripts/release_source.sh <ipa-dir> <build-number> <out-dir>
#
# Writes <out-dir>/Fusionha.ipa and source.json, and the release's tag and name
# to $GITHUB_OUTPUT. Without the IPA nothing is staged (no tag output, so
# nothing is published). One app since the v2 cutover (docs/v2.md).
set -euo pipefail
ipas=$1 build=$2 out=$3
here=$(cd "$(dirname "$0")" && pwd)
output=${GITHUB_OUTPUT:-/dev/null}

if [[ "${GITHUB_REF:-}" == refs/tags/v* ]]; then tag="$GITHUB_REF_NAME"; else tag="build-$build"; fi

if [ ! -f "$ipas/Fusionha.ipa" ]; then
  echo "::warning::No Fusionha.ipa (the build failed): nothing is released."
  exit 0
fi

mkdir -p "$out"
cp "$ipas/Fusionha.ipa" "$out/"
version=$(bash "$here/app_version.sh" Fusionha "$build")
args=(--tag "$tag" --out "$out/source.json" --app "v1=$out/Fusionha.ipa:$version:$build")

python3 "$here/make_source.py" "${args[@]}"
{
  echo "tag=$tag"
  echo "name=fusionha $version (build $build)"
} >> "$output"

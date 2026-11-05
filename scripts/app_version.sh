#!/usr/bin/env bash
# Prints the marketing version CI stamps on a scheme's build.
# Usage: scripts/app_version.sh <scheme> <build-number>
#
# Feather only offers an update when the version string changes, so the patch
# number is the CI run number. v1 (Fusionha): project.yml's first
# MARKETING_VERSION (1.1.0) ships as 1.1.<run>. v2 (FusionhaV2): 2.0.<run>.
set -euo pipefail
scheme=$1 build=$2
case "$scheme" in
  Fusionha)
    BASE=$(sed -n 's/^ *MARKETING_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' project.yml | head -1) ;;
  FusionhaV2)
    BASE=2.0.0 ;;
  *)
    echo "app_version.sh: unknown scheme $scheme" >&2; exit 1 ;;
esac
echo "${BASE%.*}.$build"

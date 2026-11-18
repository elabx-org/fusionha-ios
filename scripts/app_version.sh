#!/usr/bin/env bash
# Prints the marketing version CI stamps on a scheme's build.
# Usage: scripts/app_version.sh <scheme> <build-number>
#
# Feather only offers an update when the version string changes, so the patch
# number is the CI run number: project.yml's first MARKETING_VERSION (2.0.0
# since the v2 cutover, above v1's last 1.1.<run>) ships as 2.0.<run>.
set -euo pipefail
scheme=$1 build=$2
case "$scheme" in
  Fusionha)
    BASE=$(sed -n 's/^ *MARKETING_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' project.yml | head -1) ;;
  *)
    echo "app_version.sh: unknown scheme $scheme" >&2; exit 1 ;;
esac
echo "${BASE%.*}.$build"

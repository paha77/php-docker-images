#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source versions.env
args=()
for branch in "${PHP_BRANCHES[@]}"; do
    args+=("$branch" "${PHP_VERSIONS[$branch]}" "${UBI_GENERATIONS[$branch]}")
done
exec python3 -B scripts/describe.py "${args[@]}"

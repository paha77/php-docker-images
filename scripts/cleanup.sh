#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source versions.env
repositories=()
for branch in "${PHP_BRANCHES[@]}"; do
    repositories+=("php-$branch-cli" "s2i-ubi${UBI_GENERATIONS[$branch]}-php$branch" "php-$branch-dev")
done
exec python3 scripts/cleanup.py "${repositories[@]}"

#!/usr/bin/env bash
# Uses the default Buildx docker driver so dev resolves the freshly loaded UBI.
set -euo pipefail
cd "$(dirname "$0")/.."
source versions.env
# CI selects one image; no arguments retains the complete local build.
kind_filter=${1:-all}
branch_filter=${2:-all}
arch_filter=${3:-all}
[[ $# -le 3 && "$kind_filter" =~ ^(all|cli|ubi|dev)$ && "$arch_filter" =~ ^(all|amd64|arm64)$ ]] || exit 1
[[ "$branch_filter" == all || " ${PHP_BRANCHES[*]} " == *" $branch_filter "* ]] || exit 1
for branch in "${PHP_BRANCHES[@]}"; do
    [[ "$branch_filter" == all || "$branch_filter" == "$branch" ]] || continue
    for arch in amd64 arm64; do
        [[ "$arch_filter" == all || "$arch_filter" == "$arch" ]] || continue
        platform=linux/$arch
        [[ "$arch" != arm64 ]] || platform=linux/arm64/v8
        if [[ "$kind_filter" == all || "$kind_filter" == cli ]]; then
            docker buildx build --builder default --platform "$platform" --pull --no-cache --load \
                --build-arg PHP_VERSION="${PHP_VERSIONS[$branch]}" -t "local/php-cli:$branch-$arch" images/cli
            bash scripts/check-image.sh "local/php-cli:$branch-$arch" "$platform" cli "${PHP_VERSIONS[$branch]}"
        fi
        if [[ "$kind_filter" == all || "$kind_filter" == ubi ]]; then
            docker buildx build --builder default --platform "$platform" --pull --no-cache --load \
                --build-arg UBI_BASE="${UBI_BASES[$branch]}" -t "local/php-ubi:$branch-$arch" images/ubi
            bash scripts/check-image.sh "local/php-ubi:$branch-$arch" "$platform" ubi "${PHP_VERSIONS[$branch]}"
        fi
        if [[ "$kind_filter" == all || "$kind_filter" == dev ]]; then
            # CI loads the validated UBI artifact from this run before selecting dev.
            docker image inspect "local/php-ubi:$branch-$arch" >/dev/null
            # No --pull: use only the freshly built/loaded local UBI parent.
            docker buildx build --builder default --platform "$platform" --no-cache --load \
                --build-arg UBI_IMAGE="local/php-ubi:$branch-$arch" --build-arg COMPOSER_BASE="$COMPOSER_BASE" \
                --build-arg PHP_VERSION="${PHP_VERSIONS[$branch]}" --build-arg XDEBUG_SOURCE_VERSION="$XDEBUG_SOURCE_VERSION" \
                --build-arg XDEBUG_PACKAGE="${XDEBUG_PACKAGES[$branch]}" \
                -t "local/php-dev:$branch-$arch" images/dev
            bash scripts/check-image.sh "local/php-dev:$branch-$arch" "$platform" dev "${PHP_VERSIONS[$branch]}"
        fi
    done
done

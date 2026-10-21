#!/usr/bin/env bash
# Uses the default Buildx docker driver so dev resolves the freshly loaded UBI.
set -euo pipefail
cd "$(dirname "$0")/.."
source versions.env
for branch in "${PHP_BRANCHES[@]}"; do
    for arch in amd64 arm64; do
        platform=linux/$arch
        [[ "$arch" != arm64 ]] || platform=linux/arm64/v8
        docker buildx build --builder default --platform "$platform" --pull --no-cache --load \
            --build-arg PHP_VERSION="${PHP_VERSIONS[$branch]}" -t "local/php-cli:$branch-$arch" images/cli
        bash scripts/check-image.sh "local/php-cli:$branch-$arch" "$platform" cli "${PHP_VERSIONS[$branch]}"
        docker buildx build --builder default --platform "$platform" --pull --no-cache --load \
            --build-arg UBI_BASE="${UBI_BASES[$branch]}" -t "local/php-ubi:$branch-$arch" images/ubi
        bash scripts/check-image.sh "local/php-ubi:$branch-$arch" "$platform" ubi "${PHP_VERSIONS[$branch]}"
        # No --pull: this branch and architecture's UBI was just built in this daemon.
        docker buildx build --builder default --platform "$platform" --no-cache --load \
            --build-arg UBI_IMAGE="local/php-ubi:$branch-$arch" --build-arg COMPOSER_BASE="$COMPOSER_BASE" \
            --build-arg XDEBUG_PACKAGE="${XDEBUG_PACKAGES[$branch]}" \
            -t "local/php-dev:$branch-$arch" images/dev
        bash scripts/check-image.sh "local/php-dev:$branch-$arch" "$platform" dev "${PHP_VERSIONS[$branch]}"
    done
done

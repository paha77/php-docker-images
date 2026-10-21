#!/usr/bin/env bash
# Uses the default Buildx docker driver so dev resolves the freshly loaded UBI.
set -euo pipefail
cd "$(dirname "$0")/.."
source versions.env
for arch in amd64 arm64; do
    platform=linux/$arch
    [[ "$arch" != arm64 ]] || platform=linux/arm64/v8
    docker buildx build --builder default --platform "$platform" --pull --no-cache --load \
        --build-arg PHP_VERSION="$PHP_VERSION" -t "local/php-cli:$arch" images/cli
    docker buildx build --builder default --platform "$platform" --pull --no-cache --load \
        --build-arg UBI_BASE="$UBI_BASE" -t "local/php-ubi:$arch" images/ubi
    # No --pull: the exact architecture's upstream was just built in this daemon.
    docker buildx build --builder default --platform "$platform" --no-cache --load \
        --build-arg UBI_IMAGE="local/php-ubi:$arch" --build-arg COMPOSER_BASE="$COMPOSER_BASE" \
        -t "local/php-dev:$arch" images/dev
    for kind in cli ubi dev; do
        bash scripts/check-image.sh "local/php-$kind:$arch" "$platform" "$kind" "$PHP_VERSION"
    done
done

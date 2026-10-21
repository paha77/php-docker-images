#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source versions.env
DOCKERHUB_NAMESPACE=${DOCKERHUB_NAMESPACE:-paha77}
: "${GITHUB_SHA:?}" "${GITHUB_RUN_ID:?}" "${GITHUB_RUN_ATTEMPT:?}"
# Run IDs and attempts distinguish security refreshes at the same source revision.
release="php${PHP_VERSION}-${GITHUB_SHA}-run${GITHUB_RUN_ID}.${GITHUB_RUN_ATTEMPT}"
for kind in cli ubi dev; do
    case "$kind" in
        cli) repo="$DOCKERHUB_NAMESPACE/php-82-cli" ;;
        ubi) repo="$DOCKERHUB_NAMESPACE/s2i-ubi9-php82" ;;
        dev) repo="$DOCKERHUB_NAMESPACE/php-82-dev" ;;
    esac
    for arch in amd64 arm64; do
        docker tag "local/php-$kind:$arch" "$repo:$release-$arch"
        docker push "$repo:$release-$arch"
    done
    docker manifest create "$repo:$release" "$repo:$release-amd64" "$repo:$release-arm64"
    docker manifest annotate "$repo:$release" "$repo:$release-arm64" --os linux --arch arm64 --variant v8
    docker manifest push "$repo:$release"
    bash scripts/check-manifest.sh "$repo:$release"
done
# All immutable manifests must pass before any compatibility alias is changed.
for repo in "$DOCKERHUB_NAMESPACE/php-82-cli" "$DOCKERHUB_NAMESPACE/s2i-ubi9-php82" "$DOCKERHUB_NAMESPACE/php-82-dev"; do
    for tag in "php$PHP_VERSION" latest; do
        docker buildx imagetools create --tag "$repo:$tag" "$repo:$release"
        bash scripts/check-manifest.sh "$repo:$tag"
    done
done

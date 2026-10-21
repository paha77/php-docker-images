#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source versions.env
DOCKERHUB_NAMESPACE=${DOCKERHUB_NAMESPACE:-paha77}
: "${GITHUB_SHA:?}" "${GITHUB_RUN_ID:?}" "${GITHUB_RUN_ATTEMPT:?}"
repositories=() releases=() versions=()
for branch in "${PHP_BRANCHES[@]}"; do
    version=${PHP_VERSIONS[$branch]}
    # Run IDs and attempts distinguish security refreshes at the same source revision.
    release="php${version}-${GITHUB_SHA}-run${GITHUB_RUN_ID}.${GITHUB_RUN_ATTEMPT}"
    for kind in cli ubi dev; do
        case "$kind" in
            cli) repo="$DOCKERHUB_NAMESPACE/php-$branch-cli" ;;
            ubi) repo="$DOCKERHUB_NAMESPACE/s2i-ubi${UBI_GENERATIONS[$branch]}-php$branch" ;;
            dev) repo="$DOCKERHUB_NAMESPACE/php-$branch-dev" ;;
        esac
        for arch in amd64 arm64; do
            docker tag "local/php-$kind:$branch-$arch" "$repo:$release-$arch"
            docker push "$repo:$release-$arch"
        done
        docker manifest create "$repo:$release" "$repo:$release-amd64" "$repo:$release-arm64"
        docker manifest annotate "$repo:$release" "$repo:$release-arm64" --os linux --arch arm64 --variant v8
        docker manifest push "$repo:$release"
        bash scripts/check-manifest.sh "$repo:$release"
        repositories+=("$repo") releases+=("$release") versions+=("$version")
    done
done
# All six immutable manifests must pass before any compatibility alias is changed.
for index in "${!repositories[@]}"; do
    repo=${repositories[$index]}
    for tag in "php${versions[$index]}" latest; do
        docker buildx imagetools create --tag "$repo:$tag" "$repo:${releases[$index]}"
        bash scripts/check-manifest.sh "$repo:$tag"
    done
done

#!/usr/bin/env bash
set -euo pipefail
manifest=$(docker manifest inspect "$1")
jq -e '
  [.manifests[].platform | select(.os == "linux")] as $p |
  any($p[]; .architecture == "amd64") and
  any($p[]; .architecture == "arm64" and ((.variant // "v8") == "v8"))
' <<< "$manifest"
docker buildx imagetools inspect "$1"

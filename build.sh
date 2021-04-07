#!/bin/bash
set -euo pipefail
set -x

repo='manjarocn/base'
today=$(date -u +'%Y%m%d')

DOCKER_BUILDKIT=1 docker build --progress=plain --pull --squash -t "$repo:$today" .
docker tag "$repo:$today" "$repo:latest"
docker push "$repo:$today"
docker push "$repo:latest"

#!/bin/bash
set -euo pipefail
set -x

: "${REPO:='manjarocn/base'}"
: "${BRANCH:='stable'}"
: "${TAG:=$(date -u +'%Y%m%d')}"

DOCKER_BUILDKIT=1 docker build --progress=plain --pull --compress --squash \
    -t "$REPO:$BRANCH-$TAG" --args "BRANCH=$BRANCH" .
docker tag "$REPO:$BRANCH-$TAG" "$REPO:$BRANCH-latest"
docker push "$REPO:$BRANCH-$TAG"
docker push "$REPO:$BRANCH-latest"

if [ "$BRANCH" == 'stable' ]; then
    docker tag "$REPO:$BRANCH-$TAG" "$REPO:latest"
    docker push "$REPO:latest"
fi

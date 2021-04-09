#!/bin/bash
set -euo pipefail
set -x

: "${REPO:=manjarocn/base}"
: "${BRANCH:=stable}"
: "${TAG:=$(date -u +'%Y%m%d')}"

DOCKER_BUILDKIT=1 docker build --progress=plain --pull --compress --squash \
    --build-arg "BRANCH=$BRANCH" -t "$REPO:$BRANCH-$TAG" .
docker tag "$REPO:$BRANCH-$TAG" "$REPO:$BRANCH-latest"
docker push "$REPO:$BRANCH-$TAG"
docker push "$REPO:$BRANCH-latest"

if [ "$BRANCH" == 'stable' ]; then
    docker tag "$REPO:$BRANCH-$TAG" "$REPO:latest"
    docker push "$REPO:latest"
fi

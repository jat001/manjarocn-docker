#!/bin/bash
set -euo pipefail
# rewrite the trace output to stdout
exec 3>&1
export BASH_XTRACEFD=3
set -x

: "${REPO:=manjarocn/base}"
: "${BRANCH:=stable}"
: "${TAG:=$(date -u +'%Y%m%d')}"
: "${PUSH:=1}"

DOCKER_BUILDKIT=1 docker build --progress=plain --pull --no-cache --squash --compress \
    --build-arg "BRANCH=$BRANCH" -t "$REPO:$BRANCH-$TAG" .
docker tag "$REPO:$BRANCH-$TAG" "$REPO:$BRANCH-latest"

if [ "$PUSH" -gt 0 ]; then
    docker push "$REPO:$BRANCH-$TAG"
    docker push "$REPO:$BRANCH-latest"
fi

if [ "$BRANCH" == 'stable' ]; then
    docker tag "$REPO:$BRANCH-$TAG" "$REPO:latest"
    [ "$PUSH" -gt 0 ] && docker push "$REPO:latest"
fi

#!/bin/bash
# Multi-arch (amd64 + arm64) build + push for the rviz2 AGL-display container.
#
# Unlike the Flutter apps (docker/script/build_multiarch.sh), rviz2 is NOT built
# from per-arch pre-built bundles. Its Dockerfile is arch-agnostic:
#   FROM ros:humble-ros-base   (an official multi-arch image: amd64 + arm64)
#   RUN apt-get install ros-humble-rviz2 cage xwayland ...
# so a SINGLE `docker buildx build --platform=linux/amd64,linux/arm64` produces
# the multi-arch manifest list in one shot — no per-arch bundle, no separate
# `imagetools create` step needed (contrast: Flutter build_multiarch.sh).
#
# Usage (from apps/):
#   ./docker/script/build_rviz2_multiarch.sh
#   TAG=multiarch-verify ./docker/script/build_rviz2_multiarch.sh   # safe, non-:latest
#
# Env:
#   REGISTRY  default registry.obigo.com
#   IMAGE     registry image repo path   (default oss/rviz2-agl)
#   TAG       manifest tag               (default latest)
#   BUILDER   buildx builder name        (default mmf-buildx)
set -e

REGISTRY="${REGISTRY:-registry.obigo.com}"
IMAGE="${IMAGE:-oss/rviz2-agl}"
TAG="${TAG:-latest}"
BUILDER="${BUILDER:-mmf-buildx}"

# apps/ is the working dir; container context is the agl-display folder.
cd "$(dirname "$0")/../.."
CTX="rviz2_port/docker/agl-display"
MANIFEST="${REGISTRY}/${IMAGE}:${TAG}"

[ -f "${CTX}/Dockerfile" ] || { echo "ERR: ${CTX}/Dockerfile not found (run from apps/)"; exit 1; }

echo "=== rviz2 multi-arch build: ${CTX}/Dockerfile → ${MANIFEST} (amd64 + arm64, one-shot) ==="

# buildx builder (docker-container driver + QEMU emulation for the cross-arch build).
docker buildx create --name "${BUILDER}" --driver docker-container --use 2>/dev/null \
  || docker buildx use "${BUILDER}"

docker buildx build \
  --platform=linux/amd64,linux/arm64 \
  -f "${CTX}/Dockerfile" \
  --push -t "${MANIFEST}" \
  "${CTX}"

echo ""; echo "=== Done. Multi-arch manifest pushed ==="
docker buildx imagetools inspect "${MANIFEST}" | grep -iE "Name|Platform|MediaType" | sed 's/^/  /'

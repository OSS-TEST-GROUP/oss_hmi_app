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
BASE="${REGISTRY}/${IMAGE}"
MANIFEST="${BASE}:${TAG}"

[ -f "${CTX}/Dockerfile" ] || { echo "ERR: ${CTX}/Dockerfile not found (run from apps/)"; exit 1; }

# ── 소스 스냅샷 메타 ────────────────────────────────────────────────────────
# :${TAG}(기본 latest) 와 함께 불변 스냅샷 태그(<branch>-<date>-<shortsha>)로도 push,
# 소스 정보를 OCI 라벨로 baked. 재현성 보장 위해 커밋 안 된(tracked) 변경이 있으면 차단.
if ! git diff --quiet HEAD 2>/dev/null; then
  echo "ERROR: 커밋되지 않은 변경이 있습니다 — 커밋 후 다시 실행하세요 (스냅샷 태그/재현성 보장)." >&2
  git status --short --untracked-files=no >&2 || true
  exit 1
fi
GIT_REV="$(git rev-parse HEAD)"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD | sed 's/[^A-Za-z0-9._-]/-/g')"
GIT_SHORT="$(git rev-parse --short HEAD)"
BUILD_DATE_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SNAP="${GIT_BRANCH}-$(date -u +%Y%m%d)-${GIT_SHORT}"
SNAP_MANIFEST="${BASE}:${SNAP}"
OCI_LABELS=(
  --label "org.opencontainers.image.revision=${GIT_REV}"
  --label "org.opencontainers.image.source=github.com/obigo-gov/oss_hmi_app"
  --label "org.opencontainers.image.ref.name=${GIT_BRANCH}"
  --label "org.opencontainers.image.created=${BUILD_DATE_UTC}"
  --label "org.opencontainers.image.version=${SNAP}"
)

echo "=== rviz2 multi-arch build: ${CTX}/Dockerfile → ${MANIFEST} + ${SNAP_MANIFEST} (amd64 + arm64, one-shot) ==="

# buildx builder (docker-container driver + QEMU emulation for the cross-arch build).
docker buildx create --name "${BUILDER}" --driver docker-container --use 2>/dev/null \
  || docker buildx use "${BUILDER}"

# 단일 빌드로 :${TAG} + :${SNAP} 두 태그를 함께 push (multi -t).
docker buildx build \
  --platform=linux/amd64,linux/arm64 \
  -f "${CTX}/Dockerfile" \
  "${OCI_LABELS[@]}" \
  --push -t "${MANIFEST}" -t "${SNAP_MANIFEST}" \
  "${CTX}"

echo ""; echo "=== Done. Multi-arch manifest pushed ==="
docker buildx imagetools inspect "${MANIFEST}" | grep -iE "Name|Platform|MediaType" | sed 's/^/  /'

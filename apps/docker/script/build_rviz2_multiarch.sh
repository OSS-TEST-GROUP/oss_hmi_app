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

# 배포 정책: :latest + 스냅샷 태그 push 는 default 브랜치(develop)에서만 허용한다.
# feature/기타 브랜치에서 실수로 :latest 를 덮어쓰는 것을 방지. 정책상 default
# 브랜치 이외의 빌드는 여기서 중단한다 (필요 시 DEFAULT_BRANCH 로 정책 조정).
DEFAULT_BRANCH="${DEFAULT_BRANCH:-develop}"
if [ "${GIT_BRANCH}" != "${DEFAULT_BRANCH}" ]; then
  echo "ERROR: 현재 브랜치 '${GIT_BRANCH}' — :latest + 스냅샷 push 는 default 브랜치 '${DEFAULT_BRANCH}' 에서만 허용됩니다." >&2
  echo "       '${DEFAULT_BRANCH}' 로 머지 후 그 브랜치에서 빌드하세요." >&2
  exit 1
fi
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

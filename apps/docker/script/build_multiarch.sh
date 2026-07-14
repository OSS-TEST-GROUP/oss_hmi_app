#!/bin/bash
# Multi-architecture Docker image build+push for HMI apps (default: hmi_launcher).
#
# Builds the amd64 and arm64 runtime images from the per-arch Flutter bundles
# and assembles a multi-arch manifest list on the company registry.
#
# Why not a single `docker buildx build --platform=linux/amd64,linux/arm64`?
#   The runtime Dockerfiles do not compile from source — they ADD a per-arch,
#   pre-built bundle tarball (output/<APP>-x86_64-release.tar.gz for amd64,
#   output/<APP>-arm64-release.tar.gz for arm64) and use *different*
#   Dockerfiles (Dockerfile vs Dockerfile.arm64, different base + layout).
#   A single multi-platform build can't pick a different Dockerfile / bundle
#   per platform, so we build each arch separately, push as
#   `<tag>-amd64` / `<tag>-arm64`, and combine with `imagetools create`.
#   (Mirrors oss_multisw_framework/docker/build_multiarch.sh.)
#
# Prerequisites (build the bundles first):
#   amd64 : docker compose --profile build run --rm <APP>_builder_x86
#           → output/<APP>-x86_64-release.tar.gz
#   arm64 : docker compose --profile build run --rm <APP>_builder_arm64  (AGL SDK)
#           → output/<APP>-arm64-release.tar.gz
#           (falls back to output/<APP>-arm64-native-release.tar.gz if present)
#
# Usage (from apps/):
#   ./docker/script/build_multiarch.sh
#   APP=hmi_launcher TAG=latest ./docker/script/build_multiarch.sh
#   TAG=multiarch-verify ./docker/script/build_multiarch.sh   # safe, non-:latest
#
# Env:
#   REGISTRY     default registry.obigo.com
#   APP          pubspec app name          (default hmi_launcher)
#   IMAGE        registry image repo path  (default oss/oss-hmi-launcher)
#   TAG          manifest tag              (default latest)
#   CONFIG_FILE  per-app config filename   (default launcher_config.json)
#   APP_VERSION  arm64 bundle version dir  (default auto-detected from tarball)
set -e

REGISTRY="${REGISTRY:-registry.obigo.com}"
APP="${APP:-hmi_launcher}"
IMAGE="${IMAGE:-oss/oss-hmi-launcher}"
TAG="${TAG:-latest}"
CONFIG_FILE="${CONFIG_FILE:-launcher_config.json}"

# apps/ is the docker build context (Dockerfiles reference output/, <APP>/…).
cd "$(dirname "$0")/../.."

MANIFEST="${REGISTRY}/${IMAGE}:${TAG}"
AMD64_TAG="${MANIFEST}-amd64"
ARM64_TAG="${MANIFEST}-arm64"

amd64_bundle="output/${APP}-x86_64-release.tar.gz"
arm64_bundle="output/${APP}-arm64-release.tar.gz"

echo "=== HMI multi-arch build: ${APP} → ${MANIFEST} (amd64 + arm64) ==="

# ── bundle presence / arm64 native fallback ──────────────────────────────
[ -f "$amd64_bundle" ] || { echo "ERR: missing $amd64_bundle (build amd64 bundle first)"; exit 1; }
if [ ! -f "$arm64_bundle" ]; then
  if [ -f "output/${APP}-arm64-native-release.tar.gz" ]; then
    echo "note: using native arm64 bundle (output/${APP}-arm64-native-release.tar.gz)"
    cp -f "output/${APP}-arm64-native-release.tar.gz" "$arm64_bundle"
  else
    echo "ERR: missing $arm64_bundle (build arm64 bundle first)"; exit 1
  fi
fi

# arm64 bundle version dir (Dockerfile.arm64 BUNDLE_PATH uses APP_VERSION).
if [ -z "${APP_VERSION:-}" ]; then
  APP_VERSION="$(tar tzf "$arm64_bundle" 2>/dev/null \
    | sed -n "s#usr/share/flutter/${APP}/\([^/]*\)/release/.*#\1#p" | head -1)"
  APP_VERSION="${APP_VERSION:-3.32.5}"
fi
echo "arm64 APP_VERSION=${APP_VERSION}"

# buildx builder (QEMU for arm64 emulation on amd64 host).
docker buildx create --name hmi-buildx --driver docker-container --use 2>/dev/null \
  || docker buildx use hmi-buildx

# ── amd64 ────────────────────────────────────────────────────────────────
echo ""; echo "=== amd64: Dockerfile → ${AMD64_TAG} ==="
docker buildx build \
  --platform=linux/amd64 \
  -f docker/dockerfile/Dockerfile \
  --build-arg "APP_NAME=${APP}" \
  --build-arg "CONFIG_FILE=${CONFIG_FILE}" \
  --push -t "${AMD64_TAG}" .

# ── arm64 ────────────────────────────────────────────────────────────────
echo ""; echo "=== arm64: Dockerfile.arm64 → ${ARM64_TAG} ==="
docker buildx build \
  --platform=linux/arm64 \
  -f docker/dockerfile/Dockerfile.arm64 \
  --build-arg "APP_NAME=${APP}" \
  --build-arg "APP_VERSION=${APP_VERSION}" \
  --build-arg "CONFIG_FILE=${CONFIG_FILE}" \
  --push -t "${ARM64_TAG}" .

# ── manifest list ────────────────────────────────────────────────────────
echo ""; echo "=== manifest list: ${MANIFEST} ==="
docker buildx imagetools create -t "${MANIFEST}" "${AMD64_TAG}" "${ARM64_TAG}"

echo ""; echo "=== Done. Multi-arch manifest pushed ==="
docker buildx imagetools inspect "${MANIFEST}" | grep -iE "Name|Platform|MediaType" | sed 's/^/  /'

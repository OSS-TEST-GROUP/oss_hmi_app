#!/bin/bash
# Run RViz2 with XWayland + Weston (Phase 1-B: R003)
# This script builds and runs the rviz_agl:xwayland container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMAGE_TAG="rviz_agl:xwayland"

echo "[R003] RViz2 XWayland Environment Verification Script"
echo "======================================================"

# Check if base image exists
if ! docker image inspect rviz_agl:x11 &> /dev/null; then
    echo "[R003] ERROR: Base image rviz_agl:x11 not found"
    echo "[R003] Please build it first: bash init.sh"
    exit 1
fi

# Build XWayland image if needed
if ! docker image inspect ${IMAGE_TAG} &> /dev/null; then
    echo "[R003] Building ${IMAGE_TAG} image..."
    docker build \
        -t ${IMAGE_TAG} \
        -f "${PROJECT_ROOT}/docker/xwayland/Dockerfile" \
        "${PROJECT_ROOT}"
    echo "[R003] Build complete"
else
    echo "[R003] Image ${IMAGE_TAG} already exists"
fi

# Display image info
echo ""
echo "[R003] Image info:"
docker images ${IMAGE_TAG}

# Run container
echo ""
echo "[R003] Starting container..."
docker run --rm -it \
    --name rviz_xwayland_test \
    --cap-add SYS_ADMIN \
    --cap-add NET_ADMIN \
    --security-opt apparmor=unconfined \
    ${IMAGE_TAG}

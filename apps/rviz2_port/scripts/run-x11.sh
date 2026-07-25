#!/bin/bash
# Run RViz2 Docker container (Phase 1-A X11 baseline) with X11 display forwarding
# This script wraps hmi/rviz_agl/docker/run.sh with correct image tag

set -e

IMAGE_TAG="${IMAGE_TAG:-rviz_agl:x11}"
CONTAINER_NAME="rviz_agl_x11_runtime"

# X11 display: use :0 if DISPLAY not set
if [ -z "$DISPLAY" ]; then
    XSOCK_ENTRY=$(ls /tmp/.X11-unix/ 2>/dev/null | head -1)
    if [ -n "$XSOCK_ENTRY" ]; then
        DISPLAY=":${XSOCK_ENTRY#X}"
    else
        DISPLAY=":0"
    fi
fi
export DISPLAY

XSOCK=/tmp/.X11-unix
XAUTH=/tmp/.docker.xauth

echo "🖥️  Phase 1-A X11 Baseline RViz2 GUI 검증"
echo "  DISPLAY=$DISPLAY"
echo "  IMAGE=$IMAGE_TAG"
echo ""

# Allow X11 connections from Docker
xauth nlist "$DISPLAY" 2>/dev/null | sed -e 's/^..../ffff/' | \
    xauth -f "$XAUTH" nmerge - 2>/dev/null || true
chmod 600 "$XAUTH" 2>/dev/null || true

# Allow local connections (fallback)
xhost +local:docker 2>/dev/null || true

# Remove previous container if exists
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "Starting RViz2 container..."
docker run --rm \
    --name "$CONTAINER_NAME" \
    --platform linux/amd64 \
    -e DISPLAY="$DISPLAY" \
    -e XAUTHORITY="$XAUTH" \
    -e QT_X11_NO_MITSHM=1 \
    -e LIBGL_ALWAYS_SOFTWARE=1 \
    -v "$XSOCK:$XSOCK:rw" \
    -v "$XAUTH:$XAUTH:rw" \
    --device /dev/dri \
    --network host \
    "$IMAGE_TAG" "$@"

#!/bin/bash
# R003 AC-4 visual verification via VNC.
# Starts the rviz_agl:xwayland container with weston+xwayland+x11vnc,
# then prints connection instructions.

set -e

IMAGE_TAG="rviz_agl:xwayland"
CONTAINER_NAME="rviz_xwayland_vnc"
VNC_PORT=5900

if ! docker image inspect ${IMAGE_TAG} &>/dev/null; then
    echo "[R003-VNC] ERROR: ${IMAGE_TAG} not found. Run scripts/run-xwayland.sh first."
    exit 1
fi

docker rm -f ${CONTAINER_NAME} &>/dev/null || true

echo "[R003-VNC] Starting ${CONTAINER_NAME} (port ${VNC_PORT})..."
docker run -d \
    --name ${CONTAINER_NAME} \
    --cap-add SYS_ADMIN --cap-add NET_ADMIN \
    --security-opt apparmor=unconfined \
    -p ${VNC_PORT}:5900 \
    ${IMAGE_TAG} \
    bash -c '
      env -u WAYLAND_DISPLAY x11vnc \
          -display :0 -forever -nopw -shared \
          -visual TrueColor:24 -noxdamage -noxfixes \
          -listen 0.0.0.0 -rfbport 5900 -bg -o /tmp/x11vnc.log

      exec ros2 run rviz2 rviz2
    '

echo "[R003-VNC] Waiting 8 seconds for stack to come up..."
sleep 8

if ! docker ps --filter name=${CONTAINER_NAME} --format '{{.Names}}' | grep -q ${CONTAINER_NAME}; then
    echo "[R003-VNC] ERROR: container exited. Last logs:"
    docker logs ${CONTAINER_NAME} 2>&1 | tail -40
    exit 1
fi

echo ""
echo "[R003-VNC] Stack is up. Connect a VNC viewer to:"
echo "             localhost:${VNC_PORT}    (no password)"
echo ""
echo "             Examples:"
echo "               vncviewer localhost:${VNC_PORT}"
echo "               remmina vnc://localhost:${VNC_PORT}"
echo ""
echo "[R003-VNC] Verify the RViz2 window renders inside the VNC session."
echo "[R003-VNC] Stop with: docker rm -f ${CONTAINER_NAME}"

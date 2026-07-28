#!/bin/bash
# R003 AC-4 visual verification via Weston RDP backend.
# Replaces headless backend with rdp-backend.so so a remote RDP client can
# see the actual compositor output (including XWayland-forwarded RViz2 surface).

set -e

IMAGE_TAG="rviz_agl:xwayland"
CONTAINER_NAME="rviz_xwayland_rdp"
RDP_PORT=3389

if ! docker image inspect ${IMAGE_TAG} &>/dev/null; then
    echo "[R003-RDP] ERROR: ${IMAGE_TAG} not found. Run scripts/run-xwayland.sh first."
    exit 1
fi

docker rm -f ${CONTAINER_NAME} &>/dev/null || true

echo "[R003-RDP] Starting ${CONTAINER_NAME} on RDP port ${RDP_PORT}..."

docker run -d \
    --name ${CONTAINER_NAME} \
    --cap-add SYS_ADMIN --cap-add NET_ADMIN \
    --security-opt apparmor=unconfined \
    -p ${RDP_PORT}:3389 \
    --entrypoint /bin/bash \
    ${IMAGE_TAG} \
    -c '
      set -e
      mkdir -p /run/user/1000 && chmod 700 /run/user/1000
      export XDG_RUNTIME_DIR=/run/user/1000
      rm -f ${XDG_RUNTIME_DIR}/wayland-* 2>/dev/null || true

      mkdir -p /etc/weston
      openssl req -x509 -nodes -newkey rsa:2048 \
          -keyout /etc/weston/rdp-tls.key \
          -out  /etc/weston/rdp-tls.crt \
          -subj "/CN=rviz-xwayland-rdp" \
          -days 30 >/dev/null 2>&1
      chmod 644 /etc/weston/rdp-tls.crt /etc/weston/rdp-tls.key

      weston \
          --backend=rdp-backend.so \
          --xwayland \
          --port=3389 \
          --rdp-tls-cert=/etc/weston/rdp-tls.crt \
          --rdp-tls-key=/etc/weston/rdp-tls.key \
          --width=1920 --height=1080 \
          --log=/tmp/weston.log &

      for i in $(seq 1 30); do
        [ -S "${XDG_RUNTIME_DIR}/wayland-0" ] && [ -e "/tmp/.X11-unix/X0" ] && break
        sleep 0.5
      done

      if [ ! -e "/tmp/.X11-unix/X0" ]; then
        echo "[R003-RDP] FATAL: XWayland :0 did not come up"
        cat /tmp/weston.log
        exit 1
      fi

      source /opt/ros/humble/setup.bash
      [ -f /workspace/install/setup.bash ] && source /workspace/install/setup.bash
      export DISPLAY=:0 QT_QPA_PLATFORM=xcb LIBGL_ALWAYS_SOFTWARE=1
      exec ros2 run rviz2 rviz2
    '

echo "[R003-RDP] Waiting 10 seconds for stack to come up..."
sleep 10

if ! docker ps --filter name=${CONTAINER_NAME} --format '{{.Names}}' | grep -q ${CONTAINER_NAME}; then
    echo "[R003-RDP] ERROR: container exited. Last logs:"
    docker logs ${CONTAINER_NAME} 2>&1 | tail -40
    exit 1
fi

echo ""
echo "[R003-RDP] Stack is up. Connect an RDP client to:"
echo "             localhost:${RDP_PORT}    (no password)"
echo ""
echo "             Examples:"
echo "               xfreerdp /v:localhost:${RDP_PORT} /cert:ignore /size:1920x1080 /dynamic-resolution"
echo "               remmina  rdp://localhost:${RDP_PORT}"
echo ""
echo "[R003-RDP] Verify the RViz2 window renders inside the RDP session."
echo "[R003-RDP] Stop with: docker rm -f ${CONTAINER_NAME}"

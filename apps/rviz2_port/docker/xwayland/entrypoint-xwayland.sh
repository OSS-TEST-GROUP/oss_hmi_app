#!/bin/bash
# Entrypoint for RViz2 + XWayland + Weston (Phase 1-B)
# Starts Weston compositor (headless) with XWayland, then runs RViz2

set -e

# Source ROS2 environment
source /opt/ros/humble/setup.bash
if [ -f /workspace/install/setup.bash ]; then
    source /workspace/install/setup.bash
fi

# Ensure XDG_RUNTIME_DIR exists
mkdir -p ${XDG_RUNTIME_DIR}
chmod 700 ${XDG_RUNTIME_DIR}

# Cleanup any existing Wayland sockets
rm -f ${XDG_RUNTIME_DIR}/wayland-* 2>/dev/null || true

# Start Weston compositor in background
echo "[R003] Starting Weston compositor (headless + XWayland)..."
weston --backend=headless-backend.so \
       --width=1920 \
       --height=1080 \
       --xwayland \
       --log=/tmp/weston.log \
       &

WESTON_PID=$!
echo "[R003] Weston started with PID: $WESTON_PID"

# Wait for Wayland socket to be ready
echo "[R003] Waiting for Wayland socket: ${XDG_RUNTIME_DIR}/wayland-0"
timeout=10
while [ $timeout -gt 0 ] && [ ! -S "${XDG_RUNTIME_DIR}/wayland-0" ]; do
    sleep 0.5
    timeout=$((timeout - 1))
done

if [ ! -S "${XDG_RUNTIME_DIR}/wayland-0" ]; then
    echo "[R003] ERROR: Wayland socket not created after 10 seconds"
    cat /tmp/weston.log
    exit 1
fi
echo "[R003] Wayland socket ready: $(ls -l ${XDG_RUNTIME_DIR}/wayland-0)"

# Wait for XWayland to start (DISPLAY :0)
echo "[R003] Waiting for XWayland display :0..."
timeout=10
while [ $timeout -gt 0 ] && [ ! -e "/tmp/.X11-unix/X0" ]; do
    sleep 0.5
    timeout=$((timeout - 1))
done

if [ ! -e "/tmp/.X11-unix/X0" ]; then
    echo "[R003] ERROR: XWayland display :0 not ready after 10 seconds"
    cat /tmp/weston.log
    exit 1
fi
echo "[R003] XWayland ready: $(ls -l /tmp/.X11-unix/X0)"

# Check Weston logs for compositor startup
echo "[R003] Weston logs (first 30 lines):"
head -30 /tmp/weston.log

# Start RViz2 (via XWayland :0)
echo "[R003] Starting RViz2 via XWayland (DISPLAY=:0 QT_QPA_PLATFORM=xcb)..."
export DISPLAY=:0
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1  # Software rendering (same as R002)

# Execute RViz2 or custom command
if [ $# -eq 0 ]; then
    exec ros2 run rviz2 rviz2
else
    exec "$@"
fi

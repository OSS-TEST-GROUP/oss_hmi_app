#!/bin/bash
# R009 Wayland-only entrypoint: Weston + RViz2 native Wayland execution
# Integrates R007 guards + Weston compositor startup + RViz2 launch
#
# Usage (automated AC verification):
#   docker run --rm --cap-add SYS_ADMIN -p 3389:3389 rviz_agl:wayland-only
#
# Environment variables:
#   BACKEND: rdp | headless (default: rdp for AC-4 visual verification)
#   RDP_PORT: RDP port (default: 3389)
#   WAYLAND_DEBUG: Enable protocol logging (default: 1 for AC-3 verification)
#   RVIZ_TIMEOUT: Auto-exit after N seconds (default: 40 for AC-5)

set -e

# Configuration
BACKEND="${BACKEND:-rdp}"
RDP_PORT="${RDP_PORT:-3389}"
WAYLAND_DEBUG="${WAYLAND_DEBUG:-1}"
RVIZ_TIMEOUT="${RVIZ_TIMEOUT:-40}"

# R007 Guard 1: Correct xcb override when WAYLAND_DISPLAY set
if [ -n "$WAYLAND_DISPLAY" ] && [ "$QT_QPA_PLATFORM" = "xcb" ]; then
    echo "[R007 GUARD] WARNING: WAYLAND_DISPLAY='$WAYLAND_DISPLAY' but QT_QPA_PLATFORM=xcb"
    echo "[R007 GUARD] Forcing QT_QPA_PLATFORM=wayland"
    export QT_QPA_PLATFORM=wayland
fi

# R007 Guard 2: Auto-set wayland platform when WAYLAND_DISPLAY exists
if [ -n "$WAYLAND_DISPLAY" ] && [ -z "$QT_QPA_PLATFORM" ]; then
    echo "[R007 GUARD] Auto-setting QT_QPA_PLATFORM=wayland"
    export QT_QPA_PLATFORM=wayland
fi

# R007 Guard 3: Verify XDG_RUNTIME_DIR
if [ -n "$WAYLAND_DISPLAY" ] && [ -z "$XDG_RUNTIME_DIR" ]; then
    echo "[R007 GUARD] WARNING: XDG_RUNTIME_DIR unset, defaulting to /run/user/$(id -u)"
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

# Create XDG runtime directory
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"
rm -f "${XDG_RUNTIME_DIR}"/wayland-* 2>/dev/null || true

echo "[R009] === Wayland-Only Integration Test ==="
echo "[R009] Backend: ${BACKEND}"
echo "[R009] WAYLAND_DISPLAY: ${WAYLAND_DISPLAY}"
echo "[R009] QT_QPA_PLATFORM: ${QT_QPA_PLATFORM}"
echo "[R009] QT_WAYLAND_SHELL_INTEGRATION: ${QT_WAYLAND_SHELL_INTEGRATION}"
echo "[R009] XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR}"
echo "[R009] WAYLAND_DEBUG: ${WAYLAND_DEBUG}"

# Generate TLS cert for RDP backend (if needed)
if [ "$BACKEND" = "rdp" ]; then
    echo "[R009] Generating self-signed TLS certificate for RDP..."
    mkdir -p /etc/weston
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout /etc/weston/rdp-tls.key \
        -out /etc/weston/rdp-tls.crt \
        -subj "/CN=rviz-wayland-only" \
        -days 30 >/dev/null 2>&1
    chmod 644 /etc/weston/rdp-tls.crt /etc/weston/rdp-tls.key
fi

# Start Weston compositor (AC-1)
echo "[R009] Starting Weston compositor (backend: ${BACKEND})..."
if [ "$BACKEND" = "rdp" ]; then
    weston \
        --backend=rdp-backend.so \
        --port=${RDP_PORT} \
        --rdp-tls-cert=/etc/weston/rdp-tls.crt \
        --rdp-tls-key=/etc/weston/rdp-tls.key \
        --width=1920 --height=1080 \
        --log=/tmp/weston.log &
else
    weston \
        --backend=headless-backend.so \
        --width=1920 --height=1080 \
        --log=/tmp/weston.log &
fi

WESTON_PID=$!

# Wait for Wayland socket (AC-1 verification)
echo "[R009] Waiting for Wayland socket ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}..."
for i in $(seq 1 30); do
    if [ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]; then
        echo "[R009] ✓ Wayland socket ready (attempt $i/30)"
        break
    fi
    sleep 0.5
done

if [ ! -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]; then
    echo "[R009] FATAL: Wayland socket not created after 15 seconds"
    cat /tmp/weston.log
    exit 1
fi

# AC-2 verification: Environment variables
echo "[R009] AC-2 Verification: Environment variables"
env | grep -E "WAYLAND_DISPLAY|QT_QPA_PLATFORM|QT_WAYLAND_SHELL_INTEGRATION|XDG_RUNTIME_DIR"

# Source ROS 2 Humble environment
source /opt/ros/humble/setup.bash
[ -f /workspace/install/setup.bash ] && source /workspace/install/setup.bash

# Export Wayland debug for AC-3 verification
export WAYLAND_DEBUG

# Launch RViz2 with timeout for AC-5 verification
echo "[R009] Launching RViz2 (timeout: ${RVIZ_TIMEOUT}s)..."
echo "[R009] AC-3: Check wl_compositor binding in output below..."

# Capture start time
START_TIME=$(date +%s)

# Launch RViz2 in background with timeout
timeout ${RVIZ_TIMEOUT}s ros2 run rviz2 rviz2 2>&1 | tee /tmp/rviz2.log || true

# Calculate runtime
END_TIME=$(date +%s)
RUNTIME=$((END_TIME - START_TIME))

echo ""
echo "[R009] === Verification Summary ==="
echo "[R009] Weston PID: ${WESTON_PID} (kill -0 check below)"
echo "[R009] RViz2 runtime: ${RUNTIME} seconds (AC-5 requires 30+)"
echo ""

# AC-3 verification: wl_compositor binding
if grep -q 'wl_compositor@.*bind' /tmp/rviz2.log 2>/dev/null; then
    echo "[R009] AC-3: ✓ wl_compositor interface binding detected"
else
    echo "[R009] AC-3: ⚠ wl_compositor binding NOT found in logs (check WAYLAND_DEBUG=1)"
fi

# AC-5 verification: Runtime duration
if [ ${RUNTIME} -ge 30 ]; then
    echo "[R009] AC-5: ✓ RViz2 ran for ${RUNTIME}s (≥30s required)"
else
    echo "[R009] AC-5: ✗ RViz2 ran for ${RUNTIME}s (<30s, timeout or crash?)"
fi

# Check Weston still alive
if kill -0 ${WESTON_PID} 2>/dev/null; then
    echo "[R009] Weston compositor: ✓ Still running"
    kill ${WESTON_PID}
else
    echo "[R009] Weston compositor: ⚠ Exited (PID ${WESTON_PID})"
fi

echo "[R009] Logs saved: /tmp/weston.log /tmp/rviz2.log"
echo "[R009] === Test Complete ==="

#!/bin/bash
# R012: arm64 QEMU test environment entrypoint
# Integrates R007 guards + Weston headless + VNC + placeholder RViz2
# Pattern: oss_hmi_app test automation (CI-friendly exit codes)

set -e

echo "[R012] === arm64 QEMU Test Environment ==="
echo "[R012] Platform: $(uname -m) (expected: aarch64 if QEMU working)"
echo "[R012] QEMU emulation active: $(test "$(uname -m)" = "aarch64" && echo "YES" || echo "NO - WARNING")"

# R007 Guard 1: Prevent xcb override
if [[ -n "$WAYLAND_DISPLAY" && "$QT_QPA_PLATFORM" == "xcb" ]]; then
    echo "[R007 GUARD] WARNING: WAYLAND_DISPLAY='$WAYLAND_DISPLAY' but QT_QPA_PLATFORM=xcb" >&2
    echo "[R007 GUARD] Forcing QT_QPA_PLATFORM=wayland to prevent xcb fallback" >&2
    export QT_QPA_PLATFORM=wayland
fi

# R007 Guard 2: Auto-set QT_QPA_PLATFORM if not specified
if [[ -n "$WAYLAND_DISPLAY" && -z "$QT_QPA_PLATFORM" ]]; then
    echo "[R007 GUARD] Auto-setting QT_QPA_PLATFORM=wayland" >&2
    export QT_QPA_PLATFORM=wayland
fi

# R007 Guard 3: XDG_RUNTIME_DIR fallback
if [[ -z "$XDG_RUNTIME_DIR" ]]; then
    XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export XDG_RUNTIME_DIR
    echo "[R007 GUARD] XDG_RUNTIME_DIR not set, defaulting to $XDG_RUNTIME_DIR" >&2
fi

# Ensure XDG_RUNTIME_DIR exists
mkdir -p "$XDG_RUNTIME_DIR" || {
    echo "[R012] ERROR: Cannot create XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" >&2
    exit 1
}

echo "[R012] === Environment ==="
echo "[R012] WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
echo "[R012] QT_QPA_PLATFORM=$QT_QPA_PLATFORM"
echo "[R012] XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo "[R012] WESTON_BACKEND=$WESTON_BACKEND"
echo "[R012] VNC_PORT=$VNC_PORT"

# Start Weston compositor (headless or rdp backend)
WESTON_SOCKET="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
echo "[R012] Starting Weston compositor (backend: $WESTON_BACKEND)..."

if [[ "$WESTON_BACKEND" == "rdp" ]]; then
    # Generate self-signed certificate for RDP TLS
    if [[ ! -f /tmp/server.crt ]]; then
        echo "[R012] Generating RDP TLS certificate..."
        openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout /tmp/server.key -out /tmp/server.crt \
            -days 365 -subj "/CN=localhost" 2>/dev/null || echo "[R012] WARNING: openssl not available"
    fi
    weston --backend=rdp-backend.so &
else
    weston --backend=headless-backend.so &
fi

WESTON_PID=$!
echo "[R012] Weston PID: $WESTON_PID"

# Wait for Wayland socket
MAX_ATTEMPTS=30
ATTEMPT=0
while [[ ! -S "$WESTON_SOCKET" && $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
    ATTEMPT=$((ATTEMPT+1))
    echo "[R012] Waiting for Wayland socket ($ATTEMPT/$MAX_ATTEMPTS)..."
    sleep 1
done

if [[ ! -S "$WESTON_SOCKET" ]]; then
    echo "[R012] ERROR: Wayland socket not created after ${MAX_ATTEMPTS}s" >&2
    kill $WESTON_PID 2>/dev/null || true
    exit 1
fi

echo "[R012] ✓ Wayland socket ready: $WESTON_SOCKET"

# Optional: Start VNC server (if VNC_PORT set and xvfb available)
if [[ -n "$VNC_PORT" && "$VNC_PORT" != "0" ]]; then
    if command -v x11vnc >/dev/null 2>&1; then
        echo "[R012] Starting VNC server on port $VNC_PORT (for visual verification)..."
        Xvfb :99 -screen 0 1920x1080x24 &
        XVFB_PID=$!
        export DISPLAY=:99
        x11vnc -display :99 -rfbport "$VNC_PORT" -forever -shared -bg -nopw
        echo "[R012] ✓ VNC server listening on 0.0.0.0:$VNC_PORT"
    else
        echo "[R012] WARNING: VNC_PORT set but x11vnc not available (skipping VNC)" >&2
    fi
fi

# Trap cleanup
cleanup() {
    echo "[R012] Cleaning up..."
    kill $WESTON_PID 2>/dev/null || true
    [[ -n "$XVFB_PID" ]] && kill $XVFB_PID 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# Execute target application (placeholder rviz2 or test command)
START_TIME=$(date +%s)
echo "[R012] Executing: $*"
"$@" &
APP_PID=$!

# Wait for application (30+ seconds stability check for AC-4)
wait $APP_PID
APP_EXIT_CODE=$?
END_TIME=$(date +%s)
RUNTIME=$((END_TIME - START_TIME))

echo "[R012] Application exit code: $APP_EXIT_CODE"
echo "[R012] Application runtime: ${RUNTIME}s"

# AC-4 verification: 30+ second stability
if [[ $RUNTIME -ge 30 ]]; then
    echo "[R012] ✓ AC-4 PASS: Application ran for ${RUNTIME}s (≥30s)"
else
    echo "[R012] ✗ AC-4 FAIL: Application ran for ${RUNTIME}s (<30s, timeout or crash?)" >&2
fi

# AC-5 verification: Clean exit code
if [[ $APP_EXIT_CODE -eq 0 ]]; then
    echo "[R012] ✓ AC-5 PASS: Application exit code 0 (clean shutdown)"
else
    echo "[R012] ✗ AC-5 FAIL: Application exit code $APP_EXIT_CODE" >&2
fi

cleanup
exit $APP_EXIT_CODE

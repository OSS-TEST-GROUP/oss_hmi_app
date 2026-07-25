#!/bin/bash
# R011 runtime entrypoint for arm64 RViz2 on AGL Trout 20.0.3 Wayland
# Integrates R007 xcb-fallback-guard + Wayland environment setup
# Adapted from hmi/oss_hmi_app/apps/docker/agl-run.sh pattern

set -e

# R007 Guard 1: Block xcb override when WAYLAND_DISPLAY is set
if [ -n "$WAYLAND_DISPLAY" ] && [ "$QT_QPA_PLATFORM" = "xcb" ]; then
    echo "[R007 GUARD] WARNING: WAYLAND_DISPLAY='$WAYLAND_DISPLAY' but QT_QPA_PLATFORM=xcb" >&2
    echo "[R007 GUARD] Forcing QT_QPA_PLATFORM=wayland to prevent xcb fallback" >&2
    export QT_QPA_PLATFORM=wayland
fi

# R007 Guard 2: Auto-set wayland if not set
if [ -n "$WAYLAND_DISPLAY" ] && [ -z "$QT_QPA_PLATFORM" ]; then
    echo "[R007 GUARD] Auto-setting QT_QPA_PLATFORM=wayland" >&2
    export QT_QPA_PLATFORM=wayland
fi

# R007 Guard 3: XDG_RUNTIME_DIR fallback
: "${XDG_RUNTIME_DIR:=/run/user/1000}"
export XDG_RUNTIME_DIR

# AGL app_id (similar to oss_hmi_app pattern)
: "${APP_ID:=org.agl.rviz2}"
export APP_ID

# Qt5 Wayland shell integration (xdg-shell protocol)
: "${QT_WAYLAND_SHELL_INTEGRATION:=xdg-shell}"
export QT_WAYLAND_SHELL_INTEGRATION

echo "[agl-run] === RViz2 AGL Runtime Entrypoint ==="
echo "[agl-run] WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
echo "[agl-run] QT_QPA_PLATFORM=$QT_QPA_PLATFORM"
echo "[agl-run] QT_WAYLAND_SHELL_INTEGRATION=$QT_WAYLAND_SHELL_INTEGRATION"
echo "[agl-run] XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo "[agl-run] APP_ID=$APP_ID"

# Wayland socket sanity check
WAYLAND_SOCKET="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
if [ ! -S "$WAYLAND_SOCKET" ]; then
    echo "[agl-run] WARNING: Wayland socket not present at $WAYLAND_SOCKET" >&2
    echo "[agl-run] Ensure host mounts $XDG_RUNTIME_DIR to container with:" >&2
    echo "[agl-run]   docker run -v $XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR ..." >&2
    echo "[agl-run] Proceeding anyway (socket may appear after container start)" >&2
fi

# Execute command (default: rviz2)
echo "[agl-run] Executing: $*"
exec "$@"

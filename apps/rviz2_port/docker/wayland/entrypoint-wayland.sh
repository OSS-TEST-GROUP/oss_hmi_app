#!/bin/bash
# R007 Defensive Guard: Prevent XCB fallback when Wayland display is available
# This entrypoint ensures QT_QPA_PLATFORM=wayland when WAYLAND_DISPLAY is set,
# preventing accidental XCB fallback that breaks RViz2 rendering on AGL Wayland.

set -e

# Guard 1: Detect and correct xcb override when Wayland is available
if [ -n "$WAYLAND_DISPLAY" ] && [ "$QT_QPA_PLATFORM" = "xcb" ]; then
    echo "[R007 GUARD] WARNING: WAYLAND_DISPLAY='$WAYLAND_DISPLAY' is set but QT_QPA_PLATFORM=xcb"
    echo "[R007 GUARD] Forcing QT_QPA_PLATFORM=wayland to prevent rendering failure"
    export QT_QPA_PLATFORM=wayland
fi

# Guard 2: Auto-set wayland platform when WAYLAND_DISPLAY exists but QT_QPA_PLATFORM unset
if [ -n "$WAYLAND_DISPLAY" ] && [ -z "$QT_QPA_PLATFORM" ]; then
    echo "[R007 GUARD] Auto-setting QT_QPA_PLATFORM=wayland (WAYLAND_DISPLAY='$WAYLAND_DISPLAY')"
    export QT_QPA_PLATFORM=wayland
fi

# Guard 3: Verify XDG_RUNTIME_DIR is set (required for Wayland socket access)
if [ -n "$WAYLAND_DISPLAY" ] && [ -z "$XDG_RUNTIME_DIR" ]; then
    echo "[R007 GUARD] WARNING: WAYLAND_DISPLAY set but XDG_RUNTIME_DIR unset"
    echo "[R007 GUARD] Defaulting to /run/user/$(id -u)"
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

# Debug: Print final environment
if [ -n "$DEBUG" ]; then
    echo "[R007 GUARD] Final environment:"
    echo "  WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    echo "  QT_QPA_PLATFORM=$QT_QPA_PLATFORM"
    echo "  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
fi

# Execute original command
exec "$@"

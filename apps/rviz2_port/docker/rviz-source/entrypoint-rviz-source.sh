#!/bin/bash
# R016: RViz2 source rebuild runtime entrypoint with OGRE 14.x LD_LIBRARY_PATH override
# Feature: Option (2) — Runtime LD_LIBRARY_PATH override to force OGRE 14.5.2 linkage
# Strategy: Development validation only (not production-ready; Yocto override deferred to R010)
#
# Usage:
#   docker run --rm -e WAYLAND_DEBUG=1 rviz_agl:rviz-source
#   docker run --rm -e R016_BRIEF=1 rviz_agl:rviz-source  # Brief mode (no WAYLAND_DEBUG)
#
# Environment Variables:
#   R016_BRIEF=1           : Disable WAYLAND_DEBUG (CI-friendly mode)
#   WAYLAND_DEBUG=1        : Enable Wayland protocol debug logs (default: 1 unless R016_BRIEF set)
#   LD_LIBRARY_PATH        : Prepended with /opt/ogre/lib (OGRE 14.x override)
#
# Reference: docs/baselines/r016_rviz_source_rebuild_baseline.md

set -e

# =============================================================================
# R007 Guard: Prevent XCB fallback (inherited from R009 wayland-only entrypoint)
# =============================================================================
echo "=== R007 Guard: Validating Wayland environment ==="

# Guard 1: Prevent xcb override when WAYLAND_DISPLAY is set
if [ -n "${WAYLAND_DISPLAY}" ] && [ "${QT_QPA_PLATFORM}" = "xcb" ]; then
    echo "[R007 Guard] WARNING: QT_QPA_PLATFORM=xcb conflicts with WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
    echo "[R007 Guard] Correcting to QT_QPA_PLATFORM=wayland"
    export QT_QPA_PLATFORM=wayland
fi

# Guard 2: Auto-set QT_QPA_PLATFORM=wayland when unset (if WAYLAND_DISPLAY exists)
if [ -z "${QT_QPA_PLATFORM}" ]; then
    if [ -n "${WAYLAND_DISPLAY}" ]; then
        export QT_QPA_PLATFORM=wayland
        echo "[R007 Guard] Auto-set QT_QPA_PLATFORM=wayland (WAYLAND_DISPLAY=${WAYLAND_DISPLAY})"
    else
        echo "[R007 Guard] WARNING: WAYLAND_DISPLAY not set, QT_QPA_PLATFORM remains unset"
    fi
fi

# Guard 3: Verify XDG_RUNTIME_DIR
if [ -z "${XDG_RUNTIME_DIR}" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    mkdir -p "${XDG_RUNTIME_DIR}"
    chmod 700 "${XDG_RUNTIME_DIR}"
    echo "[R007 Guard] Auto-set XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"
fi

echo "  ✓ QT_QPA_PLATFORM=${QT_QPA_PLATFORM}"
echo "  ✓ WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
echo "  ✓ XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"

# =============================================================================
# R016 Option (2): Runtime LD_LIBRARY_PATH override to force OGRE 14.5.2 linkage
# =============================================================================
echo "=== R016 Option (2): OGRE 14.x LD_LIBRARY_PATH override ==="

# Verify OGRE 14.x is available
if [ ! -f /opt/ogre/lib/libOgreMain.so.14.5 ]; then
    echo "  ✗ ERROR: OGRE 14.5.2 library not found in /opt/ogre/lib"
    exit 1
fi

# CRITICAL: Create symlink libOgreMain.so.1.12.1 → libOgreMain.so.14.5 in /opt/ogre/lib
# Rationale: rviz2 binary is linked against SONAME "libOgreMain.so.1.12.1" (from rviz_ogre_vendor CMake export)
#            but we want runtime to load OGRE 14.x instead of apt package's 1.12.1
if [ ! -L /opt/ogre/lib/libOgreMain.so.1.12.1 ]; then
    echo "  Creating symlink: libOgreMain.so.1.12.1 → libOgreMain.so.14.5"
    ln -sf libOgreMain.so.14.5 /opt/ogre/lib/libOgreMain.so.1.12.1
    ln -sf libOgreOverlay.so.14.5 /opt/ogre/lib/libOgreOverlay.so.1.12.1
fi

# Prepend /opt/ogre/lib to LD_LIBRARY_PATH (takes precedence over apt package)
export LD_LIBRARY_PATH="/opt/ogre/lib:${LD_LIBRARY_PATH}"
echo "  ✓ LD_LIBRARY_PATH=/opt/ogre/lib:..."
echo "  ✓ Symlink: libOgreMain.so.1.12.1 → 14.5 (runtime override active)"

# Verify override works (quick check)
if ldd /workspace/install/rviz2/lib/rviz2/rviz2 2>/dev/null | grep -q "libOgreMain.so.1.12.1 => /opt/ogre/lib"; then
    echo "  ✓ AC-1 PASS: RViz2 runtime links to OGRE 14.x (/opt/ogre/lib)"
else
    echo "  ⚠ WARNING: Runtime linkage not verified (continuing anyway)"
fi

# =============================================================================
# Weston Compositor (RDP backend for visual verification)
# =============================================================================
echo "=== Starting Weston compositor (RDP backend) ==="

# Start Weston with RDP backend (port 3389)
weston \
    --backend=rdp-backend.so \
    --rdp-tls-cert=/etc/weston/server.cert \
    --rdp-tls-key=/etc/weston/server.key \
    --width=1920 \
    --height=1080 \
    &

WESTON_PID=$!
echo "  ✓ Weston started (PID ${WESTON_PID})"

# Wait for Wayland socket creation
for i in {1..10}; do
    if [ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY:-wayland-0}" ]; then
        echo "  ✓ Wayland socket ready: ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY:-wayland-0}"
        break
    fi
    echo "  Waiting for Wayland socket... (${i}/10)"
    sleep 1
done

if [ ! -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY:-wayland-0}" ]; then
    echo "  ✗ ERROR: Wayland socket not created after 10 seconds"
    kill ${WESTON_PID} 2>/dev/null || true
    exit 1
fi

# Set default WAYLAND_DISPLAY if not already set
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

# =============================================================================
# WAYLAND_DEBUG Configuration
# =============================================================================
if [ "${R016_BRIEF}" = "1" ]; then
    export WAYLAND_DEBUG=0
    echo "=== Brief mode: WAYLAND_DEBUG disabled (R016_BRIEF=1) ==="
else
    export WAYLAND_DEBUG="${WAYLAND_DEBUG:-1}"
    echo "=== WAYLAND_DEBUG=${WAYLAND_DEBUG} (protocol logging enabled) ==="
fi

# =============================================================================
# Source ROS 2 Environment (Source-built RViz2 takes priority)
# =============================================================================
echo "=== Sourcing ROS 2 Humble + Source-built RViz2 ==="

# Source overlay workspace (if exists)
if [ -f /workspace/install/setup.bash ]; then
    source /workspace/install/setup.bash
    echo "  ✓ Source-built RViz2 workspace sourced: /workspace/install"
else
    echo "  ⚠ WARNING: /workspace/install/setup.bash not found, falling back to apt RViz2"
    source /opt/ros/humble/setup.bash
fi

# =============================================================================
# Launch RViz2 (source-built binary)
# =============================================================================
echo "=== Launching source-built RViz2 ==="
echo "  Binary path: $(which rviz2 || echo 'NOT FOUND')"
echo "  RDP access: xfreerdp /v:localhost:3389 /cert:ignore"
echo "  Expected AC-4 log: wl_compositor@.*bind"
echo "  Expected AC-6: 30s+ runtime without segfault/abort"
echo ""

# Launch RViz2 (foreground)
exec ros2 run rviz2 rviz2

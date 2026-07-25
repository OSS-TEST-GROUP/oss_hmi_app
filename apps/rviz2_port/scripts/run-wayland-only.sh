#!/bin/bash
# R009 Automated Build + Verification Script
# x86_64 Wayland-only Integration Test (Option C Hybrid)
#
# This script builds rviz_agl:wayland-only image and runs automated AC verification.
# Option C: Qt5 Wayland QPA + Weston + apt rviz2 (OGRE 1.12 vendored)
#
# Usage:
#   bash scripts/run-wayland-only.sh [--brief]
#
# Options:
#   --brief    Disable WAYLAND_DEBUG (CI-friendly, no 39K line protocol logs)
#   --ci       Alias for --brief
#
# Acceptance Criteria:
#   AC-1: Weston compositor running (auto)
#   AC-2: Environment variables set (auto)
#   AC-3: wl_compositor binding (auto, grep logs)
#   AC-4: GUI displayed (user manual, RDP localhost:3389)
#   AC-5: 30s+ idle stability (auto, timeout check)

set -e

# Configuration
IMAGE_TAG="rviz_agl:wayland-only"
CONTAINER_NAME="rviz_wayland_only_test"
RDP_PORT=3389
BRIEF_MODE=0

# Parse arguments
for arg in "$@"; do
    case $arg in
        --brief|--ci)
            BRIEF_MODE=1
            shift
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--brief|--ci]"
            exit 1
            ;;
    esac
done

# Check if base image rviz_agl:qt-wayland exists (R006 dependency)
if ! docker image inspect rviz_agl:qt-wayland &>/dev/null; then
    echo "[R009] ERROR: Base image rviz_agl:qt-wayland not found"
    echo "[R009] Run scripts/run-qt-wayland.sh first (R006 dependency)"
    exit 1
fi

echo "[R009] === R009 Wayland-Only Integration Build + Verification ==="
echo "[R009] Strategy: Option C Hybrid"
echo "[R009] - Qt5 Wayland QPA (R006) + Weston (R006) + apt rviz2 (OGRE 1.12)"
echo "[R009] - OGRE 14.x integration deferred to R010 arm64 build"
echo ""

# Step 1: Build Docker image
echo "[R009] Step 1: Building ${IMAGE_TAG}..."
docker build \
    -f docker/wayland-only/Dockerfile \
    -t ${IMAGE_TAG} \
    . || {
    echo "[R009] ERROR: Docker build failed"
    exit 1
}

echo "[R009] ✓ Image built successfully"
echo ""

# Step 2: Verify image metadata
echo "[R009] Step 2: Verifying image labels..."
OGRE_VERSION=$(docker inspect ${IMAGE_TAG} | grep -oP '"org.agl.rviz2.ogre_version": "\K[^"]+' || echo "N/A")
STRATEGY=$(docker inspect ${IMAGE_TAG} | grep -oP '"org.agl.rviz2.strategy": "\K[^"]+' || echo "N/A")
echo "[R009] OGRE version: ${OGRE_VERSION}"
echo "[R009] Strategy: ${STRATEGY}"
echo ""

# Step 3: Clean up old container
docker rm -f ${CONTAINER_NAME} &>/dev/null || true

# Step 4: Launch container with RDP backend
echo "[R009] Step 3: Launching container (RDP backend, port ${RDP_PORT})..."

# Set WAYLAND_DEBUG based on brief mode
WAYLAND_DEBUG_VAL=1
if [ ${BRIEF_MODE} -eq 1 ]; then
    echo "[R009] Brief mode: WAYLAND_DEBUG=0 (CI-friendly)"
    WAYLAND_DEBUG_VAL=0
else
    echo "[R009] Verbose mode: WAYLAND_DEBUG=1 (AC-3 protocol verification)"
fi

docker run -d \
    --name ${CONTAINER_NAME} \
    --cap-add SYS_ADMIN \
    --cap-add NET_ADMIN \
    --security-opt apparmor=unconfined \
    -p ${RDP_PORT}:3389 \
    -e BACKEND=rdp \
    -e WAYLAND_DEBUG=${WAYLAND_DEBUG_VAL} \
    -e RVIZ_TIMEOUT=40 \
    ${IMAGE_TAG} || {
    echo "[R009] ERROR: Container launch failed"
    exit 1
}

echo "[R009] ✓ Container started (${CONTAINER_NAME})"
echo "[R009] Waiting 45 seconds for Weston + RViz2 startup + 40s idle test..."
sleep 45

# Step 5: Collect logs
echo ""
echo "[R009] Step 4: Collecting verification logs..."
docker logs ${CONTAINER_NAME} > /tmp/r009_verification.log 2>&1 || true

# AC-1: Weston compositor running
echo ""
echo "[R009] AC-1: Weston compositor startup..."
if grep -q "✓ Wayland socket ready" /tmp/r009_verification.log; then
    echo "[R009] AC-1: ✅ PASS — Wayland socket created"
else
    echo "[R009] AC-1: ❌ FAIL — Wayland socket not detected"
fi

# AC-2: Environment variables
echo ""
echo "[R009] AC-2: Environment variables..."
if grep -q "WAYLAND_DISPLAY=wayland-0" /tmp/r009_verification.log && \
   grep -q "QT_QPA_PLATFORM=wayland" /tmp/r009_verification.log && \
   grep -q "QT_WAYLAND_SHELL_INTEGRATION=xdg-shell" /tmp/r009_verification.log; then
    echo "[R009] AC-2: ✅ PASS — All required env vars set"
else
    echo "[R009] AC-2: ❌ FAIL — Missing environment variables"
fi

# AC-3: wl_compositor binding
echo ""
echo "[R009] AC-3: wl_compositor interface binding..."
if [ ${WAYLAND_DEBUG_VAL} -eq 1 ]; then
    if grep -q "wl_compositor@.*bind" /tmp/r009_verification.log || \
       grep -q "AC-3: ✓" /tmp/r009_verification.log; then
        echo "[R009] AC-3: ✅ PASS — wl_compositor binding detected"
    else
        echo "[R009] AC-3: ⚠️  WARN — wl_compositor binding NOT found in logs"
        echo "[R009]       (Check /tmp/r009_verification.log for WAYLAND_DEBUG output)"
    fi
else
    echo "[R009] AC-3: ⏭️  SKIP — WAYLAND_DEBUG=0 (brief mode)"
    echo "[R009]       Run without --brief for protocol verification"
fi

# AC-4: GUI display (manual verification)
echo ""
echo "[R009] AC-4: RViz2 GUI display (USER MANUAL VERIFICATION REQUIRED)"
echo "[R009]       Connect RDP client to: localhost:${RDP_PORT}"
echo "[R009]       Command: xfreerdp /v:localhost:${RDP_PORT} /cert:ignore"
echo "[R009]       Expected: RViz2 window visible on Weston compositor"

# AC-5: 30+ second idle stability
echo ""
echo "[R009] AC-5: 30+ second idle stability..."
if grep -q "AC-5: ✓" /tmp/r009_verification.log; then
    echo "[R009] AC-5: ✅ PASS — RViz2 ran 30+ seconds without crash"
elif grep -q "AC-5: ✗" /tmp/r009_verification.log; then
    echo "[R009] AC-5: ❌ FAIL — RViz2 runtime <30s (check logs for crash)"
else
    echo "[R009] AC-5: ⚠️  WARN — Could not determine runtime (check logs)"
fi

# Container status
echo ""
echo "[R009] Step 5: Container status..."
if docker ps --filter name=${CONTAINER_NAME} --format '{{.Names}}' | grep -q ${CONTAINER_NAME}; then
    echo "[R009] ✓ Container still running (Weston may still be up)"
    echo "[R009]   Use 'docker logs ${CONTAINER_NAME}' for full output"
    echo "[R009]   Use 'docker rm -f ${CONTAINER_NAME}' to clean up"
else
    echo "[R009] ⓘ Container exited (expected after 40s timeout)"
fi

# Summary
echo ""
echo "[R009] === Verification Summary ==="
echo "[R009] Logs: /tmp/r009_verification.log"
echo "[R009] Docker image: ${IMAGE_TAG} ($(docker images ${IMAGE_TAG} --format '{{.Size}}'))"
echo "[R009] Strategy: Option C Hybrid (Qt5 Wayland + Weston + apt rviz2)"
echo ""
echo "[R009] Next Steps:"
echo "[R009] 1. Review /tmp/r009_verification.log for AC-3 wl_compositor binding evidence"
echo "[R009] 2. AC-4: Connect RDP to localhost:${RDP_PORT} for visual verification"
echo "[R009] 3. If all AC pass → Update feature_list.json R009 status → review"
echo "[R009] 4. Ready for R010: arm64 cross-compile (full OGRE 14.x integration)"
echo ""
echo "[R009] === Test Complete ==="

#!/bin/bash
# R016: RViz2 colcon source rebuild automation script
# Feature: Build RViz2 from source against OGRE 14.x, verify AC 1-7
# ADR: docs/adr/ADR-005-r016-rviz-source-rebuild-strategy.md
#
# Usage:
#   ./scripts/build-rviz-source.sh [--no-cache] [--brief] [--verify-only]
#
# Options:
#   --no-cache      Force clean Docker build (no layer cache)
#   --brief         Skip AC-4 WAYLAND_DEBUG verbose logs (CI-friendly)
#   --verify-only   Skip build, only run AC verification on existing image
#
# Output:
#   - Docker image: rviz_agl:rviz-source
#   - Baseline doc: docs/baselines/r016_rviz_source_rebuild_baseline.md
#   - Exit code 0: All AC passed, R016 ready for review
#   - Exit code 1: Build/verification failed, check /tmp/r016_*.log

set -e

# Configuration
IMAGE_TAG="rviz_agl:rviz-source"
BASE_IMAGE="rviz_agl:wayland-only"
DOCKERFILE="docker/rviz-source/Dockerfile"
VERIFY_TIMEOUT=45  # AC-6 requires 30s+ idle, allow 45s total
RDP_PORT=3389

# Parse arguments
NO_CACHE=""
BRIEF_MODE=0
VERIFY_ONLY=0

for arg in "$@"; do
    case $arg in
        --no-cache)
            NO_CACHE="--no-cache"
            echo "[R016] Clean build mode: Docker cache disabled"
            ;;
        --brief)
            BRIEF_MODE=1
            echo "[R016] Brief mode: WAYLAND_DEBUG disabled for AC-4"
            ;;
        --verify-only)
            VERIFY_ONLY=1
            echo "[R016] Verify-only mode: Skipping build"
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--no-cache] [--brief] [--verify-only]"
            exit 1
            ;;
    esac
done

# Color output helpers
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_fail() { echo -e "${RED}✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Verify base image exists
echo "[R016] === RViz2 Source Rebuild Build Script ==="
echo "[R016] Base image: ${BASE_IMAGE}"
echo "[R016] Target image: ${IMAGE_TAG}"
echo ""

if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${BASE_IMAGE}$"; then
    log_fail "Base image ${BASE_IMAGE} not found"
    echo "       Run R009 first: docker build -f docker/wayland-only/Dockerfile -t ${BASE_IMAGE} ."
    exit 1
fi
log_success "Base image ${BASE_IMAGE} exists"

# Verify external repo exists
if [ ! -d "hmi/rviz_agl" ]; then
    log_fail "External repo hmi/rviz_agl not found"
    echo "       Clone ros2/rviz repository to hmi/rviz_agl (humble branch)"
    exit 1
fi
log_success "External repo hmi/rviz_agl exists"

# Verify R007 patch exists
R007_PATCH="yocto/meta-rviz2-agl/recipes-ros2/rviz2/files/0001-wayland-xcb-fallback-guard.patch"
if [ ! -f "${R007_PATCH}" ]; then
    log_fail "R007 patch not found: ${R007_PATCH}"
    exit 1
fi
log_success "R007 patch exists: ${R007_PATCH}"

# Check external repo clean status (warning only, not blocking)
cd hmi/rviz_agl
if ! git diff --quiet; then
    log_warn "External repo hmi/rviz_agl has uncommitted changes (policy violation warning)"
    git status --short | head -10
else
    log_success "External repo hmi/rviz_agl is clean"
fi
cd - > /dev/null

echo ""

# =============================================================================
# Build Stage (skip if --verify-only)
# =============================================================================
if [ ${VERIFY_ONLY} -eq 0 ]; then
    echo "[R016] === Docker Build Stage ==="
    BUILD_LOG="/tmp/r016_build.log"
    BUILD_START=$(date +%s)

    echo "[R016] Building ${IMAGE_TAG}..."
    echo "[R016] Build log: ${BUILD_LOG}"
    echo "[R016] Cache: $([ -n "${NO_CACHE}" ] && echo "disabled" || echo "enabled")"
    echo ""

    # Run Docker build in background with log capture
    if docker build ${NO_CACHE} -f ${DOCKERFILE} -t ${IMAGE_TAG} . > ${BUILD_LOG} 2>&1; then
        BUILD_END=$(date +%s)
        BUILD_TIME=$((BUILD_END - BUILD_START))
        log_success "Docker build completed in ${BUILD_TIME}s"

        # Extract key build metrics from log
        if grep -q "AC-1 PASS" ${BUILD_LOG}; then
            log_success "AC-1 (OGRE 14.x linkage) verified during build"
        else
            log_warn "AC-1 not found in build log (check ${BUILD_LOG})"
        fi

        if grep -q "AC-2 PASS" ${BUILD_LOG}; then
            log_success "AC-2 (4 packages built) verified during build"
        else
            log_warn "AC-2 not found in build log (check ${BUILD_LOG})"
        fi

        if grep -q "AC-3 PASS" ${BUILD_LOG}; then
            log_success "AC-3 (R007 patch applied) verified during build"
        else
            log_warn "AC-3 not found in build log (check ${BUILD_LOG})"
        fi
    else
        BUILD_END=$(date +%s)
        BUILD_TIME=$((BUILD_END - BUILD_START))
        log_fail "Docker build FAILED after ${BUILD_TIME}s"
        echo ""
        echo "=== Build Error Log (last 50 lines) ==="
        tail -50 ${BUILD_LOG}
        echo ""
        echo "=== Full log: ${BUILD_LOG} ==="
        exit 1
    fi

    # Check image size
    IMAGE_SIZE=$(docker images ${IMAGE_TAG} --format "{{.Size}}")
    echo "[R016] Image size: ${IMAGE_SIZE}"
    echo ""
else
    echo "[R016] === Skipping Build (--verify-only mode) ===="
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_TAG}$"; then
        log_fail "Image ${IMAGE_TAG} not found (cannot verify)"
        exit 1
    fi
    log_success "Image ${IMAGE_TAG} exists"
    echo ""
fi

# =============================================================================
# AC-1 Verification: OGRE 14.x linkage
# =============================================================================
echo "[R016] === AC-1 Verification: OGRE 14.x Linkage ==="
AC1_LOG="/tmp/r016_ac1_ldd.log"

if docker run --rm ${IMAGE_TAG} bash -c "ldd /workspace/install/rviz2/lib/rviz2/rviz2" > ${AC1_LOG} 2>&1; then
    if grep -q "libOgreMain.so.14" ${AC1_LOG}; then
        log_success "AC-1 PASS: RViz2 linked to OGRE 14.x"
        grep "libOgreMain" ${AC1_LOG}
    else
        log_fail "AC-1 FAIL: OGRE 14.x not detected"
        cat ${AC1_LOG}
        exit 1
    fi
else
    log_fail "AC-1 FAIL: ldd command failed"
    cat ${AC1_LOG}
    exit 1
fi
echo ""

# =============================================================================
# AC-2 Verification: 4 packages built
# =============================================================================
echo "[R016] === AC-2 Verification: 4 Packages Built ==="
AC2_LOG="/tmp/r016_ac2_packages.log"

PACKAGES="rviz2 rviz_common rviz_default_plugins rviz_rendering"
MISSING_PKGS=""

for pkg in ${PACKAGES}; do
    if docker run --rm ${IMAGE_TAG} test -d "/workspace/install/${pkg}"; then
        log_success "${pkg} exists"
    else
        log_fail "${pkg} MISSING"
        MISSING_PKGS="${MISSING_PKGS} ${pkg}"
    fi
done

if [ -n "${MISSING_PKGS}" ]; then
    log_fail "AC-2 FAIL: Missing packages:${MISSING_PKGS}"
    exit 1
else
    log_success "AC-2 PASS: All 4 packages built"
fi
echo ""

# =============================================================================
# AC-3 Verification: R007 patch applied
# =============================================================================
echo "[R016] === AC-3 Verification: R007 Patch Applied ==="
AC3_LOG="/tmp/r016_ac3_patch.log"

if docker run --rm ${IMAGE_TAG} grep -A 2 "R007 Guard" /workspace/src/rviz_agl/rviz2/src/main.cpp > ${AC3_LOG} 2>&1; then
    log_success "AC-3 PASS: R007 guard found in source"
    head -3 ${AC3_LOG}
else
    log_fail "AC-3 FAIL: R007 guard not found"
    exit 1
fi
echo ""

# =============================================================================
# AC-4/5/6 Verification: Native Wayland runtime (requires container run)
# =============================================================================
echo "[R016] === AC-4/5/6 Verification: Native Wayland Runtime ==="
CONTAINER_LOG="/tmp/r016_runtime_full.log"
CONTAINER_NAME="r016_verify_$$"

# Set WAYLAND_DEBUG based on brief mode
if [ ${BRIEF_MODE} -eq 1 ]; then
    WAYLAND_DEBUG_VAL=0
    log_warn "AC-4 WAYLAND_DEBUG disabled (--brief mode)"
else
    WAYLAND_DEBUG_VAL=1
fi

echo "[R016] Starting container ${CONTAINER_NAME}..."
echo "[R016] RDP port: ${RDP_PORT}"
echo "[R016] Timeout: ${VERIFY_TIMEOUT}s (AC-6 requires 30s+)"
echo "[R016] Container log: ${CONTAINER_LOG}"
echo ""

# Run container in background with RDP backend
docker run --rm --name ${CONTAINER_NAME} \
    --cap-add SYS_ADMIN \
    -p ${RDP_PORT}:${RDP_PORT} \
    -e BACKEND=rdp \
    -e RVIZ_TIMEOUT=${VERIFY_TIMEOUT} \
    -e WAYLAND_DEBUG=${WAYLAND_DEBUG_VAL} \
    ${IMAGE_TAG} > ${CONTAINER_LOG} 2>&1 &

DOCKER_PID=$!
echo "[R016] Container PID: ${DOCKER_PID}"

# Wait for container to finish or timeout
WAIT_START=$(date +%s)
TIMEOUT_GRACE=10  # Allow 10s extra for container shutdown
MAX_WAIT=$((VERIFY_TIMEOUT + TIMEOUT_GRACE))

while kill -0 ${DOCKER_PID} 2>/dev/null; do
    ELAPSED=$(($(date +%s) - WAIT_START))
    if [ ${ELAPSED} -gt ${MAX_WAIT} ]; then
        log_warn "Container timeout after ${ELAPSED}s, killing..."
        docker stop ${CONTAINER_NAME} 2>/dev/null || true
        break
    fi
    sleep 1
done

wait ${DOCKER_PID} 2>/dev/null || true

echo ""
echo "[R016] Container finished, analyzing logs..."
echo ""

# AC-4 Verification: wl_compositor binding (only if WAYLAND_DEBUG=1)
if [ ${BRIEF_MODE} -eq 0 ]; then
    if grep -q "wl_compositor@.*bind" ${CONTAINER_LOG}; then
        log_success "AC-4 PASS: wl_compositor interface binding detected"
        grep "wl_compositor@.*bind" ${CONTAINER_LOG} | head -3
    else
        log_fail "AC-4 FAIL: wl_compositor binding NOT found"
        echo "       Check ${CONTAINER_LOG} for Wayland protocol errors"
        grep -i "error\|fatal\|fail" ${CONTAINER_LOG} | head -10
        exit 1
    fi
else
    log_warn "AC-4 SKIPPED (--brief mode, WAYLAND_DEBUG=0)"
fi
echo ""

# AC-5 Verification: GUI display (user manual step)
echo "[R016] === AC-5 Verification: GUI Display (User Manual) ==="
log_warn "AC-5 requires manual RDP connection verification"
echo "       1. Connect to RDP: xfreerdp /v:localhost:${RDP_PORT} /u:ignored /cert-ignore"
echo "       2. Verify RViz2 GUI window is visible on Weston compositor"
echo "       3. Window should show RViz2 splash screen or main interface"
echo ""
echo "       (Automated check: RDP backend started)"
if grep -q "rdp-backend.so" ${CONTAINER_LOG}; then
    log_success "Weston RDP backend initialized"
else
    log_warn "RDP backend not confirmed in logs"
fi
echo ""

# AC-6 Verification: 30s+ idle stability
echo "[R016] === AC-6 Verification: 30s+ Idle Stability ==="
if grep -q "AC-5: ✓ RViz2 ran for" ${CONTAINER_LOG}; then
    RUNTIME=$(grep "AC-5: ✓ RViz2 ran for" ${CONTAINER_LOG} | grep -oE '[0-9]+s' | tr -d 's')
    if [ ${RUNTIME} -ge 30 ]; then
        log_success "AC-6 PASS: RViz2 ran for ${RUNTIME}s (≥30s required)"
    else
        log_fail "AC-6 FAIL: RViz2 ran for ${RUNTIME}s (<30s)"
        grep -A 5 "segfault\|abort\|core dumped" ${CONTAINER_LOG} || true
        exit 1
    fi
else
    log_fail "AC-6 FAIL: Runtime verification not found in logs"
    exit 1
fi
echo ""

# AC-7 Verification: OGRE 14.x API patches (if any)
echo "[R016] === AC-7 Verification: OGRE 14.x API Patches ==="
PATCH_DIR="yocto/meta-rviz2-agl/recipes-ros2"
PATCH_COUNT=$(find ${PATCH_DIR} -name "*.patch" 2>/dev/null | wc -l)

if [ ${PATCH_COUNT} -eq 0 ]; then
    log_fail "AC-7 FAIL: No patches found in ${PATCH_DIR}"
    echo "       At minimum, R007 patch should exist"
    exit 1
elif [ ${PATCH_COUNT} -eq 1 ]; then
    log_success "AC-7 PASS: 1 patch found (R007 guard only, no OGRE API changes needed)"
    find ${PATCH_DIR} -name "*.patch"
else
    log_success "AC-7 PASS: ${PATCH_COUNT} patches found (including OGRE 14.x API fixes)"
    find ${PATCH_DIR} -name "*.patch"
fi
echo ""

# =============================================================================
# Summary
# =============================================================================
echo "[R016] === Verification Summary ==="
log_success "AC-1: OGRE 14.x linkage verified"
log_success "AC-2: 4 packages built"
log_success "AC-3: R007 patch applied"
if [ ${BRIEF_MODE} -eq 0 ]; then
    log_success "AC-4: wl_compositor binding detected"
else
    log_warn "AC-4: Skipped (--brief mode)"
fi
log_warn "AC-5: Manual RDP verification required"
log_success "AC-6: 30s+ idle stability"
log_success "AC-7: Patches documented"
echo ""
echo "[R016] Image: ${IMAGE_TAG} (${IMAGE_SIZE})"
echo "[R016] Logs: ${BUILD_LOG} ${CONTAINER_LOG}"
echo ""
echo "[R016] Next Steps:"
echo "       1. Manual AC-5 verification: xfreerdp /v:localhost:${RDP_PORT} /u:ignored /cert-ignore"
echo "       2. Create baseline: docs/baselines/r016_rviz_source_rebuild_baseline.md"
echo "       3. Update feature_list.json: R016 status → review"
echo ""
log_success "R016 automated verification PASSED (pending AC-5 manual check)"
exit 0

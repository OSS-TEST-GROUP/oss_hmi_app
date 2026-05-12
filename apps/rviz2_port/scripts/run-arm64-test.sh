#!/bin/bash
# R012: arm64 QEMU test environment runner
# Automated build + test execution for CI integration
# Requires: Docker buildx with arm64 support (via QEMU binfmt_misc)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_CONTEXT="$PROJECT_ROOT/docker/arm64-test"
IMAGE_TAG="rviz_agl:arm64-test"

# Color output helpers
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[R012]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[R012 WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[R012 ERROR]${NC} $*" >&2
}

# Check QEMU binfmt_misc setup
check_qemu_setup() {
    log_info "Checking QEMU binfmt_misc arm64 support..."

    if [[ -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]]; then
        log_info "✓ QEMU arm64 emulation enabled (native binfmt)"
        return 0
    fi

    log_warn "QEMU arm64 binfmt not detected. Attempting setup via Docker..."
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes || {
        log_error "Failed to setup QEMU binfmt. Install qemu-user-static on host:"
        log_error "  sudo apt-get install qemu-user-static binfmt-support"
        return 1
    }

    log_info "✓ QEMU arm64 emulation setup complete"
}

# Build arm64 test image
build_image() {
    log_info "Building $IMAGE_TAG..."

    docker buildx build \
        --platform=linux/arm64 \
        --load \
        -f "$DOCKER_CONTEXT/Dockerfile.arm64.test" \
        -t "$IMAGE_TAG" \
        "$DOCKER_CONTEXT" || {
        log_error "Docker build failed"
        return 1
    }

    local IMAGE_SIZE=$(docker images "$IMAGE_TAG" --format "{{.Size}}")
    log_info "✓ Build complete. Image size: $IMAGE_SIZE"
}

# Run test container
run_test() {
    local MODE="${1:-headless}"  # headless or rdp
    local EXTRA_ARGS=()

    if [[ "$MODE" == "rdp" ]]; then
        log_info "Starting test container with RDP backend (port 3389)..."
        EXTRA_ARGS+=(-e WESTON_BACKEND=rdp -p 3389:3389)
    else
        log_info "Starting test container with headless backend..."
        EXTRA_ARGS+=(-e WESTON_BACKEND=headless)
    fi

    # Run container in foreground (CI-friendly)
    docker run --rm \
        --name rviz-arm64-test-runner \
        --platform=linux/arm64 \
        --cap-add SYS_ADMIN \
        "${EXTRA_ARGS[@]}" \
        "$IMAGE_TAG" || {
        log_error "Container execution failed (exit code: $?)"
        return 1
    }

    log_info "✓ Test container completed"
}

# Run container in background (for manual inspection)
run_background() {
    log_info "Starting test container in background..."

    docker run -d \
        --name rviz-arm64-test-bg \
        --platform=linux/arm64 \
        --cap-add SYS_ADMIN \
        -e WESTON_BACKEND=rdp \
        -p 3389:3389 \
        -p 5900:5900 \
        "$IMAGE_TAG" sleep infinity || {
        log_error "Background container start failed"
        return 1
    }

    log_info "✓ Container started: rviz-arm64-test-bg"
    log_info "  Inspect: docker exec -it rviz-arm64-test-bg bash"
    log_info "  VNC: vncviewer localhost:5900 (if VNC_PORT enabled)"
    log_info "  RDP: xfreerdp /v:localhost:3389 /cert:ignore"
    log_info "  Stop: docker stop rviz-arm64-test-bg"
}

# Main script
main() {
    local COMMAND="${1:-build-and-test}"

    case "$COMMAND" in
        check-qemu)
            check_qemu_setup
            ;;
        build)
            check_qemu_setup
            build_image
            ;;
        test)
            run_test headless
            ;;
        test-rdp)
            run_test rdp
            ;;
        background)
            check_qemu_setup
            build_image
            run_background
            ;;
        build-and-test)
            check_qemu_setup
            build_image
            run_test headless
            ;;
        *)
            echo "Usage: $0 {check-qemu|build|test|test-rdp|background|build-and-test}"
            echo ""
            echo "Commands:"
            echo "  check-qemu       Check/setup QEMU binfmt_misc arm64 emulation"
            echo "  build            Build arm64 test image"
            echo "  test             Run headless test (CI mode)"
            echo "  test-rdp         Run with RDP backend (port 3389)"
            echo "  background       Run container in background (manual inspection)"
            echo "  build-and-test   Build + run headless test (default)"
            exit 1
            ;;
    esac
}

main "$@"

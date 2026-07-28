# Dockerfile for R009: x86_64 Wayland-only Integration Test
# Feature: R009 — Native Wayland Integration Smoke Test (Option C Hybrid)
# Base: rviz_agl:qt-wayland (R006 Qt5 Wayland QPA + OGRE 14.x from R005)
#
# Strategy: Option C Hybrid Approach
#   - Qt5 Wayland QPA (R006) + Weston compositor (R006) + apt rviz2 (OGRE 1.12 vendored)
#   - OGRE 14.x in /opt/ogre/ is present but NOT used by apt rviz2 binary
#   - This validates: Qt5 Wayland QPA + Weston + RViz2 native Wayland operation
#   - Full OGRE 14.x integration deferred to R010 arm64 build (colcon overlay)
#
# Rationale for Option C:
#   1. AC 1-5 verification achievable without full OGRE 14.x rebuild
#   2. Fast integration smoke test (no 30+ minute rviz2 source build)
#   3. R010 arm64 build will do proper OGRE 14.x integration with source patches
#   4. Validates R005 (OGRE 14.x build) + R006 (Qt Wayland) + R007 (guards) chain
#
# Build Command:
#   docker build -f docker/wayland-only/Dockerfile -t rviz_agl:wayland-only .
#
# Verification:
#   AC-1: Weston compositor running (headless or RDP backend)
#   AC-2: WAYLAND_DISPLAY / QT_QPA_PLATFORM / QT_WAYLAND_SHELL_INTEGRATION env vars set
#   AC-3: wl_compositor interface binding (WAYLAND_DEBUG=1 grep)
#   AC-4: RViz2 GUI displayed on Weston (RDP visual verification)
#   AC-5: 30+ second idle stability (no segfault/abort)

FROM rviz_agl:qt-wayland

# Install RDP backend dependencies for visual verification
# Note: weston + xwayland already present from R006, but ensure rdp backend
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl \
    freerdp2-x11 \
    && rm -rf /var/lib/apt/lists/*

# Copy entrypoint scripts
COPY docker/wayland/entrypoint-wayland.sh /usr/local/bin/entrypoint-wayland.sh
COPY docker/wayland-only/entrypoint-wayland-only.sh /usr/local/bin/entrypoint-wayland-only.sh
RUN chmod +x /usr/local/bin/entrypoint-wayland.sh /usr/local/bin/entrypoint-wayland-only.sh

# Create workspace for verification scripts
WORKDIR /workspace

# Environment variables for native Wayland operation (AC-2)
# Note: R007 entrypoint will enforce QT_QPA_PLATFORM=wayland if needed
ENV WAYLAND_DISPLAY=wayland-0
ENV QT_QPA_PLATFORM=wayland
ENV QT_WAYLAND_SHELL_INTEGRATION=xdg-shell
ENV XDG_RUNTIME_DIR=/run/user/1000
ENV LIBGL_ALWAYS_SOFTWARE=1

# Labels for metadata
LABEL org.opencontainers.image.title="RViz2 AGL Wayland-Only Integration"
LABEL org.opencontainers.image.description="R009 x86_64 native Wayland integration test (Option C Hybrid)"
LABEL org.agl.rviz2.phase="Phase 3 (R009)"
LABEL org.agl.rviz2.feature="R009-wayland-only"
LABEL org.agl.rviz2.ogre_version="14.5.2 (present but not linked)"
LABEL org.agl.rviz2.rviz_ogre="1.12 (apt vendored, active)"
LABEL org.agl.rviz2.strategy="Option C Hybrid"

# Default command: Run Wayland-only entrypoint (includes R007 guards internally)
CMD ["/usr/local/bin/entrypoint-wayland-only.sh"]

# Dockerfile for Qt5 Wayland QPA Plugin Build Verification
# Feature: R006 — Qt5 Wayland QPA Plugin Validation
# Base: rviz_agl:wayland-dev (R005 OGRE 14.x EGL+Wayland)
#
# Build Strategy:
#   Extend R005 wayland-dev with Qt5 Wayland packages + Weston compositor
#   Single-stage: Runtime image with Qt5 Wayland dev tools for smoke testing
#
# Build Command:
#   docker build -f docker/qt-wayland/Dockerfile -t rviz_agl:qt-wayland .
#
# Verification:
#   AC-3: Qt Wayland QPA plugin loads successfully (QT_QPA_PLATFORM=wayland)
#   AC-4: Qt5 test app connects to Wayland compositor socket
#   AC-5: wl_surface and wl_compositor interfaces bind successfully

FROM rviz_agl:wayland-dev

# Install Qt5 Wayland packages (AC-1, AC-2 verified in local.conf.sample)
# Install Weston compositor for testing (not in wayland-dev)
# Install Qt5 development tools for smoke test compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Qt5 Wayland runtime and development packages
    qtwayland5 \
    libqt5waylandclient5 \
    qtwayland5-dev-tools \
    qml-module-qtwayland-compositor \
    # Qt5 development tools (already partially in wayland-dev, ensure complete)
    qtbase5-dev \
    qtbase5-dev-tools \
    libqt5widgets5 \
    # Build tools for smoke test
    g++ \
    make \
    cmake \
    pkg-config \
    # Weston compositor for testing (headless backend + XWayland)
    weston \
    libweston-9-0 \
    xwayland \
    # XKB data for Weston keyboard support
    xkb-data \
    # Debugging tools (optional but useful for AC verification)
    strace \
    && rm -rf /var/lib/apt/lists/*

# Create XDG runtime directory for Wayland socket
RUN mkdir -p /run/user/1000 && chmod 700 /run/user/1000

# Environment variables for Qt Wayland QPA plugin
ENV QT_QPA_PLATFORM=wayland
ENV QT_WAYLAND_SHELL_INTEGRATION=xdg-shell
ENV QT_DEBUG_PLUGINS=1
ENV XDG_RUNTIME_DIR=/run/user/1000
ENV WAYLAND_DISPLAY=wayland-0

# Verify Qt5 Wayland plugin installation path (AC-3 preliminary check)
RUN echo "=== Verifying Qt5 Wayland QPA plugin installation ===" \
    && ls -lh /usr/lib/x86_64-linux-gnu/qt5/plugins/platforms/libqwayland*.so \
    && echo "=== Qt5 Wayland plugins verified ==="

# Create workspace for smoke test
WORKDIR /workspace

# Labels for metadata
LABEL org.opencontainers.image.title="RViz2 AGL Qt5 Wayland Dev"
LABEL org.opencontainers.image.description="Qt5 with Wayland QPA plugin for RViz2 AGL porting"
LABEL org.opencontainers.image.version="5.15.3"
LABEL org.agl.rviz2.phase="Phase 2 (R006)"
LABEL org.agl.rviz2.feature="R006-qt-wayland-qpa"

# Default command: print Qt5 Wayland plugin info
CMD ["/bin/bash", "-c", "echo 'Qt5 Wayland Runtime Environment'; \
    echo 'Qt version: '$(qmake -query QT_VERSION); \
    echo 'Qt plugins path: '$(qmake -query QT_INSTALL_PLUGINS); \
    ls -lh /usr/lib/x86_64-linux-gnu/qt5/plugins/platforms/libqwayland*.so 2>/dev/null || true; \
    echo 'Use this image for R006 Qt Wayland QPA verification'; \
    exec /bin/bash"]

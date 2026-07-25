# Multi-stage Dockerfile for OGRE 14.x EGL+Wayland Build Verification
# Feature: R005 — OGRE 14.x Native Wayland Backend
# ADR: docs/adr/ADR-003-r005-ogre-wayland-strategy.md
#
# Build Strategy:
#   Stage 1 (ogre-builder): Build OGRE 14.5.2 with EGL+Wayland support
#   Stage 2 (wayland-runtime): Copy OGRE artifacts to R002 base for verification
#
# Build Command:
#   docker build -f docker/wayland/Dockerfile -t rviz_agl:wayland-dev .
#
# Verification:
#   AC-3: Build succeeds with exit code 0
#   AC-4: OgreWayland*.cpp files exist in build tree
#   AC-5: EGL context creation verified via smoke test

# =============================================================================
# Stage 1: OGRE 14.x Builder
# =============================================================================
FROM rviz_agl:x11 AS ogre-builder

# Build arguments
ARG OGRE_VERSION=14.5.2
ARG OGRE_SHA256=1949fe62f3e4b8043e82e4dc94f9b0ab412a5bffc9e10d3b1dddc80fe54fe1e3
ARG BUILD_JOBS=4

# Install OGRE build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools
    cmake \
    ninja-build \
    git \
    wget \
    ca-certificates \
    pkg-config \
    # Wayland development libraries
    libwayland-dev \
    libwayland-egl1-mesa \
    libwayland-egl-backend-dev \
    wayland-protocols \
    libxkbcommon-dev \
    # EGL and OpenGL ES libraries
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    libgl1-mesa-dev \
    libdrm-dev \
    # OGRE dependencies (system libraries)
    libfreetype6-dev \
    zlib1g-dev \
    libfreeimage-dev \
    libxt-dev \
    libglu1-mesa-dev \
    libxrandr-dev \
    libxaw7-dev \
    libpugixml-dev \
    ccache \
    && rm -rf /var/lib/apt/lists/*

# Download OGRE 14.x source with SHA256 verification
WORKDIR /build
RUN wget -q https://github.com/OGRECave/ogre/archive/refs/tags/v${OGRE_VERSION}.tar.gz \
    -O ogre-${OGRE_VERSION}.tar.gz \
    && echo "${OGRE_SHA256}  ogre-${OGRE_VERSION}.tar.gz" | sha256sum -c - \
    && tar xzf ogre-${OGRE_VERSION}.tar.gz \
    && rm ogre-${OGRE_VERSION}.tar.gz

# Build OGRE 14.x with Wayland+EGL support
WORKDIR /build/ogre-${OGRE_VERSION}
RUN cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/opt/ogre \
    # Wayland+EGL configuration (ADR-003 Section 2.3)
    -DOGRE_GLSUPPORT_USE_EGL=ON \
    -DOGRE_USE_WAYLAND=ON \
    -DOGRE_BUILD_RENDERSYSTEM_GL=ON \
    -DOGRE_BUILD_RENDERSYSTEM_GL3PLUS=ON \
    # Disable unnecessary components
    -DOGRE_BUILD_COMPONENT_BITES=OFF \
    -DOGRE_BUILD_COMPONENT_JAVA=OFF \
    -DOGRE_BUILD_COMPONENT_CSHARP=OFF \
    -DOGRE_BUILD_COMPONENT_PYTHON=OFF \
    -DOGRE_BUILD_SAMPLES=OFF \
    -DOGRE_BUILD_TESTS=OFF \
    -DOGRE_BUILD_TOOLS=OFF \
    -DOGRE_BUILD_PLUGIN_DOT_SCENE=OFF \
    -DOGRE_BUILD_PLUGIN_ASSIMP=OFF \
    -DOGRE_BUILD_PLUGIN_BSP=OFF \
    -DOGRE_BUILD_PLUGIN_OCTREE=OFF \
    -DOGRE_BUILD_PLUGIN_PCZ=OFF \
    # Use system libraries (not bundled dependencies)
    -DOGRE_BUILD_DEPENDENCIES=OFF \
    && cmake --build build --parallel ${BUILD_JOBS} \
    && cmake --install build

# Verify Wayland backend files exist (AC-4)
RUN echo "=== Verifying OGRE Wayland backend files ===" \
    && find /build/ogre-${OGRE_VERSION} -name "*Wayland*" | tee /tmp/ogre_wayland_files.txt \
    && if [ ! -s /tmp/ogre_wayland_files.txt ]; then \
        echo "ERROR: No Wayland backend files found in OGRE build tree"; \
        exit 1; \
    fi \
    && echo "=== Wayland backend files verified ==="

# =============================================================================
# Stage 2: Wayland Runtime Environment
# =============================================================================
FROM rviz_agl:x11 AS wayland-runtime

# Copy OGRE 14.x artifacts from builder stage
COPY --from=ogre-builder /opt/ogre /opt/ogre

# Install Wayland runtime dependencies (minimal set)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libwayland-client0 \
    libwayland-egl1 \
    libwayland-server0 \
    libwayland-cursor0 \
    libegl1-mesa \
    libgles2-mesa \
    libdrm2 \
    libxkbcommon0 \
    libfreeimage3 \
    libpugixml1v5 \
    && rm -rf /var/lib/apt/lists/*

# Update library path to include OGRE 14.x
ENV LD_LIBRARY_PATH=/opt/ogre/lib
ENV PKG_CONFIG_PATH=/opt/ogre/lib/pkgconfig
ENV OGRE_PLUGIN_DIR=/opt/ogre/lib/OGRE

# Create log directory for OGRE
RUN mkdir -p /var/log/ogre && chmod 777 /var/log/ogre

# Smoke test entrypoint will be mounted from host
WORKDIR /workspace

# Labels for metadata
LABEL org.opencontainers.image.title="RViz2 AGL OGRE 14.x Wayland Dev"
LABEL org.opencontainers.image.description="OGRE 14.x with EGL+Wayland for RViz2 AGL porting"
LABEL org.opencontainers.image.version="14.5.2"
LABEL org.agl.rviz2.phase="Phase 2 (R005)"
LABEL org.agl.rviz2.feature="R005-ogre-egl-wayland"

# Default command: print OGRE version and Wayland support status
CMD ["/bin/bash", "-c", "echo 'OGRE 14.x Wayland Runtime'; \
    ls -lh /opt/ogre/lib/libOgreMain.so* /opt/ogre/lib/OGRE/RenderSystem_GL* 2>/dev/null || true; \
    echo 'LD_LIBRARY_PATH='$LD_LIBRARY_PATH; \
    echo 'Use this image for R005 EGL context verification'; \
    exec /bin/bash"]

# OGRE EGL+Wayland build configuration for AGL Trout 20.0.3
# Feature: R005 — OGRE 14.x Native Wayland Backend
# ADR: docs/adr/ADR-003-r005-ogre-wayland-strategy.md
#
# IMPORTANT: This bbappend targets OGRE 14.3.0+ which provides native Wayland support.
# The original analysis document assumed OGRE 1.13+ for OGRE_USE_WAYLAND flag,
# but investigation reveals this feature was added in OGRE 14.3.0 (PR #3142, merged 2024-06-26).
#
# STRATEGY: SRC_URI override in bbappend (option b, not a new ogre_14.5.2.bb recipe).
# This allows meta-ros2-humble's base ogre recipe to remain intact while using OGRE 14.x source.

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# =============================================================================
# OGRE 14.x Wayland Build Configuration
# =============================================================================
# Reference: https://github.com/OGRECave/ogre/blob/v14.3.0/RenderSystems/GLSupport/CMakeLists.txt
#
# OGRE 14.x uses cmake_dependent_option for Wayland:
#   cmake_dependent_option(OGRE_USE_WAYLAND "use Wayland window manager" FALSE ...)
#
# Key differences from analysis document assumptions:
#   - OGRE 1.12.x: No Wayland backend (EGL/X11 only)
#   - OGRE 14.3.0+: Native Wayland backend with OgreWaylandEGLSupport.cpp/Window.cpp
#   - OGRE_CONFIG_UNIX_NO_X11 is NOT needed in 14.x (Wayland mode excludes X11 automatically)

EXTRA_OECMAKE:append = " \
    -DOGRE_GLSUPPORT_USE_EGL=ON \
    -DOGRE_USE_WAYLAND=ON \
    -DOGRE_BUILD_RENDERSYSTEM_GL=ON \
    -DOGRE_BUILD_RENDERSYSTEM_GL3PLUS=ON \
    -DOGRE_BUILD_COMPONENT_BITES=OFF \
    -DOGRE_BUILD_SAMPLES=OFF \
    -DOGRE_BUILD_TESTS=OFF \
    -DOGRE_BUILD_TOOLS=OFF \
    -DOGRE_BUILD_PLUGIN_DOT_SCENE=OFF \
    -DOGRE_BUILD_PLUGIN_ASSIMP=OFF \
    -DOGRE_BUILD_PLUGIN_EXRCODEC=OFF \
"

# =============================================================================
# Wayland and EGL Dependencies
# =============================================================================
# Required for native Wayland EGL rendering
DEPENDS:append = " \
    wayland \
    wayland-protocols \
    wayland-native \
    libdrm \
    virtual/egl \
    virtual/libgles2 \
"

# Issue 5 Fix (R010 Session 2c): Disable EXR codec plugin
# openexr masked via BBMASK + ASSUME_PROVIDED in local.conf
# -DOGRE_BUILD_PLUGIN_EXRCODEC=OFF ensures OGRE doesn't require openexr at build/runtime

# Runtime dependencies for Wayland compositor interaction
RDEPENDS:${PN}:append = " \
    wayland \
    libdrm \
"

# =============================================================================
# Package Configuration
# =============================================================================
# Ensure GLES2 and Wayland features are enabled in dependent packages
PACKAGECONFIG:append = " wayland egl"

# =============================================================================
# Source Override (REQUIRED for OGRE 14.x)
# =============================================================================
# meta-ros2-humble provides OGRE 1.12.x by default, which lacks Wayland support.
# Override with OGRE 14.5.2 source (minimum 14.3.0 required for OGRE_USE_WAYLAND=ON).
#
# Strategy: (b) bbappend SRC_URI override (not a new recipe)
# This approach allows the base ogre recipe to remain unchanged while injecting OGRE 14.x.

SRC_URI = "https://github.com/OGRECave/ogre/archive/refs/tags/v${PV}.tar.gz"
SRC_URI[sha256sum] = "1949fe62f3e4b8043e82e4dc94f9b0ab412a5bffc9e10d3b1dddc80fe54fe1e3"

PV = "14.5.2"
S = "${WORKDIR}/ogre-${PV}"

# Note: This SHA256 matches the Docker ARG value in docker/wayland/Dockerfile.
# Verified for v14.5.2 tarball from GitHub releases.

# =============================================================================
# Files for Patches (if needed)
# =============================================================================
# OGRE 14.3.0+ already includes OgreWaylandEGLSupport.cpp and OgreWaylandEGLWindow.cpp.
# No custom Wayland backend patches are required.
#
# If RViz2 compatibility patches are needed, add them here:
# SRC_URI:append = " \
#     file://0001-rviz2-compatibility.patch \
# "

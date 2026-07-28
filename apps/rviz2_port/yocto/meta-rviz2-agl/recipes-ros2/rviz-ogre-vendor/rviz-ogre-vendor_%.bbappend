# R010 T4: rviz_ogre_vendor bbappend for arm64 cross-compile
#
# Purpose: Replace ExternalProject_Add(ogre-v1.12.1) with find_package(OGRE 14.x)
#          to resolve R016 ABI mismatch (OGRE 1.12 vs 14.x C++ ABI incompatibility)
#
# Mechanism: Apply 0001-use-system-ogre-14x.patch to rviz_ogre_vendor/CMakeLists.txt
#            Patch replaces build_ogre() macro call with find_package(OGRE 14.5 REQUIRED)
#
# Dependencies: Requires ogre_%.bbappend (R005) to build OGRE 14.5.2 first
#
# Reference: ADR-006 Section 3 (rviz_ogre_vendor treatment Option X)

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Apply R016-derived patch to use system OGRE 14.x
SRC_URI:append = " file://0001-use-system-ogre-14x.patch"

# Ensure OGRE 14.5.2 is built before rviz_ogre_vendor
# This establishes bitbake dependency chain:
#   ogre (14.5.2) → rviz_ogre_vendor → rviz_rendering → rviz2
DEPENDS:append = " ogre"

# Remove X11 dependencies (Wayland-only build, R007 requirement)
# Base recipe may have libx11, libxrandr, libxaw in DEPENDS
DEPENDS:remove = " libx11 libxrandr libxaw virtual/libx11"

# CMake hints for find_package(OGRE) at do_configure stage
# OGRE 14.5.2 installed by ogre_%.bbappend to ${STAGING_LIBDIR}/cmake/OGRE
EXTRA_OECMAKE:append = " \
    -DOGRE_DIR=${STAGING_LIBDIR}/cmake/OGRE \
    -DOGRE_HOME=${STAGING_DIR_HOST}/usr \
"

# Notes:
#   1. Patch file at: files/0001-use-system-ogre-14x.patch (already exists from R016)
#   2. OGRE version 14.5 required (matches R005 ogre_%.bbappend)
#   3. ABI resolution: rviz_rendering compiles against OGRE 14.x headers from start
#   4. Risk R2 (X11 dependency in rviz_ogre_vendor-extras.cmake.in):
#      If do_configure fails with X11 errors, apply 0002 patch (ADR-006 Appendix)

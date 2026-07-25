# R005-R007-R008: RViz2 Wayland Support for AGL
#
# Feature Chain Integration:
# - R005: OGRE 14.x EGL+Wayland build (ogre_%.bbappend)
# - R006: Qt5 Wayland QPA plugin verification (local.conf qtwayland PACKAGECONFIG)
# - R007: XCB fallback prevention patch (defensive guard)
# - R008: RViz2 Yocto bbappend integration (this file)
#
# This bbappend implements:
# - R007: XCB fallback prevention patch (defensive guard)
# - R008: Wayland runtime dependencies (qtwayland, libxkbcommon, etc.)
# - R008: CMake build flags for release builds
#
# References:
# - ADR-003: R005 OGRE Wayland Strategy
# - ADR-004: R007 Wayland XCB Guard Strategy
# - Baseline: docs/baselines/r007_wayland_xcb_guard_baseline.md
# - Baseline: docs/baselines/r008_bbappend_integration_baseline.md

SUMMARY = "RViz2 with AGL Wayland support patches"
LICENSE = "BSD-3-Clause"

# Prepend files directory for patch lookup
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# R007: Apply defensive guard patch to prevent XCB fallback
SRC_URI:append = " file://0001-wayland-xcb-fallback-guard.patch"

# R008: Add Wayland build dependencies
DEPENDS:append = " \
    qtwayland \
    wayland \
    libxkbcommon \
"

# R008: Add Wayland runtime dependencies
RDEPENDS:${PN}:append = " \
    qtwayland \
    qtwayland-plugins \
"

# Ensure Qt Wayland platform plugin is available at runtime
FILES:${PN}:append = " \
    ${libdir}/qt5/plugins/platforms/libqwayland-*.so \
    ${libdir}/qt5/plugins/wayland-graphics-integration-client/*.so \
"

# R008: CMake build configuration for RViz2
EXTRA_OECMAKE:append = " \
    -DBUILD_TESTING=OFF \
    -DCMAKE_BUILD_TYPE=Release \
"

# R008: RViz2 installation path verification
# Standard ROS 2 Humble installs to:
# - Binary: ${bindir}/rviz2 or /opt/ros/humble/bin/rviz2
# - Libraries: ${libdir}/rviz2 or /opt/ros/humble/lib/rviz2
# - Plugins: ${libdir}/rviz2_default_plugins or /opt/ros/humble/lib/rviz2_default_plugins
#
# The base recipe from meta-ros2-humble handles installation paths via colcon.
# This bbappend does not override FILES:${PN} for binaries (uses base recipe defaults).

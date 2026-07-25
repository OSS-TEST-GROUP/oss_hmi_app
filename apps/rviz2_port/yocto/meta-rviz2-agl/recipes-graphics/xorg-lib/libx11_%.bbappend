# libx11_%.bbappend — Remove REQUIRED_DISTRO_FEATURES check for RViz2 build
#
# R010 Session 2b Issue 3 Fix: AGL removes x11 from DISTRO_FEATURES globally,
# but RViz2 build needs X11 libraries at compile time (headers only).
#
# Solution: Override REQUIRED_DISTRO_FEATURES to empty for X11 libraries.
# This allows them to build even when x11 is not in DISTRO_FEATURES.
#
# Safety: No X server is installed in runtime image (Wayland-only).

REQUIRED_DISTRO_FEATURES = ""

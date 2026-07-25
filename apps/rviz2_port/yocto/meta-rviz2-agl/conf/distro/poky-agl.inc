# poky-agl.inc — RViz2 Build-Time X11 Override
#
# R010 Session 2b Issue 3 Fix: Re-enable X11 in DISTRO_FEATURES for build-time
#
# Problem: meta-agl/meta-agl-core/conf/distro/poky-agl.conf removes x11 globally
#          (line 54: DISTRO_FEATURES:remove = "x11")
#          This blocks rviz-ogre-vendor build which transitively depends on
#          libx11, libxrandr, libxaw build-time libraries.
#
# Solution: Include this file AFTER poky-agl.conf to neutralize the :remove
#           and restore x11 to DISTRO_FEATURES.
#
# Safety: Runtime image remains Wayland-only because:
#   - IMAGE_INSTALL does not include xserver-xorg or X11 server packages
#   - R007 guards enforce QT_QPA_PLATFORM=wayland at runtime
#   - No X11 runtime dependencies in rviz2 final binary (only build-time headers)
#
# Usage: Add to local.conf:
#   require /workdir/sources/meta-rviz2-agl/conf/distro/poky-agl.inc
#
# Reference: docs/baselines/r010_session2b_iteration_fix.md

# Neutralize the x11 removal from base poky-agl distro
# This effectively cancels "DISTRO_FEATURES:remove = x11"
DISTRO_FEATURES:append = " x11"

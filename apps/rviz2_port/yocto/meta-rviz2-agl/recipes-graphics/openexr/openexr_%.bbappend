# Issue 5 Fix (R010 Session 2c): Disable openexr recipe
# openexr depends on clang-native (unavailable in baseline AGL Trout 20.0.3)
# RViz2 does not use OGRE Material exporter (openexr feature) at runtime
#
# Strategy: Mark recipe as EXCLUDE_FROM_WORLD to prevent automatic building
# while allowing DEPENDS:remove to take effect in ogre recipe

# Completely disable this recipe by clearing all tasks
deltask do_fetch
deltask do_unpack
deltask do_patch
deltask do_configure
deltask do_compile
deltask do_install
deltask do_populate_sysroot
deltask do_package
deltask do_packagedata
deltask do_package_write_rpm

# Mark as excluded from world builds
EXCLUDE_FROM_WORLD = "1"

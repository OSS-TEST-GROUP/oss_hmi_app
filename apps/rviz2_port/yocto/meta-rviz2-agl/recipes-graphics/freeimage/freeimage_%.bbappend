# Issue 5 Fix (R010 Session 2c): Remove openexr dependency from freeimage
# openexr depends on clang-native (unavailable in baseline AGL Trout 20.0.3)
# RViz2 does not use freeimage's EXR codec at runtime
# Combined with BBMASK in local.conf to prevent openexr recipe parsing
DEPENDS:remove = "openexr"

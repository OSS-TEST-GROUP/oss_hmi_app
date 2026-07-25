# rviz-default-plugins_%.bbappend
#
# Issue 4 Fix (R010 Session 2b): Suppress ignition-math6 unresolved dependency
#
# Problem: rviz-default-plugins depends on ignition-math6 (Gazebo visualization plugin)
#          but meta-ros2-humble does not provide it. This blocks rviz2 build.
#
# Solution: Mark ignition-math6 as superfluous using meta-ros ROS_SUPERFLOUS_DEPENDS.
#           This tells the build system that the dependency is optional and won't
#           be used at runtime (Gazebo integration disabled).
#
# Reference: meta-ros/meta-ros-common/classes/ros_superflore_generated.bbclass
#            ROS_SUPERFLOUS_DEPENDS pattern for unresolved ROS dependencies
#
# Acceptance Criteria (R010 T4):
#   - bitbake rviz2 no longer skips due to "ignition-math6 was skipped"
#   - rviz-default-plugins builds without ignition-math6 (Gazebo plugins disabled)
#
# Known Limitations:
#   - Gazebo-related RViz plugins (e.g., pose markers) will be non-functional
#   - Complete solution deferred to R013/R014 (add meta-gazebo layer)
#
# Baseline: docs/baselines/r010_session2b_iteration_fix.md

# Suppress ignition-math6 unresolved dependency
# This prevents rviz2 build from failing when ignition-math6 is unavailable
ROS_SUPERFLOUS_DEPENDS_${PN} += "ignition-math6"

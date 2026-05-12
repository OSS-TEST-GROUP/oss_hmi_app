# R002: Phase 1-A X11 Baseline Environment Verification

**Date**: 2026-05-01
**Phase**: Phase 1-A (X11 Baseline)
**Image Tag**: `rviz_agl:x11`
**Base Image**: `ros:humble-ros-base-jammy` (Ubuntu 22.04 + ROS2 Humble)

---

## Build Metrics

### Build Environment
- **Host Platform**: x86_64 Linux
- **Docker Version**: 29.4.1, build 055a478
- **Build Context**: `hmi/rviz_agl/`
- **Dockerfile**: `hmi/rviz_agl/docker/Dockerfile`

### Build Results
- **Build Status**: ✅ SUCCESS
- **Build Time**: ~1min 45sec (colcon build: 1min 27sec)
- **Image Size**: 1.29 GB
- **Image ID**: 716024a8afbd

### Build Layers
1. Base: `ros:humble-ros-base-jammy`
2. System dependencies: Qt5, OpenGL, OGRE, X11, ASSIMP
3. ROS2 packages: rviz2, rviz-common, rviz-default-plugins, rviz-rendering
4. Workspace overlay: colcon build (Release mode)

---

## Runtime Metrics

### RViz2 Binary Location
- **Path**: `/workspace/install/rviz2/lib/rviz2/rviz2`
- **Version**: ROS2 Humble 11.2.26
- **Size**: N/A (overlay build)

### Key Dependencies (versions)
- **Qt5**: 5.15.3+dfsg-2ubuntu0.2
- **OGRE**: rviz-ogre-vendor 11.2.26 (bundled with RViz2)
- **Mesa GL**: 23.2.1-1ubuntu3.1~22.04.3 (OpenGL 4.5, GLSL 4.5)
- **X11**: libx11-6 2:1.7.5-1ubuntu0.3

### Process Metrics
- **Container Start Time**: ~2 seconds
- **RViz2 Process RSS (idle)**: 182 MiB (186396 KB)
- **RViz2 Process VSZ**: 4.5 GiB (4666688 KB)
- **Container Memory**: 87.45 MiB
- **CPU Usage (idle)**: ~11%

---

## X11 GUI Verification

### Environment
- **Host DISPLAY**: :0
- **X11 Socket**: /tmp/.X11-unix/X0
- **XAUTHORITY**: /tmp/.docker.xauth

### AC-1: Docker Build Success
- **Status**: ✅ PASS
- **Evidence**: `docker build` completed successfully, image tagged as `rviz_agl:x11` (1.29GB)

### AC-2: No Segfault on Startup
- **Status**: ✅ PASS
- **Evidence**: Container logs show clean initialization:
  - OpenGL 4.5 (GLSL 4.5) initialized
  - No segfault or crash messages
  - RViz2 process running with PID 28

### AC-3: RViz2 Window Displayed on Host X11
- **Status**: ⚠️ NOT VERIFIED (headless environment)
- **Evidence**: Container running successfully with DISPLAY=:0
  - X11 forwarding configured via `/tmp/.X11-unix` mount
  - `xhost +local:docker` executed
  - Manual verification required with physical display

### AC-4: GUI Idle Stability (10+ seconds)
- **Status**: ✅ PASS
- **Duration**: 39+ seconds verified
- **Evidence**: Container uptime confirmed via `docker ps`, no crashes

### AC-5: Baseline Metrics Recorded
- **Status**: ✅ PASS
- **Evidence**: This document contains all baseline metrics

---

## Dependency Analysis

### APT Packages (count)
- **Total packages**: 241 (qt5/ogre/ros-humble/libgl combined)
- **Qt-related**: ~30 packages (libqt5*)
- **OGRE-related**: 6 packages (ros-humble-rviz-ogre-vendor, etc.)
- **ROS2-related**: 169 packages (ros-humble-*)
- **GL-related**: ~36 packages (libgl*, mesa*)

### Critical Dependencies (versions)
```
Qt5 Core:          libqt5core5a 5.15.3+dfsg-2ubuntu0.2
Qt5 GUI:           libqt5gui5 5.15.3+dfsg-2ubuntu0.2
Qt5 OpenGL:        libqt5opengl5 5.15.3+dfsg-2ubuntu0.2
Mesa EGL:          libegl-mesa0 23.2.1-1ubuntu3.1~22.04.3
Mesa GL:           libgl1-mesa-dri 23.2.1-1ubuntu3.1~22.04.3
GLEW:              libglew2.2 2.2.0-4
GLU:               libglu1-mesa 9.0.2-1
X11:               libx11-6 2:1.7.5-1ubuntu0.3
RViz2:             ros-humble-rviz2 11.2.26-1jammy.20260326.021558
RViz Common:       ros-humble-rviz-common 11.2.26-1jammy.20260325.234558
RViz Rendering:    ros-humble-rviz-rendering 11.2.26-1jammy.20260304.205048
OGRE Vendor:       ros-humble-rviz-ogre-vendor 11.2.26-1jammy.20260304.200738
```

---

## Known Issues / Limitations

### Identified During Verification
1. **Image Tag Mismatch**: 
   - `init.sh` builds `rviz_agl:x11`
   - Original `run.sh` expected `rviz_agl:humble`
   - **Resolution**: Created `scripts/run-x11.sh` with correct tag

2. **Build Context Issue**:
   - Original `init.sh` used `hmi/rviz_agl/docker/` as context
   - Dockerfile `COPY . /workspace/src/rviz_agl/` failed
   - **Resolution**: Changed context to `hmi/rviz_agl/` with `-f docker/Dockerfile`

3. **LIBGL_ALWAYS_SOFTWARE=1**:
   - Software rendering enabled in run script
   - Expected low FPS (will be addressed in R014)
   - NVIDIA GPU present but not using `nvidia-container-toolkit` yet

### Phase 1-A Scope
- ✅ X11 forwarding (host DISPLAY)
- ✅ Software rendering (Mesa llvmpipe)
- ❌ Native Wayland (Phase 2)
- ❌ GPU acceleration (R014)
- ❌ XWayland (R003)

---

## Comparison with Future Phases

| Metric | Phase 1-A (X11) | Phase 1-B (XWayland) | Phase 2 (Native Wayland) |
|--------|-----------------|----------------------|--------------------------|
| Image Size | 1.29 GB | +20MB (est.) | Similar to 1-A |
| Display Protocol | X11 | X11 → Wayland | Wayland |
| OGRE Backend | GLX | GLX | EGL |
| Qt QPA Plugin | xcb | xcb | wayland |
| AGL Compatibility | No | Partial | Full |
| Production Ready | No | No | Yes |
| Runtime RSS | 182 MiB | TBD | TBD |

---

## Next Steps

After R002 completion:
1. **R003**: XWayland validation (Phase 1-B)
2. **R004**: Yocto meta-rviz2-agl layer scaffolding
3. **R005**: OGRE EGL+Wayland build

---

## References

- Analysis Document: `hmi/rviz_agl/planning/rviz_agl_wayland_porting_analysis.md`
- Dockerfile: `hmi/rviz_agl/docker/Dockerfile`
- Run Script: `scripts/run-x11.sh`
- Init Script: `init.sh`

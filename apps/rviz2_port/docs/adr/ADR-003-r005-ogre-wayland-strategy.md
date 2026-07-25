# ADR-003: R005 OGRE EGL+Wayland Build Strategy

**Date**: 2026-05-01  
**Status**: Proposed  
**Feature**: R005 (Phase 2: OGRE EGL+Wayland Build and Patch)  
**Author**: Architect Agent

---

## 1. Context

R005 is the "maximum technical difficulty" task identified in the RViz2 AGL Wayland porting analysis document. The goal is to build OGRE with EGL/Wayland support instead of GLX/X11 for native Wayland rendering on AGL Terrific Trout 20.0.3.

### Current State
- **rviz_ogre_vendor version**: 11.2.26 (ROS2 Humble standard)
- **OGRE version used**: **1.12.1** (vendored via ExternalProject_Add)
- **Current backend**: GLX (X11 OpenGL context) or EGL/X11
- **Wayland support**: **NOT AVAILABLE** in OGRE 1.12.x

### Critical Discovery
The analysis document (Section 6 Issue 2) states:
> "OGRE_USE_WAYLAND flag is stabilized in OGRE 1.13+"

However, investigation reveals:
1. **OGRE 1.12.x** (all releases through 1.12.13): No Wayland backend whatsoever
2. **OGRE 14.x**: Wayland support added in PR #3142, merged 2024-06-26
3. **OGRE 14.3.0+**: Contains `OgreWaylandEGLSupport.cpp` and `OgreWaylandEGLWindow.cpp`

**The analysis document's assumption of OGRE 1.13+ Wayland support is incorrect.** The `OGRE_USE_WAYLAND` CMake option was introduced in OGRE 14.3.0, not 1.13+.

---

## 2. Decision

### 2.1 OGRE Version Strategy: **Upgrade to OGRE 14.5.2**

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **A: Stay with 1.12.1** | No RViz2 API changes | No Wayland backend; requires full custom implementation (2-4 weeks) | Rejected |
| **B: Backport Wayland to 1.12.x** | Minimal RViz2 impact | Complex; X11/EGL assumptions deeply embedded; high risk | Rejected |
| **C: Upgrade to 14.3.0+** | Native Wayland support; actively maintained | Major version jump; potential API breaks; RViz2 compatibility unknown | **Selected** |
| **D: SDL2 Backend Workaround** | Quick; SDL2 handles Wayland | OgreBites dependency; indirect EGL path; additional abstraction layer | Fallback |

**Primary Decision**: Upgrade OGRE from 1.12.1 to **14.5.2** (latest stable) with `OGRE_USE_WAYLAND=ON`.

**Version 14.5.2 Selection Rationale**:
- **14.3.0 is the minimum requirement** (first release with PR #3142 Wayland backend merged on 2024-06-26)
- **14.5.2 is the latest stable release** as of 2026-01, providing:
  - Additional Wayland backend bug fixes and stability improvements (6+ months of upstream testing)
  - Reduced risk of regression compared to bleeding-edge development versions
  - Better CI coverage for Wayland-specific code paths
  - Community-validated Wayland window backend for production use
- **Backward compatibility**: All Wayland features from 14.3.0 are included without breaking changes

**Rationale**:
- OGRE 14.3.0+ provides `OgreWaylandEGLSupport.cpp` and `OgreWaylandEGLWindow.cpp` out-of-the-box
- Wayland CI testing is in place upstream
- Major API breaking changes are documented and manageable
- Attempting custom Wayland backend for 1.12.x would require 2-4 weeks of specialized graphics programming

### 2.2 Build Verification Strategy: **Docker-First (Path A)**

Two verification paths were proposed:
- **Path A**: x86_64 Docker multi-stage build (short-term validation)
- **Path B**: Yocto bbappend (production path)

**Decision**: Path A is the R005 primary deliverable; Path B is documentation-only.

**Rationale**:
- Docker build provides rapid iteration (minutes vs hours for Yocto)
- Validates CMake flags and Wayland backend before Yocto integration
- Yocto bitbake execution deferred to R008+
- R005 focuses on proving the build strategy works

### 2.3 CMake Configuration for OGRE 14.x Wayland

```cmake
-DOGRE_GLSUPPORT_USE_EGL=ON           # Use EGL instead of GLX
-DOGRE_USE_WAYLAND=ON                 # Enable Wayland window backend
-DOGRE_BUILD_RENDERSYSTEM_GL=ON       # OpenGL render system
-DOGRE_BUILD_RENDERSYSTEM_GL3PLUS=ON  # Modern OpenGL 3.3+
-DOGRE_BUILD_COMPONENT_BITES=OFF      # Disable Bites (SDL2 dependency)
-DOGRE_BUILD_SAMPLES=OFF              # No samples needed
-DOGRE_BUILD_TESTS=OFF                # No tests needed
```

**Note**: `OGRE_CONFIG_UNIX_NO_X11` is no longer needed in 14.x; Wayland build automatically excludes X11.

### 2.4 OgreWayland Files Status

| File | Status in 14.3.0+ |
|------|-------------------|
| `OgreWaylandEGLSupport.h` | Exists |
| `OgreWaylandEGLSupport.cpp` | Exists |
| `OgreWaylandEGLWindow.h` | Exists |
| `OgreWaylandEGLWindow.cpp` | Exists |

**No custom patches required for Wayland backend files.**

### 2.5 EGL Dependency Matrix

| Scenario | Use Case | R005 Scope |
|----------|----------|------------|
| **(i) Mesa SW Rendering** | Current R002/R003 env; LIBGL_ALWAYS_SOFTWARE=1 | Primary validation target |
| **(ii) Mesa HW Rendering** | AMD/Intel GPU without proprietary driver | Secondary; may test if available |
| **(iii) NVIDIA EGL HW** | nvidia-container-toolkit required | Deferred to R014 |

**Decision**: R005 validates only (i) Mesa SW rendering. HW rendering is R014 scope.

### 2.6 RViz2 Compatibility with OGRE 14.x

| Concern | Assessment | Mitigation |
|---------|------------|------------|
| API Changes | OGRE 1.x to 14.x has breaking changes | rviz_ogre_vendor abstracts most; test incrementally |
| Material Scripts | OGRE 14.x changed material system | RViz2 uses HLMS abstractions; likely compatible |
| Plugin Loading | Plugin interfaces changed | rviz_rendering may need patches |
| CMake Integration | FindOGRE.cmake differences | Use OGRE 14.x native CMake config |

**Risk**: RViz2 may require source patches to work with OGRE 14.x. This is a known risk to be addressed in R007.

---

## 3. Implementation Blueprint

### Task Breakdown (7 Steps)

| Step | Task | Input | Output | Verification |
|------|------|-------|--------|--------------|
| **T1** | Create Docker base with Wayland dev libs | R003 Dockerfile | Dockerfile.wayland-dev | `pkg-config --exists wayland-client egl` |
| **T2** | Download OGRE 14.3.0 source | N/A | /opt/ogre-14.3.0.zip | SHA256 checksum |
| **T3** | Build OGRE 14.x with Wayland flags | T1 + T2 | libOgreMain.so, libOgreGLSupport.a | No build errors; `-DOGRE_WAYLAND` in compile flags |
| **T4** | Verify EGL context creation | T3 | Ogre.log with EGL init messages | `grep "EGL.*initialized" /var/log/Ogre.log` |
| **T5** | Update rviz_ogre_vendor CMakeLists | T3 findings | Modified CMakeLists.txt | Builds successfully |
| **T6** | Write ogre_%.bbappend (docs only) | T3 + T4 findings | Complete bbappend file | Syntax validation |
| **T7** | Document known issues / next steps | T1-T6 | ADR update + progress.txt | Review by Architect |

### Task Dependencies

```
T1 ─┬─> T2 ──> T3 ──> T4 ──> T5 ──> T7
    │                  │
    └──────────────────┴─> T6 (parallel)
```

---

## 4. Risk Register

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|------------|--------|------------|
| **R1** | OGRE 14.x API breaks rviz_rendering | 40% | High | Incremental build; isolate breaking changes; patch rviz_rendering in R007 |
| **R2** | EGL context creation segfault | 30% | Medium | Use Mesa SW rendering first; run under gdb; analyze Ogre.log |
| **R3** | Wayland-EGL surface binding fails | 25% | Medium | Verify wl_egl_window_create() success; check weston logs |
| **R4** | Docker Wayland environment incomplete | 20% | Low | Reference R003 weston.ini; ensure XDG_RUNTIME_DIR set |
| **R5** | rviz_ogre_vendor ExternalProject conflicts | 35% | Medium | Consider colcon overlay with local OGRE 14.x; bypass ExternalProject |
| **R6** | Build time excessive (>30 min) | 15% | Low | Use ccache; disable unneeded OGRE components |

---

## 5. AC Verification Matrix

| AC# | Description | Auto-Verifiable | Verification Method |
|-----|-------------|-----------------|---------------------|
| **AC-1** | ogre_%.bbappend with EGL/Wayland options | Yes | `grep -E "OGRE_USE_WAYLAND|OGRE_GLSUPPORT_USE_EGL" ogre_%.bbappend` |
| **AC-2** | DEPENDS wayland/libdrm/virtual/egl | Yes | `grep -E "wayland|libdrm|virtual/egl" ogre_%.bbappend` |
| **AC-3** | Docker multi-stage OGRE EGL build | Yes | `docker build` exit code 0; `libOgreGLSupport.a` exists |
| **AC-4** | OgreWayland*.cpp implemented | Yes | Build succeeds with `-DOGRE_USE_WAYLAND=ON` (no patch needed for 14.x) |
| **AC-5** | EGL context creation success log | Semi | `grep -E "EGL.*(initialized|created)" Ogre.log`; manual check for 5-min stability |

**AC-5 Note**: "segfault-free for 5+ minutes" requires manual observation or automated smoke test.

---

## 6. Alternatives Considered

### Alternative 1: SDL2 Backend (OgreBites)

OGRE's Bites component supports SDL2, which handles Wayland via `SDL_VIDEODRIVER=wayland`.

**Pros**:
- SDL2 is mature Wayland support
- No OGRE source modifications

**Cons**:
- OgreBites is for samples, not production use
- Adds SDL2 dependency
- Indirect EGL path (SDL2 -> EGL)
- May interfere with Qt5 event loop

**Verdict**: Reject as primary; keep as emergency fallback if OGRE 14.x native Wayland fails.

### Alternative 2: Keep OGRE 1.12.1 + Custom Wayland Patch

Write `OgreWaylandEGLSupport.cpp` / `OgreWaylandEGLWindow.cpp` from scratch.

**Pros**:
- No RViz2 compatibility risk from major version change

**Cons**:
- 2-4 weeks of specialized graphics work
- X11 assumptions embedded in EGLSupport base class
- Maintenance burden for custom code

**Verdict**: Reject. OGRE 14.x already solved this problem.

### Alternative 3: Use XWayland Permanently

Continue using R003 XWayland approach in production.

**Pros**:
- Already working
- No OGRE changes needed

**Cons**:
- +40MB image size
- +125 MiB runtime memory
- +34% CPU overhead (measured in R003)
- agl-shell integration impossible
- Not production-suitable per analysis document

**Verdict**: Reject for production; R003 is validation-only baseline.

---

## 7. Consequences

### Positive
- Native Wayland support without custom graphics code
- Upstream-maintained Wayland backend (OGRE 14.x community)
- Path to agl-shell integration (Phase 3+)
- Modern OpenGL 3.3+ via GL3Plus render system

### Negative
- Major OGRE version upgrade (1.12.1 -> 14.3.0) introduces compatibility risk
- rviz_rendering may require patches (deferred to R007)
- Build time may increase (OGRE 14.x is larger)
- Team must learn OGRE 14.x API differences

### Neutral
- ogre_%.bbappend CMake flags differ from analysis document (14.x syntax)
- Docker-first validation delays Yocto integration until R008

---

## 8. Developer Handoff

### Key Messages

1. **Start with Task T1**: Create `docker/wayland/Dockerfile` extending R003 base with OGRE build dependencies.

2. **Critical CMake Flags**: Use `OGRE_USE_WAYLAND=ON` (OGRE 14.x syntax), NOT `OGRE_USE_WAYLAND=1` or `OGRE_CONFIG_UNIX_NO_X11=1`.

3. **Version Target**: OGRE 14.3.0 minimum; prefer 14.5.2 (latest stable as of 2026-01).

### First Action

```bash
# Create docker/wayland directory
mkdir -p /home/obigo/project/oss/oss_agent2/docker/wayland

# Begin Dockerfile.wayland-dev
# Base on R003 xwayland image, add:
# - wayland-protocols, libwayland-dev, libwayland-egl-backend-dev
# - libdrm-dev, libegl1-mesa-dev, libgles2-mesa-dev
# - cmake 3.16+, ninja-build
```

---

## 9. References

- OGRE 14.3.0 Wayland PR: https://github.com/OGRECave/ogre/pull/3142
- OGRE 14.x GLSupport CMakeLists.txt: Contains `cmake_dependent_option(OGRE_USE_WAYLAND ...)`
- RViz2 rviz_ogre_vendor: `/home/obigo/project/oss/oss_agent2/hmi/rviz_agl/rviz_ogre_vendor/`
- Analysis Document: `hmi/rviz_agl/planning/rviz_agl_wayland_porting_analysis.md`
- R003 Baseline: `docs/baselines/r003_xwayland_baseline.md`

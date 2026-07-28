# ADR-005: R016 RViz2 Source Rebuild Against OGRE 14.x Strategy

**Date**: 2026-05-01  
**Status**: Proposed  
**Feature**: R016 (RViz2 colcon source rebuild against OGRE 14.x)  
**Author**: Developer Agent  
**Risk Level**: HIGH (Risk R1: OGRE 1.12 → 14.x API breakage 40%)

---

## 1. Context

R016 addresses the critical limitation discovered in R009: apt `ros-humble-rviz2` binary is hardcoded to OGRE 1.12.1 with GLX (X11 OpenGL), making native Wayland rendering impossible. The binary aborts with `Couldn't open X display` when launched in Wayland-only environments.

### R009 Root Cause Analysis
```
$ ldd /opt/ros/humble/lib/librviz_rendering.so | grep -i ogre
libOgreMain.so.1.12 => /opt/ros/humble/opt/rviz_ogre_vendor/lib/libOgreMain.so.1.12

$ ldd /opt/ros/humble/lib/rviz_ogre_vendor/lib/RenderSystem_GL.so
libGL.so => /usr/lib/x86_64-linux-gnu/libGL.so (GLX, X11-only)
```

**Conclusion**: apt package is vendor-locked to OGRE 1.12.1 GLXGLSupport. Native Wayland requires OGRE 14.x EGL+Wayland backend.

### External Repo Policy Constraint
`hmi/rviz_agl/` is an external git repository (read-only access). Direct modifications are FORBIDDEN.

**Allowed Operations**:
- ✅ Docker COPY into container build tree
- ✅ `git apply` patches inside container (ephemeral)
- ✅ Patch files saved in `yocto/meta-rviz2-agl/recipes-ros2/*/files/`
- ❌ Direct file edits in `hmi/rviz_agl/`
- ❌ `git commit` in external repo

---

## 2. Problem Statement

Build RViz2 from source against OGRE 14.5.2 (`/opt/ogre/` from R005) while:
1. Preserving external repo cleanliness (hmi/rviz_agl/ untouched)
2. Applying R007 guard patch (0001-wayland-xcb-fallback-guard.patch)
3. Handling rviz_ogre_vendor CMakeLists.txt OGRE 1.12.1 ExternalProject
4. Capturing OGRE 14.x API compatibility issues as patch files
5. Validating native Wayland runtime (wl_compositor binding, GUI display, 30s stability)

---

## 3. Decision

### 3.1 Build Strategy: **Strategy A (Skip rviz_ogre_vendor) with Fallback to C**

| Strategy | Description | External Repo Impact | Risk |
|----------|-------------|---------------------|------|
| **A: Skip Vendor** | `colcon build --packages-skip rviz_ogre_vendor` + CMake hints | ZERO (no patches) | Medium (find_package may fail) |
| **B: Mock Vendor** | Custom rviz_ogre_vendor wrapper in overlay | ZERO (separate tree) | High (complex CMake logic) |
| **C: Patch Vendor** | Modify rviz_ogre_vendor/CMakeLists.txt via patch | ZERO (patch in yocto/) | Low (direct control) |

**Primary Decision**: Try **Strategy A** first. If `find_package(rviz_ogre_vendor REQUIRED)` fails in rviz_rendering, fall back to **Strategy C**.

**Rationale**:
- Strategy A is fastest (no patch writing upfront)
- OGRE 14.x is already installed in `/opt/ogre/` (R005 artifact)
- CMake `find_package(OGRE)` should locate it via CMAKE_PREFIX_PATH
- If rviz_rendering CMakeLists.txt is tightly coupled to rviz_ogre_vendor, Strategy C patch is required

### 3.2 CMake Configuration (Strategy A)

```bash
colcon build \
    --packages-skip rviz_ogre_vendor rviz_assimp_vendor \
    --cmake-args \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="/opt/ogre;/opt/ros/humble" \
        -DOGRE_DIR=/opt/ogre/lib/OGRE/cmake \
        -Drviz_ogre_vendor_DIR=/opt/ros/humble/lib/cmake/rviz_ogre_vendor
```

**Key Points**:
- `--packages-skip rviz_ogre_vendor`: Prevent OGRE 1.12.1 download
- `CMAKE_PREFIX_PATH`: Prefer `/opt/ogre` (OGRE 14.x) over `/opt/ros/humble`
- `OGRE_DIR`: Explicit hint to OGRE 14.x CMake config
- `rviz_ogre_vendor_DIR`: Keep vendor's CMake config for other packages that depend on it

### 3.3 Fallback: Strategy C Patch (If Strategy A Fails)

If rviz_rendering fails to find OGRE:
1. Create `tools/rviz_ogre_vendor_override/CMakeLists.txt` that sets OGRE_DIR
2. OR patch `rviz_rendering/CMakeLists.txt` to accept OGRE_DIR override
3. Save patch as `yocto/meta-rviz2-agl/recipes-ros2/rviz_rendering/files/0002-ogre14-cmake-hints.patch`

---

## 4. OGRE 14.x API Compatibility Risk Mitigation

### Known API Differences (R005 findings)

| OGRE 1.12.x | OGRE 14.x | Impact |
|-------------|-----------|--------|
| `setLogDetail(LL_NORMAL)` | `setMinLogLevel(LL_NORMAL)` | Low (logging only) |
| `renderOneFrame()` | Signature unchanged | None |
| HardwareBuffer API | Minor enum changes | Medium (compile errors) |
| Material scripts | Syntax compatible | None |

### Patch Workflow (If Compilation Errors Occur)

1. **Identify Error**: Extract file path + line number from colcon build log
2. **Create Patch**: 
   ```bash
   # Inside container, after manual fix
   git -C /workspace/src/rviz_agl diff <package>/<file> > /tmp/0002-<package>-ogre14-<issue>.patch
   ```
3. **Save Patch**: Copy to `yocto/meta-rviz2-agl/recipes-ros2/<package>/files/`
4. **Update bbappend**: Add patch to SRC_URI
5. **Rebuild**: Apply all patches and retry

### Expected Patch Count
- **Best case**: 0 patches (OGRE 14.x ABI-compatible in rendering layer)
- **Likely case**: 1-3 patches (minor enum changes, deprecated methods)
- **Worst case**: 5+ patches → **BLOCK and report to user** (major refactor needed)

---

## 5. Build Environment

### Docker Multi-Stage Strategy

```dockerfile
# Stage 1: Builder (extends rviz_agl:wayland-only, R009)
FROM rviz_agl:wayland-only AS rviz-builder

# Install colcon build tools
RUN apt-get update && apt-get install -y \
    python3-colcon-common-extensions \
    python3-rosdep \
    && rm -rf /var/lib/apt/lists/*

# Copy external repo into container (ephemeral)
COPY hmi/rviz_agl /workspace/src/rviz_agl

# Apply R007 patch (inside container, not in external repo)
COPY yocto/meta-rviz2-agl/recipes-ros2/rviz2/files/0001-wayland-xcb-fallback-guard.patch /tmp/
RUN git -C /workspace/src/rviz_agl apply /tmp/0001-wayland-xcb-fallback-guard.patch

# Run colcon build with Strategy A
RUN colcon build --packages-skip rviz_ogre_vendor rviz_assimp_vendor \
    --cmake-args -DCMAKE_PREFIX_PATH=/opt/ogre ...

# Stage 2: Runtime (copy install/ directory only)
FROM rviz_agl:wayland-only AS rviz-runtime
COPY --from=rviz-builder /workspace/install /workspace/install
```

**Key Properties**:
- External repo copied into `/workspace/src/rviz_agl` (container-local)
- Patches applied inside container (never touch host `hmi/rviz_agl/`)
- Build tree discarded (only `/workspace/install/` kept in runtime image)
- R009 entrypoint reused (`entrypoint-wayland-only.sh` sources `/workspace/install/setup.bash`)

---

## 6. Acceptance Criteria Verification

| AC | Verification Method | Evidence |
|----|---------------------|----------|
| AC-1 | `ldd /workspace/install/lib/rviz2/rviz2 \| grep libOgreMain` | libOgreMain.so.14.5 (not 1.12) |
| AC-2 | `ls /workspace/install/{rviz2,rviz_common,rviz_default_plugins,rviz_rendering}/lib` | All 4 packages present |
| AC-3 | `grep -r "R007 GUARD" /workspace/src/rviz_agl/rviz2/src/main.cpp` | Patch applied |
| AC-4 | `WAYLAND_DEBUG=1 docker logs <container> \| grep wl_compositor@.*bind` | Protocol binding |
| AC-5 | RDP connection to port 3389, visual RViz2 window | User verification |
| AC-6 | Container runtime ≥30s without segfault | Automated timeout |
| AC-7 | `find yocto/meta-rviz2-agl/recipes-ros2/ -name "*.patch"` | Patch files exist |

---

## 7. Blocking Conditions (User Escalation)

Stop development and report to user if any occur:
1. **5+ OGRE API patches required** (major refactor scope, 2+ days)
2. **rviz_assimp_vendor also OGRE-dependent** (additional complexity)
3. **Build time >90 minutes** (resource exhaustion, need CI tuning)
4. **Docker build OOM** (need multi-stage optimization or host build)
5. **OGRE 14.x segfault in EGL init** (regression from R005 smoke test)

---

## 8. Alternative Rejected

### Why Not Option B (Mock rviz_ogre_vendor)?
- Requires replicating rviz_ogre_vendor's CMake config generation
- Higher risk of missing transitive dependencies
- No benefit over Strategy C if patching is needed anyway

### Why Not Defer to R010 (arm64)?
- R010 depends on R016 (feature_list.json deps: [R009, R016])
- x86_64 validation enables faster iteration (Docker cache, no QEMU overhead)
- OGRE 14.x API issues should be discovered on x86_64 first

---

## 9. Success Criteria

**Minimum Viable Outcome**:
1. RViz2 binary links to OGRE 14.5.2 (not 1.12.1)
2. Wayland compositor binding successful (WAYLAND_DEBUG logs)
3. GUI displayed via RDP (user visual verification)
4. 30s stability without crash
5. OGRE API patches (if any) documented and saved

**Ideal Outcome**:
- Zero OGRE API patches (ABI-compatible)
- Build time <30 minutes (clean)
- Image size ≤1.5GB (runtime stage)
- External repo `hmi/rviz_agl/` untouched (git status clean)

---

## 10. Next Steps After R016

If R016 PASSES:
- R010: Apply same colcon overlay to arm64 cross-compile
- R011: arm64 runtime Dockerfile uses R016 build pattern
- R015: agl-shell integration (R016 Wayland foundation validated)

If R016 BLOCKS:
- Escalate to user with:
  - Number of OGRE API patches needed
  - Estimated refactor time
  - Alternative options (stay on OGRE 1.12 + custom Wayland backend)

---

## 11. References

- ADR-003: R005 OGRE EGL+Wayland Build Strategy
- ADR-004: R007 Wayland XCB Fallback Guard
- R009 Baseline: OGRE 1.12 GLX limitation documented
- OGRE PR #3142: Wayland backend (merged 2024-06-26)
- rviz_ogre_vendor CMakeLists.txt: Line 164 (OGRE 1.12.1 ExternalProject)

# ADR-006: R010 arm64 Cross-Compile Builder Strategy (AGL Yocto SDK)

**Date**: 2026-05-01  
**Status**: Proposed  
**Feature**: R010 (arm64 cross-compile builder Dockerfile)  
**Author**: Architect Agent  
**Risk Level**: HIGH (R016 ABI mismatch inheritance, bitbake complexity)

---

## 1. Context

R010 is the arm64 cross-compile phase that absorbed R016 (RViz2 colcon source rebuild). The critical finding from R016 was:

**OGRE 1.12 <-> 14.x C++ ABI Incompatibility**

R016 attempted 4 strategies to run RViz2 against OGRE 14.x on x86_64:
1. Strategy A (Skip rviz_ogre_vendor) - FAILED: CMake still found apt OGRE 1.12
2. Strategy C (Patch rviz_ogre_vendor CMakeLists.txt) - Built OK, but ABI mismatch at runtime
3. Runtime LD_LIBRARY_PATH override - FAILED: `undefined symbol: _ZNK4Ogre9Exception18getFullDescriptionB5cxx11Ev`
4. colcon rebuild with patched rviz_ogre_vendor - Partial success, but SDK environment contaminated

**Root Cause**: `rviz_rendering` was compiled against OGRE 1.12 headers by Ubuntu's apt package. Even with OGRE 14.x `.so` at runtime, the C++ ABI differs. The only clean solution is to compile `rviz_rendering` (and all 4 rviz packages) from source against OGRE 14.x headers from the start.

**R010's Mission**: Create a clean cross-compile environment where bitbake/colcon builds RViz2 against OGRE 14.x headers, naturally resolving the ABI mismatch.

### Key Inputs

| Input | Location | Purpose |
|-------|----------|---------|
| ADR-003 | `docs/adr/ADR-003-r005-ogre-wayland-strategy.md` | OGRE 14.5.2 decision |
| ADR-004 | `docs/adr/ADR-004-r007-wayland-xcb-guard.md` | R007 guard strategy |
| ADR-005 | `docs/adr/ADR-005-r016-rviz-source-rebuild-strategy.md` | R016 4-strategy history |
| ogre bbappend | `yocto/meta-rviz2-agl/recipes-ros2/ogre/ogre_%.bbappend` | OGRE 14.5.2 SRC_URI override |
| rviz2 bbappend | `yocto/meta-rviz2-agl/recipes-ros2/rviz2/rviz2_%.bbappend` | R007 patch registration |
| rviz_ogre_vendor patch | `yocto/.../rviz_ogre_vendor/files/0001-use-system-ogre-14x.patch` | CMake export fix |
| oss_hmi_app pattern | `hmi/oss_hmi_app/apps/docker/Dockerfile.build.arm64` | AGL SDK builder reference |

---

## 2. Build Path Analysis

### Path A: AGL Yocto SDK Cross-Compile (oss_hmi_app Pattern)

**Description**: Download AGL Yocto SDK installer, source environment, use SDK's cross-compiler with colcon build.

```dockerfile
ARG AGL_SDK_URL=https://repo.obigo.com/repository/yocto-adt/agl/oss-agl-ivi-flutter-aarch64-toolchain-19.92.0.sh
RUN wget --user=${AGL_SDK_USER} --password=${AGL_SDK_PASSWORD} ${AGL_SDK_URL} -O /tmp/agl-sdk.sh
RUN /tmp/agl-sdk.sh -d /opt/agl-sdk -y
# Source SDK, then colcon build
```

**Pros**:
- Proven pattern (oss_hmi_app uses this for Flutter arm64 AOT)
- SDK provides consistent sysroot matching AGL Trout target
- Cross-compiler pre-configured for aarch64

**Cons**:
- SDK download requires authentication (AGL_SDK_USER/PASSWORD)
- SDK may not include OGRE 14.x (Flutter-focused SDK)
- colcon cross-compile with SDK environment is undocumented territory
- Need to verify ROS2 Humble compatibility in SDK

**ABI Resolution**: PARTIAL - SDK sysroot likely has OGRE 1.12 from meta-ros2-humble base. Would need to inject OGRE 14.x into sysroot.

### Path B: Ubuntu 22.04 + arm64 Cross-Toolchain

**Description**: Use `crossbuild-essential-arm64` and `gcc-aarch64-linux-gnu` with ROS2 Humble arm64 apt packages as sysroot.

```dockerfile
FROM ubuntu:22.04
RUN apt-get install -y crossbuild-essential-arm64 gcc-aarch64-linux-gnu
# Add ROS2 Humble arm64 apt sources, install to sysroot
# CMAKE_TOOLCHAIN_FILE for cross-compile
```

**Pros**:
- No SDK authentication dependency
- Fast setup (apt packages only)
- CMake toolchain file approach is well-documented

**Cons**:
- ROS2 apt arm64 packages still have OGRE 1.12 hardcoded
- Not a true AGL environment (generic Ubuntu vs AGL-specific glibc/gcc)
- Sysroot management complexity
- ABI mismatch persists (same root cause as R016)

**ABI Resolution**: FAILS - Same problem as x86_64 R016. apt packages are pre-built against OGRE 1.12.

### Path C: bitbake Direct Invocation (Yocto Full Build)

**Description**: Set up Yocto Scarthgap build environment in Docker, invoke `bitbake rviz2` which uses our meta-rviz2-agl layer.

```dockerfile
FROM ubuntu:22.04
# Yocto Scarthgap build dependencies
RUN apt-get install -y gawk wget git diffstat texinfo ...
# Clone AGL layers, meta-ros2-humble, meta-rviz2-agl
# Configure bblayers.conf, local.conf
# bitbake rviz2
```

**Pros**:
- Uses existing ogre_%.bbappend (OGRE 14.5.2 SRC_URI override)
- bitbake handles dependency resolution automatically
- rviz_rendering compiled against OGRE 14.x headers naturally
- ABI mismatch RESOLVED BY DESIGN

**Cons**:
- First build time: 4-8 hours (downloads, compiles entire dependency tree)
- Disk usage: 30-60GB (tmp/, sstate-cache/, downloads/)
- Yocto Scarthgap + Humble is "best-effort" (gcc 13 / glibc 2.39 issues possible)
- Complex Dockerfile (many layers, large context)

**ABI Resolution**: COMPLETE - bitbake builds rviz_rendering from source with OGRE 14.x as DEPENDS. No pre-built binaries involved.

### Path Comparison Summary

| Criterion | Path A (AGL SDK) | Path B (Ubuntu cross) | Path C (bitbake) |
|-----------|------------------|----------------------|------------------|
| ABI Resolution | PARTIAL | FAILS | COMPLETE |
| Build Time | Medium (SDK download + colcon) | Fast (apt only) | Slow (4-8 hours first) |
| Disk Usage | ~5GB | ~3GB | 30-60GB |
| Auth Required | Yes (SDK creds) | No | No |
| Incremental Builds | Fast (colcon cache) | Fast | Fast (sstate-cache) |
| AGL Compatibility | High (SDK matches target) | Low (generic Ubuntu) | High (exact Yocto match) |
| Complexity | Medium | Low | High |

---

## 3. Decision

### Primary Path: **C (bitbake Direct) with Hybrid Optimization**

**Rationale**:
1. Path C is the ONLY path that truly resolves the R016 ABI mismatch
2. Paths A and B would repeat R016's failure mode
3. bitbake naturally uses ogre_%.bbappend (OGRE 14.5.2) as build dependency
4. meta-rviz2-agl layer already has all required patches (R007, R008)
5. sstate-cache enables fast incremental builds after initial 4-8 hour investment

### Hybrid Optimization Strategy

To mitigate Path C's build time and disk concerns:

1. **Pre-built sstate-cache**: Share sstate-cache between builds via Docker volume
2. **Minimal target**: `bitbake rviz2 -c package` instead of full image
3. **Layer subset**: Only include layers needed for rviz2 (not full agl-ivi-demo)
4. **Two-stage Dockerfile**: Builder stage (huge) -> Runtime artifact extraction (small tar.gz)

```
+-------------------+     +--------------------+     +------------------+
| bitbake builder   | --> | sstate-cache volume| --> | subsequent builds|
| (first: 4-8 hrs)  |     | (persistent)       |     | (fast: 10-30 min)|
+-------------------+     +--------------------+     +------------------+
```

### rviz_ogre_vendor CMake Export Treatment: **Option X (Patch)**

**Decision**: Use the existing `0001-use-system-ogre-14x.patch` from R016 backup.

**Rationale**:
1. Patch already exists in `yocto/meta-rviz2-agl/recipes-ros2/rviz_ogre_vendor/files/`
2. Replaces `build_ogre()` macro call with `find_package(OGRE 14.5 REQUIRED)`
3. Tested in R016 colcon context, proven to work
4. bitbake will apply via SRC_URI automatically

**bbappend Creation Required**: `rviz_ogre_vendor_%.bbappend`

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " file://0001-use-system-ogre-14x.patch"
DEPENDS:append = " ogre"  # Ensure OGRE 14.5.2 is built first
```

### rviz_ogre_vendor-extras.cmake.in Consideration

The `rviz_ogre_vendor-extras.cmake.in` file has **X11 dependencies hardcoded**:

```cmake
# Line 122-125: X11 library linking
find_package(X11 REQUIRED)
list(APPEND _extra_interface_link_libraries ${X11_LIBRARIES} ${X11_Xt_LIB} ${X11_Xrandr_LIB})
find_library(XAW_LIBRARY NAMES Xaw Xaw7 PATHS ${DEP_LIB_SEARCH_DIR} ${X11_LIB_SEARCH_PATH})
```

**Impact**: When downstream packages (rviz_rendering) use `find_package(rviz_ogre_vendor)`, they inherit X11 link requirements even though OGRE 14.x Wayland backend doesn't need them.

**Mitigation**: Additional patch `0002-rviz_ogre_vendor-extras-wayland.patch`:
- Remove X11 REQUIRED
- Conditionally link X11 only if building for X11 backend
- Add EGL/Wayland libs for Wayland backend

**Deferred Decision**: Evaluate at build time. If bitbake fails on X11 deps in AGL (no X11), create 0002 patch then.

---

## 4. ABI Mismatch Resolution Mechanism

### How Path C Solves R016

```
bitbake dependency graph:
  rviz2 -> rviz_common -> rviz_rendering -> rviz_ogre_vendor -> ogre

With meta-rviz2-agl:
  ogre recipe uses ogre_%.bbappend -> SRC_URI = OGRE 14.5.2 (not 1.12)
  rviz_ogre_vendor uses 0001-use-system-ogre-14x.patch -> find_package(OGRE 14.5)
  rviz_rendering compiles with OGRE 14.x headers -> ABI MATCH
  rviz2 links to rviz_rendering -> OGRE 14.x compatible
```

**Key Insight**: bitbake's `DEPENDS` mechanism ensures OGRE 14.5.2 is built before rviz_ogre_vendor, which is built before rviz_rendering. Each stage uses the correct headers.

### Runtime Verification

After bitbake completes:
```bash
# In target sysroot or deployed image
ldd /opt/ros/humble/lib/rviz2/rviz2 | grep OgreMain
# Expected: libOgreMain.so.14.5 => /usr/lib/libOgreMain.so.14.5.2
# Not: libOgreMain.so.1.12 (this would indicate failure)
```

---

## 5. Implementation Blueprint

### Task Breakdown (8 Steps)

| Task | Description | Input | Output | Verification |
|------|-------------|-------|--------|--------------|
| **T1** | Create `Dockerfile.build.arm64` skeleton | oss_hmi_app pattern | Dockerfile with Yocto deps | `docker build --target=deps` |
| **T2** | Clone AGL/Yocto layers in Dockerfile | Layer URLs | `/workdir/sources/` populated | `ls /workdir/sources/meta-agl` |
| **T3** | Configure `bblayers.conf` / `local.conf` | Samples from R004 | `/workdir/build/conf/` | `bitbake-layers show-layers` |
| **T4** | Create `rviz_ogre_vendor_%.bbappend` | 0001-use-system-ogre-14x.patch | Recipe registered | Lint script pass |
| **T5** | Initial bitbake dry-run | T1-T4 | Parse success | `bitbake rviz2 -n` |
| **T6** | Full bitbake build | T5 | arm64 binaries | `file tmp/*/rviz2` = aarch64 |
| **T7** | ABI verification | T6 | ldd output | `ldd | grep libOgreMain.so.14.5` |
| **T8** | tar.gz export | T7 | `rviz_agl-arm64.tar.gz` | Archive size, contents check |

### Task Dependencies

```
T1 ──> T2 ──> T3 ──> T4 ──> T5 ──> T6 ──> T7 ──> T8
                      │
                      └── 0001-use-system-ogre-14x.patch (existing)
```

### Dockerfile Outline

```dockerfile
# Stage 1: Yocto Build Environment
FROM ubuntu:22.04 AS yocto-builder

# Yocto Scarthgap dependencies (as per Yocto docs)
RUN apt-get update && apt-get install -y \
    gawk wget git diffstat unzip texinfo gcc g++ \
    build-essential chrpath socat cpio python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping python3-git python3-jinja2 \
    libegl1-mesa libsdl1.2-dev pylint3 xterm python3-subunit \
    mesa-common-dev zstd liblz4-tool locales libacl1 \
    && rm -rf /var/lib/apt/lists/*

# Set locale (Yocto requirement)
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# Clone layers
WORKDIR /workdir/sources
RUN git clone -b scarthgap --depth=1 https://git.yoctoproject.org/poky && \
    git clone -b scarthgap --depth=1 https://github.com/AGL/meta-agl.git && \
    git clone -b scarthgap --depth=1 https://github.com/openembedded/meta-openembedded.git && \
    git clone -b scarthgap --depth=1 https://github.com/OE4T/meta-tegra.git || true && \
    git clone -b scarthgap --depth=1 https://github.com/ros/meta-ros.git

# Copy our custom layer
COPY yocto/meta-rviz2-agl /workdir/sources/meta-rviz2-agl

# Configure build
WORKDIR /workdir/build
COPY yocto/bblayers.conf.sample conf/bblayers.conf
COPY yocto/local.conf.sample conf/local.conf

# Build (can be split into separate stages for caching)
RUN . /workdir/sources/poky/oe-init-build-env /workdir/build && \
    bitbake rviz2 -c package

# Stage 2: Extract artifacts
FROM scratch AS artifacts
COPY --from=yocto-builder /workdir/build/tmp/deploy/ipk/aarch64/rviz2*.ipk /
COPY --from=yocto-builder /workdir/build/tmp/deploy/ipk/aarch64/rviz-*.ipk /
COPY --from=yocto-builder /workdir/build/tmp/deploy/ipk/aarch64/ogre*.ipk /
```

---

## 6. Risk Register

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|------------|--------|------------|
| **R1** | Yocto Scarthgap + Humble gcc 13 build failures | 40% | High | Pin known-good commits; fallback to Kirkstone |
| **R2** | rviz_ogre_vendor-extras.cmake.in X11 dependency | 60% | Medium | 0002 patch to remove X11 REQUIRED |
| **R3** | Disk exhaustion (>60GB) | 25% | High | Use Docker volume for sstate-cache; prune tmp/ |
| **R4** | First build exceeds 8 hours | 30% | Medium | Accept as one-time cost; use sstate-cache for subsequent |
| **R5** | meta-ros2-humble scarthgap branch instability | 35% | Medium | Pin to specific commit; test incrementally |
| **R6** | OGRE 14.x API changes break rviz_rendering | 40%* | High | R016 documented no API patches needed (x86_64 build succeeded) |

*R6 was 40% in ADR-005 but R016 partial success suggests lower likelihood now.

---

## 7. AC Verification Matrix

| AC# | Description | Verification Method | Evidence |
|-----|-------------|---------------------|----------|
| **AC-1** | Dockerfile.build.arm64 exists | `test -f Dockerfile.build.arm64` | File path |
| **AC-2** | ROS2 Humble arm64 cross-compile env | `bitbake rviz2 -n` exit 0 | Parse log |
| **AC-3** | OGRE 14.5.2 links rviz_rendering | `ldd rviz_rendering.so \| grep OgreMain.so.14.5` | ldd output |
| **AC-4** | rviz_ogre_vendor CMake export patch | Patch in SRC_URI, do_patch success | bitbake log |
| **AC-5** | Build artifacts in install/ | `file rviz2` shows `aarch64` | file output |
| **AC-6** | QEMU/arm64 ldd verification | `qemu-aarch64-static ldd rviz2` | ldd output |
| **AC-7** | tar.gz export | `ls rviz_agl-arm64.tar.gz` | Archive size |

---

## 8. Disk and Time Estimates

### Disk Usage Projection

| Component | Estimated Size | Persistent? |
|-----------|----------------|-------------|
| Docker image (builder) | 15-20 GB | Yes |
| /workdir/sources (layers) | 5 GB | Yes (in image) |
| sstate-cache | 20-30 GB | Yes (Docker volume) |
| tmp/ build artifacts | 30-40 GB | No (cleaned) |
| downloads/ | 5-10 GB | Yes (Docker volume) |
| **Total Peak** | **80-100 GB** | - |
| **After cleanup** | **40-50 GB** | - |

**Current Host Availability**: 605 GB free (ample)

### Time Estimates

| Phase | First Build | Subsequent |
|-------|-------------|------------|
| Docker image build (deps) | 10-15 min | Cached |
| Layer cloning | 10-20 min | Cached |
| bitbake rviz2 (parse) | 5-10 min | 1-2 min |
| bitbake rviz2 (compile) | 4-8 hours | 10-30 min (sstate) |
| Artifact extraction | 5 min | 5 min |
| **Total** | **5-9 hours** | **20-40 min** |

**Session Compatibility**: Initial build exceeds typical 2-hour session. Recommend:
1. Start build with `run_in_background`
2. Or split into multiple sessions (T1-T4 in session 1, T5-T8 in session 2)

---

## 9. Alternatives Rejected

### Why Not Path A (AGL SDK)?

- SDK's Flutter-focused toolchain likely lacks OGRE 14.x
- Would need to inject OGRE 14.x into sysroot manually
- colcon cross-compile with SDK is undocumented
- Does not truly solve ABI mismatch (same root cause as R016)

### Why Not Path B (Ubuntu Cross)?

- apt ros-humble-rviz2 arm64 packages have OGRE 1.12 hardcoded
- Would repeat R016's ABI mismatch failure
- Generic Ubuntu sysroot differs from AGL target

### Why Not Defer arm64 and Fix x86_64 First?

- R016 already explored all reasonable x86_64 options
- ABI mismatch is fundamental (compilation artifact, not runtime fixable)
- arm64 bitbake is the natural clean-slate environment
- x86_64 Docker validation can continue with R009 infrastructure smoke test

---

## 10. Developer Handoff

### Key Messages

1. **Path C (bitbake) is mandatory** - Paths A/B will fail with same ABI mismatch as R016

2. **First build is 5-9 hours** - Use `run_in_background` or multi-session approach

3. **rviz_ogre_vendor_%.bbappend is required** - Must create to apply 0001-use-system-ogre-14x.patch via SRC_URI

### First Actions

```bash
# 1. Create rviz_ogre_vendor bbappend
mkdir -p yocto/meta-rviz2-agl/recipes-ros2/rviz_ogre_vendor
cat > yocto/meta-rviz2-agl/recipes-ros2/rviz_ogre_vendor/rviz_ogre_vendor_%.bbappend << 'EOF'
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " file://0001-use-system-ogre-14x.patch"
DEPENDS:append = " ogre"
EOF

# 2. Create Dockerfile.build.arm64 skeleton
# (Reference: hmi/oss_hmi_app/apps/docker/Dockerfile.build.arm64)

# 3. Start bitbake dry-run to validate layer configuration
```

### Blocking Conditions

Stop and report to user if:
1. Yocto parse fails with meta-ros2-humble layer compatibility errors
2. rviz_ogre_vendor-extras.cmake.in X11 link fails (need 0002 patch)
3. Disk usage exceeds 100GB before build completes
4. Build time exceeds 12 hours without progress

---

## 11. References

- ADR-003: R005 OGRE EGL+Wayland Strategy
- ADR-004: R007 Wayland XCB Guard
- ADR-005: R016 RViz2 Source Rebuild (4-strategy history)
- R016 Baseline: `docs/baselines/r016_rviz_source_rebuild_baseline.md`
- R016 Strategy Decisions: `docs/baselines/r016_strategy_decisions.md`
- oss_hmi_app Pattern: `hmi/oss_hmi_app/apps/docker/Dockerfile.build.arm64`
- Analysis Document: `hmi/rviz_agl/planning/rviz_agl_wayland_porting_analysis.md` Section 4
- OGRE bbappend: `yocto/meta-rviz2-agl/recipes-ros2/ogre/ogre_%.bbappend`
- rviz2 bbappend: `yocto/meta-rviz2-agl/recipes-ros2/rviz2/rviz2_%.bbappend`
- rviz_ogre_vendor patch: `yocto/meta-rviz2-agl/recipes-ros2/rviz_ogre_vendor/files/0001-use-system-ogre-14x.patch`

---

## 12. Appendix: rviz_ogre_vendor-extras.cmake.in X11 Issue

The file `hmi/rviz_agl/rviz_ogre_vendor/rviz_ogre_vendor-extras.cmake.in` contains:

```cmake
# Lines 121-126
if(UNIX AND NOT APPLE)
  find_package(X11 REQUIRED)
  list(APPEND _extra_interface_link_libraries ${X11_LIBRARIES} ${X11_Xt_LIB} ${X11_Xrandr_LIB})
  find_library(XAW_LIBRARY NAMES Xaw Xaw7 PATHS ${DEP_LIB_SEARCH_DIR} ${X11_LIB_SEARCH_PATH})
  list(APPEND _extra_interface_link_libraries ${XAW_LIBRARY})
endif()
```

This assumes all Linux builds need X11. For AGL Wayland-only:

**Proposed 0002 Patch** (if needed):

```cmake
# Conditional X11 linking (Wayland-only builds skip X11)
if(UNIX AND NOT APPLE AND NOT DEFINED ENV{OGRE_USE_WAYLAND})
  find_package(X11 QUIET)
  if(X11_FOUND)
    list(APPEND _extra_interface_link_libraries ${X11_LIBRARIES} ${X11_Xt_LIB} ${X11_Xrandr_LIB})
    find_library(XAW_LIBRARY NAMES Xaw Xaw7 PATHS ${DEP_LIB_SEARCH_DIR} ${X11_LIB_SEARCH_PATH})
    if(XAW_LIBRARY)
      list(APPEND _extra_interface_link_libraries ${XAW_LIBRARY})
    endif()
  endif()
endif()
# For Wayland: link EGL and Wayland instead
if(DEFINED ENV{OGRE_USE_WAYLAND})
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(EGL REQUIRED egl)
  pkg_check_modules(WAYLAND REQUIRED wayland-client wayland-egl)
  list(APPEND _extra_interface_link_libraries ${EGL_LIBRARIES} ${WAYLAND_LIBRARIES})
endif()
```

**Status**: DEFERRED - Only create if bitbake fails on X11 dependency.

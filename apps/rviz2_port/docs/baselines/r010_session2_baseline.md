# R010 Session 2 Baseline: Yocto Bitbake Build (T5-T8)

## Executive Summary

Session 2 focuses on executing the actual Yocto bitbake build for arm64 RViz2 cross-compilation.
This session leverages the infrastructure prepared in Session 1 (Dockerfile, layer scripts, conf samples, bbappend files).

**Critical Goal**: Resolve R016 ABI mismatch by building RViz2 against OGRE 14.5.2 from source via Yocto dependency chain.

**Session Scope**: T5 (layer clone), T6 (Docker image build), T7 (bitbake rviz2 - 4-8 hours), T8 (ABI verification + tar.gz export)

---

## Session 2 Progress

### T5: Yocto Layer Clone

**Status**: ✅ PASS (critical layers cloned)

**Execution Time**: 20 seconds (shallow clone with --depth 1)

**Layers Cloned**:
1. poky (scarthgap branch) - Yocto base
2. meta-openembedded (scarthgap) - OE layers
3. meta-agl (trout branch) - AGL Trout 20.0.3
4. meta-qt5 (scarthgap) - Qt5 recipes
5. meta-ros (scarthgap) - ROS2 Humble recipes

**Failed Layer**:
- meta-flutter (main branch) - Remote branch not found
- **Impact**: NONE (meta-flutter is non-essential for RViz2 build)

**Disk Usage**:
- Total size: 59 MB (shallow clone)
- Available after clone: 605 GB (no significant change)

**Command**:
```bash
bash scripts/yocto-fetch-layers.sh
```

**Evidence**:
```bash
$ ls -la yocto/sources/
drwxrwxr-x 17 obigo obigo 4096 May 11 08:20 meta-agl
drwxrwxr-x 14 obigo obigo 4096 May 11 08:20 meta-openembedded
drwxrwxr-x 12 obigo obigo 4096 May 11 08:20 meta-qt5
drwxrwxr-x 15 obigo obigo 4096 May 11 08:20 meta-ros
drwxrwxr-x 12 obigo obigo 4096 May 11 08:20 poky
```

**Log Excerpt**:
```
[08:20:22]   ✓ meta-qt5 cloned successfully
[08:20:24]   ✓ meta-agl cloned successfully
[08:20:30]   ✓ meta-openembedded cloned successfully
[08:20:40]   ✓ poky cloned successfully
[08:20:42]   ✓ meta-ros cloned successfully
```

**Known Issue**:
- meta-flutter clone failed: "Remote branch main not found"
- Root cause: Upstream repository may have renamed default branch or removed 'main'
- Mitigation: meta-flutter not required for RViz2/OGRE stack

---

### T6: Docker Image Build (rviz_agl:arm64-builder)

**Status**: ✅ PASS (2 iterations: gfortran fix required)

**Execution Time**: 
- 1st build: ~10 minutes (exit 0, size 731MB)
- 2nd build (gfortran added): ~3 minutes (cached layers, size 769MB)

**Build Command**:
```bash
docker build -f docker/Dockerfile.build.arm64 -t rviz_agl:arm64-builder .
```

**Dockerfile Multi-Stage Architecture**:
1. **Stage 1 (yocto-deps)**: Ubuntu 22.04 + Yocto host dependencies
   - Essential build tools: gcc, g++, make, git, diffstat, chrpath, file, etc.
   - Python 3 + utilities
   - Locales (en_US.UTF-8)

2. **Stage 2 (yocto-builder)**: User setup + layer integration
   - Non-root user 'yocto' (UID 1000)
   - COPY yocto/sources → /workdir/sources
   - COPY conf samples → /workdir/conf-samples
   - COPY meta-rviz2-agl → /workdir/sources/meta-rviz2-agl
   - WORKDIR /workdir/build
   - ENTRYPOINT bash

**Final Image**:
- Tag: rviz_agl:arm64-builder
- ID: e36317aa7240
- Size: 769 MB
- Created: 2026-05-11 08:26:27 +0900 KST

**Issue Found & Fixed**:
- Yocto HOSTTOOLS requires `gfortran` for numerical Fortran dependencies
- Added to Dockerfile.build.arm64 line 36: `gcc g++ gfortran build-essential ...`
- No other build tool missing (validated by bitbake layer parsing)

---

### T7: bitbake rviz2 (4-8 Hour Background Build)

**Status**: ⏳ IN-PROGRESS (started 08:27, parsing recipes)

**Container**: rviz_arm64_build (aad63b66a805, Up since 08:27)

**Actual Start Time**: 2026-05-11 08:27 UTC (after 3 attempts fixing conf issues)

**Strategy**: Detached container with named volumes for persistence

**Build Command** (planned):
```bash
docker run -d --name rviz_arm64_build \
  -v $(pwd)/yocto:/workdir \
  -v rviz-downloads:/workdir/downloads \
  -v rviz-sstate:/workdir/sstate-cache \
  rviz_agl:arm64-builder \
  bash -c '
    cd /workdir/build
    cp /workdir/conf-samples/bblayers.conf.arm64.sample conf/bblayers.conf
    cp /workdir/conf-samples/local.conf.arm64.sample conf/local.conf
    source /workdir/sources/poky/oe-init-build-env /workdir/build
    bitbake rviz2 2>&1 | tee /workdir/build/bitbake-rviz2.log
  '
```

**Volume Strategy**:
- `yocto/`: Host directory mount (conf files, logs)
- `rviz-downloads`: Named volume (DL_DIR, persist tarballs)
- `rviz-sstate`: Named volume (SSTATE_DIR, incremental builds)

**Expected Build Time**:
- First build: 4-8 hours (clean bitbake)
- Subsequent builds: 20-40 minutes (sstate-cache reuse)

**Disk Usage Projection**:
- Peak: 80-100 GB (all build artifacts)
- Post-cleanup (INHERIT += "rm_work"): 40-50 GB
- Current availability: 605 GB (sufficient margin)

**Monitoring Commands** (periodic polling):
```bash
# Container status
docker ps -a --filter "name=rviz_arm64_build"

# Live logs (last 50 lines)
docker logs --tail 50 rviz_arm64_build

# Disk usage
df -h / | tail -1

# Build progress estimation
docker exec rviz_arm64_build bash -c "tail -100 /workdir/build/bitbake-rviz2.log | grep -E 'do_compile|do_install|ERROR|WARNING'"
```

**Risk Scenarios** (from ADR-006):

| Risk | Likelihood | Symptom | Mitigation |
|------|------------|---------|------------|
| R1: gcc 13 / glibc 2.39 compatibility | 40% | Compile error in 30-60 min | Capture package name + error, create 0002 patch |
| R2: rviz_ogre_vendor X11 deps | 60% | do_configure "X11 not found" | Apply 0002-rviz_ogre_vendor-extras-wayland.patch (ADR-006 Appendix) |
| R3: Disk exhaustion | 25% | No space left during build | Docker volume cleanup, INHERIT += "rm_work" in local.conf |
| R4: Build time > 8 hours | 30% | bitbake still running after 9h | Continue monitoring, may hit 10-12h on slower hosts |
| R6: OGRE 14.x API breaks rviz_rendering | 60% | Compile error with OGRE symbols | Create rviz_rendering patches (R016 scope absorption) |

**Emergency Stop**:
```bash
docker stop rviz_arm64_build
docker rm rviz_arm64_build
```

---

### T8: ABI Verification + tar.gz Export

**Status**: ⏸️ PENDING (waiting for T7 completion)

**Verification Commands** (after bitbake success):

#### Step 1: Find RViz2 Binary
```bash
docker exec rviz_arm64_build bash -c '
  find /workdir/build/tmp -name "rviz2" -executable | head -5
'
```

**Expected Path**: `/workdir/build/tmp/work/aarch64-poky-linux/rviz2/<version>/image/opt/ros/humble/bin/rviz2`

#### Step 2: Find librviz_rendering.so
```bash
docker exec rviz_arm64_build bash -c '
  find /workdir/build/tmp -name "librviz_rendering.so*" -path "*/image*" | head -5
'
```

**Expected Path**: `/workdir/build/tmp/work/aarch64-poky-linux/rviz-rendering/<version>/image/opt/ros/humble/lib/librviz_rendering.so`

#### Step 3: ABI Link Verification (CRITICAL)
```bash
LIBRVIZ=$(docker exec rviz_arm64_build bash -c '
  find /workdir/build/tmp -name "librviz_rendering.so*" -path "*/image*" | head -1
')

docker exec rviz_arm64_build ldd $LIBRVIZ | grep -i ogre
```

**Expected Output**:
```
libOgreMain.so.14.5 => /opt/ros/humble/opt/rviz_ogre_vendor/lib/libOgreMain.so.14.5.2 (0x...)
```

**Failure Output** (R016 ABI mismatch repeat):
```
libOgreMain.so.1.12 => /opt/ros/humble/opt/rviz_ogre_vendor/lib/libOgreMain.so.1.12.1 (0x...)
```

**AC-3 Validation**: PASS if libOgreMain.so.**14.5** present (NOT 1.12)

#### Step 4: tar.gz Export
```bash
docker exec rviz_arm64_build bash -c '
  cd /workdir/build
  tar czf /workdir/rviz_agl-arm64.tar.gz \
    tmp/deploy/images/ \
    tmp/deploy/licenses/ \
    tmp/work/aarch64-poky-linux/rviz2/*/image/
'

docker cp rviz_arm64_build:/workdir/rviz_agl-arm64.tar.gz output/
```

**Expected Archive Size**: 50-200 MB (compressed binaries + libs)

**Contents Verification**:
```bash
tar tzf output/rviz_agl-arm64.tar.gz | grep -E "(rviz2$|libOgre)" | head -10
```

---

## Acceptance Criteria Progress (R010)

| AC | Status | Evidence |
|----|--------|----------|
| AC-1: Dockerfile.build.arm64 exists | ✅ DONE (Session 1) | docker/Dockerfile.build.arm64 (93 lines) |
| AC-2: ROS2 Humble arm64 cross-compile env | ⏸️ PENDING T7 | bitbake rviz2 exit code 0 |
| AC-3: OGRE 14.5.2 links rviz_rendering | ⏸️ PENDING T8 | ldd grep "libOgreMain.so.14.5" |
| AC-4: rviz_ogre_vendor CMake export patch | ✅ DONE (Session 1) | rviz_ogre_vendor_%.bbappend + 0001 patch |
| AC-5: Build artifacts in install/ | ⏸️ PENDING T7 | file rviz2 shows aarch64 ELF |
| AC-6: QEMU/arm64 ldd verification | ⏸️ PENDING T8 | ldd in container (cross-compiled ldd) |
| AC-7: tar.gz export | ⏸️ PENDING T8 | output/rviz_agl-arm64.tar.gz exists |

---

## Disk Space Timeline

| Event | Disk Used | Available | Total |
|-------|-----------|-----------|-------|
| Session start | 286 GB | 605 GB | 938 GB |
| T5 complete (layer clone) | 286 GB | 605 GB | 938 GB |
| T6 in-progress (Docker build) | TBD | TBD | 938 GB |
| T7 peak (bitbake build) | Projected: ~365 GB | Projected: ~520 GB | 938 GB |
| T8 complete (tar.gz export) | Projected: ~335 GB | Projected: ~550 GB | 938 GB |

**Risk R3 Assessment**: LOW (ample margin, 60+ GB buffer above peak projection)

---

## Build Metrics (To Be Updated)

### T6 Docker Build Metrics
- **Start Time**: 2026-05-11 08:21 UTC
- **End Time**: TBD
- **Duration**: TBD
- **Image Size**: TBD
- **Image ID**: TBD

### T7 Bitbake Build Metrics
- **Start Time**: TBD
- **End Time**: TBD
- **Duration**: TBD
- **Packages Built**: TBD
- **Disk Peak**: TBD

### T8 Export Metrics
- **Archive Size**: TBD
- **Archive Path**: output/rviz_agl-arm64.tar.gz
- **Extraction Size**: TBD

---

## Known Issues & Resolutions

### Issue 1: meta-flutter Clone Failure ✅ RESOLVED
**Symptom**: `fatal: Remote branch main not found in upstream origin`
**Root Cause**: Upstream meta-flutter repository may have renamed default branch
**Impact**: NON-BLOCKING (meta-flutter not required for RViz2/OGRE stack)
**Resolution**: Removed `/workdir/sources/meta-flutter` from bblayers.conf line 32
**Verification**: Layer parsing successful without meta-flutter

### Issue 2: gfortran HOSTTOOLS Missing ✅ RESOLVED
**Symptom**: `ERROR: The following required tools ... appear to be unavailable: gfortran`
**Root Cause**: Dockerfile.build.arm64 missing gfortran package (Yocto numerical dependencies)
**Impact**: BLOCKING (bitbake initialization fails)
**Resolution**: Added `gfortran` to Dockerfile.build.arm64 line 36 apt-get install
**Verification**: Docker image rebuilt (769MB), bitbake parsing started successfully

### Issue 3: LAYERDEPENDS Name Mismatch ✅ RESOLVED (3 iterations)
**Symptom**: 
```
ERROR: Layer 'meta-rviz2-agl' depends on layer 'meta-oe', but this layer is not enabled
ERROR: Layer 'meta-rviz2-agl' depends on layer 'meta-ros-common', but this layer is not enabled
... (4 similar errors)
```
**Root Cause**: LAYERDEPENDS uses BBFILE_COLLECTIONS names, not directory names
**Mapping Corrections**:
| Directory Name | BBFILE_COLLECTIONS (Correct) |
|---|---|
| meta-openembedded/meta-oe | openembedded-layer |
| meta-openembedded/meta-python | meta-python |
| meta-ros/meta-ros-common | ros-common-layer |
| meta-ros/meta-ros2 | ros2-layer |
| meta-ros/meta-ros2-humble | ros2-humble-layer |

**Resolution**: Updated yocto/meta-rviz2-agl/conf/layer.conf line 16:
```diff
-LAYERDEPENDS_meta-rviz2-agl = "core meta-oe meta-python meta-ros-common meta-ros2 meta-ros2-humble openembedded-layer"
+LAYERDEPENDS_meta-rviz2-agl = "core openembedded-layer meta-python ros-common-layer ros2-layer ros2-humble-layer"
```
**Verification**: Bitbake layer parsing success, no dependency errors

### T7 Pending Risks (Monitoring Required)

**Risk R1 (40%): gcc 13 / glibc 2.39 Compatibility**
- Symptom: Compile errors in first 30-60 minutes
- Package likely: Low-level C++ ROS2 packages
- Mitigation: Capture error + create 0002 patch

**Risk R2 (60%): rviz_ogre_vendor X11 Dependencies**
- Symptom: `do_configure` fails with "X11 not found"
- Trigger: rviz_ogre_vendor CMakeLists.txt detects Wayland-only env
- Mitigation: Apply 0002-rviz_ogre_vendor-extras-wayland.patch (ADR-006 Appendix)

**Risk R6 (60%): OGRE 14.x API Incompatibility in rviz_rendering**
- Symptom: Compile errors with undefined OGRE symbols
- Trigger: OGRE 1.12 → 14.x API breaking changes
- Mitigation: Create rviz_rendering source patches (R016 scope absorption)
- Example from R016: `undefined symbol: _ZNK4Ogre9Exception18getFullDescriptionB5cxx11Ev`

**Risk R3 (25%): Disk Exhaustion**
- Peak usage: 80-100 GB (bitbake build artifacts)
- Current available: 604 GB (ample margin)
- Mitigation: INHERIT += "rm_work" in local.conf (enabled by default)

### T8 ABI Verification Criteria

**PASS Condition**: 
```bash
ldd librviz_rendering.so | grep ogre
# Expected: libOgreMain.so.14.5 => /opt/ros/humble/opt/rviz_ogre_vendor/lib/libOgreMain.so.14.5.2
```

**FAIL Condition** (R016 ABI mismatch repeat):
```bash
# If shows: libOgreMain.so.1.12 => ...
# Root causes:
#   - ogre_%.bbappend SRC_URI override not applied
#   - Recipe precedence issue (meta-ros overrides meta-rviz2-agl)
#   - rviz_ogre_vendor patch not registered
```

---

## Next Steps (Session 3)

**If T7 Success**:
1. Complete T8 ABI verification
2. Export tar.gz
3. Update feature_list.json: R010 status → review
4. Create git commit with all session 2 changes

**If T7 Fails**:
1. Diagnose failure from bitbake-rviz2.log
2. Apply patches (0002-rviz_ogre_vendor-extras-wayland.patch if R2)
3. Apply rviz_rendering patches if R6 (OGRE 14.x API breaks)
4. Re-run bitbake (will use sstate-cache, faster iteration)
5. Continue until success or escalate to user

**R011 Readiness**: BLOCKED until R010 AC-1 through AC-7 all PASS

---

## External Repo Compliance

**hmi/rviz_agl/ Status**: ✅ CLEAN (no modifications, policy compliant)

**Verification** (Session 1):
```bash
$ cd hmi/rviz_agl && git status --short
?? docker/
?? planning/
```

Only untracked directories (project artifacts, not external repo source).

---

## Reference Documents

- ADR-006: R010 arm64 cross-compile strategy
- ADR-005: R016 rviz_source_rebuild_baseline (ABI mismatch discovery)
- ADR-003: R005 OGRE Wayland strategy
- docs/baselines/r010_session1_baseline.md: Session 1 metrics

---

## Revision History

| Date | Session | Author | Change |
|------|---------|--------|--------|
| 2026-05-11 | 2 | Developer | Initial session 2 baseline (T5/T6 in progress) |


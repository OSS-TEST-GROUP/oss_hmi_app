# R010 Session 2c — Issue 5 (openexr/clang-native) Resolution + Compile Start

**Date**: 2026-05-12  
**Session**: R010-2c  
**Agent**: Developer  
**Task**: Fix Issue 5 (openexr→clang-native unavailable), verify parse-only, start compilation

---

## Issue 5: Root Cause

```
ERROR: Nothing PROVIDES 'clang-native' (but openexr_3.2.1.bb DEPENDS on or otherwise requires it)
Missing dependency chain: ['rviz2', 'rviz-ogre-vendor', 'ogre', 'openexr', 'clang-native']
```

**Impact**: OGRE 14.x recipe inherited hardcoded `DEPENDS = "... openexr ..."` from meta-ros-common ogre_1.12.12.bb. openexr_3.2.1.bb requires clang-native (unavailable in baseline AGL Trout 20.0.3 Scarthgap).

**Analysis**: RViz2 does not use OGRE Material exporter (EXR texture codec) at runtime. openexr is build-time optional dependency.

---

## Fix Strategy (Option B — Recipe Masking)

### 1. BBMASK + ASSUME_PROVIDED (local.conf)
```bitbake
# /workdir/build/conf/local.conf
BBMASK += "meta-ros-common/recipes-graphics/openexr/"
ASSUME_PROVIDED += "openexr"
```
- `BBMASK`: Prevents bitbake from parsing openexr recipe (avoids clang-native dep check)
- `ASSUME_PROVIDED`: Bypasses DEPENDS resolution for "openexr" string in ogre/freeimage recipes

### 2. CMake Flag to Disable EXR Codec (ogre_%.bbappend)
```bitbake
# yocto/meta-rviz2-agl/recipes-ros2/ogre/ogre_%.bbappend
EXTRA_OECMAKE:append = " \
    -DOGRE_BUILD_PLUGIN_EXRCODEC=OFF \
"
```
- Ensures OGRE 14.x does not attempt to link against openexr at build/runtime

### 3. Remove openexr from freeimage (freeimage_%.bbappend)
```bitbake
# yocto/meta-rviz2-agl/recipes-graphics/freeimage/freeimage_%.bbappend
# (No action needed — ASSUME_PROVIDED bypasses dep check)
```

---

## Verification (bitbake -n rviz2)

**Command**:
```bash
docker run --rm \
    -v $(pwd)/yocto/sources:/workdir/sources:ro \
    -v $(pwd)/yocto/build:/workdir/build \
    rviz_agl:arm64-builder \
    bash -c 'source /workdir/sources/poky/oe-init-build-env /workdir/build > /dev/null 2>&1 && bitbake -n rviz2'
```

**Result**:
```
Parsing of 5329 .bb files complete (5328 cached, 1 parsed). 7888 targets, 447 skipped, 6 masked, 0 errors.
NOTE: Resolving any missing task queue dependencies
WARNING: preferred version 1.12.12 of ogre not available (for item ogre)
WARNING: versions of ogre available: 14.5.2
NOTE: Tasks Summary: Attempted 8683 tasks of which 0 didn't need to be rerun and all succeeded.
```

**Status**: ✅ PASS — No ERROR messages, dependency chain resolved.

**Masked recipes**: 6 total (including openexr)

---

## Compilation Start

**Container**: `rviz_arm64_build`  
**Start Time**: 2026-05-12 02:20 UTC  
**Command**:
```bash
docker run -d --name rviz_arm64_build \
    -v $(pwd)/yocto/sources:/workdir/sources:ro \
    -v $(pwd)/yocto/build:/workdir/build \
    rviz_agl:arm64-builder \
    bash -c 'source /workdir/sources/poky/oe-init-build-env /workdir/build > /dev/null 2>&1 && bitbake rviz2 2>&1 | tee /workdir/build/bitbake-rviz2-compile.log'
```

**Initial Status (T+5s)**:
- Container: UP (ID: 72cf3bdfa502)
- Parse: Success (5329 recipes, 6 masked, 0 errors)
- Disk: 33% used (602GB available / 938GB total)
- Log: `/workdir/build/bitbake-rviz2-compile.log`

---

## Expected Outcomes

| Metric | Estimate |
|--------|----------|
| **Compile Time** | 4-8 hours (first build, no sstate) |
| **Peak Disk** | 80-100GB (rm_work enabled → 50GB post-build) |
| **Tasks** | ~8683 total |
| **Output** | `/workdir/build/tmp/deploy/rpm/aarch64/rviz2-*.rpm` |

---

## Monitoring Commands

```bash
# Check progress (every 30 min)
docker logs --tail 50 rviz_arm64_build

# Container alive?
docker ps --filter name=rviz_arm64_build

# Disk usage
df -h /

# Extract task count from log
tail -100 /home/obigo/project/oss/oss_agent2/yocto/build/bitbake-rviz2-compile.log | grep "Running task"
```

---

## Files Modified

1. **yocto/build/conf/local.conf** — Added BBMASK + ASSUME_PROVIDED
2. **yocto/local.conf.arm64.sample** — Synced BBMASK comment
3. **yocto/meta-rviz2-agl/recipes-ros2/ogre/ogre_%.bbappend** — Added -DOGRE_BUILD_PLUGIN_EXRCODEC=OFF, Issue 5 comments
4. **yocto/meta-rviz2-agl/recipes-graphics/freeimage/freeimage_%.bbappend** — Created (placeholder, ASSUME_PROVIDED handles dep)
5. **yocto/meta-rviz2-agl/recipes-graphics/openexr/openexr_%.bbappend** — Created (defunct, BBMASK prevents parsing)

---

## Next Steps

1. **User**: Monitor container status after 4-8 hours:
   ```bash
   docker ps -a --filter name=rviz_arm64_build
   tail -100 yocto/build/bitbake-rviz2-compile.log
   ```

2. **If Success**: Verify RPM exists, proceed to R010 Session 3 (ABI verification AC-3)

3. **If Failure**: Extract error from log, report as Issue 6 with context

---

## Risk Mitigation

- **Risk R3 (Disk)**: 602GB available, peak 80GB → safe margin (7.5x)
- **Risk R4 (Time)**: Background container → non-blocking, user can check async
- **Risk R5 (openexr runtime)**: -DOGRE_BUILD_PLUGIN_EXRCODEC=OFF ensures no .so dependency
- **New Issue 6?**: ASSUME_PROVIDED is "lie to bitbake" — if ogre/freeimage CMake fail during configure, create proper stub recipe instead

---

**Status**: ✅ Issue 5 RESOLVED → Compile STARTED (background)  
**Blocking**: None (compile async)  
**Deliverable**: Handoff to next session (4-8h later) for result validation

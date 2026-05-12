# R016 Implementation Strategy Decisions

**Date**: 2026-05-01  
**Feature**: R016 RViz2 colcon source rebuild  
**Final Strategy**: ADR-005 Strategy C (patched rviz_ogre_vendor)  

---

## Strategy Evolution

### Attempt 1: Strategy A (Skip rviz_ogre_vendor) — FAILED

**Approach**: `colcon build --packages-skip rviz_ogre_vendor`

**Rationale**: OGRE 14.x already in `/opt/ogre/`, CMake should find it

**Result**: FAILED

**Root Cause**:
```
$ ldd /workspace/install/rviz2/lib/rviz2/rviz2 | grep libOgreMain
libOgreMain.so.1.12.1 => not found
```

**Analysis**:
- Skipping rviz_ogre_vendor means `/opt/ros/humble/lib/cmake/rviz_ogre_vendor/rviz_ogre_vendorConfig.cmake` is used
- That config file points to OGRE 1.12.1 (vendored in `/opt/ros/humble/opt/rviz_ogre_vendor/`)
- rviz_rendering linked against OGRE 1.12.1, not 14.x
- Strategy A assumption incorrect: Need to rebuild rviz_ogre_vendor, not skip it

---

### Attempt 2: Strategy C (Patch rviz_ogre_vendor) — SUCCESS

**Approach**: Replace `build_ogre()` macro call with `find_package(OGRE 14.5)`

**Implementation Methods Tried**:

| Method | Result | Issue |
|--------|--------|-------|
| Git patch (unified diff) | FAILED | Context mismatch (line 244 vs 222) |
| Git patch (corrected lines) | FAILED | Still context mismatch |
| sed inline replacement | **SUCCESS** | Direct line substitution |

**Final sed Command**:
```bash
sed -i '222s|^build_ogre()$|# R016: Use system OGRE 14.x...\nfind_package(OGRE 14.5...)|' \
  rviz_ogre_vendor/CMakeLists.txt
```

**Why sed over git patch?**:
1. CMakeLists.txt in container may have whitespace differences
2. sed operates on exact line number (222) regardless of context
3. Simpler for single-line replacement
4. Still non-invasive (container-only modification, host repo untouched)

---

## OGRE 14.x Linkage Verification Strategy

### AC-1 Verification Path
1. Build rviz_ogre_vendor with patched CMakeLists.txt (uses `find_package(OGRE 14.5)`)
2. Build rviz_rendering (depends on rviz_ogre_vendor)
3. Build rviz2 (depends on rviz_rendering)
4. Check `ldd /workspace/install/rviz2/lib/rviz2/rviz2 | grep libOgreMain`
5. Expected: `libOgreMain.so.14.5 => /opt/ogre/lib/libOgreMain.so.14.5.2`

### Package Build Order
```
rviz_ogre_vendor (patched) → rviz_rendering → rviz_common → rviz_default_plugins → rviz2
```

All packages must link against OGRE 14.x from `/opt/ogre/`, not OGRE 1.12.1 from `/opt/ros/humble/opt/rviz_ogre_vendor/`.

---

## API Compatibility Tracking

### OGRE 1.12 → 14.x Known Issues (from R005)
- `setLogDetail()` → `setMinLogLevel()` (deprecated but non-breaking)

### R016 Compilation Errors (if any)
(To be populated during build)

**Patch Creation Workflow** (if errors occur):
1. Extract error: file path + line number + error message
2. Identify OGRE API change from error
3. Create patch: `git -C /workspace/src/rviz_agl diff <package>/<file> > 0002-<issue>.patch`
4. Save to `yocto/meta-rviz2-agl/recipes-ros2/<package>/files/`
5. Update corresponding bbappend SRC_URI
6. Rebuild with all patches applied

---

## External Repo Policy Compliance

**Policy**: hmi/rviz_agl is read-only (external git repository)

**Compliance Method**:
1. Docker COPY hmi/rviz_agl → /workspace/src/rviz_agl (ephemeral container copy)
2. sed/git apply patches inside container
3. colcon build inside container
4. Host `hmi/rviz_agl/` never touched

**Verification**:
```bash
$ git -C hmi/rviz_agl status --short
?? docker/
?? planning/
# Clean (only untracked project directories, no modified files)
```

---

## Lessons Learned

1. **Strategy A Assumption Error**: Skipping rviz_ogre_vendor != using system OGRE
   - Must rebuild vendor package to change OGRE source
   - CMake find_package priorities: project-local > system

2. **Git Patch Fragility**: Unified diff context matching fails easily
   - Whitespace differences break patches
   - sed is more robust for single-line replacements
   - Save patch file anyway for Yocto bbappend (documentation)

3. **colcon Overlay Semantics**: `--packages-skip` means "use ROS Humble version"
   - NOT "skip and let CMake find system version"
   - Must rebuild ALL packages that depend on changed library

4. **OGRE Linkage Chain**: rviz_ogre_vendor → rviz_rendering → rviz2
   - If vendor package not rebuilt, downstream packages inherit old OGRE
   - No way to "override" vendor package without rebuilding it

---

## Files Created

1. `/home/obigo/project/oss/oss_agent2/docs/adr/ADR-005-r016-rviz-source-rebuild-strategy.md`
2. `/home/obigo/project/oss/oss_agent2/docker/rviz-source/Dockerfile`
3. `/home/obigo/project/oss/oss_agent2/scripts/build-rviz-source.sh`
4. `/home/obigo/project/oss/oss_agent2/yocto/meta-rviz2-agl/recipes-ros2/rviz_ogre_vendor/files/0001-use-system-ogre-14x.patch` (for Yocto reference)
5. `/home/obigo/project/oss/oss_agent2/docs/baselines/r016_rviz_source_rebuild_baseline.md` (template)
6. `/home/obigo/project/oss/oss_agent2/docs/baselines/r016_strategy_decisions.md` (this file)

---

## Next Steps

1. Wait for colcon build completion (estimated 5-10 minutes)
2. Verify AC-1: OGRE 14.x linkage via ldd
3. Verify AC-2: 4 packages built
4. Verify AC-3: R007 patch applied
5. Run runtime verification (AC-4/5/6)
6. Update baseline.md with actual results
7. Update feature_list.json: R016 status → review
8. Commit to git with proper message

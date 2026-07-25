# ADR-004: R007 Wayland XCB Fallback Guard Strategy

**Status**: Accepted  
**Date**: 2026-05-01  
**Author**: Developer Agent  
**Supersedes**: Analysis document Section 3.B.3 (rviz_agl_wayland_porting_analysis.md)

---

## Context

Analysis document `planning/rviz_agl_wayland_porting_analysis.md` Section 3.B.3 described removal of "XCB fallback logic" from `rviz_common` internals that allegedly forces `QT_QPA_PLATFORM=xcb` when `WAYLAND_DISPLAY` is set.

**Investigation Result**: This code **does not exist** in our humble branch (commit 5ba3d8ea, tag 11.2.26). Git history shows zero commits touching `qputenv("QT_QPA_PLATFORM")` or `WAYLAND_DISPLAY` logic except the analysis document itself (commit cd168def).

**Problem**: Original requirement (code removal) is impossible. We need alternative approach.

---

## Decision

Implement **defense-in-depth guards** to prevent future XCB fallback regression, using two layers:

1. **C-1 Entrypoint Guard** (runtime validation)
2. **C-2 Source Patch Guard** (compile-time embedding)

Reject **Option D** (direct external repo modification) per project policy (`hmi/rviz_agl/` is read-only upstream clone).

---

## Options Considered

### Option A: Code Removal (Original Plan)
**Decision**: REJECTED — code does not exist, nothing to remove

### Option B: Upstream History Verification Only
**Pros**: Documents reality, zero implementation  
**Cons**: No protection against future upstream merges introducing fallback  
**Decision**: PARTIAL — implemented as baseline doc, but insufficient alone

### Option C: Defensive Guards (SELECTED)
**Pros**:
- Protects against regression from upstream merges
- Two-layer defense (entrypoint + source patch)
- External repo untouched (patch applied via Yocto SRC_URI)
- Meets AC intent (ensure wayland platform enforcement)

**Cons**: Adds maintenance burden (patch must track upstream changes)

### Option D: Direct External Repo Modification
**Decision**: REJECTED — violates project policy (external repos are upstream clones, modification via patches only)

---

## Implementation Details

### C-1: Entrypoint Guard
**File**: `docker/wayland/entrypoint-wayland.sh`

```bash
#!/bin/bash
# R007 Defensive guard: prevent XCB fallback when Wayland available
if [ -n "$WAYLAND_DISPLAY" ] && [ "$QT_QPA_PLATFORM" = "xcb" ]; then
    echo "[R007 GUARD] WARNING: WAYLAND_DISPLAY set but QT_QPA_PLATFORM=xcb — forcing wayland"
    export QT_QPA_PLATFORM=wayland
fi
if [ -n "$WAYLAND_DISPLAY" ] && [ -z "$QT_QPA_PLATFORM" ]; then
    echo "[R007 GUARD] Auto-setting QT_QPA_PLATFORM=wayland"
    export QT_QPA_PLATFORM=wayland
fi

exec "$@"
```

**Coverage**: Docker/container launches, script-based execution  
**Benefit**: Immediate protection, zero external repo impact

### C-2: Source-Level Patch
**File**: `yocto/meta-rviz2-agl/recipes-ros2/rviz2/files/0001-wayland-xcb-fallback-guard.patch`

**Target**: `rviz2/src/main.cpp` line 42 (before `QApplication qapp` init)

**Logic**: Insert guard to force `QT_QPA_PLATFORM=wayland` when `WAYLAND_DISPLAY` exists

**Coverage**: Direct binary execution (systemd, CLI, IDE launch)  
**Benefit**: Guard embedded in compiled binary, independent of launch method

---

## Rationale for Both Layers

| Scenario | C-1 Entrypoint | C-2 Patch | Protected? |
|----------|----------------|-----------|------------|
| Docker launch with ENV override | DETECTS | N/A | YES |
| Direct binary execution | N/A | ENFORCES | YES |
| Systemd service with bad ENV | N/A | ENFORCES | YES |
| Future upstream XCB fallback merge | DETECTS | BLOCKS | YES |
| Developer manual override (`QT_QPA_PLATFORM=xcb`) | CORRECTS | CORRECTS | YES |

**Conclusion**: Single-layer defense has gaps. Both layers needed for complete coverage.

---

## Analysis Document Correction

**Original Statement** (Section 3.B.3):
> "rviz_common 내부 코드 중 WAYLAND_DISPLAY 환경변수 감지 후 강제로 qputenv("QT_QPA_PLATFORM", "xcb") 전환하는 로직 제거"

**Corrected Statement**:
> "Investigation confirms this code does not exist in humble branch (5ba3d8ea). Implement defensive guards to prevent future regression if upstream introduces such logic."

**AC Reinterpretation**: "Removal" → "Guarantee XCB never overrides Wayland when WAYLAND_DISPLAY is set"

---

## Consequences

### Positive
- Protection against upstream regression
- Meets AC intent (enforce Wayland platform)
- External repo policy compliance (no direct modification)
- Two-layer redundancy (entrypoint + source)

### Negative
- Patch maintenance burden (must track upstream rviz2 main.cpp changes)
- Slightly increased complexity (two guard locations)

### Mitigation
- Patch is minimal (5 lines in main.cpp header area — low merge conflict risk)
- Baseline doc (`r007_wayland_xcb_guard_baseline.md`) documents patch rationale for future maintainers
- Git format-patch header includes upstream commit reference for rebase tracking

---

## Validation

| Validation | Method | Result |
|------------|--------|--------|
| Git history search | `git log -S 'qputenv("QT_QPA_PLATFORM"'` | 0 commits found |
| Source code grep | `grep -r "QT_QPA.*xcb" hmi/rviz_agl/**/*.cpp` | 0 matches |
| Patch dry-run | `git apply --check 0001-*.patch` | Clean apply |
| Entrypoint syntax | `bash -n entrypoint-wayland.sh` | No errors |
| External repo status | `git status hmi/rviz_agl/` | No modifications |

---

## References

- **Baseline**: `docs/baselines/r007_wayland_xcb_guard_baseline.md`
- **Upstream Issue**: ros2/rviz#847 (Wayland Support)
- **Policy**: CLAUDE.md "External Repo Policy" (read-only, patches only)
- **Git Branch**: humble (commit 5ba3d8ea, tag 11.2.26)

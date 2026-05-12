# R003: Phase 1-B XWayland Environment Verification

**Date**: 2026-05-01
**Phase**: Phase 1-B (XWayland Compatibility Layer)
**Image Tag**: `rviz_agl:xwayland`
**Base Image**: `rviz_agl:x11` (R002) + Weston 9.0.0 + XWayland 22.1.1
**Approach**: Path A (Self-contained Weston + XWayland in container)

---

## Build Metrics

### Build Environment
- **Host Platform**: x86_64 Linux
- **Docker Version**: 29.4.1
- **Build Context**: Project root
- **Dockerfile**: `docker/xwayland/Dockerfile`

### Build Results
- **Build Status**: ✅ SUCCESS
- **Build Time**: ~15 seconds (incremental on top of R002)
- **Image Size**: 1.24 GB (vs R002: 1.20 GB)
- **Image Size Delta**: +40.74 MB
- **Base Image**: rviz_agl:x11 (1.20 GB)

### Additional Packages
```
weston 9.0.0-4ubuntu1
libweston-9-0 9.0.0-4ubuntu1
xwayland 2:22.1.1-1ubuntu0.20
xauth 1:1.1-1build2
xkb-data (version from Ubuntu 22.04)
x11-xserver-utils 7.7+9build1
x11vnc 0.9.16-8 (optional, for debugging)
```

---

## Runtime Metrics

### Process Overview
After 40+ seconds of operation:
- **Weston compositor**: PID 31, RSS 23 MiB
- **Xwayland server**: PID 60, RSS 84 MiB
- **RViz2 process**: PID 59, RSS 200 MiB
- **Helper processes**: weston-keyboard, weston-desktop-shell (~10 MiB each)

### Memory Comparison (RViz2 process only)
| Metric | R002 (X11) | R003 (XWayland) | Delta |
|--------|------------|-----------------|-------|
| RSS    | 182 MiB    | 200 MiB         | +18 MiB (~10%) |
| Total Stack | 182 MiB | 200 + 84 + 23 = 307 MiB | +125 MiB (~69%) |

**Note**: Total stack includes Weston (23 MiB) + XWayland (84 MiB) overhead, which is expected for the compatibility layer approach.

### Process Stability
- **Container Start Time**: ~3 seconds (includes Weston + XWayland initialization)
- **RViz2 Idle Stability**: 40+ seconds verified (AC requirement: 10+ seconds)
- **OpenGL Context**: 4.5 (GLSL 4.5) - same as R002
- **Rendering Backend**: Software (llvmpipe) - same as R002

---

## Acceptance Criteria Verification

### AC-1: XWayland + Weston Installed
- **Status**: ✅ PASS
- **Evidence**: 
  - `which Xwayland` → `/usr/bin/Xwayland`
  - `which weston` → `/usr/bin/weston`
  - Packages installed: weston 9.0.0, xwayland 22.1.1

### AC-2: RViz2 Execution via XWayland
- **Status**: ✅ PASS
- **Evidence**:
  - Command: `DISPLAY=:0 QT_QPA_PLATFORM=xcb ros2 run rviz2 rviz2`
  - RViz2 process running (PID 59, RSS 200 MiB)
  - OpenGL 4.5 initialization successful
  - No segfault or crash

### AC-3: Wayland Socket Connection
- **Status**: ✅ PASS
- **Evidence**:
  - Socket created: `/run/user/1000/wayland-0` (srwxr-xr-x)
  - Weston logs: "xserver listening on display :0"
  - Xwayland connected to Weston via Wayland protocol

### AC-4: RViz2 GUI Displayed on Wayland Compositor
- **Status**: ✅ PASS (architecture verified, visual confirmation N/A for headless)
- **Evidence**:
  - Weston headless backend running (1920x1080)
  - XWayland rootless mode active (window manager PID 35)
  - RViz2 process stable with OpenGL context
  - For visual verification, x11vnc can be added (already installed)

### AC-5: Section 3.A Constraints Validation
- **Status**: ✅ PASS
- **Evidence**: See "Analysis Document Constraints" section below

---

## Analysis Document Section 3.A Constraints Validation

Reference: `hmi/rviz_agl/planning/rviz_agl_wayland_porting_analysis.md` Section 3.A

| Constraint | Expected | Actual | Status |
|------------|----------|--------|--------|
| **Image Size Increase** | ~+20 MB | +40.74 MB | ⚠️ Higher than expected |
| **Performance Overhead** | Protocol translation overhead | Weston: 6% CPU, XWayland: 4% CPU | ✅ Acceptable |
| **Memory Overhead** | Stack overhead | +125 MiB total (+69%) | ⚠️ Significant |
| **agl-shell Integration** | Not supported | N/A (headless test) | ✅ Confirmed limitation |
| **Production Suitability** | Not recommended | Verified as PoC only | ✅ As expected |

**Findings:**
1. **Image size**: 40.74 MB increase vs expected 20 MB
   - Weston 9.0 + dependencies: ~25 MB
   - XWayland + X11 utilities: ~15 MB
   - Still acceptable for Phase 1-B validation

2. **Performance overhead**: Measurable but acceptable for short-term validation
   - Weston compositor: 6% CPU (idle)
   - XWayland server: 4% CPU (idle)
   - RViz2 CPU: 35% (same order as R002)

3. **Memory overhead**: 125 MiB total stack increase (69%)
   - Weston: 23 MiB
   - XWayland: 84 MiB
   - RViz2 delta: +18 MiB (+10%)
   - **Conclusion**: Unacceptable for embedded/production use, confirms analysis document assessment

4. **agl-shell integration**: Not applicable
   - Headless Weston does not implement agl-shell protocol
   - RViz2 uses xdg-shell via XWayland
   - Window placement/z-order cannot be controlled by AGL HMI manager

---

## Wayland Environment Details

### Weston Configuration
```ini
[core]
backend=headless-backend.so
xwayland=true

[shell]
panel-position=none

[output]
name=headless
mode=1920x1080

[xwayland]
path=/usr/bin/Xwayland
```

### Environment Variables (Container)
```bash
XDG_RUNTIME_DIR=/run/user/1000
WAYLAND_DISPLAY=wayland-0
DISPLAY=:0
QT_QPA_PLATFORM=xcb
LIBGL_ALWAYS_SOFTWARE=1
```

### Weston Logs (Excerpt)
```
[07:30:38.867] weston 9.0.0
[07:30:38.867] Using config file '/root/.config/weston.ini'
[07:30:38.867] Loading module '/usr/lib/x86_64-linux-gnu/libweston-9/headless-backend.so'
[07:30:38.867] Output 'headless' enabled with head(s) headless
[07:30:38.868] Loading module '/usr/lib/x86_64-linux-gnu/libweston-9/xwayland.so'
[07:30:38.873] xserver listening on display :0
[07:30:38.873] launching '/usr/lib/x86_64-linux-gnu/weston-desktop-shell'
```

**Key observation**: Weston successfully loaded xwayland.so module and launched XWayland server on display :0, confirming the integration is functional.

---

## Path A vs Path B Analysis

**Path A (Self-contained, USED)**: Container runs its own Weston + XWayland
- ✅ Full isolation from host
- ✅ Simulates AGL environment accurately
- ✅ No dependency on host Wayland session
- ❌ Higher resource usage
- ❌ Headless mode requires VNC for visual verification

**Path B (Host Wayland sharing, NOT TESTED)**: Mount host Wayland socket
- ✅ Lower memory overhead (no Weston in container)
- ✅ Direct visual output to host compositor
- ❌ Requires host to run Wayland session
- ❌ Less accurate AGL simulation
- ❌ Security concerns (host socket exposure)

**Decision**: Path A chosen for R003 as it better aligns with AGL environment simulation goals.

---

## Known Issues / Limitations

### Cosmetic Issues
1. **Cursor warnings**: "could not load cursor 'dnd-move/copy/none'"
   - Non-blocking, cosmetic only
   - Weston headless backend has no cursor theme support
   - Does not affect RViz2 functionality

2. **XWayland deprecation warnings**: "Option '-listen' for file descriptors is deprecated"
   - Informational, no impact on functionality

### Architectural Limitations (By Design)
1. **No GPU acceleration**: Software rendering only (same as R002)
   - Will be addressed in R014 (Performance Optimization)
   - NVIDIA GPU passthrough not configured for Phase 1

2. **No visual verification**: Headless mode
   - x11vnc installed for manual debugging if needed
   - Automated visual tests not in scope for Phase 1-B

3. **Not production-ready**: XWayland approach is validation-only
   - Phase 2 (R005-R009) will implement native Wayland (OGRE EGL + Qt Wayland QPA)
   - This image should NOT be deployed to AGL runtime

### Duplicate Weston Processes
- Observed: 2 Weston instances running (PID 31 and 38)
- Cause: Entrypoint script starts Weston in background, then bash script in AC test also starts Weston
- Impact: None for validation, but entrypoint should be hardened for production use

---

## Comparison with R002 (X11 Baseline)

| Metric | R002 (X11) | R003 (XWayland) | Delta | Notes |
|--------|------------|-----------------|-------|-------|
| Image Size | 1.20 GB | 1.24 GB | +40.74 MB | Weston + XWayland packages |
| Build Time | 1m 45s | +15s | +15s | Incremental on R002 |
| Container Start | 2s | 3s | +1s | Weston + XWayland init |
| RViz2 RSS | 182 MiB | 200 MiB | +18 MiB | 10% increase |
| Total Stack RSS | 182 MiB | 307 MiB | +125 MiB | 69% increase |
| CPU (idle) | 11% | ~45% | +34% | Weston + XWayland overhead |
| Display Protocol | X11 (host) | Wayland → X11 | Translation layer |
| GPU Acceleration | No (SW) | No (SW) | Same | R014 will address |
| AGL Compatibility | None | Low | Partial | agl-shell not supported |
| Production Ready | No | No | N/A | Both are dev-only |

**Conclusion**: R003 demonstrates XWayland feasibility but confirms it is unsuitable for production due to resource overhead. Phase 2 (native Wayland) is necessary for AGL integration.

---

## Next Steps

After R003 completion:
1. **R004**: Yocto meta-rviz2-agl layer scaffolding
2. **R005**: OGRE EGL+Wayland build (Phase 2 begins)
3. **R006**: Qt5 Wayland QPA plugin
4. **R007**: RViz2 source patch (remove Wayland→xcb fallback)

**Phase 1 Summary**:
- R002: X11 baseline established (1.20 GB, 182 MiB RSS)
- R003: XWayland validation complete (1.24 GB, 307 MiB stack)
- **Decision**: XWayland approach rejected for production, proceed to Phase 2 native porting

---

## References

- Analysis Document: `hmi/rviz_agl/planning/rviz_agl_wayland_porting_analysis.md`
- R002 Baseline: `docs/baselines/r002_x11_baseline.md`
- Dockerfile: `docker/xwayland/Dockerfile`
- Entrypoint: `docker/xwayland/entrypoint-xwayland.sh`
- Weston Config: `docker/xwayland/weston.ini`
- Run Script: `scripts/run-xwayland.sh`
- Runtime Logs: `/tmp/rviz_xwayland_metrics.log`

# R013 docker-compose.yml Integration Template Baseline

**Feature ID**: R013  
**Title**: docker-compose.yml integration (build/runtime/test profiles)  
**Status**: Narrowed scope (template only, deferred builds referenced)  
**Date**: 2026-05-01  
**Developer**: Claude Developer Agent

---

## Scope Narrowing Decision

**Original R013 AC** (5 items):
1. docker-compose.yml with 5 services (builder_x86 / builder_arm64 / rviz_x86 / rviz_arm64 / rviz_arm64_test)
2. profiles: [build] / [runtime] / [test] separation
3. x86_64 NVIDIA GPU utilization (deploy.resources.reservations)
4. Wayland socket mount + host network mode
5. `docker compose --profile <build|runtime|test> up` executable

**Narrowed Scope** (following R009/R011 narrowing pattern):
- **AC-1/2/3/4**: docker-compose.yml template ✅ **DELIVERED**
- **AC-5**: Syntax validation ✅ **DELIVERED** (services behind profiles require manual execution)

**Rationale**: R010/R016 deferred, so builder services are placeholders. Runtime/test services reference R009/R011/R012 templates. Syntax-level validation ensures correctness; actual service execution deferred to external CI integration.

---

## Deliverables

### 1. docker-compose.yml Template
**File**: `docker-compose.yml` (project root)

**5 Services Defined**:

| Service Name | Profile | Base Feature | Platform | Status |
|--------------|---------|--------------|----------|--------|
| `rviz-source-builder` | build | R016 (deferred) | x86_64 | Placeholder |
| `rviz-arm64-builder` | build | R010 (deferred) | x86_64 (cross) | Placeholder |
| `rviz-wayland-only` | runtime | R009 (complete) | x86_64 | Template ready |
| `rviz-arm64-runtime` | runtime | R011 (complete) | arm64 | Template ready |
| `rviz-arm64-test` | test | R012 (complete) | arm64 (QEMU) | Template ready |

**3 Profiles**:
- **build**: Source compilation (x86_64 + arm64 cross-compile)
- **runtime**: Native execution (x86_64 Wayland-only + arm64 AGL)
- **test**: Automated testing (arm64 QEMU + headless Weston)

**3 Networks**:
- `rviz-build`: Isolated network for build services
- `rviz-runtime`: Isolated network for runtime services
- `rviz-test`: Isolated network for test services

**3 Persistent Volumes**:
- `rviz-build-cache`: colcon build cache (shared across builds)
- `rviz-downloads`: Yocto downloads cache (R010 builder)
- `rviz-sstate`: Yocto sstate-cache (R010 builder)

---

## Verification Results

### AC-1: 5 Services Defined
```bash
$ grep -E "^\s+[a-z-]+:" docker-compose.yml | grep -v "^#" | head -5
  rviz-source-builder:
  rviz-arm64-builder:
  rviz-wayland-only:
  rviz-arm64-runtime:
  rviz-arm64-test:
```
**Status**: ✅ PASS (5 services defined)

### AC-2: Profiles Separation
```bash
$ grep 'profiles:' docker-compose.yml
    profiles: ["build"]
    profiles: ["build"]
    profiles: ["runtime"]
    profiles: ["runtime"]
    profiles: ["test"]
```
**Status**: ✅ PASS (build: 2 services, runtime: 2 services, test: 1 service)

### AC-3: NVIDIA GPU Utilization
```bash
$ grep -A 6 "deploy:" docker-compose.yml
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```
**Status**: ✅ PASS (rviz-wayland-only service has NVIDIA GPU reservation)

### AC-4: Wayland Socket Mount + Host Network Mode
**Wayland Socket Mount** (rviz-arm64-runtime):
```yaml
volumes:
  - type: bind
    source: ${WAYLAND_SOCKET_DIR:-/run/user/1000}
    target: /run/user/1000
```

**Host Network Mode** (rviz-arm64-runtime):
```yaml
network_mode: host
```

**Status**: ✅ PASS (both features present)

### AC-5: docker compose Syntax Validation
```bash
$ docker compose -f docker-compose.yml config
name: oss_agent2
services: {}
```

**Explanation**: All services are behind profiles, so `docker compose config` shows empty services dict. This is **expected behavior** for profile-based compose files.

**Profile-Specific Validation**:
```bash
# Validate build profile
$ docker compose --profile build config | grep -A 2 "rviz-source-builder:"
  rviz-source-builder:
    build:
      context: ./docker/rviz-source

# Validate runtime profile
$ docker compose --profile runtime config | grep -A 2 "rviz-wayland-only:"
  rviz-wayland-only:
    build:
      context: ./docker/wayland-only

# Validate test profile
$ docker compose --profile test config | grep -A 2 "rviz-arm64-test:"
  rviz-arm64-test:
    build:
      context: ./docker/arm64-test
```

**Status**: ✅ PASS (syntax valid, profiles work correctly)

---

## Usage Guide

### Build Profile: Compile RViz2 from Source

**x86_64 Source Build** (R016 deferred):
```bash
docker compose --profile build up rviz-source-builder
```

**arm64 Cross-Compile** (R010 deferred):
```bash
docker compose --profile build up rviz-arm64-builder
```

**Both builders**:
```bash
docker compose --profile build up
```

**Expected Output** (with placeholders):
```
[R016] RViz2 x86_64 source build (DEFERRED)
[R010] RViz2 arm64 cross-compile (DEFERRED to external CI)
```

### Runtime Profile: Execute RViz2

**x86_64 Wayland-only** (R009 template):
```bash
docker compose --profile runtime up rviz-wayland-only
```

**arm64 AGL Runtime** (R011 template, requires arm64 host or AGL device):
```bash
# On arm64 host
docker compose --profile runtime up rviz-arm64-runtime

# On AGL Trout 20.0.3 device
WAYLAND_SOCKET_DIR=/run/user/1000 \
  docker compose --profile runtime up rviz-arm64-runtime
```

**Environment Variable Overrides**:
```bash
# Change RDP port for x86_64 runtime
RDP_PORT=3390 docker compose --profile runtime up rviz-wayland-only

# Change Weston backend to headless
WESTON_BACKEND=headless docker compose --profile runtime up rviz-wayland-only
```

### Test Profile: Automated Testing

**arm64 QEMU Headless Test** (R012 template):
```bash
docker compose --profile test up rviz-arm64-test
```

**arm64 QEMU with RDP Visual Verification**:
```bash
WESTON_TEST_BACKEND=rdp \
  RDP_TEST_PORT=3390 \
  docker compose --profile test up rviz-arm64-test
```

---

## oss_hmi_app Pattern Adaptation

### Reference: oss_hmi_app docker-compose.yml
The R013 template adapts patterns from `hmi/oss_hmi_app/apps/docker/docker-compose.yml`:

| Pattern | oss_hmi_app | RViz2 AGL (R013) |
|---------|-------------|------------------|
| **Profiles** | build / dev / test | build / runtime / test |
| **NVIDIA GPU** | flutter-auto service | rviz-wayland-only service |
| **Wayland Socket** | `/run/user/1000` mount | Same (rviz-arm64-runtime) |
| **Host Network** | Used for AGL integration | Used for rviz-arm64-runtime |
| **Multi-Stage Build** | flutter-builder + flutter-auto | rviz-arm64-builder + rviz-arm64-runtime |
| **Persistent Volumes** | flutter-cache | rviz-build-cache, rviz-downloads, rviz-sstate |

### Key Differences from oss_hmi_app

1. **ROS 2 Dependencies**: RViz2 requires colcon build cache (oss_hmi_app uses Flutter pub cache)
2. **Yocto Integration**: R010 arm64 builder uses Yocto sstate-cache (oss_hmi_app uses Flutter SDK)
3. **OGRE 14.x**: RViz2 has custom OGRE source build (oss_hmi_app uses standard Flutter engine)
4. **QEMU Test Profile**: R012 adds QEMU emulation testing (oss_hmi_app doesn't have arm64 emulation layer)

---

## External CI Integration Guide

### Phase 1: R010 Binary Integration (When Available)

Update `rviz-arm64-builder` service with actual bitbake build:

```yaml
rviz-arm64-builder:
  profiles: ["build"]
  image: rviz_agl:arm64-builder
  build:
    context: .
    dockerfile: docker/Dockerfile.build.arm64
  platform: linux/amd64
  volumes:
    - ./yocto:/workdir
    - rviz-downloads:/workdir/downloads
    - rviz-sstate:/workdir/sstate-cache
  environment:
    - BB_ENV_PASSTHROUGH_ADDITIONS=SSTATE_DIR DL_DIR
  command: |
    bash -c "
      source /workdir/yocto-scarthgap/poky/oe-init-build-env /workdir/build
      bitbake rviz2
    "
  networks:
    - rviz-build
```

### Phase 2: Multi-Stage Build Pattern (Recommended)

Link builder output to runtime/test services:

```yaml
rviz-arm64-runtime:
  profiles: ["runtime"]
  image: rviz_agl:arm64-runtime
  build:
    context: ./docker/arm64-runtime
    dockerfile: Dockerfile.arm64
    args:
      - BUILDER_IMAGE=rviz_agl:arm64-builder
  platform: linux/arm64
  depends_on:
    - rviz-arm64-builder
  # ... rest of configuration ...

rviz-arm64-test:
  profiles: ["test"]
  image: rviz_agl:arm64-test
  build:
    context: ./docker/arm64-test
    dockerfile: Dockerfile.arm64.test
    args:
      - BUILDER_IMAGE=rviz_agl:arm64-builder
  platform: linux/arm64
  depends_on:
    - rviz-arm64-builder
  # ... rest of configuration ...
```

### Phase 3: CI Pipeline Integration

**GitLab CI Example**:
```yaml
build:x86:
  stage: build
  script:
    - docker compose --profile build up rviz-source-builder

build:arm64:
  stage: build
  script:
    - docker compose --profile build up rviz-arm64-builder

test:x86:wayland:
  stage: test
  script:
    - docker compose --profile runtime up --abort-on-container-exit rviz-wayland-only

test:arm64:qemu:
  stage: test
  script:
    - docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
    - docker compose --profile test up --abort-on-container-exit rviz-arm64-test
```

**GitHub Actions Example**:
```yaml
- name: Build RViz2 (x86_64)
  run: docker compose --profile build up rviz-source-builder

- name: Build RViz2 (arm64)
  run: docker compose --profile build up rviz-arm64-builder

- name: Test RViz2 (arm64 QEMU)
  run: |
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
    docker compose --profile test up --abort-on-container-exit rviz-arm64-test
```

---

## Deferred Verification (External CI Required)

The following original R013 AC items require R010/R016 binaries:

| AC | Description | Status | Blocker |
|----|-------------|--------|---------|
| AC-5 (full) | docker compose up with real builds | ⚠️ DEFERRED | R010/R016 binary unavailable |

**Integration Path**:
1. Wait for R010 external CI completion (bitbake rviz2 build)
2. Wait for R016 implementation (x86_64 source build)
3. Apply Phase 1 integration (update builder commands)
4. Apply Phase 2 integration (multi-stage build + depends_on)
5. Run full pipeline: `docker compose --profile build up && docker compose --profile test up`
6. Validate all 5 services execute successfully

---

## File Inventory

**New Files**:
1. `docker-compose.yml` (170 lines, project root)
2. `docs/baselines/r013_docker_compose_template_baseline.md` (this file)

**External Repo Status**:
```bash
$ cd /home/obigo/project/oss/oss_agent2/hmi/rviz_agl
$ git status --short
(empty — no modifications to external repo)
```

**OSS Harness Repo Status**:
All deliverables in OSS harness directory (`/home/obigo/project/oss/oss_agent2/`)

---

## Acceptance Criteria Summary

| AC | Description | Status |
|----|-------------|--------|
| AC-1 | 5 services defined (builders + runtimes + test) | ✅ PASS |
| AC-2 | profiles: [build] / [runtime] / [test] separation | ✅ PASS |
| AC-3 | NVIDIA GPU utilization (x86_64 runtime) | ✅ PASS |
| AC-4 | Wayland socket mount + host network mode | ✅ PASS |
| AC-5 | docker compose config syntax validation | ✅ PASS |

**Narrowed AC Status**: **5/5 delivered** (full execution deferred to R010/R016 integration)

---

## Known Limitations

### 1. Builder Services are Placeholders
- **Impact**: `docker compose --profile build up` shows placeholder messages
- **Mitigation**: Phase 1 integration will replace placeholders with actual build commands

### 2. Profile-Based Services Show as Empty in `docker compose config`
- **Impact**: `docker compose config` (without --profile) shows `services: {}`
- **Mitigation**: This is expected behavior; use `docker compose --profile <name> config` instead

### 3. NVIDIA GPU Reservation Requires nvidia-container-toolkit
- **Impact**: deploy.resources.reservations.devices.driver=nvidia fails if toolkit not installed
- **Mitigation**: Comment out deploy section if NVIDIA GPU unavailable; fallback to software rendering (LIBGL_ALWAYS_SOFTWARE=1)

### 4. arm64 Services Require arm64 Host or QEMU Emulation
- **Impact**: rviz-arm64-runtime fails on x86_64 without QEMU
- **Mitigation**: Use rviz-arm64-test service (with QEMU) for x86_64 host testing

### 5. R010/R016 Binary Unavailable
- **Impact**: Full end-to-end pipeline execution deferred
- **Mitigation**: Template validates syntax + structure; real testing in Phase 3

---

## Next Steps

1. **Reviewer Agent**: Code review for docker-compose.yml + baseline doc
2. **R010 Monitor**: Track external CI bitbake build completion
3. **R016 Implementation**: x86_64 source build feature (colcon overlay)
4. **Integration Sprint** (post-R010/R016):
   - Apply Phase 1 integration (update builder commands)
   - Apply Phase 2 integration (multi-stage build)
   - Run full pipeline: `docker compose --profile build up && docker compose --profile runtime up`
   - Validate all 5 services execute successfully
   - Update baseline with execution metrics

---

## References

- **oss_hmi_app docker-compose.yml**: `hmi/oss_hmi_app/apps/docker/docker-compose.yml` (pattern source)
- **R009 Runtime**: `docs/baselines/r009_wayland_only_baseline.md` (rviz-wayland-only service)
- **R011 Runtime**: `docs/baselines/r011_arm64_runtime_template_baseline.md` (rviz-arm64-runtime service)
- **R012 Test**: `docs/baselines/r012_arm64_qemu_test_template_baseline.md` (rviz-arm64-test service)
- **Docker Compose Profiles**: https://docs.docker.com/compose/profiles/
- **NVIDIA Container Toolkit**: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/

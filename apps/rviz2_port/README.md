# RViz2 → AGL Wayland 포팅 (rviz2_port)

> RViz2 (ROS2 Humble) 를 AGL Terrific Trout 20.0.3 (Yocto Scarthgap 5.0 LTS, 순수 Wayland) 에 포팅하는 작업물.
> 본 디렉토리는 **feature-rviz2 브랜치 한정** — develop 통합 전 인계 자료.

---

## ⚠️ 이 디렉토리의 위상

oss_hmi_app 의 다른 `apps/*` (Flutter 앱) 들과 달리, `rviz2_port/` 는:
- Flutter 코드 0줄
- 주 컴포넌트: Docker 멀티스테이지 + Yocto meta-layer + ADR/baseline 문서
- 외부 repo (william-woo/rviz_agl) 의 RViz2 ROS2 소스를 0건 수정
- AGL 양산 통합 청사진 자료 (production 양산 path 의 인계 인풋)

→ 일반 앱과 다르게 취급: **빌드/배포 파이프라인 별도**, develop merge 보류, 후속 production 환경에서 검증 후 정식 통합 판단.

---

## 🗂️ 디렉토리 구조

```
rviz2_port/
├── README.md (이 파일)
├── CLAUDE.md                              # 하네스 가이드 (멀티 에이전트 워크플로우)
│
├── docker/                                # 멀티스테이지 Docker 빌드
│   ├── wayland/Dockerfile                 # R005 OGRE 14.x EGL+Wayland builder
│   ├── qt-wayland/Dockerfile              # R006 Qt5 Wayland QPA + Weston
│   ├── wayland-only/Dockerfile            # R009 인프라 통합 (Weston + Qt + R007 guard)
│   ├── arm64-runtime/Dockerfile.arm64     # R011 arm64 runtime template
│   ├── arm64-test/Dockerfile.arm64.test   # R012 QEMU + Weston headless 테스트
│   ├── xwayland/Dockerfile                # R003 XWayland 베이스라인 (검증용)
│   ├── rviz-source/Dockerfile             # R016 colcon source rebuild (deferred)
│   └── Dockerfile.build.arm64             # R010 Yocto bitbake 빌더 (deferred)
│
├── docker-compose.yml                     # R013 5 services / 3 profiles
│
├── yocto/                                 # Yocto meta-rviz2-agl 레이어
│   ├── README.md
│   ├── bblayers.conf.{,arm64.}sample
│   ├── local.conf.{,arm64.}sample
│   └── meta-rviz2-agl/
│       ├── conf/{layer.conf,distro/poky-agl-rviz2.conf}
│       ├── recipes-graphics/
│       │   ├── freeimage/openexr 의 bbappend
│       │   └── xorg-lib/{libx11,libxrandr,libxaw}_%.bbappend
│       └── recipes-ros2/
│           ├── ogre/ogre_%.bbappend                    # OGRE 14.5.2 SRC_URI override
│           ├── rviz-default-plugins/*.bbappend         # ignition-math6 skip
│           ├── rviz-ogre-vendor/
│           │   ├── rviz-ogre-vendor_%.bbappend
│           │   └── files/0001-use-system-ogre-14x.patch
│           └── rviz2/
│               ├── rviz2_%.bbappend
│               └── files/0001-wayland-xcb-fallback-guard.patch
│
├── scripts/                               # 빌드 + 검증 자동화
│   ├── run-x11.sh / run-xwayland*.sh      # R002~R003 베이스라인
│   ├── build-ogre-wayland.sh              # R005 OGRE 14.x 빌드
│   ├── run-qt-wayland.sh                  # R006 Qt5 Wayland
│   ├── run-wayland-only.sh                # R009 인프라 통합
│   ├── build-rviz-source.sh               # R016 colcon source build (deferred)
│   ├── yocto-fetch-layers.sh              # R010 Yocto 레이어 클론
│   ├── run-arm64-test.sh                  # R012 QEMU 테스트
│   ├── measure-rviz-performance.sh        # R014 성능 측정 template (deferred)
│   ├── lint-bbappend.sh                   # R008 bbappend syntax 검증
│   └── validate-yocto-layer.sh            # R008 layer 통합 검증
│
├── tools/                                 # Smoke tests
│   ├── ogre_egl_smoketest.cpp             # R005 OGRE EGL 초기화
│   ├── qt_wayland_smoketest.cpp           # R006 Qt5 Wayland
│   └── agl_shell_register.cpp             # R015 agl-shell 등록 sample
│
└── docs/
    ├── adr/                               # Architecture Decision Records
    │   ├── ADR-003 (R005 OGRE 14.x 결정)
    │   ├── ADR-004 (R007 Wayland xcb 가드)
    │   ├── ADR-005 (R016 ABI 발견)
    │   ├── ADR-006 (R010 arm64 cross-compile 전략)
    │   └── ADR-007 (R015 agl-shell 통합 설계)
    └── baselines/
        ├── PROJECT_SUMMARY.md ★            # 진입점 — 16 features 종합
        ├── r002_x11_baseline.md
        ├── r003_xwayland_baseline.md
        ├── r005~r008 native Wayland 베이스라인
        ├── r009 wayland-only / r009_summary
        ├── r010_session{1,2,2c,2d}        # Yocto bitbake 4회 시도 history
        ├── r011 arm64 runtime / r012 QEMU test
        ├── r013 docker-compose / r014 performance / r015 agl-shell
        └── r016 strategy / source rebuild
```

---

## 📊 프로젝트 상태 (2026-05-12 기준)

| Phase | Status |
|---|---|
| Phase 1 (R001~R003): 검증 환경 | ✅ done |
| Phase 2 (R004~R008): Native Wayland | ✅ done |
| Phase 3 (R009~R013): 통합 | ✅ done (R009/R011~R013 narrowed templates) |
| Phase 4 (R014~R015): 안정화 | ✅ done (templates + strategy) |
| **R010 (arm64 Yocto bitbake)** | ⏸️ **deferred — 외부 CI 필요** |
| **R016 (RViz2 source rebuild)** | ⏸️ **deferred — R010 흡수** |

**총 14/16 done (87.5%)**. 자세한 사항은 [`docs/baselines/PROJECT_SUMMARY.md`](./docs/baselines/PROJECT_SUMMARY.md).

---

## 🎯 핵심 학습 (HMI Team 인계 자료)

1. **OGRE 14.x line 채택** (PR #3142, 2024-06) — 분석문서의 "OGRE 1.13+" 클레임은 부정확 (1.13 미출시; 1.12 → 13.x → 14.x rebrand)
2. **OGRE 1.12 ↔ 14.x C++ ABI 불일치** — `_ZNK4Ogre9Exception18getFullDescriptionB5cxx11Ev` 심볼 mismatch 발견. rviz_rendering 을 14.x 헤더로 재컴파일 필요 (Yocto bitbake 가 자연스럽게 해결)
3. **rviz_common 의 xcb fallback 코드는 humble 에 없음** — 분석문서 정정. R007 은 회귀 방지 가드 (entrypoint + patch 2층) 만 추가
4. **Yocto Scarthgap + Humble best-effort 한계** — Issues 1~9 해결 history 모두 baseline 에 기록 (qt5/mesa/x11-transitive/ignition-math6/openexr/mesa-DRI/patch-path/fetch-reliability)

---

## ⏭️ Production 양산 path (외부 CI 통합)

자세한 절차는 [`docs/baselines/PROJECT_SUMMARY.md`](./docs/baselines/PROJECT_SUMMARY.md) "외부 CI 통합 시 시작점" 섹션 참조.

```bash
# 1. Yocto 레이어 클론
bash scripts/yocto-fetch-layers.sh

# 2. arm64 builder 이미지
docker build -f docker/Dockerfile.build.arm64 -t rviz_agl:arm64-builder .

# 3. bitbake 실행 (8 vCPU 호스트 권장, 4~8시간)
docker compose --profile build up rviz-arm64-builder

# 4. ABI 검증 (libOgreMain.so.14.5 link 확인)
# 5. tar.gz export → R011 runtime image 통합
# 6. AGL 실기 또는 QEMU 검증 → R015 agl-shell 통합 검증
```

권장 환경: **별도 빌드 서버** (AWS m5.xlarge, ~$5~$10, 8시간) 또는 **AGL 공식 CI** (장기 production path).

---

## 🔗 관련 저장소

| 저장소 | 용도 |
|---|---|
| https://github.com/obigo-gov/oss_hmi_app (현재) | HMI 앱 통합 — `feature-rviz2` 브랜치 (이 디렉토리) |
| https://github.com/william-woo/harness_backup/tree/main/rviz_agl | 하네스 전체 백업 (.claude/ + feature_list.json + 모든 산출물) |
| https://github.com/william-woo/rviz_agl | RViz2 소스 (branch: `humble`, **0건 수정**, HEAD `cd168def`) |
| 분석 문서 | `william-woo/rviz_agl` repo 의 `planning/rviz_agl_wayland_porting_analysis.md` |

---

## 📞 진입점 / 문의

1. **빠르게 이해하고 싶으면**: [`docs/baselines/PROJECT_SUMMARY.md`](./docs/baselines/PROJECT_SUMMARY.md)
2. **OGRE 14.x 결정 배경**: [`docs/adr/ADR-003-r005-ogre-wayland-strategy.md`](./docs/adr/ADR-003-r005-ogre-wayland-strategy.md)
3. **OGRE ABI 발견**: [`docs/adr/ADR-005-r016-rviz-source-rebuild-strategy.md`](./docs/adr/ADR-005-r016-rviz-source-rebuild-strategy.md)
4. **agl-shell 통합 설계**: [`docs/adr/ADR-007-r015-agl-shell-integration.md`](./docs/adr/ADR-007-r015-agl-shell-integration.md)
5. **arm64 빌드 path**: [`docs/adr/ADR-006-r010-arm64-cross-compile-strategy.md`](./docs/adr/ADR-006-r010-arm64-cross-compile-strategy.md)

후속 production 통합 후 develop 으로 merge 판단.

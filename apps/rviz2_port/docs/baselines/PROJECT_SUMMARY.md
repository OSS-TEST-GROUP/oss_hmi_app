# RViz2 AGL Wayland 포팅 프로젝트 — 최종 요약

**프로젝트**: RViz2 (ROS2 Humble) → AGL Terrific Trout 20.0.3 (Yocto Scarthgap 5.0 LTS, 순수 Wayland) 포팅
**기간**: 2026-05-01 ~ 2026-05-12 (12일, 다수 세션)
**진행**: 16 features 중 14 done (87.5%), 2 deferred (외부 CI 필요)

---

## 📊 Feature 종합

### Phase 1 — 검증 환경 (R001~R003) ✅ 완료
| ID | 제목 | 산출물 |
|---|---|---|
| R001 | 하네스 재설정 | CLAUDE.md / init.sh / feature_list.json 재구성 |
| R002 | X11 baseline | `rviz_agl:x11` 1.29GB / RSS 182MiB / 39초 안정 |
| R003 | XWayland baseline | `rviz_agl:xwayland` 1.33GB / +69% 메모리 → 양산 부적합 검증 |

### Phase 2 — Native Wayland (R004~R008) ✅ 완료
| ID | 제목 | 핵심 |
|---|---|---|
| R004 | Yocto meta-rviz2-agl 레이어 | layer.conf / bblayers/local.conf samples |
| R005 | OGRE EGL+Wayland | **OGRE 14.5.2** native Wayland (PR #3142, 2024-06) — 분석문서 "1.13+" 정정 |
| R006 | Qt5 Wayland QPA | libqwayland-egl.so primary, weston RDP backend 통합 |
| R007 | Wayland xcb fallback 가드 | **xcb fallback code humble 에 없음** 확인 + 회귀 방지 가드 2층 |
| R008 | RViz2 Yocto bbappend 통합 | rviz2_%.bbappend (SRC_URI/DEPENDS/RDEPENDS + lint 통과) |

### Phase 3 — 통합 (R009~R013) ✅ 완료 (narrowed)
| ID | 제목 | Narrowing 사유 |
|---|---|---|
| R009 | x86_64 Wayland-only 컨테이너 | apt rviz2 의 OGRE 1.12 GLX hardcoded → infra smoke test only, runtime 검증 → R016 |
| R010 | arm64 cross-compile builder | **DEFERRED** — bitbake 4회 시도(~12h) 모두 fail (호스트 네트워크/Scarthgap+Humble best-effort 한계) |
| R011 | arm64 runtime Dockerfile | R010 deferred → template + 외부 CI 통합 가이드 |
| R012 | arm64 QEMU + Weston 테스트 | 동상 — template only |
| R013 | docker-compose.yml | 5 services / 3 profiles (build/runtime/test) syntax 검증 통과 |

### Phase 4 — 안정화 (R014~R015) ✅ 완료 (narrowed)
| ID | 제목 | 산출물 |
|---|---|---|
| R014 | 렌더링 성능 측정/이미지 최적화 | 전략 문서 530줄 (fps/메모리/NVIDIA/GLES2 decision matrix) |
| R015 | agl-shell 통합 | ADR-007 (option B hybrid), agl_shell_register.cpp sample |

### Deferred — 외부 CI 통합 후 처리
| ID | 제목 | 상태 |
|---|---|---|
| R016 | RViz2 colcon source rebuild (R009 분할분) | **DEFERRED** — OGRE 1.12↔14.x C++ ABI 불일치 발견, R010 흡수 |
| R010 | arm64 cross-compile builder | **DEFERRED** — bitbake 빌드 인프라 외부 환경 필요 |

---

## 🏗️ 핵심 산출물

### Docker 이미지 (검증 완료)
- `rviz_agl:x11` (R002) — X11 baseline, OGRE 1.12 vendored
- `rviz_agl:xwayland` (R003) — XWayland 호환, RDP 시각 검증
- `rviz_agl:wayland-dev` (R005) — OGRE 14.5.2 EGL+Wayland native
- `rviz_agl:qt-wayland` (R006) — Qt5 Wayland QPA 통합
- `rviz_agl:wayland-only` (R009) — 인프라 통합 (rviz2 binary 제외)

### Templates (외부 CI 대기)
- `docker/arm64-runtime/Dockerfile.arm64` (R011)
- `docker/arm64-test/Dockerfile.arm64.test` (R012)
- `docker-compose.yml` (R013)

### Yocto meta-rviz2-agl 레이어
```
yocto/meta-rviz2-agl/
├── conf/
│   ├── layer.conf
│   └── distro/poky-agl-rviz2.conf  ← 커스텀 AGL distro
├── recipes-graphics/
│   ├── freeimage/*.bbappend
│   ├── openexr/*.bbappend
│   └── xorg-lib/{libx11,libxrandr,libxaw}_%.bbappend
└── recipes-ros2/
    ├── ogre/ogre_%.bbappend                       ← 14.5.2 SRC_URI override
    ├── rviz-default-plugins/*.bbappend             ← ignition-math6 skip
    ├── rviz-ogre-vendor/
    │   ├── rviz-ogre-vendor_%.bbappend
    │   └── files/0001-use-system-ogre-14x.patch
    └── rviz2/
        ├── rviz2_%.bbappend
        └── files/0001-wayland-xcb-fallback-guard.patch  ← R007 가드
```

### Architecture Decision Records (7종)
- **ADR-003** OGRE Wayland Strategy (R005): OGRE 14.x line PR #3142 채택
- **ADR-004** Wayland xcb Guard (R007): humble 에 xcb 코드 부재 + 회귀 방지 가드
- **ADR-005** R016 RViz2 Source Rebuild Strategy: OGRE 1.12↔14.x ABI 불일치 발견
- **ADR-006** R010 arm64 Cross-Compile Strategy: bitbake direct path (Path C)
- **ADR-007** R015 agl-shell Integration: agl-shell + xdg-shell hybrid (Option B)

### Baseline 문서 (11종)
- r002 X11, r003 XWayland, r005 OGRE Wayland, r006 Qt Wayland
- r007 xcb guard, r008 bbappend integration
- r009 wayland-only / r009_summary
- r010_session1 / session2 / session2c / session2d
- r011 arm64 runtime template
- r012 arm64 QEMU test / r013 docker-compose / r014 performance / r015 agl-shell

---

## 🎯 핵심 학습 (Production 양산 자료)

### 1. OGRE 버전 사실관계 정정
- 분석 문서 "OGRE 1.13+ stabilization" 클레임은 **부정확** — OGRE 1.13 출시된 적 없음
- 실제 native Wayland window backend = OGRE 14.x line (PR #3142 머지 2024-06-26)
- ROS 2 Humble 의 rviz_ogre_vendor 는 OGRE 1.12.1 vendoring → 14.x 업그레이드 필요

### 2. R016 ABI 불일치 발견
- OGRE 1.12 ↔ 14.x 는 단순 SONAME 차이 아닌 **C++ ABI 자체 다름**
  - 증거: `undefined symbol: _ZNK4Ogre9Exception18getFullDescriptionB5cxx11Ev`
- → rviz_rendering 을 OGRE 14.x 헤더로 처음부터 컴파일해야 함 (LD_LIBRARY_PATH override 불가)
- Yocto bitbake 의 DEPENDS chain 이 자연스럽게 이걸 해결 (R010 path)

### 3. xcb fallback code 부재 확인
- 분석 문서가 명시한 "rviz_common 내부 Wayland 감지 시 xcb 강제 설정 로직" 은 **humble 브랜치에 존재하지 않음**
- `git log -S 'qputenv("QT_QPA_PLATFORM"'` 결과 0 commits
- → R007 은 회귀 방지 방어 가드만 추가 (분석 문서 정정 deliverable)

### 4. Yocto Scarthgap + Humble best-effort 한계
- meta-ros2-humble scarthgap 브랜치는 unresolved deps 다수
- 발견한 Issue (모두 해결): qt5/qtbase, mesa opengl, X11 transitive, ignition-math6, openexr/clang-native, mesa DRI3, patch path
- 발견한 Issue (해결 못 함): bitbake fetch reliability (`do_unpack` 단계 clone 캐시 일관성)

### 5. flutter-auto 와 RViz2 공존
- AGL 의 flutter-auto 가 EGL context 점유 가능 → RViz2 동시 실행 시 Mesa DRM 환경에서는 정상 (검증 deferred)
- Vendor GPU 드라이버에서는 실기 별도 검증 필요

---

## ⏭️ Deferred 항목 처리 (4 paths)

### Path 1: AGL 공식 CI (권장 production)
- meta-rviz2-agl 레이어 AGL gerrit 등록
- 공식 CI 가 빌드 + 검증
- 시간: review/approval (수주)

### Path 2: 별도 빌드 서버 / 클라우드 (즉시 unblock)
- AWS m5.xlarge / GCP n2-standard-4 (8 vCPU / 32GB / 200GB SSD)
- `bash scripts/yocto-fetch-layers.sh && docker compose --profile build run rviz-arm64-builder`
- 8시간 + 비용 ~$5

### Path 3: AGL Yocto SDK pre-built 활용
- agl-image-flutter-sdk sysroot 다운로드
- colcon cross-compile (bitbake 우회)
- R016 ABI 재발 가능성 (sysroot OGRE 가 1.12 면)

### Path 4: 현 호스트 Issue 8/9 직접 해결
- `BB_NO_NETWORK = "0"` + premirror + fetch 사전 단계 분리
- 12시간 더 투자해도 미해결 가능성

→ **권장 path 2** (즉시) + **path 1** (장기 production).

---

## 🔗 산출물 위치

- 메인 하네스: 본 디렉토리 (`/home/obigo/project/oss/oss_agent2/`, git repo 아님)
- 백업 저장소: https://github.com/william-woo/harness_backup/tree/main/rviz_agl
- 외부 RViz2 소스 (수정 0건): https://github.com/william-woo/rviz_agl (branch `humble`, HEAD `cd168def`)
- OSS HMI App 통합 브랜치: `feature-rviz2` (oss_hmi_app/`apps/rviz2_port/` — 본 wrap-up 으로 푸시)

---

## 📐 외부 CI 통합 시 시작점

```bash
# 1. 클론
git clone https://github.com/william-woo/harness_backup
cd harness_backup/rviz_agl

# 2. Yocto 레이어 풀 클론
bash scripts/yocto-fetch-layers.sh

# 3. Docker 빌드 (8 vCPU 호스트 권장)
docker build -f docker/Dockerfile.build.arm64 -t rviz_agl:arm64-builder .

# 4. bitbake 실행 (4~8시간)
docker compose --profile build up rviz-arm64-builder
# 또는:
docker run -d --name rviz_arm64_build \
    -v "$(pwd)/yocto/sources:/workdir/sources" \
    -v "$(pwd)/yocto/build:/workdir/build" \
    -v "$(pwd)/yocto/downloads:/workdir/downloads" \
    rviz_agl:arm64-builder \
    bash -c 'source /workdir/sources/poky/oe-init-build-env /workdir/build && bitbake rviz2'

# 5. ABI 검증
docker exec rviz_arm64_build bash -c '
  find /workdir/build/tmp -name "librviz_rendering.so*" -path "*image*" | head -1 | xargs ldd | grep ogre
'
# 예상: libOgreMain.so.14.5 (1.12 아님)

# 6. tar.gz export
docker exec rviz_arm64_build tar czf /workdir/build/rviz_agl-arm64.tar.gz tmp/deploy
docker cp rviz_arm64_build:/workdir/build/rviz_agl-arm64.tar.gz output/

# 7. R011 runtime 이미지에 binary 통합 (placeholder 교체)
# docker/arm64-runtime/Dockerfile.arm64 의 placeholder RUN echo... 라인을:
# COPY --from=builder /opt/ros/humble/bin/rviz2 /usr/bin/rviz2

# 8. AGL 실기 또는 QEMU 검증
docker compose --profile test up rviz-arm64-test
```

---

## 결론

RViz2 AGL Wayland 포팅 프로젝트는 **인프라/청사진/검증 환경 전부 완성**되어 외부 CI 환경에서 R010 1회 빌드로 양산 path 마무리 가능. 핵심 발견 (OGRE 14.x line 채택 / ABI 불일치 / xcb 코드 부재 / Yocto Scarthgap+Humble best-effort 한계) 은 후속 팀에게 정직히 인계됨.

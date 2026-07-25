# 🧰 프로젝트 하네스 가이드

> 이 파일은 Claude Code가 이 프로젝트를 이해하고 올바르게 작동하기 위한 핵심 가이드입니다.
> **팀원 모두 이 파일을 읽고 프로젝트 시작 전 반드시 설정을 완료하세요.**

---

## 📋 프로젝트 개요

- **프로젝트명**: RViz2 AGL Wayland 포팅 (rviz_agl)
- **대상 소스**: `hmi/rviz_agl/` (ROS2 Humble, https://github.com/william-woo/rviz_agl)
- **목적**: ROS 2 Humble의 RViz2를 AGL Terrific Trout 20.0.3 (Yocto Scarthgap 5.0 LTS, 순수 Wayland 환경) 에 네이티브 포팅
- **기술 스택**: ROS2 Humble / Qt5 Wayland QPA / OGRE 1.x EGL / Yocto Scarthgap / Docker 멀티스테이지
- **타겟 플랫폼**: x86_64 개발 컨테이너 + arm64 AGL 실기 (둘 다 지원)
- **빌드 경로**: Docker 멀티스테이지 (우선) + Yocto bbappend 레이어 (meta-rviz2-agl)
- **MVP 시작점**: Phase 1 — XWayland로 RViz2를 AGL 위에서 일단 띄우는 것부터
- **작업 브랜치**: `feature_rviz_agl_wayland` (rviz_agl 저장소 내)
- **기획서**: `hmi/rviz_agl/planning/rviz_agl_wayland_porting_analysis.md` (핵심 분석 문서, Phase 1~4 로드맵)
- **이전 프로젝트 아카이브**: `docs/archive/feature_list_hmi_launcher_2026-04.json` (L001~L009, AGL Launcher)

---

## 🗂️ 디렉토리 구조

```
project-root/
├── CLAUDE.md                      # ← 지금 읽는 파일 (하네스 루트)
├── claude-progress.txt            # 에이전트 세션 간 인계 파일 (자동 관리)
├── feature_list.json              # 기능 목록 및 진행 상태 (자동 관리)
├── init.sh                        # 환경 검증 스크립트
├── .claude/                       # 하네스 설정 디렉토리
│   ├── settings.json
│   ├── agents/
│   ├── skills/
│   ├── commands/
│   ├── hooks/
│   └── rules/
├── docs/
│   └── archive/                   # 이전 프로젝트 아카이브
│       └── feature_list_hmi_launcher_2026-04.json
└── hmi/
    ├── oss_hmi_app/               # Flutter HMI 앱들 (참고용)
    │   └── apps/docker/           # ← Docker 멀티스테이지 빌드 패턴 참고
    └── rviz_agl/                  # ★ RViz2 AGL 포팅 작업 디렉토리
        ├── planning/
        │   └── rviz_agl_wayland_porting_analysis.md  # ★ 핵심 분석 문서
        ├── docker/                # Docker 빌드 파일들
        │   ├── Dockerfile         # 기존 X11 기반 (Phase 1 기준선)
        │   ├── entrypoint.sh
        │   └── run.sh
        ├── rviz2/                 # RViz2 메인 패키지
        ├── rviz_common/           # RViz 공통 코드
        ├── rviz_rendering/        # OGRE 렌더링 백엔드
        ├── rviz_ogre_vendor/      # OGRE 빌드 래퍼
        ├── rviz_default_plugins/
        ├── rviz_assimp_vendor/
        ├── rviz_rendering_tests/
        └── rviz_visual_testing_framework/
```

---

## ⚡ 빠른 시작

### 새 프로젝트 시작 (초기화)
```
/project:init
```
→ Planner 에이전트가 기능 목록 생성, 환경 셋업, 초기 커밋까지 자동 진행

### 작업 세션 시작
```
/project:start-session
```
→ 이전 진행 상황 파악 → 다음 작업 선택 → 개발 시작

### 세션 마무리 (인계)
```
/project:handoff
```
→ 진행 파일 업데이트 → git 커밋 → 다음 세션을 위한 컨텍스트 저장

### 현재 상태 확인
```
/project:status
```

---

## 🤖 에이전트 역할 분담

| 에이전트 | 트리거 | 주요 책임 |
|---|---|---|
| **Planner** | 프로젝트 초기, 기능 추가 요청 | 요구사항 분석, feature_list.json 관리, 우선순위 결정 |
| **Architect** | 새 컴포넌트 설계, 구조 변경 | 시스템 설계, 기술 선택, ADR 작성 |
| **Developer** | 실제 구현 | 코드 작성, 단위 테스트, 버그 수정 |
| **Reviewer** | 구현 완료 후 | 코드 품질, 보안, 성능 리뷰 |
| **QA** | 리뷰 통과 후 | E2E 테스트, 인수 검증, 기능 완료 마킹 |

**에이전트 호출 방법:**
```
# 특정 에이전트에게 위임
Use the planner agent to break down this feature: [기능 설명]
Use the developer agent to implement: [구현 내용]
Use the qa agent to verify: [검증 대상]
```

---

## 📏 필수 코딩 규칙

> **이 규칙들은 모든 에이전트가 반드시 따라야 합니다.**

### 진행 관리
- `claude-progress.txt`를 세션 시작 시 반드시 읽을 것
- `feature_list.json`의 기능 상태는 `passes` 필드만 수정 (삭제/편집 금지)
- 작업 완료 시 반드시 git commit (설명적인 커밋 메시지 사용)
- 미완성 상태로 세션 종료 금지 — 항상 mergeable 상태 유지

### 코드 품질
- 함수/클래스에 반드시 docstring 작성
- 새 기능에는 반드시 단위 테스트 포함
- PR 전 `Reviewer` 에이전트 리뷰 필수
- 기능 완료 전 `QA` 에이전트 E2E 검증 필수

### 금지 사항
- ❌ feature_list.json에서 테스트 항목 삭제
- ❌ 테스트 없이 기능 완료 마킹
- ❌ 미완성 코드를 main 브랜치에 커밋
- ❌ 한 세션에서 여러 기능 동시 구현 (한 번에 하나씩)

---

## 🔨 주요 명령어

> 모든 RViz2 관련 명령은 `hmi/rviz_agl/` 디렉토리에서 실행합니다.

```bash
RVIZ_DIR=hmi/rviz_agl

# 환경 점검 (Docker 빌드 + 기동 검증)
bash init.sh

# Phase 1-A: 기존 X11 기반 Docker 빌드 및 실행
cd "$RVIZ_DIR/docker"
docker build -t rviz_agl:x11 -f Dockerfile .
./run.sh  # X11 forwarding으로 RViz2 GUI 확인

# Phase 2+: Wayland native 빌드 (향후 Dockerfile.wayland)
docker build -t rviz_agl:wayland -f Dockerfile.wayland .

# ROS2 colcon 빌드 (컨테이너 내부 또는 호스트)
cd "$RVIZ_DIR"
colcon build --merge-install --cmake-args \
  -DOGRE_GLSUPPORT_USE_EGL=1 \
  -DOGRE_USE_WAYLAND=1 \
  -DOGRE_CONFIG_UNIX_NO_X11=1

# RViz2 실행 (Wayland 환경변수)
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/run/user/1000
export QT_WAYLAND_SHELL_INTEGRATION=xdg-shell
ros2 run rviz2 rviz2

# Yocto bbappend 빌드 (AGL 빌드 환경, 향후)
cd <AGL-build-directory>
source agl-init-build-env
bitbake rviz2

# Docker compose 통합 (향후 R013)
docker compose --profile build up       # x86_64/arm64 빌드
docker compose --profile runtime up rviz_agl_runtime_x64
docker compose --profile test up        # QEMU arm64 테스트
```

---

## 📝 세션 시작 체크리스트

에이전트가 새 세션을 시작할 때 **반드시** 다음 순서로 진행:

1. `claude-progress.txt` 읽기 (이전 세션 내용 파악)
2. `git log --oneline -10` 실행 (최근 변경 확인)
3. `feature_list.json` 읽기 (완료/미완료 기능 확인)
4. 개발 서버 실행 및 기본 동작 확인 (`init.sh`)
5. 가장 높은 우선순위의 미완료 기능 선택
6. **한 번에 하나의 기능만** 구현

---

## 📊 feature_list.json 필드 설명

| 필드 | 관리 주체 | 값 |
|---|---|---|
| `passes` | **QA 에이전트만** | `false` → `true` (절대 삭제 금지) |
| `status` | 각 에이전트 | `todo` → `in-progress` → `review` → `qa` → `done` |
| `dependencies` | Planner | 선행 Feature ID 목록 |

**status 전환 규칙:**
- `todo` → `in-progress`: Developer/Architect 세션 시작 시
- `in-progress` → `review`: Developer 구현 + 테스트 완료 시
- `review` → `qa`: Reviewer APPROVED 시
- `qa` → `done`: QA PASS 시 (passes: true와 동시)

---

## 🏗️ Architect 에이전트 호출 기준

다음 중 하나라도 해당되면 Developer 시작 전 Architect를 먼저 호출:

- 새로운 DB 테이블/스키마가 필요한 기능
- 새로운 외부 API 연동
- 기존 모듈 간 의존성 변경
- 3개 이상의 파일에 걸친 구조적 변경
- 보안/인증 관련 기능

해당 없으면 Developer가 바로 구현 시작 가능.

---

## 🔗 참고 문서

- [아키텍처 결정 기록](./docs/adr/)
- [코딩 컨벤션](.claude/rules/coding-standards.md)
- [Git 컨벤션](.claude/rules/git-conventions.md)

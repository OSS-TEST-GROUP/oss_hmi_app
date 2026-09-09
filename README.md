# oss_hmi_app

차량용 **HMI 앱 모음 (Flutter)**. MMF(Multi-middleware Framework) 백엔드와 **rosbridge/ROS2**
로 통신하며, 런처 셸(hmi_launcher)이 모니터 앱들을 임베드해 하나의 화면으로 제공한다.

- **타겟 보드**: Orin AGX (AGL Yocto, arm64) — flutter-auto/Wayland
- **개발 환경**: x86_64 Ubuntu (GTK, Xvfb/X11)
- **배포**: 사내 registry `registry.obigo.com/oss/*` (멀티아치 amd64+arm64)

## 앱 목록

| 디렉토리 | 이름(런처 카드) | 역할 | 문서 |
|---|---|---|---|
| [apps/hmi_launcher](apps/hmi_launcher) | Launcher | 런처 셸 + Settings/Manage Apps + AI 런처봇. 패널 6종 임베드 | [README](apps/hmi_launcher/README.md) · [Settings 사용법](apps/hmi_launcher/SETTINGS_USAGE.md) |
| [apps/adsw_monitor](apps/adsw_monitor) | ADSW Monitor (📡) | 자율주행(Autoware) 상태 대시보드 | [README](apps/adsw_monitor/README.md) · [사용법](apps/adsw_monitor/USAGE.md) |
| [apps/diag_monitor](apps/diag_monitor) | Diagnostic Monitor (🩺) | MMF 미들웨어 진단(diagnosticmgr) 대시보드 | [README](apps/diag_monitor/README.md) · [사용법](apps/diag_monitor/USAGE.md) |
| [apps/lfc_monitor](apps/lfc_monitor) | Lifecycle Monitor (🔄) | 서비스/컨테이너 헬스 모니터·제어 | [README](apps/lfc_monitor/README.md) · [사용법](apps/lfc_monitor/USAGE.md) |
| [apps/ota_monitor](apps/ota_monitor) | OTA Monitor (📦) | OTA 업데이트 관측·조작 (기본 숨김) | [README](apps/ota_monitor/README.md) · [사용법](apps/ota_monitor/USAGE.md) |
| [apps/rviz2_panel](apps/rviz2_panel) | RViz2 Panel (🤖) | RViz2 컨테이너 상태 모니터링·제어 | [README](apps/rviz2_panel/README.md) |
| [apps/oss_launcher_bot](apps/oss_launcher_bot) | Launcher Bot (🤖) | AI 어시스턴트 (standalone; 런처에 내장) | [README](apps/oss_launcher_bot/README.md) |
| [apps/vehicle_data_app](apps/vehicle_data_app) | Vehicle Data (🚗) | 차량 데이터 API 수신 대시보드 (런처 임베드) | [README](apps/vehicle_data_app/README.md) |
| [apps/vehicle_data_test](apps/vehicle_data_test) | Vehicle Data (🚗) | 차량 데이터 API 테스트 시뮬레이터 (단독) | [README](apps/vehicle_data_test/README.md) |

> **hmi_launcher** 는 ota_monitor·adsw_monitor·diag_monitor·lfc_monitor·rviz2_panel·vehicle_data_app 을 path-dep 로 **임베드**한다(별도 컨테이너 불필요).
> Launcher Bot·Vehicle Data Test 는 standalone 전용 실행이 가능하다.

## 빠른 시작

- **로컬 x86 실행**: 각 앱 README 의 "설치·실행" (`docker compose ... up <app>`) — [DOCKER_GUIDE](apps/docker/docs/DOCKER_GUIDE.md) §1
- **보드(AGL) 배포·자동시작**: [docs/build-install-run-guide.md](docs/build-install-run-guide.md) · [docs/board-autostart-guide.md](docs/board-autostart-guide.md)
- **멀티아치 registry push/pull**: [DOCKER_GUIDE](apps/docker/docs/DOCKER_GUIDE.md) §6~§7 (또는 `apps/docker/script/build_multiarch.sh`)

## 문서 인덱스

### 앱 사용 가이드 (운영자용)
- [adsw_monitor/USAGE.md](apps/adsw_monitor/USAGE.md) — ADSW Monitor
- [diag_monitor/USAGE.md](apps/diag_monitor/USAGE.md) — 미들웨어 진단 모니터
- [lfc_monitor/USAGE.md](apps/lfc_monitor/USAGE.md) — Lifecycle 모니터 (제어 포함)
- [ota_monitor/USAGE.md](apps/ota_monitor/USAGE.md) — OTA 모니터
- [hmi_launcher/SETTINGS_USAGE.md](apps/hmi_launcher/SETTINGS_USAGE.md) — Settings / Manage Apps
- [rviz2_panel/README.md](apps/rviz2_panel/README.md) — RViz2 Panel

### 빌드·배포
- [apps/docker/docs/DOCKER_GUIDE.md](apps/docker/docs/DOCKER_GUIDE.md) — x86/arm64 빌드·실행, registry push, **멀티아치(§7)**
- [docs/build-install-run-guide.md](docs/build-install-run-guide.md) — 전 앱 빌드→설치→실행 요약 (launcher 특이사항 포함)
- [docs/board-autostart-guide.md](docs/board-autostart-guide.md) — 보드 재부팅 자동시작
- [apps/docker/docs/board-default-launcher-setup.md](apps/docker/docs/board-default-launcher-setup.md) · [board-flashing-setup.md](apps/docker/docs/board-flashing-setup.md)

### 테스트
- [apps/ota_monitor/integration_test/INTEGRATION_TEST_GUIDE.md](apps/ota_monitor/integration_test/INTEGRATION_TEST_GUIDE.md) — OTA 통합 테스트

## 디렉토리 구조
```
oss_hmi_app/
├── apps/
│   ├── hmi_launcher/        # 런처 셸 (모니터·패널 임베드)
│   ├── adsw_monitor/        # AD SW
│   ├── diag_monitor/        # 미들웨어 진단
│   ├── lfc_monitor/         # Lifecycle Monitor
│   ├── ota_monitor/         # OTA Monitor
│   ├── rviz2_panel/         # RViz2 Panel
│   ├── rviz2_port/          # RViz2 컨테이너 이식
│   ├── oss_launcher_bot/    # Launcher Bot (AI)
│   ├── vehicle_data_app/    # Vehicle Data App (런처 임베드)
│   ├── vehicle_data_test/   # Vehicle Data Test (단독 시뮬레이터)
│   └── docker/              # dockerfile/ · compose/ · script/ · docs/(DOCKER_GUIDE)
└── docs/                    # build-install-run / board-autostart 가이드
```

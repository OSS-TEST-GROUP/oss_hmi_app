# ota_monitor — OTA Monitor

MMF **OTA Manager** 를 관측·조작하는 운영/진단 콘솔 (rosbridge 경유). 런처 카드 "OTA Monitor"(📦).
런처에서는 기본 숨김(Manage Apps 에서 활성). 단독 실행 또는 hmi_launcher 에 임베드.

## 개요
- App List(클라이언트별 트리) + Client Interaction(등록/Manager Status/AppUpdateStatus) + Actor API Call(설정 조회·변경, 상태 조회, **업데이트 실행**)
- Manager 생존은 `NotifyOtaMgrHeartbeat` 기반, 로컬 검증에 `ota_manager_mock` compose 서비스 활용 가능
- 상세 사용법: [USAGE.md](USAGE.md)

## Standalone 빌드
> `apps/` 에서 실행. 상세·멀티아치·registry: [docker/docs/DOCKER_GUIDE.md](docker/docs/DOCKER_GUIDE.md)

```bash
# x86_64 (dev)
docker compose -f docker/compose/docker-compose.yml --profile build run --rm ota_monitor_builder_x86   # → output/ota_monitor-x86_64-release.tar.gz
docker compose -f docker/compose/docker-compose.yml build ota_monitor                                   # 런타임 이미지 ota_monitor:x86_64

# arm64 (AGL 보드)
docker compose -f docker/compose/docker-compose.yml --profile build run --rm ota_monitor_builder_arm64  # → output/ota_monitor-arm64-release.tar.gz
docker buildx build --platform linux/arm64 -f docker/dockerfile/Dockerfile.arm64 \
  --build-arg APP_NAME=ota_monitor -t ota_monitor:arm64 .
```

## 설치·실행
```bash
# x86_64 로컬 (NVIDIA GPU 환경: --runtime=nvidia --gpus all)
docker compose -f docker/compose/docker-compose.yml up ota_monitor
# (선택) OTA Manager mock 과 함께 로컬 검증
docker compose -f docker/compose/docker-compose.yml up ota_manager_mock ota_monitor
```
- 보드(AGL) 배포/자동시작: [../../docs/build-install-run-guide.md](../../docs/build-install-run-guide.md), [../../docs/board-autostart-guide.md](../../docs/board-autostart-guide.md)
- 통합 테스트: [integration_test/INTEGRATION_TEST_GUIDE.md](integration_test/INTEGRATION_TEST_GUIDE.md)

## 설정 (config.json)
- `rosbridge.url`(기본 `ws://localhost:9090`), `statusTopic`(`/app_status/ota_monitor`), `initialApps`, `heartbeatIntervalSec`, `theme`(light/dark)
- 읽기 경로: `OTA_CONFIG` → `$XDG_CONFIG_HOME/ota_monitor/` → `~/.config/ota_monitor/` → `/etc/ota_monitor/` → 번들 `config/config.json`
- 런타임 편집(Settings): rosbridge URL·Theme

## 문서
- 사용법: [USAGE.md](USAGE.md) · 빌드/배포 상세: [docker/docs/DOCKER_GUIDE.md](docker/docs/DOCKER_GUIDE.md)

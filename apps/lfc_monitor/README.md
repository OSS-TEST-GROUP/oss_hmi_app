# lfc_monitor — Lifecycle Monitor

MMF `lifecycle_mgr`/`adsw_manager` 백엔드의 **서비스·컨테이너 헬스를 실시간 모니터링·제어**하는
HMI (rosbridge 경유). 런처 카드 "Lifecycle Monitor"(🔄). 단독 실행 또는 hmi_launcher 에 임베드.

## 개요
- Containers & Services 패널(상태 badge, Start/Stop, Recovery policy) + Events 타임라인
- 제어: 서비스/컨테이너 시작·정지, 복구 정책 변경, 전체 OTA 모드 전환 (`ctrl/*` 정책 게이트)
- 상세 사용법: [USAGE.md](USAGE.md)

## Standalone 빌드
> `apps/` 에서 실행. 상세·멀티아치·registry: [docker/docs/DOCKER_GUIDE.md](docker/docs/DOCKER_GUIDE.md)

```bash
# x86_64 (dev)
docker compose -f docker/compose/docker-compose.yml --profile build run --rm lfc_monitor_builder_x86   # → output/lfc_monitor-x86_64-release.tar.gz
docker compose -f docker/compose/docker-compose.yml build lfc_monitor                                   # 런타임 이미지 lfc_monitor:x86_64

# arm64 (AGL 보드)
docker compose -f docker/compose/docker-compose.yml --profile build run --rm lfc_monitor_builder_arm64  # → output/lfc_monitor-arm64-release.tar.gz
docker buildx build --platform linux/arm64 -f docker/dockerfile/Dockerfile.arm64 \
  --build-arg APP_NAME=lfc_monitor -t lfc_monitor:arm64 .
```

## 설치·실행
```bash
# x86_64 로컬 (NVIDIA GPU 환경: --runtime=nvidia --gpus all)
docker compose -f docker/compose/docker-compose.yml up lfc_monitor
```
- 보드(AGL) 배포/자동시작: [../../docs/build-install-run-guide.md](../../docs/build-install-run-guide.md), [../../docs/board-autostart-guide.md](../../docs/board-autostart-guide.md)
- QEMU arm64 헤드리스 테스트(VNC): DOCKER_GUIDE §3-2 (`lfc_monitor_arm64_test`)

## 설정 (config.json)
- `rosbridge.url`(기본 `ws://127.0.0.1:9090`), `statusTopic`(`/app_status/lfc_monitor`), `pollIntervalSec`(5), `theme`(light/dark)
- 읽기 경로: `--config` → `LFC_MONITOR_CONFIG` → `./config/config.json` → `~/.config/lfc_monitor/` → `/etc/lfc_monitor/`
- 런타임 편집(앱바 Settings): rosbridge URL·Theme·Service Mode

## 문서
- 사용법: [USAGE.md](USAGE.md) · 빌드/배포 상세: [docker/docs/DOCKER_GUIDE.md](docker/docs/DOCKER_GUIDE.md)

# hmi_launcher — Launcher

차량 HMI 의 **런처 셸**. 홈/사이드바 + 프롬프트바 프레임에 monitor 앱들을 **임베드**하고,
Settings·Manage Apps·(옵션)AI 런처봇을 제공한다. rosbridge 로 MMF 백엔드와 통신.

## 개요
- **임베드 앱**: `ota_monitor` · `adsw_monitor` · `lfc_monitor` 를 path-dep 로 컴파일 포함(별도 컨테이너 불필요). OTA Monitor 는 기본 숨김(Manage Apps 에서 활성).
- **Settings / Manage Apps**: 연결(rosbridge)·앱 테마·시간대·앱 표시/숨김. → [SETTINGS_USAGE.md](SETTINGS_USAGE.md)
- **AI 런처봇**: v_agentos 데몬 연결 시 활성(상단바 Standard↔AI SDK). 끄려면 `LAUNCHER_BOT_ENABLED=0`.
- 앱 발견: `HMI_APPS_ROOT` 또는 `/usr/share/flutter/hmi_launcher/<ver>/apps` 의 `<app>/manifest.json` 스캔.

## Standalone 빌드
> `apps/` 에서 실행. 상세·멀티아치·registry: [docker/docs/DOCKER_GUIDE.md](docker/docs/DOCKER_GUIDE.md)

```bash
# x86_64 (dev)
docker compose -f docker/compose/docker-compose.yml --profile build run --rm hmi_launcher_builder_x86   # → output/hmi_launcher-x86_64-release.tar.gz
docker compose -f docker/compose/docker-compose.yml build hmi_launcher                                   # 런타임 이미지 hmi_launcher:x86_64

# arm64 (AGL 보드) — APP_VERSION=3.32.5 고정
docker compose -f docker/compose/docker-compose.yml --profile build run --rm hmi_launcher_builder_arm64  # → output/hmi_launcher-arm64-release.tar.gz
docker buildx build --platform linux/arm64 -f docker/dockerfile/Dockerfile.arm64 \
  --build-arg APP_NAME=hmi_launcher --build-arg APP_VERSION=3.32.5 --build-arg CONFIG_FILE=launcher_config.json \
  -t hmi_launcher:arm64 .
```

## 설치·실행
```bash
# x86_64 로컬 (NVIDIA GPU 환경: --runtime=nvidia --gpus all, DISPLAY 필요)
docker compose -f docker/compose/docker-compose.yml up hmi_launcher
```
- **보드(AGL) 배포·자동시작**: [../../docs/build-install-run-guide.md](../../docs/build-install-run-guide.md), [../../docs/board-autostart-guide.md](../../docs/board-autostart-guide.md), [docker/docs/board-default-launcher-setup.md](docker/docs/board-default-launcher-setup.md)
- **멀티아치 registry push/pull**: DOCKER_GUIDE §6~§7 (또는 `docker/script/build_multiarch.sh`)

## 설정 (launcher_config.json)
- `rosbridge.url`(기본 `ws://localhost:9090`), `statusTopic`, `rosReconnectIntervalSec`, `heartbeatIntervalSec`, `otaTheme`/`adswTheme`/`lfcTheme`
- 읽기 경로: `HMI_LAUNCHER_CONFIG` → `$XDG_CONFIG_HOME/hmi_launcher/` → `~/.config/hmi_launcher/` → `/var/lib/hmi_launcher/`
- 런타임 편집(Settings): rosbridge URL·앱 테마·시간대 즉시 반영·저장

## 문서
- 설정 사용법: [SETTINGS_USAGE.md](SETTINGS_USAGE.md)
- 임베드 앱 사용법: [../adsw_monitor/USAGE.md](../adsw_monitor/USAGE.md) · [../lfc_monitor/USAGE.md](../lfc_monitor/USAGE.md) · [../ota_monitor/USAGE.md](../ota_monitor/USAGE.md)
- 빌드/배포 상세: [docker/docs/DOCKER_GUIDE.md](docker/docs/DOCKER_GUIDE.md)

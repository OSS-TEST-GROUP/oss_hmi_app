# HMI 앱 빌드·설치·실행 가이드 (x86_64 / arm64)

> hmi_launcher · adsw_monitor · lfc_monitor · ota_monitor 를 소스에서 빌드해
> PC(x86_64) 또는 AGL 보드(arm64, 예: Orin AGX)에 설치·실행하는 전 과정.
> 2026-07 실보드(172.16.10.162) 검증 절차 기준.
> 단계별 세부·QEMU 테스트는 [apps/docker/docs/DOCKER_GUIDE.md](../apps/docker/docs/DOCKER_GUIDE.md),
> 보드 기본 런처 등록은 [apps/docker/docs/board-default-launcher-setup.md](../apps/docker/docs/board-default-launcher-setup.md),
> 재부팅 자동시작은 [board-autostart-guide.md](board-autostart-guide.md) 참조.

---

## 0. 구성 개요

| 앱 | 역할 | 배포 형태 |
|---|---|---|
| **hmi_launcher** | 홈 런처 셸 — 앱 그리드 + **임베디드 패널**(OTA/lfc/adsw) + Manage Apps + 설정 | 보드 배포의 **주 이미지** |
| adsw_monitor / lfc_monitor / ota_monitor | 각 모니터 앱 | 런처에 **path 의존성으로 임베드**됨(pubspec). 단독 이미지 빌드도 가능 |

즉 보드에는 보통 **hmi_launcher 이미지 하나**만 올리면 모니터 앱들이 패널로 포함된다.
빌드는 전부 **compose 빌더 컨테이너**로 수행한다 (호스트 Flutter 불필요, 단 유닛테스트는
호스트 `flutter test` 로도 가능).

---

## 1. x86_64 (PC 개발/테스트)

```bash
cd apps/docker/compose

# 1) 빌드 (Flutter Linux GTK 번들) — 앱별 빌더 서비스
docker compose --profile build run --rm hmi_launcher_builder_x86
#   (adsw_monitor_builder_x86 / lfc_monitor_builder_x86 / ota_monitor_builder_x86 동일 패턴)

# 2) 런타임 이미지 + 실행 (X11/NVIDIA 는 compose 서비스에 정의돼 있음)
docker compose up -d hmi_launcher            # image: hmi_launcher:x86_64
```
세부(빌더 이미지 생성, config 변경 등)는 DOCKER_GUIDE.md §1 참조.

---

## 2. arm64 (AGL 보드 배포)

### 2-1. AOT 크로스컴파일 (AGL Yocto SDK 빌더)
```bash
cd apps/docker/compose
docker compose --profile build run --rm hmi_launcher_builder_arm64
# → apps/output/hmi_launcher-arm64-release.tar.gz
```
- 빌더 이미지는 최초 1회 자동 빌드(AGL SDK 다운로드 — `AGL_SDK_USER/PASSWORD` env).
- **hmi_launcher 빌더는 ota/adsw/lfc_monitor 디렉토리 마운트가 모두 필요**하다
  (pubspec path 의존성 — compose 에 정의돼 있으므로 그대로 쓰면 됨).
- 성공 판정: 로그 `** Complete **` + tar.gz 갱신 시각.

### 2-2. 런타임 이미지 조립
```bash
cd apps
VER=3.32.21           # 이미지 태그 (배포 버전 — 자유롭게 증가)
docker buildx build --platform=linux/arm64 -f docker/dockerfile/Dockerfile.arm64 \
  --build-arg APP_NAME=hmi_launcher \
  --build-arg APP_VERSION=3.32.5 \
  --build-arg CONFIG_FILE=launcher_config.json \
  -t oss-hmi-launcher:$VER --load .
```
> ⚠️ **APP_VERSION 함정 (필독)**: `APP_VERSION` 은 이미지 태그가 아니라 **AOT tar 내부
> 경로의 Flutter 엔진 버전 `3.32.5` 로 고정**해야 한다 (tar 레이아웃 =
> `usr/share/flutter/hmi_launcher/3.32.5/release/`). 이미지 버전을 넣으면 BUNDLE_PATH 가
> 빈 디렉토리를 가리켜 flutter-auto 가 `libflutter_engine.so: cannot open` 으로 검은
> 화면이 된다. **이미지 태그(-t)와 APP_VERSION 은 별개다.**
- 다른 앱 단독 이미지: `APP_NAME=<app>` `CONFIG_FILE=config.json` 으로 동일 절차.
- 버전 tar 백업 관례: `cp output/hmi_launcher-arm64-release.tar.gz output/...-release.$VER.tar.gz`

### 2-3. 설치 (보드로 전달)
```bash
# (a) registry
REG=registry.obigo.com/oss
docker tag oss-hmi-launcher:$VER $REG/oss-hmi-launcher:$VER
docker tag oss-hmi-launcher:$VER $REG/oss-hmi-launcher:latest
docker push $REG/oss-hmi-launcher:$VER && docker push $REG/oss-hmi-launcher:latest

# (b) 직접 전송
docker save oss-hmi-launcher:$VER | gzip -1 | ssh root@<board> 'gunzip | docker load'
```

### 2-4. 보드 실행
전제: agl-compositor 가동(`/run/wayland-0`), flutter-auto·엔진이 호스트에 존재
(AGL 이미지 기본), NVIDIA GL 스택 스테이징(`/opt/nv-gl` — run 스크립트가 자동 수행).

```bash
docker stop hmi_launcher 2>/dev/null; docker rm hmi_launcher 2>/dev/null
docker run -d --name hmi_launcher --net=host --privileged \
  --restart unless-stopped \
  -v /run/wayland-0:/run/wayland-0 \
  -v /usr/bin/flutter-auto:/usr/bin/flutter-auto:ro \
  -v /usr/share/flutter/3.32.5/release/lib/libflutter_engine.so:/usr/share/flutter/3.32.5/release/lib/libflutter_engine.so:ro \
  -v /usr/share/flutter/3.32.5/release/data/icudtl.dat:/usr/share/flutter/icudtl.dat:ro \
  -v /opt/nv-gl:/opt/nv-gl:ro \
  -v /usr/share/glvnd/egl_vendor.d:/usr/share/glvnd/egl_vendor.d:ro \
  -v /usr/share/egl/egl_external_platform.d:/usr/share/egl/egl_external_platform.d:ro \
  -v /root/oss/hmi_launcher_config.json:/etc/hmi_launcher/config.json:ro \
  -e LD_LIBRARY_PATH=/opt/nv-gl -e HOME=/tmp -e XDG_RUNTIME_DIR=/run \
  -e WAYLAND_DISPLAY=wayland-0 -e LAUNCHER_BOT_ENABLED=0 \
  oss-hmi-launcher:$VER --window-type BG
```
> ⚠️ **`--window-type BG` 필수**: 컴포지터가 `activate-by-default=false` 라 NORMAL
> 윈도우는 활성화 없이는 그려지지 않는다(앱은 돌지만 화면 검정). BG=배경 레이어.
> ⚠️ 기존 컨테이너를 `docker inspect` 로 복제할 땐 **Config.Cmd(BG 인자)까지 채취**할 것.

- `hmi_launcher_config.json` (호스트 `/root/oss/`): rosbridge url(`ws://<core보드>:9090`) 등
  런타임 설정 — 백엔드(MMF core/ext-ros2) 보드 IP 에 맞춘다.
- 백엔드 쪽 빌드·실행은 `oss_multisw_framework/docs/build-install-run-guide.md` 참조.

### 2-5. 검증
```bash
docker logs hmi_launcher | grep "Window Type"                       # BG
docker exec hmi_launcher grep -c libflutter_engine /proc/1/maps     # >0 = 엔진 로드(렌더 중)
journalctl -t agl-compositor | grep -i background                   # "(background) position view ..."
# 터치 안 되면: journalctl -t agl-compositor | grep -i touch  (장치 인식 — 터치 USB 는 모니터 일체형 주의)
```
호스트 유닛테스트: `cd apps/hmi_launcher && flutter test` (adsw/lfc/ota 동일).

---

## 3. 자주 밟는 함정 요약

| 함정 | 증상 | 대처 |
|---|---|---|
| `APP_VERSION` 에 이미지 버전 | 검은 화면, `libflutter_engine.so: cannot open` | **3.32.5(엔진버전) 고정**, 태그는 `-t` 로 |
| `--window-type BG` 누락 | 앱은 돌지만 화면 검정 (Window Type: NORMAL) | CMD 에 `--window-type BG` |
| 빌더에 path-dep 마운트 누락 | `flutter pub get` 실패 (../lfc_monitor 등) | compose 빌더 서비스 그대로 사용 |
| 수동 stop 후 재부팅 | 컨테이너 안 뜸 | unless-stopped 특성 — `docker start hmi_launcher` |
| 화면 OK 인데 터치 안 됨 | 컴포지터 "unmapped surface" 경고 | 디스플레이 정상 상태에서 `docker restart hmi_launcher` |
| 런처 lfc 제어 키 불일치 | lfc 패널 제어 무반응 | 런처와 MMF 백엔드를 **같은 IDL 세대(mw_type)** 로 배포 |

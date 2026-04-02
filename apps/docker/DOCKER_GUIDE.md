# adsw_monitor Docker 빌드 & 실행 가이드

## 개요

| 파일 | 역할 |
|------|------|
| `Dockerfile.build` | x86_64 Flutter Linux 빌드 이미지 |
| `Dockerfile.build.arm64` | arm64 AGL AOT 빌드 이미지 (AGL Yocto SDK 사용) |
| `Dockerfile` | x86_64 런타임 이미지 (GTK 기반) |
| `Dockerfile.arm64` | arm64 런타임 이미지 (flutter-auto, AGL 디바이스용) |
| `Dockerfile.arm64.test` | arm64 테스트 이미지 (QEMU + Weston 헤드리스, x86_64 호스트 테스트용) |
| `docker-compose.yml` | 전체 서비스 구성 |

모든 `docker` / `docker compose` 명령은 **`apps/` 디렉토리에서 실행**합니다.

```bash
cd apps/
```

---

## 1. x86_64 빌드 & 실행

### 1-1. 빌드 이미지 생성

```bash
docker compose --profile build build adsw_monitor_builder_x86
```

또는 직접:

```bash
docker build -f docker/Dockerfile.build -t adsw_monitor_builder:x86_64 .
```

### 1-2. 앱 빌드 (Flutter Linux GTK 번들 생성)

```bash
docker compose --profile build run --rm adsw_monitor_builder_x86
```

또는 직접:

```bash
docker run --rm \
  -v $(pwd)/adsw_monitor:/workspace/app \
  -v $(pwd)/output:/workspace/output \
  adsw_monitor_builder:x86_64
```

결과물: `output/adsw_monitor-x86_64-release.tar.gz`

### 1-3. 런타임 이미지 생성

```bash
docker compose build adsw_monitor
```

또는 직접:

```bash
docker build -f docker/Dockerfile -t adsw_monitor:x86_64 .
```

### 1-4. 실행

```bash
docker compose up adsw_monitor
```

또는 직접 (X11 환경):

```bash
docker run --rm \
  -e DISPLAY=:1 \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v $(pwd)/adsw_monitor/config/config.json:/app/config/config.json \
  --network host \
  --name adsw_monitor \
  adsw_monitor:x86_64
```

NVIDIA GPU 사용 시:

```bash
docker run --rm \
  --runtime=nvidia --gpus all \
  -e DISPLAY=:1 \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v $(pwd)/adsw_monitor/config/config.json:/app/config/config.json \
  --network host \
  --name adsw_monitor \
  adsw_monitor:x86_64
```

---

## 2. arm64 빌드

### 2-1. 빌드 이미지 생성

AGL Yocto SDK를 내부 Nexus에서 다운로드하여 설치합니다 (약 10-15분 소요).

```bash
docker compose --profile build build adsw_monitor_builder_arm64
```

또는 직접:

```bash
docker build \
  --build-arg AGL_SDK_USER=ossdev \
  --build-arg AGL_SDK_PASSWORD=ossdev1234 \
  -f docker/Dockerfile.build.arm64 \
  -t adsw_monitor_builder:arm64 .
```

### 2-2. 앱 빌드 (arm64 AOT 크로스컴파일)

```bash
docker compose --profile build run --rm adsw_monitor_builder_arm64
```

또는 직접:

```bash
docker run --rm \
  -v $(pwd)/adsw_monitor:/workspace/app \
  -v $(pwd)/output:/workspace/output \
  adsw_monitor_builder:arm64 \
  --app-path=/workspace/app \
  --output-dir=/workspace/output
```

결과물: `output/adsw_monitor-arm64-release.tar.gz`

---

## 3. arm64 런타임

arm64 런타임에는 두 가지 컨테이너가 제공됩니다.

### 3-1. AGL 디바이스용 (`Dockerfile.arm64`)

실제 AGL 하드웨어에서 flutter-auto로 실행하는 프로덕션 이미지입니다.

**사전 조건:**
- `output/adsw_monitor-arm64-release.tar.gz` 빌드 완료
- 호스트에 `flutter-auto` 바이너리 설치 (`/usr/bin/flutter-auto`)
- Wayland 컴포지터 실행 중 (AGL 환경)

**이미지 빌드:**

```bash
# x86_64 호스트에서 arm64 이미지 크로스빌드
docker buildx build --platform linux/arm64 \
  -f docker/Dockerfile.arm64 \
  -t adsw_monitor:arm64 .
```

**AGL 디바이스에서 실행:**

```bash
docker run --rm \
  -v /usr/bin/flutter-auto:/usr/bin/flutter-auto:ro \
  -v /dev/dri:/dev/dri \
  -v /run/user/1001:/run/user/1001 \
  -e WAYLAND_DISPLAY=wayland-0 \
  -e XDG_RUNTIME_DIR=/run/user/1001 \
  -v /path/to/config.json:/usr/share/flutter/adsw_monitor/3.32.2/release/data/flutter_assets/assets/config/config.json \
  --network host \
  adsw_monitor:arm64
```

---

### 3-2. QEMU 에뮬레이션 테스트용 (`Dockerfile.arm64.test`)

x86_64 호스트에서 QEMU arm64 에뮬레이션으로 실행하는 테스트 이미지입니다.
flutter-auto와 AGL flutter 엔진이 이미지에 내장되며, Weston 헤드리스 Wayland 컴포지터를 자동으로 시작합니다.

**사전 조건:**
- `adsw_monitor_builder:arm64` 이미지 빌드 완료
- `output/adsw_monitor-arm64-release.tar.gz` 빌드 완료
- `output/agl-binaries/` 디렉토리에 AGL 바이너리 추출 완료

**AGL 바이너리 추출 (최초 1회):**

```bash
# flutter-auto, libflutter_engine.so, icudtl.dat, libc++ 추출
bash docker/extract-agl-binaries.sh
```

> `extract-agl-binaries.sh`가 없을 경우 아래 명령을 직접 실행:

```bash
mkdir -p output/agl-binaries/{bin,lib,flutter/3.32.2/release/{lib,data}}

docker run --rm --entrypoint bash adsw_monitor_builder:arm64 -c \
  "cat /opt/agl-sdk/sysroots/aarch64-agl-linux/usr/bin/flutter-auto" \
  > output/agl-binaries/bin/flutter-auto

docker run --rm --entrypoint bash adsw_monitor_builder:arm64 -c \
  "cat /opt/agl-sdk/sysroots/aarch64-agl-linux/usr/share/flutter/3.32.2/release/lib/libflutter_engine.so" \
  > output/agl-binaries/flutter/3.32.2/release/lib/libflutter_engine.so

docker run --rm --entrypoint bash adsw_monitor_builder:arm64 -c \
  "cat /opt/agl-sdk/sysroots/aarch64-agl-linux/usr/share/flutter/3.32.2/release/data/icudtl.dat" \
  > output/agl-binaries/flutter/3.32.2/release/data/icudtl.dat

docker run --rm --entrypoint bash adsw_monitor_builder:arm64 -c \
  "cat /opt/agl-sdk/sysroots/aarch64-agl-linux/usr/lib/libc++.so.1.0" \
  > output/agl-binaries/lib/libc++.so.1.0

docker run --rm --entrypoint bash adsw_monitor_builder:arm64 -c \
  "cat /opt/agl-sdk/sysroots/aarch64-agl-linux/usr/lib/libc++abi.so.1.0" \
  > output/agl-binaries/lib/libc++abi.so.1.0

chmod +x output/agl-binaries/bin/flutter-auto
```

**이미지 빌드:**

```bash
docker build --platform linux/arm64 \
  -f docker/Dockerfile.arm64.test \
  -t adsw_monitor:arm64-test .
```

또는 docker compose:

```bash
docker compose --profile test build adsw_monitor_arm64_test
```

**실행:**

```bash
docker run --rm --platform linux/arm64 \
  --security-opt seccomp=unconfined \
  --name adsw_monitor_arm64_test \
  adsw_monitor:arm64-test
```

> `--security-opt seccomp=unconfined` 필수: QEMU arm64 환경에서 Flutter Dart VM이 `clone` 계열 syscall을 사용하는데,
> Docker 기본 seccomp 프로파일이 이를 차단하여 `thread::join failed: Resource deadlock avoided` 크래시가 발생합니다.

또는 docker compose (seccomp 설정 포함):

```bash
docker compose --profile test run --rm adsw_monitor_arm64_test
```

**정상 실행 시 로그:**

```
[INFO] Weston 시작 완료 (PID=14)
[I] (0) Loading AOT: /usr/share/flutter/adsw_monitor/3.32.2/release/lib/libapp.so
[config] loaded: ...
```

---

## 4. config.json 변경

rosbridge URL 또는 상태 토픽을 변경할 때 사용합니다.

```bash
# 현재 설정 확인
python3 tools/config_tool.py show

# URL 변경 후 컨테이너 재시작
python3 tools/config_tool.py set --ros-url ws://192.168.1.10:9090 --restart

# 토픽 변경
python3 tools/config_tool.py set --status-topic /my/topic
```

config.json은 컨테이너에 볼륨 마운트되어 있으므로, 호스트 파일 수정 후 컨테이너를 재시작하면 반영됩니다.

---

## 5. 전체 빌드 파이프라인 요약

```
소스 코드
   │
   ├─ [x86_64]─ docker compose --profile build run --rm adsw_monitor_builder_x86
   │                └─> output/adsw_monitor-x86_64-release.tar.gz
   │                         │
   │             docker compose build adsw_monitor
   │                         └─> adsw_monitor:x86_64 (런타임 이미지)
   │
   └─ [arm64] ─ docker compose --profile build run --rm adsw_monitor_builder_arm64
                    └─> output/adsw_monitor-arm64-release.tar.gz
                             │
                ┌────────────┴────────────┐
         AGL 디바이스용             QEMU 테스트용
   docker buildx build          docker build --platform linux/arm64
   -f Dockerfile.arm64           -f Dockerfile.arm64.test
         │                               │
   adsw_monitor:arm64          adsw_monitor:arm64-test
```

# adsw_monitor Docker 빌드 & 실행 가이드

> 이 문서는 **adsw_monitor 를 예시로 한 단계별 상세 가이드**입니다 (다른 앱도 서비스명만
> 바꿔 동일 패턴). **hmi_launcher 를 포함한 전체 앱의 빌드→설치→실행 요약과 launcher
> 특이사항**(APP_VERSION=3.32.5 고정, `--window-type BG`, path-dep 마운트 등)은
> [docs/build-install-run-guide.md](../../docs/build-install-run-guide.md) 를 먼저 보세요.
> 보드 기본 런처 등록: [board-default-launcher-setup.md](board-default-launcher-setup.md),
> 재부팅 자동시작: [docs/board-autostart-guide.md](../../docs/board-autostart-guide.md).

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

또는 직접 (NVIDIA GPU 환경):

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

> **NVIDIA GPU 필수**: X 서버가 NVIDIA 전용 GLX(NV-GLX)를 사용하므로 `--runtime=nvidia --gpus all` 없이는
> GLX 오류(`BadValue, request_code 152`)로 크래시가 발생합니다.

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

**실행 구조:**

```
┌─────────────────────────────────────────────────────────────┐
│                  x86_64 호스트                               │
│                                                             │
│  $ vncviewer localhost:5900  ──────────────────────────┐   │
│    (username: root / password: 임의)                    │   │
│                                                         │   │
│  ┌──────────────────────────────────────────────────┐   │   │
│  │  Docker 컨테이너 (linux/arm64, QEMU 에뮬레이션)   │   │   │
│  │                                                  │   │   │
│  │  agl-run-test.sh                                 │   │   │
│  │       │                                          │   │   │
│  │       ├─► Weston (VNC 백엔드, :5900) ────────────┼───┘   │
│  │       │      ▲  Wayland 소켓                     │       │
│  │       │      │  /run/user/1001/wayland-0         │       │
│  │       └─► flutter-auto (arm64, QEMU 실행)        │       │
│  │                │                                 │       │
│  │                ├─ libflutter_engine.so (AGL)     │       │
│  │                ├─ libapp.so (AOT 빌드 결과물)     │       │
│  │                └─ config.json (rosbridge URL)    │       │
│  └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

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

**실행 (헤드리스 — 로그만 확인):**

```bash
docker run --rm --platform linux/arm64 \
  --security-opt seccomp=unconfined \
  --name adsw_monitor_arm64_test \
  adsw_monitor:arm64-test
```

**실행 (VNC — UI 화면 확인):**

터미널 1 — 컨테이너 시작:

```bash
VNC_PORT=5900 docker compose --profile test run --rm adsw_monitor_arm64_test
```

터미널 2 — VNC 접속:

```bash
vncviewer localhost:5900
# username: root  /  password: 아무거나 (예: 1234)
```

> **VNC 인증**: Weston VNC 백엔드는 VeNCrypt X509Plain (TLS + username/password)만 지원합니다.
> username은 컨테이너 내 실제 시스템 사용자(`root`)를 입력해야 합니다.
> password는 PAM bypass로 인해 **어떤 값이든 허용**됩니다.
> VNC 뷰어에서 username=`root`, password=임의 문자열을 입력하세요.

> **VNC를 사용하는 이유**: arm64 QEMU 컨테이너에서 호스트 X11 SHM(MIT-SHM 확장)을 사용할 수 없어
> X11 백엔드 렌더링이 불가합니다. VNC 백엔드(neatvnc)는 네트워크 프로토콜을 사용하므로 SHM 없이 작동합니다.

> **`--security-opt seccomp=unconfined` 필수**: QEMU arm64에서 Flutter Dart VM의 `clone` syscall을
> Docker 기본 seccomp이 차단하여 `thread::join failed: Resource deadlock avoided` 크래시 발생.

> **앱 렌더링 지연**: VNC 연결 후 앱 UI가 표시되기까지 약 10~20초가 소요됩니다 (QEMU 소프트웨어 렌더링).
> 처음에는 Weston 배경 화면만 보이다가 잠시 후 AD SW Monitor 앱 창이 나타납니다.

또는 docker compose (헤드리스):

```bash
docker compose --profile test run --rm adsw_monitor_arm64_test
```

docker compose로 VNC:

```bash
VNC_PORT=5900 docker compose --profile test run --rm adsw_monitor_arm64_test
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

---

## 6. 레지스트리 push (registry.obigo.com)

빌드한 런타임 이미지를 사내 레지스트리 `registry.obigo.com` 에 올려 보드/타 머신에서
pull 해 쓰는 절차입니다. 네임스페이스 관례: **`registry.obigo.com/oss/<image>`**
(예: `oss/oss-hmi-launcher`, `oss/adsw_monitor`).

> 아래 예시는 `oss-hmi-launcher` (arm64) 기준. 다른 앱도 이미지명만 바꿔 동일하게 적용.
> arm64 이미지를 x86_64 호스트에서 push 하려면 buildx(+QEMU) 필요.

### 6-1. 로그인 (최초 1회 / 캐시 만료 시)

```bash
docker login registry.obigo.com        # username / password 입력
# 성공하면 ~/.docker/config.json 의 auths 에 캐시됨 → 이후 생략 가능
```

### 6-2. 빌드 + push (버전 + latest 동시) — 권장

buildx `--push` 는 빌드와 레지스트리 업로드를 한 번에 처리합니다(로컬 load 불필요).

```bash
cd apps
docker buildx build --builder mmf-buildx --platform linux/arm64 \
  -f docker/Dockerfile.arm64 \
  --build-arg APP_NAME=hmi_launcher \
  --build-arg APP_VERSION=3.32.5 \
  --build-arg CONFIG_FILE=launcher_config.json \
  -t registry.obigo.com/oss/oss-hmi-launcher:3.32.12 \
  -t registry.obigo.com/oss/oss-hmi-launcher:latest \
  --push .
```

> `APP_VERSION`(번들 경로 결정, 보드 flutter 엔진 버전) 과 이미지 **태그**(`3.32.12`)는
> 서로 별개다. `:latest` 는 포인터 태그라 새 버전 push 시 함께 갱신해야 최신이 유지된다.

### 6-3. 빌드 + push (분리) — 로컬 이미지를 tag 후 push

이미 로컬에 런타임 이미지가 있을 때:

```bash
# 로컬 이미지(태그 없음) → 레지스트리 태그 부여
docker tag oss-hmi-launcher:3.32.12 registry.obigo.com/oss/oss-hmi-launcher:3.32.12
docker tag oss-hmi-launcher:3.32.12 registry.obigo.com/oss/oss-hmi-launcher:latest

# push (개별 또는 모든 태그)
docker push registry.obigo.com/oss/oss-hmi-launcher:3.32.12
docker push registry.obigo.com/oss/oss-hmi-launcher:latest
# 또는 한 번에:
docker push --all-tags registry.obigo.com/oss/oss-hmi-launcher
```

### 6-4. push 결과 검증 (pull 없이)

```bash
docker buildx imagetools inspect registry.obigo.com/oss/oss-hmi-launcher:latest
docker manifest inspect registry.obigo.com/oss/oss-hmi-launcher:3.32.12   # arm64 확인
```

### 6-5. 보드/타 머신에서 pull & 실행

```bash
docker pull registry.obigo.com/oss/oss-hmi-launcher:latest

# run 스크립트의 IMAGE= 로 지정 (일반 / AI 제외)
IMAGE=registry.obigo.com/oss/oss-hmi-launcher:latest APP_VER=3.32.5 sh run-on-board-arm64.sh
IMAGE=registry.obigo.com/oss/oss-hmi-launcher:latest APP_VER=3.32.5 sh run-on-board-no-ai.sh
```

### 6-6. 관리 / 정리

```bash
docker images registry.obigo.com/oss/oss-hmi-launcher     # 로컬 태그 목록
docker rmi registry.obigo.com/oss/oss-hmi-launcher:3.32.12 # 로컬 태그 제거(레지스트리 무관)
docker buildx prune -f                                     # buildx 캐시 정리
docker logout registry.obigo.com
```


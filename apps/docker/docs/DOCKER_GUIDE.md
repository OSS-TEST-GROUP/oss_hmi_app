# adsw_monitor Docker 빌드 & 실행 가이드

> 이 문서는 **adsw_monitor 를 예시로 한 단계별 상세 가이드**입니다 (다른 앱도 서비스명만
> 바꿔 동일 패턴). **hmi_launcher 를 포함한 전체 앱의 빌드→설치→실행 요약과 launcher
> 특이사항**(APP_VERSION=3.32.5 고정, `--window-type BG`, path-dep 마운트 등)은
> [docs/build-install-run-guide.md](../../../docs/build-install-run-guide.md) 를 먼저 보세요.
> 보드 기본 런처 등록: [board-default-launcher-setup.md](board-default-launcher-setup.md),
> 재부팅 자동시작: [docs/board-autostart-guide.md](../../../docs/board-autostart-guide.md).

## 개요

| 파일 | 역할 |
|------|------|
| `Dockerfile.build` | x86_64 Flutter Linux 빌드 이미지 |
| `Dockerfile.build.arm64` | arm64 AGL AOT 빌드 이미지 (AGL Yocto SDK 사용) |
| `Dockerfile` | x86_64 런타임 이미지 (GTK 기반) |
| `Dockerfile.arm64` | arm64 런타임 이미지 (flutter-auto, AGL 디바이스용) |
| `Dockerfile.arm64.test` | arm64 테스트 이미지 (QEMU + Weston 헤드리스, x86_64 호스트 테스트용) |
| `compose/docker-compose.yml` | 전체 서비스 구성 |

모든 `docker` / `docker compose` 명령은 **`apps/` 디렉토리에서 실행**합니다.

```bash
cd apps/
```

---

## 1. x86_64 빌드 & 실행

### 1-1. 빌더 이미지 — **레지스트리에서 pull** (직접 빌드 불필요)

빌더(툴체인) 이미지는 `registry.obigo.com/oss/oss-hmi-builder` 에 올라가 있다.
태그가 곧 툴체인 신분이다:

| 태그 | 내용 | 크기 |
|---|---|---|
| `x86-flutter3.32.5` | Flutter 3.32.5 (Linux GTK 번들 빌드용) | 2.2 GB |
| `agl20.0.3-flutter3.32.5` | 위 + AGL SDK 20.0.3 (arm64 AOT 크로스빌드) | 14 GB |

```bash
cd apps
docker compose -f docker/compose/docker-compose.yml pull hmi_launcher_builder_x86
docker compose -f docker/compose/docker-compose.yml pull hmi_launcher_builder_arm64
```

**arm64 도 AGL SDK 자격증명이 필요 없다** — SDK 가 이미지에 들어 있다.
`AGL_SDK_PASSWORD` 는 아래 "툴체인 재생성" 때만 쓴다.

> **왜 레지스트리로 옮겼나** (2026-08-18): 예전엔 4 앱 × 2 아키가 **같은 이미지를
> 8 개 이름으로 각자 빌드**했고(로컬 2.2GB×4 + 14GB×4), 툴체인 변경이 커밋으로만
> 전파돼 낡은 이미지를 가진 사람은 옛 SDK 로 계속 빌드했다. Flutter 핀을 3.32.5 로
> 맞춘 뒤에도 3.41.8 이미지를 쓰면 `pubspec.lock` 이 거부돼 빌드가 실패하는데, 그
> 원인이 "내 이미지가 낡았다"라는 걸 알아채기 어렵다. 이제 커밋의 `image:` 태그가
> 툴체인을 지목하므로 그 불일치 자체가 생기지 않는다.

### 1-1b. 툴체인 재생성 (관리자 — Flutter/AGL SDK 버전 올릴 때만)

AGL SDK 취득 경로는 **기본이 Nexus** 이고 S3 는 선택이다:

| `AGL_SDK_SOURCE` | 받는 곳 | 필요한 인증 |
|---|---|---|
| `nexus` (기본) | `repo.obigo.com` | `AGL_SDK_USER` / `AGL_SDK_PASSWORD` |
| `s3` | `s3://oss-artifact` | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` |

둘 다 같은 SDK(20.0.3)를 받으므로 만들어지는 이미지 내용은 동일하다.

```bash
cd apps
# 1) Dockerfile.build{,.arm64} 의 ARG FLUTTER_VERSION (+ SDK URL) 갱신
# 2) 새 태그로 이미지 생성
AGL_SDK_PASSWORD=... docker compose -f docker/compose/docker-compose.yml \
  --profile toolchain build hmi_builder_image_x86 hmi_builder_image_arm64
# 3) push (태그는 compose 의 image: 와 같아야 한다)
docker push registry.obigo.com/oss/oss-hmi-builder:x86-flutter3.32.5
docker push registry.obigo.com/oss/oss-hmi-builder:agl20.0.3-flutter3.32.5
# 4) compose 의 앱 빌더 image: 태그 12 곳 + pubspec.lock 재생성을 **같은 커밋에** 담는다
```

**S3 에서 받으려면** `AGL_SDK_SOURCE=s3` 로 바꾸고 AWS 키를 준다:

```bash
cd apps
AGL_SDK_SOURCE=s3 \
AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_DEFAULT_REGION=ap-northeast-2 \
docker compose -f docker/compose/docker-compose.yml \
  --profile toolchain build hmi_builder_image_arm64
```

compose 없이 직접 빌드할 때:

```bash
cd apps
docker build -f docker/dockerfile/Dockerfile.build.arm64 \
  --build-arg AGL_SDK_SOURCE=s3 \
  --build-arg AWS_ACCESS_KEY_ID=... \
  --build-arg AWS_SECRET_ACCESS_KEY=... \
  -t registry.obigo.com/oss/oss-hmi-builder:agl20.0.3-flutter3.32.5 ..
```

> ⚠️ 호스트의 `~/.aws/credentials` 는 **빌드 컨테이너로 상속되지 않는다** — 키를
> build-arg(또는 위 compose env)로 직접 넘겨야 한다. 다른 버킷/경로를 쓸 때는
> `--build-arg AGL_SDK_S3_URL=s3://…` 로 바꾼다(Nexus 쪽은 `AGL_SDK_URL`).
>
> `AGL_SDK_SOURCE` 에 `nexus`/`s3` 외의 값을 주면 그 자리에서 중단된다.
> 자격증명이 비어 있으면 각 경로에 맞는 안내가 출력된다(실측: 0.15 초에 중단).

### 1-1c. (참고) 예전 방식 — 로컬 빌드

```bash
docker compose -f docker/compose/docker-compose.yml --profile build build adsw_monitor_builder_x86
```

또는 직접:

```bash
docker build -f docker/dockerfile/Dockerfile.build -t adsw_monitor_builder:x86_64 .
```

### 1-2. 앱 빌드 (Flutter Linux GTK 번들 생성)

```bash
docker compose -f docker/compose/docker-compose.yml --profile build run --rm adsw_monitor_builder_x86
```

또는 직접:

```bash
docker run --rm \
  -v $(pwd)/adsw_monitor:/workspace/app \
  -v $(pwd)/output:/workspace/output \
  adsw_monitor_builder:x86_64
```

결과물: `output/adsw_monitor-x86_64-release.tar.gz`

> **⚠️ pubspec.lock 은 빌더 안에서만 갱신한다** (2026-08-18 확정)
>
> 빌드는 `flutter pub get --enforce-lockfile` 로 돌아간다 — lock 을 **고쳐 쓰지 않고**,
> 커밋된 lock 으로 풀리지 않으면 그 자리에서 실패한다. 의존성을 추가·변경했다면:
>
> ```bash
> cd apps && docker compose -f docker/compose/docker-compose.yml --profile build \
>   run --rm --entrypoint bash <APP>_builder_x86 \
>   -c 'cd /workspace/apps/<APP> && flutter pub get'
> git add <APP>/pubspec.lock && git commit -m "build(<APP>): pubspec.lock 갱신"
> ```
>
> **로컬에서 `dart pub get` 으로 만들지 말 것** — Flutter SDK 가 핀으로 묶는
> `analyzer`/`_fe_analyzer_shared`/`meta`/`test_api` 를 보지 않아 빌더와 어긋난다.
> 이 상태였을 때 pub 이 매 빌드마다 lock 을 되돌려 써서 워크트리를 더럽혔고, 그 변경이
> 이미지 빌드의 재현성 가드에 **원인과 무관해 보이는 자리에서** 걸렸다(8 앱 중 6 개가 해당).
> **Flutter 버전은 AGL SDK/보드와 같아야 한다(3.32.5)** — 이게 근본 원인이었다.
> arm64 AOT 는 `create_aot_with_yocto_sdk.py` 가 PATH 앞에 **AGL SDK 의 Flutter
> (3.32.5 / Dart 3.8.1, 보드 `/usr/share/flutter/3.32.5` 와 동일)** 를 끼워 넣고 돌리고,
> x86 번들은 이미지의 `/opt/flutter` 를 쓴다. 이 둘이 다르면(예전 `/opt/flutter`=3.41.8)
> 서로의 lock 을 거부해 **빌드마다 30 줄씩 왕복**한다. 지금은 `ARG FLUTTER_VERSION=3.32.5`
> 로 정렬했고, x86·arm64 두 경로 모두 `--enforce-lockfile` 로 검증한다.
>
> ⚠️ `os.putenv` 는 `os.environ` 을 갱신하지 않으므로 스크립트 안에서 `which flutter` 를
> 찍어도 `/opt/flutter` 가 나온다 — **버전 확인은 실제 빌드 로그의 해석 결과로** 하라.
>
> 관련: arm64 번들은 x86 빌더가 만든 `<APP>/build/flutter_assets` 를 쓴다 →
> **x86 을 먼저** 돌려야 하고, 이전 실패가 남긴 `<APP>/temp/` 가 있으면
> `mkdir data lib` 충돌로 또 실패한다.

### 1-3. 런타임 이미지 생성

```bash
docker compose -f docker/compose/docker-compose.yml build adsw_monitor
```

또는 직접:

```bash
docker build -f docker/dockerfile/Dockerfile -t adsw_monitor:x86_64 .
```

### 1-4. 실행

```bash
docker compose -f docker/compose/docker-compose.yml up adsw_monitor
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

### 1-5. 다른 PC 에서 hmi_launcher amd64 실행 (run-hmi-x86.sh)

임의의 x86_64 리눅스 PC 에서 `oss-hmi-launcher` amd64 이미지를 실행할 때는
[docker/script/run-hmi-x86.sh](../script/run-hmi-x86.sh) 를 쓴다. 코드 변경 없이
**런타임 설정만** 흡수한다 — rosbridge URL / DISPLAY / uid / GPU / 런처봇.

```bash
# 로컬에 MMF(rosbridge :9090)가 있는 PC — 그대로
bash docker/script/run-hmi-x86.sh

# 보드의 rosbridge 로 연결
ROSBRIDGE_URL=ws://172.16.10.151:9090 bash docker/script/run-hmi-x86.sh

# 비-NVIDIA PC (소프트웨어 GL) / NVIDIA 강제
GPU=none   bash docker/script/run-hmi-x86.sh
GPU=nvidia bash docker/script/run-hmi-x86.sh   # nvidia-container-toolkit 필요
```

다른 PC 로 옮길 때 실제로 달라지는 지점:

| 항목 | 기본(전제) | 다른 PC |
|---|---|---|
| rosbridge URL | `ws://localhost:9090` | `ROSBRIDGE_URL` 로 대상 지정 (로컬 MMF 있으면 그대로) |
| DISPLAY | `$DISPLAY`(없으면 `:0`) | 그 PC 의 실제 디스플레이. 스크립트가 `xhost +local:` 자동 실행 |
| uid / XDG_RUNTIME_DIR | `id -u` 자동 | 로그인 사용자 uid 자동 반영 (`/run/user/<uid>`) |
| Xauthority | 불필요 | `xhost +local:` 로 대체(GDM 전용 경로 마운트 제거) |
| GPU | `auto`(nvidia 감지) | 비-NVIDIA 는 mesa 소프트웨어 GL 폴백 |
| 런처봇(AI) | `LAUNCHER_BOT_ENABLED=0` | 데몬 있으면 `LAUNCHER_BOT=1 AGENT_HOST=.. AGENT_PORT=..` |
| **docker 소켓** | 자동 마운트(`/var/run/docker.sock` + docker gid) | 소켓 없으면 건너뛰고 안내 — **rviz2_panel 의 Start/Stop 이 이 소켓을 쓴다** |

#### x86 에서 rviz2_panel 로 rviz2 컨테이너 띄우기

되는 것과 안 되는 것이 갈린다 — **컨테이너 수명 관리는 되고, 화면 배치는 안 된다.**

| 기능 | 보드(arm64) | x86 |
|---|---|---|
| Start / Stop / 상태 / docker logs | ✅ | ✅ (소켓 필요 — 위 표) |
| rviz2 표출 | cage + 패널 영역 배치 | **독립 X 윈도우** (WM 이 배치) |
| `View rviz2` / 홈버튼 | ✅ | ❌ — agl-compositor 가 없어 agl-shell gRPC 호출이 무효 |

x86 에서는 패널 설정(영구 저장) 카드에서 **`dockerRunArgs` 를 X11 세트로 바꿔야 한다**.
보드 기본값은 cage/wayland 전용이라 그대로 쓰면 rviz2 가 표시 경로를 못 찾는다:

```
--net=host
-e DISPLAY=:0
-v /tmp/.X11-unix:/tmp/.X11-unix
-e LIBGL_ALWAYS_SOFTWARE=1
```

> · `--user 1001:1001` 은 cage 전용이므로 **빼도 된다**(x11 모드는 cage 를 건너뛴다).
> · X 인증이 막히면(`Authorization required, but no authorization protocol specified`)
>   호스트에서 `xhost +local:docker` 를 주거나 `-v <Xauthority>:/root/.Xauthority:ro` 를 추가한다.
> · `image` 는 `…-amd64` 접미 태그를 직접 지정하는 편이 안전하다 — 멀티아치 `:latest` 는
>   로컬 캐시 상태에 따라 arm64 가 잡혀 QEMU 로 느리게 돌 수 있다(실측 2026-09-09).
> · 저장하면 `$XDG_CONFIG_HOME/rviz2_panel/config.json` 에 남아 재기동 후에도 유지된다.

패널을 거치지 않고 rviz2 만 x86 에서 띄워볼 때는 [`docker/script/run-rviz2-x86.sh`](../script/run-rviz2-x86.sh)
가 더 간단하다 — GPU 자동 판정(`GPU=nvidia|none`), `xhost +local:`, `domain.env` 도메인 승계를 해준다.
단 이 스크립트는 `--entrypoint bash` 로 **entrypoint 를 우회**하므로 오버레이·vehicle_info 파라미터
주입 같은 보드와 동일한 초기화는 타지 않는다. 그 초기화가 필요하면 위 `docker run` 경로를 쓴다.

> compose(`docker-compose.yml`)의 x86 서비스는 NVIDIA + GDM 세션(uid 1000)을 전제로
> 하드코딩돼 있어 다른 PC 에 그대로 쓰기 어렵다. 이식은 이 스크립트를 사용한다.

---

## 2. arm64 빌드

### 2-1. 빌드 이미지 생성

AGL Yocto SDK를 AWS S3에서 다운로드하여 설치합니다 (약 10-15분 소요).
*(AWS CLI 인증이 설정되어 있지 않은 경우 `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` 환경변수 또는 `--build-arg`로 전달해야 합니다.)*

```bash
# 사전 `aws configure` 로그인이 되어있거나 환경변수가 주입된 경우
AWS_ACCESS_KEY_ID="..." AWS_SECRET_ACCESS_KEY="..." \
  docker compose -f docker/compose/docker-compose.yml --profile toolchain build hmi_builder_image_arm64
```

또는 `docker build` 직접 실행 시:

```bash
docker build \
  --build-arg AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  --build-arg AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  -f docker/dockerfile/Dockerfile.build.arm64 \
  -t adsw_monitor_builder:arm64 .
```

### 2-2. 앱 빌드 (arm64 AOT 크로스컴파일)

```bash
docker compose -f docker/compose/docker-compose.yml --profile build run --rm adsw_monitor_builder_arm64
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
  -f docker/dockerfile/Dockerfile.arm64 \
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
bash docker/script/extract-agl-binaries.sh
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
  -f docker/dockerfile/Dockerfile.arm64.test \
  -t adsw_monitor:arm64-test .
```

또는 docker compose:

```bash
docker compose -f docker/compose/docker-compose.yml --profile test build adsw_monitor_arm64_test
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
> 처음에는 Weston 배경 화면만 보이다가 잠시 후 ADSW Monitor 앱 창이 나타납니다.

또는 docker compose (헤드리스):

```bash
docker compose -f docker/compose/docker-compose.yml --profile test run --rm adsw_monitor_arm64_test
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

> **레지스트리 계정 — `ossuser` 단일 계정으로 pull·push**: registry.obigo.com(Harbor) 는
> **`ossuser` 계정 하나로 pull·push 를 모두** 수행한다. `docker login registry.obigo.com
> -u ossuser` 후 `--push`/`docker push` 가 그대로 동작한다(별도 push 계정·로그인 전환 불필요).
> - **builder 등 관리자 권한 계정은 쓰지 않는다.**
> - CI(Jenkins/Actions)에서도 ossuser 자격증명을 **secret/credentials 로 주입**(하드코딩 금지).

### 6-2. 빌드 + push (버전 + latest 동시) — 권장

buildx `--push` 는 빌드와 레지스트리 업로드를 한 번에 처리합니다(로컬 load 불필요).

```bash
cd apps
docker buildx build --builder mmf-buildx --platform linux/arm64 \
  -f docker/dockerfile/Dockerfile.arm64 \
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

---

## 7. 멀티아치(amd64 + arm64) 이미지 push / pull

§6 은 아키별 단일 이미지 절차다. 여기서는 **하나의 태그(`:latest` 등)에 amd64·arm64
두 이미지를 묶는 manifest list** 를 만들어, x86 dev 는 amd64 를, Orin 보드(aarch64)는
arm64 를 **자동으로** 받도록 하는 절차를 설명한다. (2026-07 Orin AGX 보드 검증 완료 — 보드가
`:latest` pull 시 arm64 자동 선택 → ext-agl 로 기동 확인.)

> **왜 `--platform=linux/amd64,linux/arm64` 한 방이 안 되나**: 런타임 이미지는 소스 컴파일이
> 아니라 아키별 **사전 빌드 번들**(`output/<APP>-x86_64-release.tar.gz` /
> `-arm64-release.tar.gz`)을 ADD 하고, Dockerfile 도 아키별로 다르다(`Dockerfile` vs
> `Dockerfile.arm64`). 단일 멀티플랫폼 빌드는 플랫폼별로 Dockerfile/번들을 바꿀 수 없으므로,
> **아키별로 각각 빌드·push → manifest list 로 결합**한다. (MMF `docker/build_multiarch.sh` 와 동일 패턴)

### 7-1. 스크립트 (권장)

```bash
cd apps
# :latest 로 amd64+arm64 멀티아치 push
TAG=latest ./docker/script/build_multiarch.sh
# 검증용 태그(:latest 미변경)
TAG=multiarch-verify ./docker/script/build_multiarch.sh
# 다른 앱
APP=adsw_monitor IMAGE=oss/oss-adsw-monitor ./docker/script/build_multiarch.sh
```

전제: 두 아키 번들이 `output/` 에 있어야 한다.

```bash
docker compose -f docker/compose/docker-compose.yml --profile build run --rm hmi_launcher_builder_x86    # → output/hmi_launcher-x86_64-release.tar.gz
docker compose -f docker/compose/docker-compose.yml --profile build run --rm hmi_launcher_builder_arm64  # → output/hmi_launcher-arm64-release.tar.gz
```

> 스크립트는 arm64 번들이 없으면 `-arm64-native-release.tar.gz` 로 폴백하고, `APP_VERSION`
> 은 번들 경로에서 자동 감지한다. 환경변수: `REGISTRY`/`APP`/`IMAGE`/`TAG`/`CONFIG_FILE`/`APP_VERSION`.

### 7-2. 수동 (스크립트 내부 동작)

```bash
cd apps
REG=registry.obigo.com/oss/oss-hmi-launcher

# 1) 아키별로 각각 빌드·push
docker buildx build --builder mmf-buildx --platform=linux/amd64 \
  -f docker/dockerfile/Dockerfile \
  --build-arg APP_NAME=hmi_launcher --build-arg CONFIG_FILE=launcher_config.json \
  --push -t ${REG}:latest-amd64 .

docker buildx build --builder mmf-buildx --platform=linux/arm64 \
  -f docker/dockerfile/Dockerfile.arm64 \
  --build-arg APP_NAME=hmi_launcher --build-arg APP_VERSION=3.32.5 --build-arg CONFIG_FILE=launcher_config.json \
  --push -t ${REG}:latest-arm64 .

# 2) manifest list 로 결합 (한 태그 = 두 아키)
docker buildx imagetools create -t ${REG}:latest ${REG}:latest-amd64 ${REG}:latest-arm64
```

### 7-3. push 결과 검증 (pull 없이)

```bash
docker buildx imagetools inspect registry.obigo.com/oss/oss-hmi-launcher:latest
# → Platform: linux/amd64 + linux/arm64 두 매니페스트 표시.
#   Platform: unknown/unknown 항목은 buildx attestation(provenance/SBOM) — 무해.
#   원치 않으면 buildx build 에 --provenance=false 추가.
```

### 7-4. pull

```bash
# ① 자동 — 호스트 아키에 맞게 (가장 흔함)
docker pull registry.obigo.com/oss/oss-hmi-launcher:latest
#   x86 dev  → amd64 이미지 자동 수신
#   Orin 보드(aarch64) → arm64 이미지 자동 수신

# ② 특정 아키 강제 (예: x86 에서 arm64 받기)
docker pull --platform=linux/arm64 registry.obigo.com/oss/oss-hmi-launcher:latest

# ③ 받은 이미지 아키 확인
docker image inspect registry.obigo.com/oss/oss-hmi-launcher:latest --format '{{.Architecture}} {{.Os}}'
```

### 7-5. verify 태그 정리 (registry v2 API)

`docker rmi` 는 로컬만 지운다. **레지스트리의 태그**를 지우려면 v2 API 로 digest 를 얻어 DELETE 한다
(레지스트리에 delete 활성화 필요).

```bash
REG=registry.obigo.com; REPO=oss/oss-hmi-launcher
AUTH=$(python3 -c "import json;print(json.load(open('$HOME/.docker/config.json'))['auths']['registry.obigo.com']['auth'])")
ACCEPT="application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json"
DIGEST=$(curl -sI -H "Authorization: Basic $AUTH" -H "Accept: $ACCEPT" \
  "https://$REG/v2/$REPO/manifests/multiarch-verify" | tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}')
curl -s -o /dev/null -w "%{http_code}\n" -X DELETE -H "Authorization: Basic $AUTH" \
  "https://$REG/v2/$REPO/manifests/$DIGEST"   # 202 = 삭제 성공
```

> ⚠️ digest 삭제는 그 digest 를 가리키는 **모든 태그**를 제거한다. 삭제 전 `:latest` 등
> 실운영 태그와 digest 가 겹치지 않는지 확인할 것.

### 7-6. 보드에서 실행 (ext-agl 경유)

보드의 ext-agl(adsw_manager)이 `agl-service-list.yaml` 의 `image:` 를 `docker run` 한다.
멀티아치 `:latest` 로 바꾸려면 (config 는 host 마운트: `/opt/adsw/config/agl-service-list.yaml`):

```bash
ssh root@<board> '
  CFG=/opt/adsw/config/agl-service-list.yaml
  cp "$CFG" "${CFG}.bak-$(date +%Y%m%d%H%M%S)"          # 원복용 백업
  sed -i "s#^\( *image: \).*oss-hmi-launcher:.*#\1registry.obigo.com/oss/oss-hmi-launcher:latest#" "$CFG"
  docker pull registry.obigo.com/oss/oss-hmi-launcher:latest
  docker stop hmi_launcher && docker rm hmi_launcher     # 기존 컨테이너 제거(있어야 새 이미지로 재run)
  docker restart oss-mmf-ext-agl'                        # adsw 가 새 config 로 hmi_launcher 재기동
```

> 보드 화면 캡처(AGL Wayland): `XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 weston-screenshooter`


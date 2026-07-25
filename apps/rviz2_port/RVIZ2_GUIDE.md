# RViz2 on AGL (Orin) — 빌드 · 이미지 · 실행 · 사용 가이드

> `oss_hmi_app` 소스에서 RViz2를 NVIDIA Jetson Orin AGX 보드의 AGL(순수 Wayland) 위에서
> **hmi_launcher의 앱(RViz2 Monitor)** 으로 실행하기 위한 전체 가이드.
> 대상 실기: `root@172.16.10.162` (AGL 20.0.3 / L4T R36.4.4 / arm64).
>
> 최종 갱신: 2026-07-25 (F010 — direct-docker 제어 + 터치 + 홈버튼 + adsw 통합).

---

## 1. 개요 & 아키텍처

RViz2는 **컨테이너 격리** 방식으로 실행됩니다. 호스트 AGL 이미지는 불변이고, ROS2 Humble /
Qt5 / OGRE 스택 전체를 Docker 컨테이너 안에 격리합니다. 사용자는 hmi_launcher의
**RViz2 Monitor** 앱에서 rviz2를 켜고/끄고/화면을 봅니다.

```
agl-compositor (호스트, 순수 Wayland, agl-shell)
├─ agl-shell-grpc-server            # 127.0.0.1:14005 — 앱 활성화/float API
├─ hmi_launcher (flutter-auto)      # 런처. app_id=hmi_launcher
│   └─ RViz2 Monitor (rviz2_monitor, 내장 Flutter 앱)
│        └─ docker CLI + docker.sock 로 rviz2 컨테이너를 "직접" 제어
│           + agl-shell gRPC 로 화면 전환 (core/rosbridge 미사용)
├─ rviz2 컨테이너  (app_id=wlroots)  # RViz2 Monitor 의 Start 로 기동
│   └─ cage(중첩 wlroots 키오스크) ── XWayland ── rviz2 (Qt5/OGRE, SW-GL)
└─ homebar 컨테이너 (app_id=homebar) # rviz2 화면에서 런처로 돌아가는 플로팅 홈 버튼
```

**핵심 설계 결정**

- **컨테이너 격리** — 호스트 AGL 불변. rviz2 스택은 컨테이너 안.
- **cage(중첩 wlroots)** — weston 9는 `set_app_id` 미호출로 agl-shell이 활성화 못 함.
  cage는 `app_id="wlroots"` 설정 + 단일 앱 풀스크린. XWayland로 rviz2(X11/Qt5) 구동.
- **SW-GL(llvmpipe)** — `LIBGL_ALWAYS_SOFTWARE=1`. OGRE 1.12.1은 rviz-ogre-vendor 번들.
- **direct-docker 제어(F010)** — rviz2_monitor가 lfc_monitor처럼 core와 통신하지 않고,
  로컬 rviz2 컨테이너를 `docker run/stop/logs`로 직접 제어. 화면 전환은 agl-shell gRPC.

**app_id / 출력**: rviz2·cage=`wlroots`, 런처=`hmi_launcher`, 홈버튼=`homebar`, output=`DP-1`.

---

## 2. 구성 요소 & 소스 위치

| 구성 요소 | 경로 | 역할 |
|---|---|---|
| **rviz2-agl 컨테이너** | `apps/rviz2_port/docker/agl-display/` | rviz2 + cage + XWayland (아키 무관 이미지) |
| ├ `Dockerfile` | 〃 | 원본: `FROM ros:humble-ros-base` + apt(rviz2/cage/xwayland) |
| ├ `Dockerfile.touch` | 〃 | **터치 지원본(현재 배포)**: wlroots 0.16.2/cage 0.1.5/wayland 1.22 소스빌드 |
| ├ `entrypoint.sh` | 〃 | `cage -- ros2 run rviz2 rviz2` |
| └ `run-on-board.sh` | 〃 | 보드 수동 실행 (소켓 탐지 + docker run + activate) |
| **RViz2 Monitor 앱** | `apps/rviz2_monitor/` | hmi_launcher 내장 Flutter 앱 (rviz2 관제/제어) |
| ├ `lib/controller/rviz2_controller.dart` | 〃 | docker CLI + agl-shell gRPC 제어 로직 |
| └ `lib/view/rviz2_view_page.dart` | 〃 | 상태카드 + Start/Stop + logs + 화면보기 UI |
| **homebar (홈 버튼)** | `apps/rviz2_port/docker/homebar/` | rviz2 위 플로팅 "홈" 버튼 (런처 복귀) |
| **멀티아치 빌드 스크립트** | `apps/docker/script/build_rviz2_multiarch.sh` | rviz2-agl amd64+arm64 원샷 빌드+push |
| **x86 실행 스크립트** | `apps/docker/script/run-rviz2-x86.sh` | x86 개발 PC에서 rviz2 직접 실행 |
| **hmi_launcher 통합** | `apps/hmi_launcher/`, `apps/docker/` | rviz2_monitor를 내장한 런처 (별도 문서) |

> **레지스트리**: `registry.obigo.com`. 이미지 = `oss/rviz2-agl`(rviz2 컨테이너),
> `oss/oss-hmi-launcher`(rviz2_monitor 내장 런처). push 권한 계정 = **ossuser**.

---

## 3. 빌드

> ### 아키텍처(amd64 / arm64) 제공 현황 — 레지스트리 태그
> | 태그 | amd64 | arm64 | 내용 |
> |---|:-:|:-:|---|
> | **`oss/rviz2-agl:latest`** | base | **touch** | 멀티아치. amd64=표준, **arm64=터치 수정본** |
> | **`oss/rviz2-agl:touch`** | — | touch | arm64 터치 수정본(명시적 태그) |
>
> - **`:latest` 는 amd64 + arm64 둘 다 제공**되며, **arm64 는 터치 수정본**(wlroots 0.16.2/
>   cage 0.1.5)입니다. 따라서 arm64 보드가 `:latest` 를 pull하면 **터치되는 이미지**를 받습니다.
> - amd64 는 표준(base) 이미지입니다 — x86 개발은 host X11로 rviz2를 직접 띄워(cage 우회, §5-4)
>   중첩 wayland 터치 이슈가 없으므로 터치 수정본이 필요 없습니다.
> - 참고: `:latest` 는 `imagetools create` 로 [amd64 base manifest + arm64 :touch manifest]를
>   결합해 구성했습니다(§4-4). 표준 arm64 base 는 기존 digest 로 남아있으나 태그 없음.

### 3-1. rviz2-agl 컨테이너 — 표준(터치 미지원, amd64+arm64 멀티아치)

원본 Dockerfile은 아키 무관(`FROM ros:humble-ros-base`)이라 buildx 한 방으로 멀티아치 생성:

```bash
cd apps
./docker/script/build_rviz2_multiarch.sh                      # → registry.obigo.com/oss/rviz2-agl:latest
TAG=multiarch-verify ./docker/script/build_rviz2_multiarch.sh # 검증용(:latest 미변경)
```
> Flutter 앱과 달리 아키별 번들이 없어 `buildx --platform=amd64,arm64` 원샷으로 manifest
> list 생성 (2회 빌드 + imagetools 결합 불필요).

### 3-2. rviz2-agl 컨테이너 — 터치 지원본(현재 실기 배포본) ★

jammy 패키지 cage 0.1.4/wlroots 0.15.1은 **중첩 wayland 백엔드에서 터치를 전달하지 못합니다**
(마우스만 동작). 터치를 살리려면 wlroots 0.16.2(터치 전달) + cage 0.1.5 + wayland 1.22 +
seatd를 **소스 빌드**해야 합니다 → `Dockerfile.touch`.

QEMU 에뮬레이션은 매우 느리므로 **Orin 보드에서 네이티브 빌드**를 권장합니다:

```bash
# 보드에서 (arm64 네이티브, ~10분). 컨텍스트는 Dockerfile 만 있으면 됨(base 상속).
scp apps/rviz2_port/docker/agl-display/Dockerfile.touch root@172.16.10.162:/tmp/rviz2-touch/Dockerfile.touch
ssh root@172.16.10.162 'cd /tmp/rviz2-touch && docker build -f Dockerfile.touch -t rviz2-agl:touch .'
# 배포용 태그
ssh root@172.16.10.162 'docker tag rviz2-agl:touch registry.obigo.com/oss/rviz2-agl:latest'
```
> `Dockerfile.touch` 는 `FROM registry.obigo.com/oss/rviz2-agl:latest`(=3-1 표준 이미지) 위에
> wayland 1.22 → seatd → wlroots 0.16.2 → cage 0.1.5 를 소스 빌드한다. 옵션 요점:
> - wlroots `-Dxwayland=enabled` + `backends=auto`(hwdata/xcb-renderutil 없는 백엔드 자동 비활성)
> - wayland `-Db_ndebug=true` + 이미지 `STOPSIGNAL SIGKILL` → cage 종료 시 crash/hang 방지 (§7 참조)

### 3-3. homebar (플로팅 홈 버튼) — 보드 네이티브 빌드

```bash
DIR=apps/rviz2_port/docker/homebar
ssh root@172.16.10.162 'mkdir -p /tmp/homebar'
scp "$DIR"/{Dockerfile,homebar.c,agl_shell.proto,entrypoint.sh} root@172.16.10.162:/tmp/homebar/
ssh root@172.16.10.162 'cd /tmp/homebar && docker build -t homebar:latest .'
```
> homebar는 xdg_toplevel Wayland 앱(원형 반투명 홈 버튼) + grpcurl 포함. 자세한 동작은 §6-3.

### 3-4. RViz2 Monitor(rviz2_monitor) — hmi_launcher에 내장

`rviz2_monitor`는 hmi_launcher가 컴파일 시 path-dep로 포함하는 Flutter 앱입니다. 단독 빌드가
아니라 **hmi_launcher를 빌드**하면 함께 들어갑니다 (AGL SDK 크로스컴파일):

```bash
cd apps
# arm64 번들 (AGL Yocto SDK 크로스컴파일, 계정 ossdev/ossdev1234)
AGL_SDK_USER=ossdev AGL_SDK_PASSWORD=ossdev1234 USER_UID=$(id -u) USER_GID=$(id -g) \
  docker compose -f docker/compose/docker-compose.yml --profile build run --rm hmi_launcher_builder_arm64
# → output/hmi_launcher-arm64-release.tar.gz  (rviz2_monitor path-dep 포함)
```
> hmi_launcher 이미지 빌드/배포는 hmi_launcher 문서 참조. rviz2_monitor 변경 시 이 번들을
> 재빌드해야 반영됨.

---

## 4. 이미지 생성 & push / pull

### 4-1. 레지스트리 로그인 (push 권한)

```bash
printf '%s' '<PASSWORD>' | docker login registry.obigo.com -u ossuser --password-stdin
```
> 기본 캐시 토큰은 **pull 전용**입니다. push하려면 push 권한 계정(ossuser)으로 로그인.

### 4-2. push

```bash
# rviz2-agl 표준(멀티아치)은 build_rviz2_multiarch.sh 가 자동 push (§3-1)
# 터치 지원본을 push (arm64 단독)
docker buildx build --builder hmi-buildx --platform=linux/arm64 \
  -f apps/rviz2_port/docker/agl-display/Dockerfile.touch \
  --push -t registry.obigo.com/oss/rviz2-agl:latest apps/rviz2_port/docker/agl-display
```

### 4-3. pull (보드) — 또는 save/load

```bash
# 보드가 레지스트리 pull 가능한 경우
ssh root@172.16.10.162 'docker pull registry.obigo.com/oss/rviz2-agl:latest'

# push 권한이 없을 때: 로컬 빌드 → save → scp → load
docker buildx build --platform=linux/arm64 -f Dockerfile.touch --load -t registry.obigo.com/oss/rviz2-agl:latest .
docker save registry.obigo.com/oss/rviz2-agl:latest | gzip -1 > rviz2.tar.gz
scp rviz2.tar.gz root@172.16.10.162:/tmp/
ssh root@172.16.10.162 'gunzip -c /tmp/rviz2.tar.gz | docker load'
```

> **중요**: 보드의 adsw_manager는 이미지를 **재-pull 하지 않고 로컬 이미지를 사용**합니다.
> 따라서 보드에서 `docker build` 하거나 `docker load` 한 뒤 `docker tag ... :latest` 만 하면
> 즉시 반영됩니다(레지스트리 필수 아님).

### 4-4. arm64 터치본을 `:latest` 의 arm64 로 편입 (멀티아치 유지)

`:latest` 는 멀티아치(amd64+arm64)라 arm64 터치본을 그냥 push하면 amd64가 사라집니다.
대신 arm64 터치본을 `:touch` 로 push한 뒤, `imagetools create` 로 amd64(base)+arm64(touch)를
결합해 `:latest` 를 재구성합니다:

```bash
# 1) 보드에서 arm64 터치본을 :touch 로 push (ossuser 로그인 후)
ssh $BOARD 'docker tag registry.obigo.com/oss/rviz2-agl:latest registry.obigo.com/oss/rviz2-agl:touch \
  && docker push registry.obigo.com/oss/rviz2-agl:touch'

# 2) 현재 :latest 의 amd64 digest 확인
docker buildx imagetools inspect registry.obigo.com/oss/rviz2-agl:latest \
  --format '{{range .Manifest.Manifests}}{{.Platform.OS}}/{{.Platform.Architecture}} {{.Digest}}{{println}}{{end}}'

# 3) :latest = amd64(base digest) + arm64(:touch) 로 재구성
docker buildx imagetools create -t registry.obigo.com/oss/rviz2-agl:latest \
  registry.obigo.com/oss/rviz2-agl@sha256:<amd64-base-digest> \
  registry.obigo.com/oss/rviz2-agl:touch
```

---

## 5. 배포 & 실행

### 5-1. 보드 자동 기동 (adsw / ext-agl)

부팅 시 `oss-mmf-ext-agl` 컨테이너의 adsw_manager가 `/opt/adsw/config/agl-service-list.yaml`을
읽어 서비스를 자동 기동합니다. **현재 등재**: `hmi_launcher`, `homebar`.
(rviz2는 adsw가 관리하지 않음 — rviz2_monitor가 직접 기동.)

homebar 서비스 항목 예 (repo: `oss_multisw_framework .../agl-service-list.yaml`):
```yaml
- name: homebar
  recovery_policy: ALWAYS
  is_enabled: true
  image: homebar:latest        # 보드 로컬 빌드본
  extra_args: [--network, host, --user, 1001:1001,
    -v, /run/user/1001:/host-xdg, -e, XDG_RUNTIME_DIR=/host-xdg, -e, WAYLAND_DISPLAY=wayland-0]
```
> hmi_launcher 항목은 docker.sock 마운트 + `--group-add 999`(docker 그룹) 필요 —
> rviz2_monitor가 컨테이너 안에서 docker CLI로 rviz2를 제어하기 위함.

부팅 재현/검증:
```bash
ssh root@172.16.10.162 'systemctl reboot'      # 컴포지터/adsw/앱 전부 재기동
# 복귀 후: docker ps → hmi_launcher + homebar + oss-mmf-ext-agl 자동 기동, homebar는 숨김 상태
```

### 5-2. rviz2 실행 (사용자 흐름 — 권장)

보드 화면에서:
1. 런처 홈 → **RViz2 Monitor** 타일 탭
2. **Start** → rviz2_monitor가 `docker run` 으로 rviz2 컨테이너 기동
3. **rviz2 화면 보기** → agl-shell gRPC `ActivateApp(wlroots)` 로 rviz2 전면 표시 + 홈버튼 등장
4. **홈 버튼(우상단)** 탭 → 런처로 복귀 (+ 홈버튼 숨김)

rviz2_monitor가 실행하는 실제 명령(참고):
```bash
docker run -d --name rviz2 --net=host --ipc=host --user 1001:1001 --group-add 44 \
  -v /run/user/1001:/host-xdg -e XDG_RUNTIME_DIR=/host-xdg -e WAYLAND_DISPLAY=wayland-0 \
  -e HOME=/tmp -e LIBGL_ALWAYS_SOFTWARE=1 [-e ROS_DOMAIN_ID=<n>] \
  registry.obigo.com/oss/rviz2-agl:latest
# 화면 전환: agl-shell gRPC 127.0.0.1:14005 AglShellManagerService/ActivateApp {app_id:"wlroots", output_name:"DP-1"}
```

### 5-3. rviz2 수동 실행 (보드, 디버그용)

```bash
ssh root@172.16.10.162
export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0
bash /path/to/run-on-board.sh          # 소켓 탐지 + docker run + agl-shell activate
# 또는 직접
agl-shell-activator -a activate -p wlroots -o DP-1     # 표출
agl-shell-activator -a activate -p hmi_launcher -o DP-1 # 런처 복귀
```

### 5-4. x86 개발 PC 실행 (cage 우회, 호스트 X11)

```bash
cd apps
GPU=nvidia bash docker/script/run-rviz2-x86.sh    # NVIDIA GLX (nvidia-container-toolkit 필요)
GPU=none   bash docker/script/run-rviz2-x86.sh    # SW-GL(llvmpipe)
```

---

## 6. 사용 가이드 (RViz2 Monitor 앱)

### 6-1. 화면 구성

- **좌: 상태 카드** — rviz2 컨테이너 상태(running/stopped/exit code), Start/Stop, "rviz2 화면 보기",
  "홈으로", 새로고침. 그 아래 Run Options(ROS_DOMAIN_ID / .rviz config 경로 — 다음 Start에 적용).
- **우: docker logs** — rviz2 컨테이너 로그 실시간(tail 300 + follow).

### 6-2. 동작

| 버튼 | 동작 |
|---|---|
| Start | `docker run` 으로 rviz2 기동 → 자동으로 화면 전환 + 홈버튼 표시 |
| Stop | `docker stop` 으로 rviz2 정지 (즉시, §7 STOPSIGNAL) + 홈버튼 숨김 |
| rviz2 화면 보기 | agl-shell `ActivateApp(wlroots)` → rviz2 전면 + 홈버튼 표시 |
| 홈으로 | agl-shell `ActivateApp(hmi_launcher)` → 런처 + 홈버튼 숨김 |

- **터치**: rviz2 3D 뷰 회전/툴바 조작 모두 터치로 동작 (wlroots 0.16 터치 전달).

### 6-3. 홈 버튼 (homebar)

- rviz2 전면 표시 중 **우상단에 뜨는 원형 반투명 버튼**. 탭하면 런처로 복귀.
- **rviz2에서만 표시, 런처에서는 숨김** — homebar는 foreground 앱을 스스로 알 수 없어,
  rviz2_monitor가 화면 전환 시 gRPC로 표시(ActivateApp+SetAppFloat+SetAppPosition)/
  숨김(DeactivateApp)을 제어. 홈버튼 탭 자체도 런처 활성화 + 자기 숨김.
- 위치/크기/투명도는 `homebar.c`(`BTN_W/BTN_H`, `fill` alpha) + `entrypoint.sh`(`HOMEBAR_X/Y`)에서 조정.
- 부팅 자동 표시가 안 될 경우(누적 상태): `sh /opt/adsw/homebar-up.sh` 재실행 또는 재부팅.

---

## 7. 트러블슈팅 & 알려진 이슈

| 증상 | 원인 / 해결 |
|---|---|
| **터치 미동작(마우스만)** | cage 0.1.4/wlroots 0.15.1의 중첩 wayland 백엔드가 터치 미전달. → `Dockerfile.touch`(wlroots 0.16.2/cage 0.1.5)로 해결. |
| **docker.sock permission denied** (rviz2_monitor) | 컨테이너 uid 1001이 docker 그룹 아님. → hmi_launcher extra_args에 `--group-add 999`(docker gid; `stat -c %g /var/run/docker.sock`로 확인). |
| **화면 전환 안 됨** | agl-shell-grpc-server(:14005) 확인. `--net=host`라 컨테이너에서 127.0.0.1:14005 도달. rviz2 컨테이너 재기동 후 wlroots 재등록 필요할 수 있음. |
| **cage 종료 시 crash(exit 133) / docker stop 지연** | wayland 1.22 `wl_display_terminate` assertion. → wayland `-Db_ndebug=true` + 이미지 `STOPSIGNAL SIGKILL`로 즉시 정지(~200ms). exit **137**(SIGKILL)은 크래시가 아닌 정상 정지 코드. |
| **홈버튼 첫 표시 flaky** | 컴포지터 float 재표시 레이스. → homebar.c `unset_maximized` + entrypoint settle 재시도로 완화. 안 뜨면 `homebar-up.sh` 재실행/재부팅. |
| **rviz2가 안 뜸(런처 유지)** | rviz2 컨테이너가 死/미기동. `docker ps -a --filter name=rviz2` + `docker logs rviz2` 확인. Start(=docker run) 재시도. |

**입력 주입 도구 부재**: 보드에 uinput/wtype/ydotool 없음. 자동 검증 시 `/dev/input/event1`
(WingCoolTouch, ABS X:0..16383 Y:0..9599)에 `input_event` 직접 write로 가상 터치 주입 가능.

---

## 8. 요약 치트시트

```bash
BOARD=root@172.16.10.162
# 빌드(터치 지원본, 보드 네이티브)
scp apps/rviz2_port/docker/agl-display/Dockerfile.touch $BOARD:/tmp/rviz2-touch/Dockerfile.touch
ssh $BOARD 'cd /tmp/rviz2-touch && docker build -f Dockerfile.touch -t rviz2-agl:touch . \
  && docker tag rviz2-agl:touch registry.obigo.com/oss/rviz2-agl:latest'
# 실행/전환 (보드)
ssh $BOARD 'export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0; \
  agl-shell-activator -a activate -p wlroots -o DP-1'      # rviz2 표출
ssh $BOARD 'export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0; \
  agl-shell-activator -a activate -p hmi_launcher -o DP-1' # 런처 복귀
# 상태
ssh $BOARD 'docker ps --format "{{.Names}} | {{.Status}}"'
```

---

## 부록 A. 터치 수정 상세 (개발 핵심)

> "우리가 개발한 rviz2"의 핵심 중 하나. arm64 실기에서 **터치가 되게** 만든 작업 + 그 부수
> 효과(cage 종료 크래시)까지 정리. 소스: `apps/rviz2_port/docker/agl-display/Dockerfile.touch`.

### A-1. 문제

Orin/AGL 실기에서 rviz2를 띄우면 **마우스는 되는데 터치가 안 됨**.

### A-2. 근본 원인

렌더링 경로가 `agl-compositor → cage(중첩 wlroots) → XWayland → rviz2` 인데, jammy 패키지
**cage 0.1.4 / wlroots 0.15.1** 의 wayland 백엔드가 부모 컴포지터로부터 받은 **`wl_touch`(터치)
이벤트를 자식으로 전달하지 못합니다** (포인터/키보드만 전달). 즉 터치가 rviz2에 닿기 전에
cage에서 유실됩니다. wlroots는 **0.16 부터** wayland 백엔드에 터치 전달이 추가됐습니다.

### A-3. 수정 — 소스 빌드 스택 (Dockerfile.touch)

표준 이미지(`ros:humble` + apt cage/xwayland) 위에 아래를 **소스 빌드**해 `/usr/local`에 설치:

| 구성 | 버전 | 이유 |
|---|---|---|
| wayland | **1.22.0** | wlroots 0.16 이 wayland ≥1.21 요구 (jammy는 1.20) |
| wayland-protocols | 1.31 | wlroots 0.16 의존 |
| seatd / libseat | 0.8.0 | wlroots 0.16 **필수** 의존. jammy libseat-dev 의 pkg-config 인식이 불안정 → 소스 공급 |
| **wlroots** | **0.16.2** | **wayland 백엔드 터치 전달** (핵심). `-Dxwayland=enabled`, `backends=auto`(hwdata/xcb-renderutil 없는 백엔드 자동 비활성) |
| cage | 0.1.5 | wlroots 0.16 호환. `app_id="wlroots"` 유지(agl-shell 활성화 정합) |

- `PKG_CONFIG_PATH`: `/usr/local/...` 을 앞에 둬 wayland 1.22 가 jammy 1.20 보다 우선하되,
  시스템 pkgconfig(libinput/pixman/xcb 등)도 검색되도록 뒤에 append.
- **빌드는 Orin 보드 네이티브 권장**(QEMU 에뮬레이션은 매우 느림). §3-2 참조.

### A-4. 부수 수정 — cage 종료 크래시 (wayland 1.22 assertion)

wayland **1.21+** 의 `wl_display_terminate()` 는 종료용 eventfd write 결과를 assert 합니다.
중첩 cage 종료(SIGTERM) 시 이 write 가 실패해 **abort (exit 133)** 가 발생했습니다
(jammy 1.20 엔 이 로직/assertion 자체가 없어 조용히 넘어갔음 = 터치 수정의 부작용).

2단계로 해결:
1. wayland 를 **`-Db_ndebug=true`**(assert 컴파일 제거)로 빌드 → abort 제거. 단 이것만으론
   cage 가 SIGTERM 에 종료를 못 해 `docker stop` 이 grace(10s) 후 SIGKILL → 느림.
2. 이미지에 **`STOPSIGNAL SIGKILL`** 추가 → `docker stop` 이 즉시 SIGKILL(cage 핸들러 우회)
   → **~200ms 즉시 정지 + assertion 없음**.

> 결과: `docker stop rviz2` 가 10,253ms → **192ms**, assertion 로그 사라짐. 종료 exit code 는
> **137(SIGKILL)** — 크래시가 아니라 정상 정지 코드. (완전한 clean exit 0 은 cage graceful
> shutdown 자체 수정 필요 = deep, 보류. §7 참조.)

### A-5. 검증 (Orin 실기)

- **터치 동작 확인** (사용자 실탭 + 에이전트 가상 터치 주입 both).
- 유휴(25s+) / 터치 / 활성전환 churn 모두 안정 — 크래시는 **종료 시에만** 이었고 A-4로 해소.
- `docker stop` 192ms + assertion 없음, rviz2 렌더/터치 정상 유지.

### A-6. 배포 & 아키

- 레지스트리 `oss/rviz2-agl:latest` 의 **arm64 = 터치 수정본**, `oss/rviz2-agl:touch`(arm64) 도 존재 (§4-4).
- **amd64 는 터치 수정본 불필요** — x86 개발은 host X11로 rviz2 직접 실행(cage 우회, §5-4)이라
  중첩 wayland 터치 이슈가 발생하지 않음. 따라서 `:latest` 의 amd64 는 표준(base) 유지.

---

## 참고 문서

- `apps/rviz2_port/docker/agl-display/README.md` — 컨테이너 격리 방식 상세(원본)
- `apps/rviz2_monitor/README.md` — RViz2 Monitor 앱
- `apps/rviz2_port/docs/adr/` — 아키텍처 결정 기록:
  - `ADR-003` OGRE/Wayland 전략, `ADR-004` wayland-xcb 가드,
  - `ADR-005` rviz 소스 리빌드, `ADR-006` arm64 크로스컴파일, `ADR-007` agl-shell 통합

# Orin AGX 보드: hmi_launcher 를 기본 런처(home)로 등록 + 부팅 자동 실행

> 대상 보드: NVIDIA Jetson AGX Orin (AGL / agl-compositor), `root@172.16.10.52`
> 목적: AGL 기본 런처(`flutter-ics-homescreen`)를 비활성화하고, 우리 **hmi_launcher**
> 도커 컨테이너를 **전체 화면 기본 home** 으로 띄우며, **부팅 시 자동 실행**되게 한다.
> 검증: 2026-06-19, `oss-hmi-launcher:3.32.5` (Flutter 3.32.5, arm64).

---

## 0. 배경 — AGL 의 화면 표시 모델

agl-compositor 는 출력(DP-1)에 **단 하나의 "background" 앱**을 둔다. background 가 없으면
**black curtain**(검은 막)이 덮여 다른 앱이 보이지 않는다. weston.ini 가
`activate-by-default=false` 이므로 일반 앱은 `agl-shell-activator` 로 명시 activate 해야
보이지만, 그래도 background 위에 얹히는 형태다.

기본 `flutter-ics-homescreen` 은 **background** 역할을 차지해 home 으로 동작한다.
우리 앱을 home 으로 만들려면 **우리 앱이 background 역할을 가져야** 하고,
그 방법이 flutter-auto 의 **`--window-type BG`** 옵션이다.

> ⚠️ **하지 말 것**: background 앱을 `agl-shell-activator -a activate` 하면 agl-compositor 가
> **SIGSEGV 로 죽는다**. `--window-type BG` 앱은 자동으로 화면 전체에 배치되므로 activate 불필요.
> 또한 `agl-shell-activator -a fullscreen` / flutter-auto `-f` 는 이 앱에서 **검은 화면**을 유발하므로
> 쓰지 않는다 — 전체 화면은 `--window-type BG` 로 달성한다.

---

## 1. 사전 조건

- `oss-hmi-launcher:3.32.5` 이미지가 보드에 `docker load` 되어 있을 것
  (빌드/전송은 [oss-hmi-launcher 보드 배포 가이드](#) / `docker/run-on-board-arm64.sh` 참고)
- 보드에 NVIDIA Tegra GL 스택 + flutter-auto + Flutter 엔진/ICU 가 존재(AGL rootfs 기본 포함)
- 실행 스크립트가 보드에 배포되어 있을 것:

```bash
scp apps/docker/run-on-board-arm64.sh root@172.16.10.52:/opt/run-oss-hmi-launcher.sh
```

---

## 2. 기본 런처(homescreen) 비활성화

```bash
ssh root@172.16.10.52

# 기본 AGL 홈스크린 중지 + 부팅 자동 시작 해제
systemctl disable --now flutter-ics-homescreen.service

# 확인 (둘 다 disabled / inactive 여야 함)
systemctl is-enabled flutter-ics-homescreen.service   # -> disabled
systemctl is-active  flutter-ics-homescreen.service   # -> inactive
```

> 한 출력에 background 는 하나뿐이므로, 우리 앱을 background 로 띄우려면 homescreen 은
> 반드시 꺼져 있어야 한다.

---

## 3. 우리 앱을 기본 home 으로 등록 (전체 화면)

핵심은 컨테이너의 flutter-auto 에 **`--window-type BG`** 를 전달하는 것이다.
`docker/run-on-board-arm64.sh` 가 이미 이 인자로 컨테이너를 실행한다(아래 발췌).

```sh
docker run -d --name oss-hmi-launcher --restart unless-stopped --privileged --network host \
  --user 1001:1001 --group-add 44 --group-add 1008 \
  -v "${RUNTIME_DIR}/wayland-0:${RUNTIME_DIR}/wayland-0" \
  -v /usr/bin/flutter-auto:/usr/bin/flutter-auto:ro \
  -v /usr/share/flutter/3.32.5/release/lib/libflutter_engine.so:/usr/share/flutter/3.32.5/release/lib/libflutter_engine.so:ro \
  -v /usr/share/flutter/3.32.5/release/data/icudtl.dat:/usr/share/flutter/icudtl.dat:ro \
  -v /opt/nv-gl:/opt/nv-gl:ro \
  -v /usr/share/glvnd/egl_vendor.d:/usr/share/glvnd/egl_vendor.d:ro \
  -v /usr/share/egl/egl_external_platform.d:/usr/share/egl/egl_external_platform.d:ro \
  -e LD_LIBRARY_PATH=/opt/nv-gl -e HOME=/tmp \
  -e XDG_RUNTIME_DIR="${RUNTIME_DIR}" -e WAYLAND_DISPLAY=wayland-0 \
  oss-hmi-launcher:3.32.5 --window-type BG     # ← 마지막 인자가 agl-run.sh 를 거쳐 flutter-auto 로 전달
```

수동 1회 실행/확인:

```bash
sh /opt/run-oss-hmi-launcher.sh
# 컴포지터 로그에서 background 획득 확인:
CPID=$(pgrep -x agl-compositor); journalctl _PID=$CPID --no-pager | grep -iE "curtain|background" | tail
#   -> "Removed black curtain from output DP-1"
#   -> "(background) position view ... on output DP-1"
```

> `--window-type BG` 를 받으면 flutter-auto 가 agl-shell 의 BACKGROUND 역할을 요청하고,
> 컴포지터가 curtain 을 걷고 우리 앱을 **출력 전체**에 배치한다 = 전체 화면 home.

---

## 4. 부팅 자동 실행 (systemd 서비스)

서비스 유닛(`apps/docker/oss-hmi-launcher.service`)을 보드에 설치한다:

```bash
scp apps/docker/oss-hmi-launcher.service root@172.16.10.52:/etc/systemd/system/
ssh root@172.16.10.52 'systemctl daemon-reload && systemctl enable oss-hmi-launcher.service'
```

유닛 내용:

```ini
[Unit]
Description=OSS HMI Launcher (hmi_launcher) as default home app
Requires=agl-compositor.service docker.service
After=agl-compositor.service docker.service graphical.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh /opt/run-oss-hmi-launcher.sh
ExecStop=/usr/bin/docker stop oss-hmi-launcher
TimeoutStartSec=120

[Install]
WantedBy=graphical.target
```

- `run-on-board-arm64.sh` 는 부팅 타이밍에 대비해 **wayland 소켓을 최대 40초 대기**(자동 감지:
  `/run/wayland-0` 또는 `/run/user/1001/wayland-0`)한 뒤 컨테이너를 실행한다.
- 컨테이너는 `--restart unless-stopped` 라 docker 데몬에 의해서도 재기동되지만,
  소켓 경로 감지와 마운트 일관성을 위해 **부팅 트리거는 이 서비스가 담당**한다.

검증(부팅 시뮬레이션):

```bash
systemctl restart oss-hmi-launcher.service
systemctl is-active oss-hmi-launcher.service          # -> active
docker inspect oss-hmi-launcher --format '{{.State.Status}}'  # -> running
```

실제 재부팅 후 화면에 hmi_launcher 가 전체 화면으로 떠야 한다.

---

## 5. 되돌리기 (기본 homescreen 으로 복구)

```bash
ssh root@172.16.10.52
systemctl disable --now oss-hmi-launcher.service
docker stop oss-hmi-launcher
systemctl enable --now flutter-ics-homescreen.service
```

---

## 6. 트러블슈팅

| 증상 | 원인 / 조치 |
|---|---|
| 화면이 **검정**(앱 안 보임) | background 가 없음 → 우리 앱이 `--window-type BG` 로 떴는지, homescreen 이 꺼졌는지 확인. 컴포지터 로그에 "Removed black curtain" 이 없으면 background 미획득. |
| 컨테이너가 **재시작 루프** + "Failed to connect to Wayland display" | wayland 소켓 경로 불일치. 스크립트가 `/run/wayland-0` vs `/run/user/1001/wayland-0` 자동 감지 — 컴포지터가 떠 있는지(`systemctl is-active agl-compositor`) 확인. |
| 화면이 **90° 회전** | weston.ini `[output] transform` 이 패널 방향과 불일치. 가로 모니터=`normal`, 세로 패널=`rotate-90`. |
| 모니터가 **단색 파랑(No Signal)** | 앱 문제 아님 — DP 케이블/어댑터 물리 문제. 케이블 교체/재삽입, 모니터 입력 소스(DP) 확인. |
| 컴포지터가 죽음(검정) | background 앱을 `agl-shell-activator -a activate` 하지 말 것(SIGSEGV). 복구: `pkill -9 -f agl-shell-grpc-server; systemctl restart agl-compositor.socket; systemctl restart agl-compositor`. |

---

## 참고: 관련 파일

- 실행 스크립트: `apps/docker/run-on-board-arm64.sh` (소켓 자동 감지 + GL 스택 마운트 + `--window-type BG`)
- systemd 유닛: `apps/docker/oss-hmi-launcher.service`
- 런타임 이미지: `apps/docker/Dockerfile.arm64` (ubuntu:24.04 = 보드 glibc 2.39 정합)

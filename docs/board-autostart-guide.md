# 보드 재부팅 자동시작 가이드 — hmi_launcher (+ ext-agl)

> AGL HMI 보드(예: 172.16.10.81, Orin AGX)에서 재부팅 시 `hmi_launcher` 도커
> 컨테이너가 자동으로 올라오게 하는 방법. 2026-07 실보드 검증 구성 기준.
> MMF 백엔드 컨테이너(core/ext-ros2/ext-agl)의 자동시작은
> `oss_multisw_framework/docs/board-autostart-guide.md` 참조 — 원리는 동일하다.

---

## 1. 원리 — Docker restart policy (systemd 유닛 불필요)

```
부팅 → ① systemd: agl-compositor.service 시작 (디스플레이 스택)
     → ② systemd: docker.service 시작            (systemctl enable docker)
     → ③ docker 데몬이 restart policy 컨테이너 자동 복원
          → oss-mmf-ext-agl (adsw_manager + ota_client)
          → hmi_launcher    (flutter-auto + 런처 앱)
```

| 요소 | 설정 | 확인 |
|---|---|---|
| docker 부팅 시작 | `systemctl enable docker` (1회) | `systemctl is-enabled docker` → `enabled` |
| 컴포지터 부팅 시작 | `systemctl enable agl-compositor` | `enabled` + `/run/wayland-0` 소켓 존재 |
| 컨테이너 정책 | `docker run --restart unless-stopped ...` | `docker inspect hmi_launcher --format '{{.HostConfig.RestartPolicy.Name}}'` |

컨테이너를 **1회 생성**해 두면(아래 §2) 재부팅마다 docker 가 자동 복원한다.

---

## 2. 최초 설치 — hmi_launcher 컨테이너 생성

이미지 로드 후(`docker load` 또는 registry pull) 아래처럼 생성한다.
전체 레시피는 `apps/docker/docs/board-default-launcher-setup.md`(기본 home 등록)와
보드의 `/opt/run-oss-hmi-launcher.sh` 참조.

```bash
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
  oss-hmi-launcher:<VER> --window-type BG
```

**절대 빠뜨리면 안 되는 것 2가지:**
- **`--window-type BG`** (컨테이너 CMD) — 컴포지터가 `activate-by-default=false` 라
  NORMAL 윈도우는 활성화 없이는 그려지지 않는다(앱은 돌지만 **화면 검정**).
  BG(배경 레이어)는 활성화 없이 표시된다. 확인: 로그의 `Window Type: BG`.
- **`--restart unless-stopped`** — 이게 자동시작의 전부다.

---

## 3. 주의사항

1. **`unless-stopped` 의 의미** — 수동 `docker stop` 후엔 재부팅해도 안 살아난다.
   복구: `docker start hmi_launcher`.
2. **디스플레이 스택 의존성** — 런처는 컴포지터(wayland-0)가 있어야 화면에 그려진다.
   부팅 시 대개 컴포지터가 먼저 뜨지만 **순서는 보장되지 않는다.** 컨테이너가 먼저 떠도
   surface 가 pending 으로 대기했다가 출력이 생기면 매핑되는데, 이때 컴포지터에
   `"unmapped surface or view in the layer list"` 경고가 남으면 **화면엔 보이는데
   터치가 안 되는** 상태가 될 수 있다 → 디스플레이 스택이 온전한 상태에서
   `docker restart hmi_launcher` 로 재매핑하면 해소.
3. **모니터 일체형 터치** — 터치스크린 USB 가 모니터에 통합된 구성에서는 모니터
   미연결/불량 = 터치 하드웨어 부재다. 진단:
   `journalctl -t agl-compositor | grep -i touch` (장치 인식 + 출력 연계 확인).
4. **adsw_manager 와의 관계** — ext-agl 컨테이너의 agl_adsw_manager 가 hmi_launcher
   를 서비스로 관리(start/stop/recovery)한다. 재부팅 직후엔 docker 가 두 컨테이너를
   모두 복원하므로 adsw 는 상태만 보고하면 되고, 이후 lfc_monitor 에서 start/stop
   제어가 가능하다.
5. **레거시 유닛 주의** — 보드에 남아 있어도 현행 구성에선 쓰이지 않는다:
   - `oss-hmi-launcher.service` (disabled): 다른 컨테이너 이름(oss-hmi-launcher)을
     대상으로 하는 옛 방식. systemd 로 순서를 강제하고 싶을 때 참고용.
   - `agl-adsw-manager.service` (disabled): adsw_manager 를 호스트 네이티브
     바이너리로 돌리던 컨테이너 이전 시절의 잔재.

---

## 4. 검증 방법

```bash
systemctl is-enabled docker agl-compositor          # 둘 다 enabled
docker inspect hmi_launcher     --format '{{.HostConfig.RestartPolicy.Name}}'   # unless-stopped
docker inspect oss-mmf-ext-agl  --format '{{.HostConfig.RestartPolicy.Name}}'   # unless-stopped
sudo reboot   # → 재부팅 후:
docker ps                                            # 두 컨테이너 Up
docker logs hmi_launcher | grep "Window Type"        # BG
docker exec hmi_launcher grep -c libflutter_engine /proc/1/maps   # >0 = 엔진 로드(렌더 중)
journalctl -t agl-compositor | grep -i background    # "(background) position view ... on output" 확인
```

---

## 5. 요약

| 컨테이너 | 생성 스크립트/레시피 | 자동시작 메커니즘 |
|---|---|---|
| hmi_launcher | §2 (또는 `/opt/run-oss-hmi-launcher.sh` 참고) | docker enabled + `--restart unless-stopped` |
| oss-mmf-ext-agl | `/opt/adsw/run-ext-agl.sh` | 동일 |

**"docker enabled + `--restart unless-stopped` + `--window-type BG`"** — 이 세 가지가
핵심이다. 관련 문서: `apps/docker/docs/board-default-launcher-setup.md`(기본 home 등록·컴포지터
설정), `apps/docker/docs/DOCKER_GUIDE.md`(이미지 빌드).

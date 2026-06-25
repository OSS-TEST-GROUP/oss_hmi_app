# 보드 플래싱 후 앱 실행 환경 셋업 (AI 비활성 hmi_launcher)

> 대상 보드: NVIDIA Jetson AGX Orin (AGL / `agl-ivi-demo-flutter` 이미지, agl-compositor)
> 목적: 보드에 새 이미지를 **플래싱한 직후**, AGL 기본 데모 앱을 끄고 **oss_hmi_app
> 도커 컨테이너(AI 기능 비활성)** 를 전체 화면 기본 home 으로 **부팅 자동 실행**되게 한다.
> 기반: [board-default-launcher-setup.md](board-default-launcher-setup.md) (2026-06-19 검증) +
> 레지스트리 배포([oss_hmi_app/apps/docker/DOCKER_GUIDE.md] §6).
> 작성일: 2026-06-23.

---

## 핵심 3단계 (요약)

1. **AGL 기본 데모 앱 비활성화** — `flutter-ics-homescreen.service` (출력당 background 는 하나뿐)
2. **oss_hmi_app 도커 이미지 설치** — `registry.obigo.com/oss/oss-hmi-launcher:latest` pull
3. **AI 비활성 런처 systemd 자동 실행** — `LAUNCHER_BOT_ENABLED=0` + `oss-hmi-launcher.service` enable

> ⚠️ **플래싱은 rootfs 를 초기화**한다. 도커 이미지 외에 **호스트 스크립트/유닛/도커 인증은
> 사라지므로 매 플래시 후 재배포**해야 한다(아래 0단계).

---

## 0. 플래싱 직후 전제조건 확인/복구

```bash
ssh root@<BOARD_IP>

# (a) docker 존재 + 부팅 기동 (docker.service enable 필수 — 이유는 §3.5 참조)
which docker && systemctl enable docker.service && systemctl is-active docker

# (b) flutter-auto + Flutter 엔진 + Tegra GL 존재 확인 (agl-ivi-demo-flutter 기본 포함)
ls /usr/bin/flutter-auto /usr/share/flutter/3.32.5/release/lib/libflutter_engine.so

# (c) 레지스트리 로그인 (pull 위해 1회)
docker login registry.obigo.com
#   → 사내망 불가/무인증 배포면, 호스트에서 전송:
#     docker save registry.obigo.com/oss/oss-hmi-launcher:latest | gzip \
#       | ssh root@<BOARD_IP> 'gunzip | docker load'
```

---

## 1. AGL 기본 데모 앱(homescreen) 비활성화

```bash
systemctl disable --now flutter-ics-homescreen.service
systemctl is-enabled flutter-ics-homescreen.service   # → disabled
systemctl is-active  flutter-ics-homescreen.service   # → inactive
```

> agl-compositor 는 출력(DP-1)에 background 앱을 **하나만** 둔다. 우리 앱이 background 를
> 가지려면 기본 homescreen 이 반드시 꺼져 있어야 한다(안 그러면 검은 화면).

---

## 2. oss_hmi_app 도커 이미지 설치

```bash
docker pull registry.obigo.com/oss/oss-hmi-launcher:latest
docker images registry.obigo.com/oss/oss-hmi-launcher   # 확인
```

> 이미지는 **AI 가능 풀 빌드**다. AI 사용 여부는 이미지가 아니라 **실행 시 env**
> (`LAUNCHER_BOT_ENABLED`)와 v-agentos 데몬 유무로 결정된다(3단계에서 비활성).

---

## 3. AI 비활성 런처 + 부팅 자동 실행

### 3-1. 호스트 스크립트/유닛 배포 (매 플래시 후 필요)

```bash
# 실행 스크립트 (AI 비활성: LAUNCHER_BOT_ENABLED=0)
scp apps/docker/run-on-board-no-ai.sh root@<BOARD_IP>:/opt/run-oss-hmi-launcher.sh
# systemd 유닛
scp apps/docker/oss-hmi-launcher.service root@<BOARD_IP>:/etc/systemd/system/
```

### 3-2. 스크립트가 레지스트리 이미지를 쓰도록 IMAGE 기본값 변경

```bash
ssh root@<BOARD_IP> \
  "sed -i 's|IMAGE=\"\${IMAGE:-.*}\"|IMAGE=\"\${IMAGE:-registry.obigo.com/oss/oss-hmi-launcher:latest}\"|' \
   /opt/run-oss-hmi-launcher.sh"
```

> `run-on-board-no-ai.sh` 는 `docker run ... -e LAUNCHER_BOT_ENABLED=0 ... --window-type BG`
> 로 컨테이너를 띄운다(봇/음성/AI-SDK UI 숨김 = 순수 앱 런처). `--restart unless-stopped` 포함.

### 3-3. 부팅 자동 실행 등록

```bash
ssh root@<BOARD_IP> 'systemctl daemon-reload && systemctl enable --now oss-hmi-launcher.service'
```

`oss-hmi-launcher.service` 핵심(부팅 순서 — docker + 컴포지터 이후):

```ini
[Unit]
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

---

## 3.5 부팅 자동시작 메커니즘 — 컨테이너 restart policy + `docker.service`

보드가 재부팅돼도 런처가 자동으로 뜨려면 **아래 두 설정이 모두** 갖춰져야 한다.
하나라도 빠지면 부팅 자동 기동이 안 된다.

### (A) docker 데몬이 부팅 시 자동 기동 — `systemctl enable docker.service`

```bash
systemctl enable docker.service
systemctl is-enabled docker.service   # → enabled
ls /etc/systemd/system/multi-user.target.wants/ | grep docker   # docker.service 심볼릭 존재해야
```

**왜 `docker.socket` 만으론 부족한가 (함정)**: AGL 기본 상태는 `docker.socket`
(소켓 활성화) 만 enabled 이고 `docker.service` 는 **disabled** 인 경우가 많다.
소켓 활성화는 **클라이언트가 소켓에 접속하는 순간에만** 데몬을 깨운다. 따라서
부팅 직후엔 데몬이 떠 있지 않고, 데몬이 떠야 복구되는 **`--restart` 정책
컨테이너도 자동 복구되지 않는다**. 누군가 `docker ps` 같은 명령을 한 번 쳐야
비로소 데몬이 뜬다.

> 과거엔 `oss-hmi-launcher.service`(systemd) 가 부팅 때 `docker run` 을 호출해
> **간접적으로** 데몬을 깨웠다 — 그래서 `docker.service` 가 disabled 여도 런처가 떴다.
> systemd 런처 유닛을 제거하고 **컨테이너 restart policy 에만 의존하는 구성**
> (adsw_manager 컨테이너 등)으로 바꾸면 이 간접 경로가 사라지므로 **반드시
> `docker.service` 를 enable** 해야 한다.

### (B) 컨테이너 restart policy — `--restart unless-stopped`

```bash
docker run ... --restart unless-stopped ...        # 또는 compose: restart: unless-stopped
docker inspect <container> --format '{{.HostConfig.RestartPolicy.Name}}'   # → unless-stopped
```

- `unless-stopped`: 데몬 기동 시 자동 복구. 단, 사용자가 명시적으로 `docker stop`
  한 컨테이너는 복구하지 않는다(의도적 정지 존중).
- `always` 와의 차이: `always` 는 `docker stop` 후에도 데몬 재시작 시 다시 켠다.
  운영상 의도적 정지를 존중하려면 **`unless-stopped` 권장**.

### (A)+(B) 조합 = 부팅 자동시작

| 구성 | (A) docker.service | (B) restart policy | 부팅 복구 경로 |
|---|---|---|---|
| **systemd 직접기동**<br>(`oss-hmi-launcher.service`) | 필요 | run 스크립트의 `--restart unless-stopped` | 유닛(`WantedBy=graphical.target`)이 부팅 시 `docker run` 호출 → 데몬도 함께 기동 |
| **adsw_manager 컨테이너**<br>(`oss-mmf-ext-agl`) | **필수** (런처 유닛 없이 컨테이너 정책에만 의존) | `oss-mmf-ext-agl` + `hmi_launcher` 모두 `unless-stopped` | `docker.service` 가 부팅 시 데몬 기동 → `oss-mmf-ext-agl` 자동 복구 → 내부 adsw_manager 가 `hmi_launcher` 기동 |

> ⚠️ **부팅 순서**: docker 데몬이 `agl-compositor`(wayland) 보다 먼저 떠서 런처
> 컨테이너 첫 기동이 wayland 소켓을 못 찾고 실패할 수 있다. systemd 직접기동은
> 유닛의 `After=agl-compositor.service` 로 순서를 보장하고, adsw_manager 구성은
> **1Hz 모니터가 컴포지터 준비 후 자동 재기동**(self-heal)한다 — 한두 번 실패해도 결국 올라온다.

> 플래싱은 rootfs 를 초기화하므로 `docker.service` enable 도 **매 플래시 후 재설정** 대상이다(0단계 (a) 에 포함).

---

## 4. 검증

```bash
# 서비스/컨테이너 상태
systemctl is-active oss-hmi-launcher.service                  # → active
docker inspect oss-hmi-launcher --format '{{.State.Status}}'  # → running

# AI 비활성(봇 숨김) 로그 확인
docker logs oss-hmi-launcher 2>&1 | grep -i aiAvailable       # → aiAvailable=false

# background 획득 확인 (전체 화면 home)
CPID=$(pgrep -x agl-compositor); journalctl _PID=$CPID --no-pager | grep -iE "curtain|background" | tail
#   → "Removed black curtain from output DP-1"

# 실제 재부팅 후 전체 화면 hmi_launcher(AI 비활성) 자동 표시 확인
reboot
```

---

## 5. 트러블슈팅 (요약)

| 증상 | 조치 |
|---|---|
| 화면 **검정** | homescreen 안 꺼짐 / 우리 앱이 background 미획득. flutter-ics-homescreen disable 재확인, 컴포지터 로그에 "Removed black curtain" 확인 |
| **모니터 전원 OFF→ON(또는 케이블 재연결) 후 검정** | DP 핫플러그로 컴포지터가 출력 disable→re-enable 하지만 background 표면을 재배치하지 않음("Removed black curtain" 안 나옴). 런처 재기동만으론 부족 → **`systemctl restart agl-compositor` 후 `systemctl restart oss-hmi-launcher`** 순으로 복구. |
| **모니터 전원 재투입 후 터치 안 됨** | 모니터 케이블이 비디오(DP)+터치(USB)를 함께 물면, 전원 OFF 시 USB 터치가 끊겼다 **다른 포트로 재열거**됨(`dmesg`에 `usb 1-4.x: USB disconnect` → 새 번호로 재연결). 컴포지터 재시작이 새 event 노드를 다시 잡아야 함(위 검정화면 복구와 동일). 그래도 터치 무반응이면 USB 컨트롤러 hang → USB 재바인드(`echo <port> > /sys/bus/usb/drivers/usb/unbind; …/bind`) 또는 재부팅. 파이프라인 확인: event1 에 합성 탭 주입 시 UI 반응하면 컴포지터→런처는 정상(=물리 패널/USB 문제). |
| `output already has background` | 재배포 시 이전 background 슬롯 잔존 → `systemctl restart agl-compositor` 후 런처 재기동 |
| 컨테이너 **재시작 루프** + "Failed to connect to Wayland display" | wayland 소켓 경로 — 스크립트가 `/run/wayland-0` vs `/run/user/1001/wayland-0` 자동 감지, `systemctl is-active agl-compositor` 확인 |
| pull 실패 (`unauthorized`) | `docker login registry.obigo.com` 또는 `docker save \| docker load` 전송 |
| 봇/음성 UI 가 보임(AI 비활성 의도인데) | `LAUNCHER_BOT_ENABLED=0` 미적용 → run 스크립트가 no-ai 버전인지 확인 |

> **모니터 전원 재투입 = 비디오+터치 동시 끊김.** DP 핫플러그로 화면(검정)과 USB 터치(재열거)가 함께 영향받는다.
> 운영에서 무인 복구가 필요하면 DP connector 핫플러그 udev 룰로 `agl-compositor`+런처를 자동 재기동하는 훅을 두는 것을 권장.

---

## 참고 파일

- AI 비활성 실행 스크립트: `oss_hmi_app/apps/docker/run-on-board-no-ai.sh`
- 일반(AI) 실행 스크립트: `oss_hmi_app/apps/docker/run-on-board-arm64.sh`
- systemd 유닛: `oss_hmi_app/apps/docker/oss-hmi-launcher.service`
- 런타임 이미지 빌드/레지스트리 push: `oss_hmi_app/apps/docker/DOCKER_GUIDE.md` §6
- 기본 런처 등록 상세: `board-default-launcher-setup.md`

# rviz2 시나리오 테스트 가이드

hmi_launcher 의 **rviz2_panel** 로 rviz2 컨테이너를 제어하고, 151 보드의 Autoware 를
시각화하면서 **자율주행 시뮬레이션·앱 전환·lfc 제어·adsw 데이터 수신** 을 한 흐름으로
반복 검증하는 절차다. 실행 대상은 두 곳이며 **표시 계층만 다르고 나머지는 동일**하다.

| 대상 | 표시 경로 | 스크립트 | 입력 | 캡처 |
|---|---|---|---|---|
| **Orin 보드**(arm64/AGL) | agl-compositor + cage + homebar | `board_scenario.sh` | `/dev/input` 터치 주입(`board-tap.py`) | `weston-screenshooter`(`board-shot.sh`) |
| **x86 개발 PC**(amd64) | 호스트 X11 직행 (cage/homebar 없음) | `pc_scenario.sh` | XTEST 클릭(`xtool` 컨테이너) | `import -window root` |

두 경로 모두 **151 의 core / ext-ros2 / Autoware 3 파티션을 그대로** 쓴다. ROS·Autoware·앱
계층은 동일하고, PC 는 agl-shell 이 없어 **homebar 항목만 판정에서 제외**한다.

산출물 위치: `apps/rviz2_port/test/scenario/`

---

## 1. 시나리오 구성 (1 회차)

```
0) 정규화        rviz2 정지 → 런처 홈 → RViz2 Panel 진입
1) 패널 Start    컨테이너 기동 + entrypoint 마커(오버레이 로드 / ego 추종 전환)
1-b) 표시 전환   rviz2 를 전면으로 (보드=agl-shell activate, PC=X11 창 활성화)
2) 자율주행 시뮬 151 에서 autoware-sim.sh → route/engage + **ego 실제 이동** 3중 판정
3) adsw_monitor  화면 + 151 rosbridge 로 Autoware 데이터 경로 확인
4) lfc_monitor   autoware **3 파티션 전체** Stop → Start
4-b) 초기포즈    파티션 재생성 후 /initialpose3d 재주입
5) 패널 Stop     컨테이너 정지 확인 (exit 137 정상)
```

판정 실패 시 **즉시 중단**하고 이유·회차·누적 PASS 를 출력한다(`exit 2`).

### 판정 기준 (관측 가능한 것만)

| 항목 | 기준 | 근거 |
|---|---|---|
| 기동/정지 | 컨테이너 상태 + entrypoint 마커 + exit code | `docker inspect` |
| route/engage | `success=True` | 시뮬 로그 |
| **ego 표출** | 3D 뷰 중앙 박스 밝기 > 35 | 실측: 표출 73~88 / 미표출 21 |
| **ego 이동** | 주행 중 두 프레임의 3D 뷰 평균 절대차 > 3 | 카메라가 에고를 따라가므로 정지면 0 에 가깝다 |
| **맵 변위** | 시뮬 로그 첫/마지막 위치 ≥ 10m | 좌표 기반 교차 검증 |
| adsw 데이터 | `ros2 topic hz` + rosbridge 구독자 합 ≥ 2 | 151 ext-ros2 안에서 확인 |
| lfc 제어 | Stop 후 실행수 0 · Start 후 3 | 151 `docker ps` |
| homebar (보드만) | activate 로그 증가 + 탭 후 전면=launcher | PC 는 N/A |

---

## 2. 사전 조건

### 공통 — 151 보드
```bash
ssh beyhpc@172.16.10.151
docker ps            # oss-mmf-core, oss-mmf-ext-ros2 (healthy)
ls /tmp/autoware-sim.sh   # 없으면 apps/rviz2_port/docker/agl-display/autoware-sim.sh 를 복사
```
- Autoware 3 파티션(`autoware-perception/decision/control`)은 **`MANUAL` recovery** 다.
  ext-agl 이나 core 를 재생성하면 lifecycle_mgr 가 그룹을 정지시키고 **자동 복구하지 않는다**
  → 아래 "3 파티션 복구" 를 먼저 수행한다.
- 도메인은 **42** 로 통일한다(MMF 기본값도 42). 다르면 rviz2 가 아무것도 못 받는다.

### 보드(arm64) 경로
```bash
scp apps/rviz2_port/test/scenario/board-tap.py  root@<board>:/root/tap.py
scp apps/rviz2_port/test/scenario/board-shot.sh root@<board>:/root/shot.sh
# 컨테이너: oss-mmf-ext-agl → hmi_launcher, rviz2 는 패널이 기동
```

### PC(amd64) 경로
```bash
# ① 입력·창제어·캡처 도구 (호스트에 xdotool 설치 없이)
docker build -f apps/rviz2_port/test/scenario/xtool.Dockerfile -t xtool:local .
xhost +local:                 # 컨테이너가 호스트 X 에 붙도록

# ② 런처 설정 (XDG_CONFIG_HOME 로 마운트할 디렉토리)
mkdir -p ~/hmi_cfg/hmi_launcher
cp apps/rviz2_port/test/scenario/hmi_launcher.config.json        ~/hmi_cfg/hmi_launcher/config.json
cp apps/rviz2_port/test/scenario/hmi_launcher.app_visibility.json ~/hmi_cfg/hmi_launcher/app_visibility.json

# ③ rviz2_panel 설정 (amd64 X11 용 image/dockerRunArgs)
cp apps/rviz2_port/test/scenario/rviz2_panel.x86.json ~/rviz2_panel.json

# ④ ext-agl 기동 (서비스 목록의 경로들을 자기 환경에 맞게 수정)
docker run -d --name oss-mmf-ext-agl --privileged --net=host --restart unless-stopped \
  --group-add "$(stat -c %g /var/run/docker.sock)" \
  -e ROS_DOMAIN_ID=42 -e MMF_DDS_DOMAIN_ID=42 -e HMI_RUNTIME_UID="$(id -u)" -e DISPLAY=:0 \
  -v /dev/shm:/dev/shm -v /run/user/"$(id -u)":/run/user/"$(id -u)" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v <경로>/agl-service-list.x86.pc.yaml:/oss/bin/config/agl-service-list.x86.yaml:ro \
  registry.obigo.com/oss/oss-mmf-ext-agl:latest
```

PC 에서 꼭 필요한 세 가지 (없으면 각각 이렇게 실패한다):
1. **`--gpus all`** — 없으면 런처가 GTK/GLX `BadValue` 로 즉사(exit 133).
2. **`app_visibility.json`** — `rviz2_panel` 은 기본 숨김(`kDefaultDisabled`)이라 타일이 안 보인다.
3. **`config.json`(XDG 경로)** — 런처는 `/app/config/launcher_config.json` 이 아니라
   `$XDG_CONFIG_HOME/hmi_launcher/config.json` 을 읽는다. 없으면 rosbridge 가 `localhost` 로
   붙어 lfc/adsw 가 빈 목록이 된다.

---

## 3. 실행

```bash
# 보드
bash apps/rviz2_port/test/scenario/board_scenario.sh            # 무한 반복
LOOPS=1 bash .../board_scenario.sh                              # 1 회차만

# PC (모니터 1번 = DP-5, +0+1080 기준으로 좌표가 잡혀 있다)
bash apps/rviz2_port/test/scenario/pc_scenario.sh
LOOPS=1 bash .../pc_scenario.sh
```

출력 예:
```
═══════════ 회차 1 ═══════════
  1 패널 Start  : up=10s 오버레이=ok ego뷰=ok
  1-b 창 배치    : 전면="rviz2"
  2 시뮬+ego    : route=True engage=True · 표출 a=87 b=83(>35) · 화면차=10.93(>3) · 변위=94m(>=10)
  3 adsw_monitor: Autoware 발행=8(1 기대) · rosbridge 구독=1(>=1 기대)
  4 lfc 제어    : Stop 후=0(0 기대) · Start 후=3(3 기대)
  5 패널 Stop   : ok exit=137
  판정          : PASS (297s) · 누적 PASS=1
```

### 3 파티션 복구 (시작 전 / 실패 후)

lfc_monitor UI 로 한다(제품 경로). **의존 순서**가 있다.

1. 런처 홈 → **Lifecycle Monitor**
2. 목록을 아래로 크게 드래그해 **스크롤 최상단으로 정규화**
   (목록이 뷰포트보다 길어 Stop 후 약 74px 밀린다 — 고정 좌표가 어긋나는 원인)
3. 컨테이너 행 Start 를 **perception → decision → control** 순서로
   (perception 이 시뮬레이터를 갖고 있어 먼저 떠야 한다)
4. `/initialpose3d` 주입 — 새로 만든 시뮬레이터는 포즈가 없어 아무것도 발행하지 않고,
   그 상태로 라우팅하면 `route_handler: Failed to find a proper route!` 로 실패한다

```bash
ssh beyhpc@172.16.10.151 'docker exec -e ROS_DOMAIN_ID=42 autoware-perception bash -lc "
 source /opt/ros/humble/setup.bash; source /opt/autoware/setup.bash;
 ros2 topic pub -t 5 /initialpose3d geometry_msgs/msg/PoseWithCovarianceStamped
 \"{header: {frame_id: map}, pose: {pose: {position: {x: 3655.152, y: 73490.295, z: 0.0},
   orientation: {z: 0.981391, w: 0.192022}}, covariance: [0.25,0,0,0,0,0, 0,0.25,0,0,0,0,
   0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0.07]}}\""'
```

---

## 4. 좌표 (1920×1080 기준)

PC 는 모니터 1번(`+0+1080`)에 창을 풀스크린으로 올린 뒤 **로컬 좌표 + y 오프셋 1080** 으로 클릭한다.

| 요소 | 좌표 |
|---|---|
| 홈 아이콘 / AD SW / Lifecycle / RViz2 타일 | `41,110` / `329,276` / `778,276` / `1226,276` |
| 패널 Start / Stop / View rviz2 / Launcher | `165,230` / `271,230` / `412,230` / `552,230` |
| lfc 컨테이너 Start (control/decision/perception) | `170,229` / `170,395` / `170,561` |
| lfc 서비스 Stop (control/decision/perception) | `255,301` / `255,467` / `255,633` |
| homebar (보드만) | `1899,13` |

> 패널 버튼의 y 가 **상태와 무관하게 230 고정**인 것은 UI 재구성의 결과다. 이전에는
> `Last changed` 줄·에러 배너 유무로 20px 씩 움직여 오탭이 났다. 레이아웃을 바꿀 때는
> 이 좌표표와 두 스크립트의 상수를 함께 갱신한다.

---

## 5. 알려진 함정 (모두 실측으로 확인된 것)

| 증상 | 원인 | 대응 |
|---|---|---|
| `engage=?` / 변위 0m | 시뮬의 모드 토글 폴링이 최대 6회(약 84초) 걸림 | 고정 대기 대신 **engage 라인 폴링**, 실패 시 decision 재기동 + 초기포즈 후 1회 재시도 |
| lfc Start 3건 모두 무반응 | 목록 스크롤이 밀려 고정 좌표가 제목을 때림 | 탭 직전 **아래로 드래그**해 최상단 정규화 (페이지 재진입으로는 초기화 안 됨) |
| lfc 목록이 비어 보임 | 앱이 `Ros` 객체 재생성 시에만 재구독 | Settings → Apply 또는 런처 재시작 |
| rviz2 즉시 종료(`❌ 호스트 wayland 소켓 없음`) | PC 에 agl-compositor 가 없음 | `-e DISPLAY=:0` 를 주면 entrypoint 가 **X11 직행 모드**로 폴백 |
| 런처 exit 133 (GLX BadValue) | 컨테이너에 GPU 접근 없음 | `--gpus all`(nvidia) 또는 `--device /dev/dri` |
| Autoware 토픽이 안 보임 | 도메인 불일치 또는 멀티 NIC | 도메인 42 통일, entrypoint 의 DDS NIC 화이트리스트 사용 |
| 파티션이 조용히 정지 | ext-agl/core 재생성 시 그룹 리컨사일(`MANUAL` recovery) | 위 "3 파티션 복구" 수행. 시나리오 중에는 ext-agl 을 만지지 않는다 |
| 자동화 프로세스를 스스로 죽임 | `pkill -f "…scenario…"` 가 자기 명령줄과 매칭 | 대괄호 패턴(`pc_scen[a]rio`) 사용 |
| 보드 탭 좌표가 전부 빗나감 | 화면이 세로(`transform=rotate-90`) — 입력도 함께 회전된다 | [화면 방향 가이드](board-display-orientation-guide.md) 로 가로 전환(또는 캡처 기준 좌표 재측정) |
| 런처가 AGL 홈스크린과 겹쳐 보임 / 런처가 안 보임 | agl-shell 이 창 기하를 소유 — 풀화면 롤을 못 받았거나, 매핑 전 `SetAppFullscreen` 으로 서페이스가 죽음 | [풀화면 메인화면 가이드](board-launcher-fullscreen-guide.md) — 컨테이너 재생성으로 복구 |
| rviz2 를 켰는데 화면이 런처 그대로 | 풀화면 롤이 일반 창보다 위 레이어 → `ActivateApp wlroots` 만으로는 가려짐 | rviz2 이미지 갱신(entrypoint 가 `SetAppFullscreen wlroots` 수행) |

---

## 6. 실측 기록 (2026-08)

| 구간 | 결과 |
|---|---|
| 보드(arm64) 누적 | **239 회 PASS** (최장 연속 174 회) |
| PC(amd64) | 12·5·5·5 회 PASS — 유일한 실패는 위 `engage` 폴링 문제로 원인 규명·수정 |
| 회차 소요 | 보드 325~342초 · PC 297초 → 폴링 전환 후 약 200초 목표 |
| rviz2 fps | 보드 2~4 (llvmpipe) · PC 31 |

산출물: 회차별 캡처(`PC-<n>-*.png` / `L-<n>-*.png`)와 실행 로그가 스크립트 실행 디렉토리에 남는다.

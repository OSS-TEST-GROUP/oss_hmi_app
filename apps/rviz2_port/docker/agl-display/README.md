# rviz2 AGL-display 컨테이너 (cage 기반) — 현재 정본

> Orin AGX + AGL 순수 Wayland 에서 rviz2 를 실행하는 **컨테이너 격리** 방식. 호스트 AGL
> 이미지는 불변, docker 컨테이너 안에서 rviz2 스택(ROS2 Humble / Qt5 / OGRE) 전체를 격리.
> 2026-07-20 Orin AGX 실기 검증(표출 5/5) + 2026-07-23 입력(XTEST) 검증 완료.

## 구조

```
cage(wlroots 키오스크, app_id="wlroots", wayland 클라이언트 + XWayland 내장)
  └─ rviz2 (Qt5/OGRE → llvmpipe SW-GL)   # OGRE 1.12.1 = rviz-ogre-vendor 번들(별도 OGRE 설치 불필요)
```
- **아키 무관 Dockerfile**: `FROM ros:humble-ros-base` + apt(ros-humble-rviz2 / cage / xwayland). ros:humble 는 멀티아치(amd64+arm64) 베이스라 한 Dockerfile 로 양 아키 빌드.
- cage 채택: weston 9 는 `set_app_id` 미호출 → agl-compositor 활성화 불가. cage 는 app_id="wlroots" 설정 + 단일앱 풀스크린.

## 파일

| 파일 | 역할 |
|---|---|
| `Dockerfile` | rviz2 + cage + xwayland 컨테이너 (아키 무관) |
| `entrypoint.sh` | `cage -- ros2 run rviz2 rviz2` (app_id=wlroots, SW-GL) |
| `run-on-board.sh` | 보드(arm64/AGL) 수동 실행 — 소켓 탐지 + docker run + agl-shell 활성화 |
| `agl-service-list.rviz2.yaml` | ext-agl(adsw_manager) 등재 스니펫 (부팅 자동기동/복구) |
| `autoware-sim.sh` | 151 보드 Autoware 를 자율주행시켜 이 rviz2 로 시각화 검증 (아래) |
| `autoware-lane-chain.py` | 라우팅 그래프에서 긴 주행 경로(EGO/GOAL 포즈) 추출 |

## 자율주행 시뮬레이션 검증 (151 Autoware ↔ 81 rviz2)

151 보드의 Autoware(planning simulator)에 경로를 넣고 autonomous 로 engage 하면,
81 보드에서 도는 이 rviz2 가 주행을 실시간으로 그린다.

```bash
# 1) 경로 후보 뽑기 (Autoware 컨테이너 안 — lanelet2 + 지도가 있는 곳)
scp autoware-lane-chain.py beyhpc@172.16.10.151:/tmp/
ssh beyhpc@172.16.10.151 'docker cp /tmp/autoware-lane-chain.py autoware-perception:/tmp/ && \
  docker exec autoware-perception bash -lc "source /opt/autoware/setup.bash; python3 /tmp/autoware-lane-chain.py"'

# 2) 주행 트리거 (기본값 = 실측 검증된 794m 루프)
ssh beyhpc@172.16.10.151 'bash -s' < autoware-sim.sh
#   다른 경로: EGO="…" GOAL="…" 를 스크립트 앞에 붙여 env 로 넘긴다
```

**실측 결과** (2026-08-04): lanelet 4 → 99, 794m / 36 세그먼트, **115초 완주**,
목표점 오차 5cm. 보드 rviz2 에 `Motion | Moving` / 기어 `D` / 9 km/h /
남은거리·ETA / 초록 궤적이 표시되고, 도착 시 `Routing | Arrived` + 기어 `P` 로 전환.

주행이 안 될 때의 실측 원인 두 가지:
- `route: success=False message='The planned route is empty.'` — 시작·목표가
  **라우팅 그래프상 연결되지 않음**. 기하적으로 이어져 보여도 lanelet 관계가 없으면
  실패한다 → `autoware-lane-chain.py` 후보를 쓸 것.
- engage 는 되는데 안 움직이고 `MRM State | Normal→Emergency` — 차량이 차선 밖에
  놓여 `trajectory_deviation` ERROR → MRM 비상정지. EGO 를 차선 중앙으로 다시 잡는다.

### 화면에서 Pose / Goal 지정 (2026-08-14 실측)

1. 툴바 `2D Pose Estimate` → 지도에서 **차선 한가운데**를 누른 채 **진행 방향으로 끌고 놓기**
2. 툴바 `2D Goal Pose` → 진행 방향 **앞쪽** 차선 한가운데에서 같은 방식
3. 왼쪽 `AutowareStatePanel` 에서 `Localization | Initialized`, `Routing | Set` 확인 후 `Auto`

터치 조작 팁:

| 항목 | 내용 |
|---|---|
| 툴은 1회용 | 한 번 쓰면 `Interact` 로 돌아간다 — 다시 찍으려면 툴 버튼을 다시 누른다 |
| 지도 이동(팬) | 지도 위 한 손가락 드래그 (`Interact`/`Move Camera` 둘 다) |
| 확대/축소 | 마우스 휠. 터치만 있으면 Views 패널의 `Scale`(px/m) 값. `Zero` 버튼이 Scale 10 / Angle 0 / X,Y 0 으로 리셋 |
| 차선 폭 | Scale 10 에서 **화면상 약 50~70px**. 조금만 벗어나도 실패한다(실측) |
| 목표 판정 | 위치뿐 아니라 **각도**도 본다 — 목표 자세의 **차량 사각형이 차선 안에 다 들어가야** 한다. 벗어나면 `Goal's footprint exceeds lane!` → `Goal is not valid! Please check position and angle of goal_pose` → `The planned route is empty` (실측). 드래그를 **차선 중심선과 나란히** 해야 통과한다 |

**이 두 가지를 고치기 전에는 화면 조작이 전혀 먹지 않았다**:

| 증상 | 원인 | 조치 |
|---|---|---|
| 찍어도 Autoware 가 못 받음 | entrypoint 의 DDS NIC 화이트리스트가 rviz2 의 **발신**을 막았다. `ros2 node list` 에 rviz2 노드가 0개로 안 보였다 | `DDS_NIC_WHITELIST` 기본 해제 (필요한 보드만 `=1`) |
| 포즈를 찍어도 차량이 안 움직임 | rviz 기본 `SetInitialPose` 툴은 `/initialpose` 로 쏘는데 planning simulator 는 `/initialpose3d` 만 받는다 | entrypoint 가 툴 블록의 토픽을 `/initialpose3d` 로 치환 (`RVIZ_INITIALPOSE3D=0` 로 해제) |

**출발이 안 될 때**(`Routing | Set` 인데 `Motion | Stopped` + `Accept Start` 비활성):
151 로그에 `planning trajectory is too far from ego in longitudinal direction` → `Invalid Trajectory
published` 가 반복되면 플래닝 상태가 틀어진 것이다. 포즈가 차선 중앙/방향에서 벗어났거나,
경로를 여러 번 바꿔 상태가 꼬인 경우다. STOP → `clear_route` → 포즈 재설정으로 안 풀리면
**Autoware 3 파티션을 재기동**한다(`docker restart autoware-{decision,control,perception}`).

### 맵이 안 보일 때 — **먼저 초기 위치를 확인한다** (2026-08-14 실측)

증상: rviz2 는 정상 기동하고 Displays 도 `Global Status: Ok` 인데 화면에 폴라 그리드와
차량만 있고 **맵(점군·레인렛)이 전혀 없다**.

원인은 대개 rviz2 가 아니라 **151 Autoware 의 초기 위치 미설정**이다. KCity 맵은 원점에서
멀리 떨어져 있고(실측: 맵 마커 x≈3,684 / y≈73,713 — 약 73km), 카메라는 에고(base_link)를
따라가도록 설정돼 있다. 초기 위치가 없으면 `/localization/kinematic_state` 와 `/tf` 가
발행되지 않아 카메라가 원점에 머물고, 맵은 화면 밖에 있다.

판별 (rviz2 컨테이너 안에서):

```bash
docker exec rviz2 bash -lc 'source /opt/ros/humble/setup.bash
  ros2 topic echo --once /map/vector_map_marker | head -3   # 맵 자체는 오는가(latched)
  timeout 5 ros2 topic echo --once /localization/kinematic_state   # 에고 위치 — 없으면 이 문제
  timeout 5 ros2 topic echo --once /tf'                            # 동적 TF — 없으면 이 문제
```

`AutowareStatePanel` 의 `Localization | Uninitialized` 도 같은 신호다.

조치 — 초기 위치만 넣으면 즉시 맵이 뜬다(주행까지 하려면 `autoware-sim.sh`):

```bash
docker exec rviz2 bash -lc 'source /opt/ros/humble/setup.bash
  ros2 topic pub -t 5 /initialpose3d geometry_msgs/msg/PoseWithCovarianceStamped \
   "{header: {frame_id: map}, pose: {pose: {position: {x: 3655.152, y: 73490.295, z: 0.0},
     orientation: {z: 0.981391, w: 0.192022}}}}"'
```

> 토픽은 `/initialpose3d` 다 — rviz2 의 `/initialpose` 가 아니다(실측).

### 에고 차량이 안 보일 때 (해결됨 — 기본 동작 변경)

`autoware.rviz` 의 기본 뷰는 `TopDownOrtho` + `Target Frame: viewer` 인데, **`viewer` 는
Autoware 가 맵 중심에 고정해 발행하는 static 프레임**이다(실측: `map→viewer` =
(3749.7, 73724.3)). Scale 10 이면 화면에 보이는 범위가 약 93×95m 라서, 에고가 맵 중심에서
멀어지면 **차량이 화면 밖으로 나가** "ego 가 안 보인다"가 된다. 모델(URDF 30,768B +
`lexus.dae`/velodyne 메시)은 정상 로드된 상태였고 **카메라만의 문제**였다.

→ `entrypoint.sh` 가 기동 시 config 사본을 만들어 **Current View 의 Target Frame 만
`base_link` 로 치환**한다(저장된 뷰 `ThirdPersonFollower`/`TopDownOrtho@viewer` 는 그대로
남아 rviz Views 패널에서 선택 가능). 맵 중심 고정을 원하면 `-e RVIZ_FOLLOW_EGO=0`.

함께 고친 것 — rviz 플러그인이 읽는 **차량 치수 파라미터**. Autoware 는 rviz 를
vehicle_info 파라미터와 함께 launch 하지만 우리는 `ros2 run` 이라 비어 있어
`Failed to get vehicle_info: parameter 'wheel_radius' is not initialized` 경고가 났다.
오버레이의 `sample_vehicle_description/config/vehicle_info.param.yaml` 을
`--ros-args --params-file` 로 주입해 경고 0건(실측). 끄려면 `-e RVIZ_VEHICLE_PARAMS=0`,
다른 차량이면 `-e RVIZ_VEHICLE_PARAM_FILE=<경로>`.

전제: 양쪽 `ROS_DOMAIN_ID=42` + 같은 RMW(`rmw_fastrtps_cpp`) + 멀티 NIC 화이트리스트
(entrypoint 가 자동 처리). rviz2 는 `RVIZ_CONFIG=/opt/autoware/share/autoware_launch/rviz/autoware.rviz`
로 띄운다 (rviz2_panel 의 "Autoware (151) preset" 버튼이 이 3개를 한 번에 채운다).

## autoware 오버레이 — 이제 이미지 안에 들어있다 (별도 오버레이 이미지 없음)

`Dockerfile.all`(정본, 예전엔 `Dockerfile.autoware`)이 **`/opt/autoware` 트리를 통째로**
—151 이 실제로 실행하는 파티션 이미지에서 직접— 복사한다(548MB). 예전처럼 `/opt/autoware`
만 담은 별도 `autoware-overlay` 이미지를 사람이 만들어 push 하는 단계는 **없다**.

> ⚠️ 선별 복사가 아니다. rviz2 가 쓰는 건 msgs 라이브러리 + rviz 플러그인 + `.rviz` 설정
> 뿐인데(합 ~57MB), 파티션의 설치 트리 전체가 함께 온다 — 아래 인벤토리 참조.

```dockerfile
ARG AUTOWARE_SRC_IMAGE=ghcr.io/oss-test-group/autoware-partition:adsw-perception
ARG TOUCH_IMAGE=registry.obigo.com/oss/rviz2-agl:touch
FROM ${AUTOWARE_SRC_IMAGE} AS awsrc
FROM ${TOUCH_IMAGE}        AS autoware
...
COPY --from=awsrc /opt/autoware /opt/autoware
```

바뀐 점과 이유:

| | 이전 (autoware-overlay 이미지) | 현재 (단일 이미지) |
|---|---|---|
| 오버레이 준비 | 151 에서 수동 추출 + push | **없음** — 빌드가 파티션 이미지에서 직접 COPY |
| 버전 정합 | 사람이 갱신을 잊으면 어긋남 | 실행 중 Autoware 와 **같은 이미지**라 자동 정합 |
| 아키 | arm64 단일(151 에서 추출) | 파티션 이미지가 멀티아치 → **amd64/arm64 자동 선택** |
| 빌드 시 당기는 용량 | 548MB | 5.7GB (파티션 이미지, 최초 1회·레이어 캐시됨) |

### 포함된 파일 인벤토리 (2026-08-11 실측, `rviz2-agl:latest` = 4201d2d)

`COPY --from=awsrc /opt/autoware /opt/autoware` 한 줄이 가져오는 것의 실제 내용:

| 최상위 | 크기 | 내용 |
|---|--:|---|
| `lib/` | 362MB | 공유 라이브러리 508개 + **노드 실행 파일 201개** |
| `share/` | 101MB | 패키지 자원 244개 (msg 정의, `.rviz`, 파라미터, 메시/URDF) |
| `include/` | 53MB | 헤더 — **런타임 불필요** (빌드용) |
| `local/` | 34MB | ament 병합 설치 레이아웃 |
| `setup.bash` 외 | ~60KB | 환경 스크립트 (entrypoint 가 source) |

**패키지 244개의 실제 구성** — "msgs + 플러그인"이 아니다:

| 분류 | 개수 | rviz2 가 쓰는가 |
|---|--:|---|
| `*_msgs` (autoware_* / tier4_* / nebula·pandar·robosense·morai 등) | 40 | ✅ 토픽 역직렬화에 필수 |
| rviz 플러그인 패키지 | 16 | ✅ 화면 표출 |
| 그 외 (perception·planning·localization 노드, CUDA 유틸, launch, cmake) | 188 | ❌ 딸려온 것 |

**rviz 플러그인 16종** (`find /opt/autoware/lib -name "*rviz*plugin*.so"`):

```
libautoware_bag_time_manager_rviz_plugin.so   libtier4_adapi_rviz_plugin.so
libautoware_mission_details_overlay_rviz_plugin.so  libtier4_camera_view_rviz_plugin.so
libautoware_overlay_rviz_plugin.so            libtier4_datetime_rviz_plugin.so
libautoware_perception_rviz_plugin.so         libtier4_dummy_object_rviz_plugin.so
libautoware_string_stamped_rviz_plugin.so     libtier4_localization_rviz_plugin.so
libtier4_planning_factor_rviz_plugin.so       libtier4_planning_rviz_plugin.so
libtier4_state_rviz_plugin.so                 libtier4_system_rviz_plugin.so
libtier4_traffic_light_rviz_plugin.so         libtier4_vehicle_rviz_plugin.so
```

**rviz 설정** — `autoware.rviz` 가 **두 곳**에 있다(내용은 사실상 동일, 2바이트 차):

| 경로 | 크기 |
|---|--:|
| `share/obigo_launch/rviz/autoware.rviz` | 162,069 B |
| `share/autoware_launch/rviz/autoware.rviz` | 162,067 B |

같은 두 디렉토리에 `planning_bev.rviz` / `planning_tpv.rviz` / `perception.rviz` /
`scenario_simulator.rviz` / `autoware_test_utils.rviz` 도 함께 온다
(`obigo_launch` 7.5MB / `autoware_launch` 2.4MB). 패널의 "Autoware (151) preset" 은
`autoware_launch` 쪽 경로를 채운다.

**오버레이가 이미지 밖에서 필요로 하는 apt 패키지** (`Dockerfile.all` runtime 스테이지):
오버레이만 복사하면 그 밖의 transitive 의존이 없어 `autoware.rviz` 로드가 중단된다.

```
ros-humble-lanelet2  ros-humble-geographic-msgs  ros-humble-unique-identifier-msgs
ros-humble-pcl-msgs  ros-humble-radar-msgs       ros-humble-grid-map-msgs
ros-humble-velodyne-msgs  ros-humble-can-msgs    ros-humble-udp-msgs
ros-humble-logging-demo
```

특히 `geographic_msgs` 가 없으면 `autoware_adapi_v1_msgs` 구독이
`Type support not from this implementation` 으로 실패한다(실측).

### 다이어트 — 실제 쓰는 것만 남긴다 (548MB → 154MB)

위 인벤토리대로 파티션 트리에는 rviz2 가 쓰지 않는 것이 대부분이다. 그래서 빌드가
[prune-autoware-overlay.sh](./prune-autoware-overlay.sh) 로 트리를 줄인다
(`Dockerfile.all` 의 `awtrim` 스테이지, 전체 트리를 원하면 `--build-arg AUTOWARE_PRUNE=0`).

**손으로 만든 제외 목록을 두지 않는다** — 목록은 파티션 갱신 때마다 어긋난다(예전
`autoware-overlay` 이미지가 겪은 문제). 대신 유지 집합을 트리 자신에서 유도한다:

| 단계 | 규칙 |
|---|---|
| 유지 패키지 | rviz 플러그인 인덱스(`ament_index/…/rviz_common__pluginlib__plugin`) ∪ msgs(`rosidl_interfaces`) ∪ `*_description`(URDF `package://` 메시) ∪ `*_launch`(`.rviz` 설정) |
| 유지 라이브러리 | 위 패키지의 `.so` → **ldd 클로저**(트리 내부 의존만, `LD_LIBRARY_PATH=$SRC/lib` 필수) |
| share | 패키지 디렉토리만 걸러내고 **인프라 디렉토리(`ament_index`, `colcon-core`)는 유지** |
| 파이썬 모듈 | `local/lib/python3.*/dist-packages/<유지 패키지>` — rviz2 화면엔 불필요하지만 **컨테이너 안 `ros2` CLI 가 Autoware 타입을 다루려면 필요** |
| 최상위 | 파일 전부 유지 (`.colcon_install_layout` 등 숨김 마커 포함) |

파티션이 새 플러그인·새 msgs 를 추가하면 자동으로 유지 집합에 들어온다.

**결과(2026-08-14 amd64 실측)**: 548MB → **154MB**, 패키지 244 → 90, `.so` 508 → 358,
파이썬 모듈 42 개 유지. 이미지 전체는 2.1GB → 1.7GB 대.

> 파이썬 모듈은 처음엔 통째로 버렸었다(그때 124MB). 화면은 멀쩡했지만 **컨테이너 안에서
> 진단이 불가능**해졌다 — `ros2 service call … autoware_adapi_v1_msgs/srv/…` 가
> "The passed service type is invalid", `ros2 topic echo /api/…` 가 무응답이었다.
> rviz2 자체는 C++ 타입서포트(`.so`)만 쓰기 때문에 증상이 화면에 안 나타나서 늦게 발견됐다.
> 지금은 유지 패키지의 모듈만 남긴다(+30MB).

**빌드 가드 3종** — 프룬이 조용히 망가지는 것을 막는다(아래 세 실패를 실제로 겪었다):

| 가드 | 검사 | 놓쳤을 때의 증상 |
|---|---|---|
| 1 | 플러그인 인덱스 ≥ 10 | rviz 가 Autoware 디스플레이를 **하나도** 못 만든다 |
| 2 | `_local_setup_util_sh.py` 가 `AMENT_PREFIX_PATH` 를 생성 | `share/colcon-core/packages` 나 `.colcon_install_layout` 이 빠지면 패키지 0개로 보여 환경이 안 만들어진다 |
| 3 | 남긴 `.so` 의 미해결 의존 0 | 플러그인이 `dlopen` 실패로 조용히 빠진다(ldd 클로저를 `LD_LIBRARY_PATH` 없이 돌렸을 때 실제로 발생) |

**검증**: Xvfb 로 `rviz2 -d autoware.rviz` 를 띄워 전체 트리(기준선)와 프룬 트리의 로그를
비교한다 — 둘 다 `[ERROR]` 0 이어야 한다.

```bash
docker build -q -t rviz2-verify . <<'EOF'
FROM registry.obigo.com/oss/rviz2-agl:latest
USER root
RUN apt-get update && apt-get install -y --no-install-recommends xvfb && rm -rf /var/lib/apt/lists/*
EOF
docker run --rm --entrypoint bash rviz2-verify -c '
  export LIBGL_ALWAYS_SOFTWARE=1
  source /opt/ros/humble/setup.bash; source /opt/autoware/setup.bash
  xvfb-run -s "-screen 0 1920x1080x24" timeout 60     rviz2 -d /opt/autoware/share/autoware_launch/rviz/autoware.rviz 2>&1 | grep -c ERROR'
```

인벤토리 재현 명령:

```bash
docker run --rm --entrypoint bash registry.obigo.com/oss/rviz2-agl:latest -c '
  du -sh /opt/autoware /opt/autoware/*
  ls /opt/autoware/share | wc -l                        # 244
  ls /opt/autoware/share | grep -c "_msgs$"             # 40
  find /opt/autoware/lib -name "*rviz*plugin*.so" | wc -l   # 16
  find /opt/autoware/share -name "*.rviz"'
```

### Dockerfile 을 고치는 대신 build-arg 로 넘긴다

- **다른 파티션**(decision/control)이나 **특정 스냅샷 핀**:
  `--build-arg AUTOWARE_SRC_IMAGE=ghcr.io/oss-test-group/autoware-partition:adsw-decision`
  (재현성이 필요하면 `…@sha256:<digest>` 로 다이제스트 핀)
- **레지스트리/네임스페이스 이전**: 같은 인자의 앞부분만 바꿔 넘긴다.
- **아키별 touch 베이스 지정**: 레지스트리의 `:touch` 는 아직 arm64 만 올라가 있다. amd64 를
  빌드할 때는 로컬 빌드본을 지정한다 —
  `--build-arg TOUCH_IMAGE=rviz2-agl:touch-amd64`

### amd64(x86 dev/CI) 빌드

`:touch` 의 라이브러리 경로가 아키 무관으로 바뀌고(두 트리플릿 나열 + grpcurl `TARGETARCH`
매핑) 오버레이가 멀티아치 파티션에서 오므로, **x86 PC 에서도 같은 Dockerfile 로** 체인이 빌드된다:

```bash
cd apps/rviz2_port/docker/agl-display
DOCKER_BUILDKIT=1 docker build --platform linux/amd64 -f Dockerfile.touch -t rviz2-agl:touch-amd64 .
DOCKER_BUILDKIT=1 docker build --platform linux/amd64 -f Dockerfile.autoware \
    --build-arg TOUCH_IMAGE=rviz2-agl:touch-amd64 -t rviz2-agl:amd64-autoware .
```
> x86 은 agl-compositor 가 없어 cage/homebar 경로가 그대로 동작하지 않는다 — 표출은
> `run-rviz2-x86.sh`(호스트 X11 직행) 또는 nested weston 을 쓴다.

### 로컬 이미지를 build-arg 로 넘길 때 — 빌더별 차이

`COPY --from` / `FROM` 의 **로컬 이미지** 해석은 빌더에 따라 다르다(실측 2026-08-04):

| 빌더 | 로컬 이미지 사용 | 이 프로젝트에서 쓰는 곳 |
|---|:-:|---|
| classic (`DOCKER_BUILDKIT=0`) | ✅ | `build_rviz2_autoware.sh` (보드 네이티브 빌드) |
| dockerd 내장 BuildKit (기본 드라이버) | ✅ | 수동 `docker build` (위 amd64 예시) |
| buildx `docker-container` 드라이버 | ❌ 레지스트리에서만 해석 | `build_rviz2_local.sh` (로컬 QEMU 빌드) |

buildx docker-container 경로에서 로컬 태그를 쓰려면 push 하거나 `--build-context` 로 우회한다:

```bash
docker buildx build --build-context awsrc=docker-image://<로컬태그> …
```

### 갱신이 실제로 의미 있는지 판별 (3-해시)

Autoware 파티션이 바뀌었을 때 **rviz2 재빌드가 의미 있는지**는 세 해시로 판별한다. launch
XML(`share/obigo_launch/…`)이나 `__pycache__` 만 달라진 경우 rviz2 는 쓰지 않으므로 재빌드
이득이 없다. 양쪽(151 파티션 컨테이너 / 보드 rviz2 컨테이너)에서 각각:

```bash
find /opt/autoware/lib -name "*rviz*plugin*.so" | sort | xargs md5sum | md5sum        # 플러그인 16종
find /opt/autoware/lib -name "libautoware_*msgs*.so" -o -name "libtier4_*msgs*.so" \
  | sort | xargs md5sum | md5sum                                                     # msgs 라이브러리
md5sum /opt/autoware/share/autoware_launch/rviz/autoware.rviz                        # rviz 설정
```

(2026-08-04 실측: 세 해시 일치 → 당시 재추출 불필요였다.)

**빌드 후 확인**: `docker exec rviz2 ls /opt/autoware/share | wc -l`(244 기준) + 위 세 해시 +
`autoware.rviz` 무오류 로드(기동 로그 `▶ autoware 오버레이 로드됨`).

## 태그 정책 (2026-08-14 확정)

보드는 **`:latest` 를 pull 해서** 쓴다. 그래서 `:latest` 는 항상 **전 기능 이미지**여야 한다.

| 태그 | 내용 | 만드는 방법 |
|---|---|---|
| **`:latest`** | 터치(소스빌드 wayland 1.22/wlroots/cage) + homebar + grpcurl + Autoware 오버레이 **전부** | `Dockerfile.all` 로 각 아키 네이티브 빌드 → per-arch push → [publish-latest.sh](./publish-latest.sh) |
| `autoware-<branch>-<date>-<sha>` | 위와 동일한 내용의 **불변 스냅샷** | 같은 빌드에서 함께 push |
| **`:base`** | ros:humble + rviz2 + apt cage 만 (터치·homebar·오버레이 **없음**) | `apps/docker/script/build_rviz2_multiarch.sh` (기본 태그가 `:base`) |
| `provision` | 프로비저닝용 변종 | 별도 관리 |

`:latest` 는 반드시 `publish-latest.sh` 로 옮긴다 — 필수 구성 4종(cage/homebar/grpcurl/`/opt/autoware`)을
**두 아키 모두** 확인하고, 하나라도 없으면 태그를 옮기지 않는다:

```bash
./publish-latest.sh autoware-develop-20260811-5ef55ee     # 검증 → :latest 이동
VERIFY_ONLY=1 ./publish-latest.sh <태그>                   # 검증만
```

> **왜 이 정책이 생겼나**: 2026-08-13 에 베이스 빌드 스크립트(`build_rviz2_multiarch.sh`,
> 당시 기본 `TAG=latest`)가 `:latest` 를 덮어써 보드에서 **터치·홈버튼·Autoware 오버레이가
> 전부 사라졌다**. 이미지에는 최신 entrypoint 만 들어 있어 cage 를 찾지 못했다.
> 지금은 ① 그 스크립트의 기본 태그가 `:base` 이고 `TAG=latest` 면 실행을 거부하며
> ② `:latest` 이동은 위 검증 스크립트를 거친다.

## 빌드 — **Dockerfile.all 하나로** (권장)

`:base` → `:touch` → `:latest` 3-이미지 체인을 **단일 multi-stage Dockerfile** 로 합쳤다
(`Dockerfile.all`). 중간 태그를 유지·동기화할 필요가 없고, 빌드 도구가 최종 이미지에서
빠져 약 **210MB 작다**(실측 amd64 2.31GB → 2.1GB, arm64 3.09GB → 2.85GB).

```bash
cd apps/rviz2_port/docker/agl-display
# 네이티브 빌드(권장) — QEMU 소스빌드는 수 시간이라 각 아키에서 네이티브로 만든다
DOCKER_BUILDKIT=1 docker build -f Dockerfile.all -t registry.obigo.com/oss/rviz2-agl:latest .
# 다른 파티션/스냅샷 핀
DOCKER_BUILDKIT=1 docker build -f Dockerfile.all \
  --build-arg AUTOWARE_SRC_IMAGE=ghcr.io/oss-test-group/autoware-partition:adsw-decision -t … .
# 멀티아치: 아키별로 만들어 push 한 뒤 매니페스트 결합
docker buildx imagetools create -t <repo>:latest <repo>:<snap>-amd64 <repo>:<snap>-arm64
```

스테이지 구성: `awsrc`(파티션 이미지 = 오버레이 공급) · `runtime`(ros+rviz2+RMW+XWayland+
SW-GL+오버레이 런타임 의존) · `builder`(wayland/wlroots/cage/grpcurl/homebar 소스빌드) ·
`final`(runtime + builder 의 /usr/local + awsrc 의 /opt/autoware + entrypoint).

> 통합 과정에서 체인이 **가려온 의존 2건**이 드러나 명시적으로 선언했다:
> `libxcb-composite0`/`libxcb-res0`(런타임 — 예전엔 `-dev` 패키지 덕에 우연히 존재),
> `xwayland`(**빌드타임** — wlroots `-Dxwayland=enabled` 요구, 예전엔 `:base` 에서 상속).

## 빌드 (레거시 3-변형 체인, 하위호환)

```bash
cd apps
./docker/script/build_rviz2_multiarch.sh              # → registry.obigo.com/oss/rviz2-agl:latest
TAG=multiarch-verify ./docker/script/build_rviz2_multiarch.sh   # 검증용(:latest 미변경)
```
> Flutter 앱(build_multiarch.sh)과 달리 아키별 번들이 없어 `buildx --platform=amd64,arm64` **한 방**으로 manifest list 생성 (2회 빌드 + imagetools 결합 불필요).

## 런타임

- **arm64 (Orin/AGL — 주 타겟)**: `./run-on-board.sh` (수동) 또는 ext-agl 등재(자동). 표출/홈전환은 agl-shell 스위처(F006, `docs/design/F006-switcher.md`) 가 `agl-shell-activator -a activate -p wlroots` 로 수행.
- **amd64 (x86 dev/CI)**: `bash docker/script/run-rviz2-x86.sh` — 호스트 X11 에 rviz2 직접 실행(cage 우회). `GPU=nvidia|none`.

## 설치 (보드 자동시작 — ext-agl)

`/opt/adsw/config/agl-service-list.yaml` 의 `services:` 에 `agl-service-list.rviz2.yaml` 항목 추가 → adsw_manager 가 rviz2 컨테이너를 기동/복구 관리.

```bash
# 보드에서 (예시)
scp agl-service-list.rviz2.yaml root@<board>:/tmp/
ssh root@<board> 'cat /tmp/agl-service-list.rviz2.yaml >> /opt/adsw/config/agl-service-list.yaml && docker restart oss-mmf-ext-agl'
```
> ⚠️ ext-agl 은 `docker run` 만 하고 **agl-shell 활성화는 안 함** → rviz2 는 기동되지만 비활성(비표출). 표출은 F006 스위처가 담당(상시기동 + activate-swap 모델).

## GPU 가속 (F008, 선택)

현재 llvmpipe(SW, ~30fps). 런처가 쓰는 `/opt/nv-gl`(호스트 NVIDIA GL 스택) 마운트 패턴을 적용하면 tegra EGL 가속 — 후속 F008.

## 📌 rviz2_port 는 이 두 디렉토리만 남았다

`rviz2_port/` 의 나머지(포팅 청사진 R005~R016 의 x86 개발체인 Dockerfile, Yocto
`meta-rviz2-agl` 레이어, scripts/tools, ADR·baseline 문서, RVIZ2_GUIDE.md,
RVIZ2_AUTOWARE_CONNECT.md, docker-compose.yml)는 **삭제됐다**. 현재 실제로 쓰이는 것은:

| 디렉토리 | 역할 |
|---|---|
| `agl-display/` (본 디렉토리) | 보드에서 도는 rviz2 이미지 — `:base` → `:touch` → `:latest`(autoware). **홈 버튼(homebar)도 이 이미지에 통합**(`homebar.c`) |

**homebar 통합(2026-08)**: 예전엔 `../homebar/` 의 별도 컨테이너였다. homebar 는 cage 와
무관한 **호스트 agl-compositor 의 일반 Wayland 클라이언트**라 rviz2 와 같은 컨테이너에서
돌려도 동작이 동일하고, 생명주기가 일치해(버튼은 rviz2 가 살아있는 동안만 존재) 부팅 시
show/hide 경합과 스테일 서페이스가 사라진다. `Dockerfile.touch` 가 `homebar` 바이너리와
`grpcurl` 을 담고, `entrypoint.sh` 가 cage 와 함께 띄운 뒤 서페이스 매핑 마커를 기다려
float 한다. 끄려면 `-e HOMEBAR=0`. adsw 서비스 목록에서도 homebar 항목이 제거됐다.

> 삭제된 파일들은 **git 이력에 그대로 남아 있다** — 필요하면
> `git log --diff-filter=D --oneline -- apps/rviz2_port` 로 찾아 복원한다.

## 참고
- **cage 구조 해설**: [`../../docs/cage-architecture.md`](../../docs/cage-architecture.md) — cage 가 무엇인지,
  중첩 컴포지터 이중 역할, 소켓 2개, 터치 소스빌드 스택, 실측 제약 전체
- 표준 빌드/푸시 스크립트: `apps/docker/script/build_rviz2_autoware.sh`(autoware 변형),
  `build_rviz2_multiarch.sh`(base/멀티아치)
- rviz2 를 제어하는 앱: `apps/rviz2_panel/`

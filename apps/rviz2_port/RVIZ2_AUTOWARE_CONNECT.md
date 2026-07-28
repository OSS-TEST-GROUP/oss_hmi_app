# RViz2(162) ↔ Autoware(151) 크로스보드 연결 스펙

> **목적**: 162 보드의 `rviz2_monitor`(→ rviz2 컨테이너)가 **151 보드에서 실행 중인
> Autoware**의 ROS2 그래프에 크로스보드로 붙어 시각화하기 위한 **실행 옵션 스펙**.
> rviz2_monitor 개발/운영 에이전트 전달용. 최종 갱신: 2026-07-25.

## 1. 토폴로지

| 보드 | 실행 | 네트워크 | DDS |
|---|---|---|---|
| **151** | Autoware perception/decision/control (`junohb/autoware-partition:sample-adsw-*`) | `--network host` + `--pid=host` | **`ROS_DOMAIN_ID=42`**, RMW = 이미지 기본값(§3-② 확인 필요) |
| **162** | rviz2 (rviz2_monitor가 `docker run --net=host …`) | `--net=host` | rviz2 이미지 기본 = **FastDDS** |

- 두 보드 동일 서브넷(`172.16.10.x`), **다른 호스트** → 공유메모리(SHM) 불가, **UDP 디스커버리로만** 연결된다.
- 크로스보드 연결의 3대 변수: **① 도메인 · ② RMW · ③ 디스커버리** (아래 §3).

## 2. rviz2 필수 실행 옵션 (`docker run`)

```bash
docker run -d --name rviz2 \
  --net=host --ipc=host \                  # (기존 유지) 실 NIC DDS / 동일호스트 SHM(크로스보드는 UDP fallback)
  --user 1001:1001 --group-add 44 \
  -v /run/user/1001:/host-xdg -e XDG_RUNTIME_DIR=/host-xdg -e WAYLAND_DISPLAY=wayland-0 \
  -e HOME=/tmp -e LIBGL_ALWAYS_SOFTWARE=1 \
  -e ROS_DOMAIN_ID=42 \                     # ① Autoware 와 반드시 동일
  -e RMW_IMPLEMENTATION=<Autoware와 동일> \  # ② rmw_fastrtps_cpp | rmw_cyclonedds_cpp (§3-②)
  # ROS_LOCALHOST_ONLY 는 설정 금지(=0 유지). 1이면 크로스보드 차단.
  # (멀티캐스트 불가 시) ③ 유니캐스트 피어 설정 파일 마운트 (§3-③)
  registry.obigo.com/oss/rviz2-agl:latest
```

> `run-on-board.sh` / rviz2_monitor 기본 `dockerRunArgs` 에 이미 있는 것: `--net=host --ipc=host
> --user 1001:1001 --group-add 44 -v /run/user/1001:/host-xdg -e XDG_RUNTIME_DIR -e WAYLAND_DISPLAY
> -e HOME=/tmp -e LIBGL_ALWAYS_SOFTWARE=1`. **추가로 필요한 건 ①②(③)** 뿐이다.

## 3. 3대 변수 상세

### ① `ROS_DOMAIN_ID=42` — 반드시 Autoware와 동일
- rviz2_monitor **Run Options의 `ROS_DOMAIN_ID` 필드에 `42`** 입력 → `-e ROS_DOMAIN_ID=42` 로 주입.
- 값이 다르면 토픽이 **전혀** 안 보인다. (Autoware saved-service-list 가 domain 42 로 격리 기동함)

### ② `RMW_IMPLEMENTATION` — Autoware와 반드시 일치 (⚠ 최대 위험 포인트)
- 현재 **rviz2 이미지 = FastDDS**(`ros-humble-rviz2` apt 기본, RMW 미명시). Autoware 이미지도 RMW env 가
  baked 되어 있지 않아 **런타임 기본값**을 쓴다 → 실제 값을 반드시 확인해야 한다.
- **확인 (Autoware 실행 중일 때, 151에서):**
  ```bash
  docker exec <autoware컨테이너> printenv RMW_IMPLEMENTATION   # 비어 있으면 Humble 기본 = rmw_fastrtps_cpp
  ```
- **분기:**
  - Autoware = **FastDDS(`rmw_fastrtps_cpp`)** → rviz2 그대로 일치 ✅ (RMW env 생략 가능)
  - Autoware = **CycloneDDS(`rmw_cyclonedds_cpp`)** → rviz2 이미지에 **`ros-humble-rmw-cyclonedds-cpp` 설치** +
    `-e RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` 필요. (RMW 불일치 시 discovery 자체가 안 됨)
- **권장**: rviz2 이미지에 **두 RMW 모두 설치**해두고, rviz2_monitor Run Options 에 **`RMW_IMPLEMENTATION`
  입력 필드**를 추가(ROS_DOMAIN_ID 처럼 `-e` 주입) → 이미지 재빌드 없이 Autoware 쪽에 맞춘다.

### ③ 크로스보드 디스커버리 (다른 보드)
- **1순위: 멀티캐스트(기본)** — `--net=host` + 동일 서브넷이면 대개 추가 설정 없이 붙는다. **되면 ③ 스킵.**
- **2순위: 유니캐스트 피어(멀티캐스트가 스위치에서 막힐 때)**
  - CycloneDDS: `-e CYCLONEDDS_URI=file:///cfg/cyclonedds.xml` + 파일 마운트
    ```xml
    <CycloneDDS><Domain>
      <Discovery><Peers><Peer address="172.16.10.151"/></Peers></Discovery>
      <General><Interfaces><NetworkInterface name="<162의 eth 인터페이스명>"/></Interfaces></General>
    </Domain></CycloneDDS>
    ```
  - FastDDS: `-e FASTRTPS_DEFAULT_PROFILES_FILE=/cfg/fastdds.xml` (initial peers = `172.16.10.151`) 또는 Discovery Server.
  - → rviz2_monitor Run Options 에 "피어/디스커버리 설정 파일 경로" 옵션을 추가하면 유연.

## 4. ⚠️ 메시지 타입 · rviz 플러그인 (실사용 최대 제약)

크로스보드 연결이 성공해도 **무엇이 보이느냐**는 rviz2 이미지에 설치된 것에 달렸다.

- **표준 타입 → vanilla rviz2 로 표시 OK** (`ros-humble-rviz-default-plugins`):
  `tf2`(`/tf`,`/tf_static`), `sensor_msgs/PointCloud2`·`Image`, `nav_msgs`, `visualization_msgs/MarkerArray`,
  `geometry_msgs`.
- **Autoware 전용 타입 → 기본 이미지로는 표시 불가**:
  `autoware_*_msgs`, `tier4_*_msgs`, `autoware_auto_*` 등은 **메시지 패키지 + Autoware rviz 플러그인**이
  이미지에 없으면 subscribe/표시 안 됨.
  - 완전한 Autoware 시각화가 목표면 rviz2 이미지에 **autoware msgs + autoware rviz 플러그인** 추가 설치 필요(용량 큼).
  - TF/포인트클라우드/맵/기본 마커만이면 **현재 vanilla 이미지로 충분**.
- **`.rviz` 설정**: rviz2_monitor Run Options 의 `.rviz config 경로` 에 `autoware.rviz` 마운트 후 지정.
  단, config 가 참조하는 display 플러그인이 이미지에 있어야 함(없으면 해당 display 만 누락).

## 5. 맵(Map) — Autoware(151) 소유, rviz2 는 구독·렌더링 (⚠ latched QoS)

**map 파일은 rviz2 가 아니라 Autoware 가 가진다.** rviz2 에 map 파일을 둘 필요 없다.

- map 파일(`.pcd` 포인트클라우드, `.osm`/lanelet2 벡터맵)은 **151(Autoware)** 에 있고,
  Autoware 의 **map_loader**(pointcloud_map_loader / lanelet2_map_loader)가 읽어 토픽으로 발행한다:
  - `/map/pointcloud_map` — `sensor_msgs/PointCloud2`
  - `/map/vector_map`(+ marker) — 벡터/lanelet 맵
- **rviz2(162)는 이 토픽을 DDS 로 구독해서 렌더링만** 한다.

### ⚠️ latched(TRANSIENT_LOCAL) QoS — 크로스보드에서 map 만 안 보이는 주범
- map 토픽은 보통 **부팅 시 1회, `TRANSIENT_LOCAL`(latched)** 로 발행된다.
- rviz2 가 Autoware 보다 **나중에 접속**하면, rviz2 Display 의 QoS Durability 기본값(**Volatile**)으로는
  **이미 지나간 latched 샘플을 못 받아 map 만 비어 보인다** (TF·센서 스트림은 정상 수신).
- **해결**: rviz2 의 해당 Display(PointCloud2 / Map 등)에서 **Durability Policy = `Transient Local`** 로 설정.
- 확인: `ros2 topic info /map/pointcloud_map -v` → Publisher 의 Durability 가 `TRANSIENT_LOCAL` 인지.

### 타입/플러그인
- 포인트클라우드 map(`PointCloud2`) → **vanilla rviz2 표시 OK** (Durability 만 맞추면 됨).
- 벡터/lanelet map(`autoware_map_msgs/LaneletMapBin` + autoware lanelet rviz 플러그인)일 수 있음 →
  그 경우 rviz2 이미지에 **autoware msgs + 플러그인 필요**(§4). MarkerArray 로도 발행되면 vanilla 가능.

## 6. 검증 절차

162 의 rviz2 컨테이너 안에서:
```bash
ros2 topic list                 # /tf, /perception/... 등 Autoware 토픽이 보여야 함 (비면 ①②③ 불일치)
ros2 node list                  # autoware 노드가 보이는지
ros2 topic echo /tf --once      # 실제 데이터 흐름 확인
```
토픽이 보이면 rviz2 Displays 에서 Fixed Frame(예: `map` 또는 `base_link`) 설정 + TF / PointCloud2 추가.

## 7. rviz2_monitor 에 권장하는 변경

1. Run Options 에 **`RMW_IMPLEMENTATION` 입력 필드** 추가 → `-e RMW_IMPLEMENTATION=` 주입 (Autoware 매칭용).
2. rviz2 이미지에 **cyclonedds + fastrtps RMW 둘 다** 포함 (Autoware 가 어느 쪽이든 대응).
3. (옵션) 유니캐스트 피어/디스커버리 설정 파일 마운트 옵션.
4. (풀 비주얼 필요 시) autoware msgs + rviz 플러그인 포함 이미지 variant.
5. "Autoware on 151" 기본 프리셋: `ROS_DOMAIN_ID=42` + `RMW_IMPLEMENTATION=<autoware 값>` 저장.
6. map 표시용 프리셋 `.rviz` 제공: PointCloud2/Map display 의 **Durability = Transient Local** 기본 설정(§5).

## 8. 참고 소스
- Autoware 기동 설정(도메인 42/host/pid): `oss_multisw_framework/service/extension/ros2/adsw_manager/config/saved-service-list.yaml`
- rviz2 기동/이미지: `apps/rviz2_port/RVIZ2_GUIDE.md`, `apps/rviz2_monitor/lib/config/app_config.dart`(기본 `dockerRunArgs`), `apps/rviz2_monitor/lib/view/rviz2_view_page.dart`(Run Options)

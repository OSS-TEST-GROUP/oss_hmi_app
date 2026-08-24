#!/bin/bash
# Autoware 자율주행 시뮬레이션 트리거 — 보드 rviz2 시각화 검증용
#
# 151 보드(Autoware planning simulator)에 경로를 넣고 autonomous 로 engage 해
# 실제로 주행시킨다. 81 보드의 rviz2(우리 이미지, ROS_DOMAIN_ID=42)가 그 주행을
# 실시간으로 그린다 — Motion=Moving / 기어 D / 남은거리·ETA / 초록 궤적.
#
# 실행 위치: **Autoware 호스트(151)** — `docker exec autoware-decision` 가 되는 곳.
#   ssh beyhpc@172.16.10.151 'bash -s' < autoware-sim.sh
#
# 기본 EGO/GOAL 은 실측 검증된 794m 루프(lanelet 4 → 99, 36 세그먼트, 115초 완주,
# 목표 오차 5cm). 다른 경로를 쓰려면 autoware-lane-chain.py 로 후보를 뽑아
# EGO/GOAL 환경변수로 넘긴다.
#
# 환경변수:
#   EGO   "x y qz qw"   초기 위치·자세 (기본: lanelet 4 중간)
#   GOAL  "x y qz qw"   목표 위치·자세 (기본: lanelet 99 중간)
#   CTR   컨테이너명    (기본 autoware-decision — AD API 서비스가 있는 파트)
#   DOMAIN ROS_DOMAIN_ID (기본 42 — adsw junohb 파티션과 동일)
#   TRACK 추적 횟수     (기본 48 → 5초 간격 = 최대 4분)
set -e

CTR="${CTR:-autoware-decision}"
DOMAIN="${DOMAIN:-42}"
EGO="${EGO:-3655.152 73490.295 0.981391 0.192022}"
GOAL="${GOAL:-3656.523 73465.238 -0.661011 0.750376}"
TRACK="${TRACK:-48}"

read -r ex ey ez ew <<< "$EGO"
read -r gx gy gz gw <<< "$GOAL"

docker exec -i -e ROS_DOMAIN_ID="$DOMAIN" -e EX="$ex" -e EY="$ey" -e EZ="$ez" -e EW="$ew" \
  -e GX="$gx" -e GY="$gy" -e GZ="$gz" -e GW="$gw" -e TRACK="$TRACK" "$CTR" bash <<'INNER'
set -e
source /opt/ros/humble/setup.bash 2>/dev/null || true
source /opt/autoware/setup.bash 2>/dev/null || true

# 1) STOP 모드로 내린 뒤 경로 해제. autonomous 상태에서는 clear_route 가 거부된다
#    ("The route is already set." / success=False) — 실측.
ros2 service call /api/operation_mode/change_to_stop \
  autoware_adapi_v1_msgs/srv/ChangeOperationMode "{}" >/dev/null 2>&1 || true
sleep 2
ros2 service call /api/routing/clear_route \
  autoware_adapi_v1_msgs/srv/ClearRoute "{}" 2>&1 | grep -oE "success=(True|False)" | head -1 | sed 's/^/clear:  /'
sleep 2

# 2) 초기 위치. 토픽은 /initialpose3d (rviz2 의 /initialpose 가 아니다 — 실측).
#    한 번 publish 로는 놓치는 경우가 있어 -t 5.
#    초기 포즈가 **실제로 반영됐는지 확인한 뒤** 라우팅해야 한다. 시뮬레이터가 대기
#    상태(컨트롤 파티션 재기동 직후 등)면 발행을 안 해 포즈가 늦게 반영되고, 그 상태로
#    set_route_points 를 부르면 서비스는 success=True 를 주지만 behavior 쪽에서
#    `route_handler: Failed to find a proper route!` 로 실패해 궤적이 안 나온다(실측).
for _p in 1 2 3 4 5; do
    ros2 topic pub -t 5 /initialpose3d geometry_msgs/msg/PoseWithCovarianceStamped \
     "{header: {frame_id: map}, pose: {pose: {position: {x: $EX, y: $EY, z: 0.0},
       orientation: {z: $EZ, w: $EW}}, covariance: [0.25,0,0,0,0,0, 0,0.25,0,0,0,0,
       0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0.07]}}" >/dev/null 2>&1
    sleep 6
    _cur="$(timeout 10 ros2 topic echo --once /localization/kinematic_state 2>/dev/null \
            | sed -n '/position:/,+2p' | grep -oE '[-0-9.]+' | head -2 | tr '\n' ' ')"
    if [ -n "$_cur" ] && awk -v c="$_cur" -v x="$EX" -v y="$EY" \
         'BEGIN{split(c,a," "); exit !(((a[1]-x)^2+(a[2]-y)^2) < 4)}'; then
        echo "초기포즈 반영 확인: $_cur"
        break
    fi
    echo "  (초기포즈 미반영 — 재발행 ${_p}/5, 현재=${_cur:-없음})"
done

# 3) 목표. 실패 사유는 message 로 온다:
#    "The planned route is empty." = 라우팅 그래프상 시작→목표 연결 없음
#    (기하적으로 가까워도 lanelet 관계가 없으면 실패 → autoware-lane-chain.py 사용)
ros2 service call /api/routing/set_route_points autoware_adapi_v1_msgs/srv/SetRoutePoints \
 "{header: {frame_id: map}, goal: {position: {x: $GX, y: $GY, z: 0.0},
   orientation: {z: $GZ, w: $GW}}, waypoints: []}" 2>&1 \
   | grep -oE "success=(True|False)|message='[^']*'" | tr '\n' ' ' | sed 's/^/route:  /'; echo
sleep 4
printf 'lanes:  '; ros2 topic echo --once /planning/mission_planning/route 2>/dev/null \
  | grep -oE "id: [0-9]+" | wc -l

# 3-b) **모드 토글로 operation mode state 를 강제 발행** (파티션 재기동 후 필수).
#    실측: `/system/operation_mode/state` 는 모드가 바뀔 때만 발행된다. 파티션을
#    재기동하면 늦게 올라온 scenario_selector 가 그 샘플을 못 받아
#    "Waiting for operation mode state." 에서 멈추고 → behavior_path_planner
#    "waiting for scenario_topic" → **trajectory 미발행** →
#    `is_autonomous_mode_available: false` → engage 가 success=False 로 거부된다.
#    local→stop 으로 한 번 왕복하면 샘플이 발행되어 체인이 풀린다(실측: 직후
#    trajectory 9.9Hz, autonomous 가용 true).
# 토글은 1회성이면 타이밍을 놓친다 — 컨트롤 파티션이 방금 재기동된 경우 노드가 아직
# 준비되지 않아 상태 샘플이 안 나가고, 그러면 궤적이 안 생겨 engage 가 거부된다(실측:
# 174회 연속 성공 후 175회차에서 재현). **가용 상태가 될 때까지 재토글하며 폴링**한다.
_avail=""
for _try in 1 2 3 4 5 6; do
    ros2 service call /api/operation_mode/change_to_local \
      autoware_adapi_v1_msgs/srv/ChangeOperationMode "{}" >/dev/null 2>&1 || true
    sleep 3
    ros2 service call /api/operation_mode/change_to_stop \
      autoware_adapi_v1_msgs/srv/ChangeOperationMode "{}" >/dev/null 2>&1 || true
    sleep 6
    _avail="$(timeout 10 ros2 topic echo --once /api/operation_mode/state 2>/dev/null \
        | grep -oE 'is_autonomous_mode_available: (true|false)' | head -1)"
    case "$_avail" in *true) break ;; esac
    echo "  (autonomous 미가용 — 모드 재토글 ${_try}/6)"
    sleep 5
done
printf 'autonomous 가용: '; echo "${_avail:-확인실패}"

# 4) engage. 차량이 차선 밖이면 trajectory_deviation ERROR → MRM Emergency 로
#    막힌다(실측). 그 경우 EGO 를 차선 중앙으로 다시 잡아야 한다.
ros2 service call /api/operation_mode/change_to_autonomous \
  autoware_adapi_v1_msgs/srv/ChangeOperationMode "{}" 2>&1 \
  | grep -oE "success=(True|False)" | head -1 | sed 's/^/engage: /'

# 5) 주행 추적 — 위치가 실제로 움직이는지, 도착(vel=0)까지.
for i in $(seq 1 "$TRACK"); do
  sleep 5
  P=$(timeout 4 ros2 topic echo --once /localization/kinematic_state \
        --field pose.pose.position 2>/dev/null | tr -d ' \n' | sed 's/---//;s/z:.*//')
  V=$(timeout 3 ros2 topic echo --once /vehicle/status/velocity_status \
        --field longitudinal_velocity 2>/dev/null | tr -d ' \n' | sed 's/---//')
  echo "t=$((i*5))s $P vel=$V"
done
INNER

#!/bin/bash
# 무한 반복 시나리오 (멈추라고 할 때까지). 한 회차:
#   1) rviz2_panel Start  → 컨테이너 기동 + entrypoint 마커(ego 추종 뷰 / homebar)
#   2) 자율주행 시뮬      → route/engage + **ego 실제 이동**(표출·화면변화·맵변위)
#   3) homebar 체크       → 탭 → activate 로그 증가 + 런처 전환(표시·히트 가능 증명)
#   4) adsw_monitor       → 화면 + **Autoware 메시지 실제 수신** (주행 직후에 확인)
#   5) lfc_monitor        → 화면 + **autoware 3 파티션 전체 Stop→Start 정상 동작**
#   6) rviz2_panel Stop   → 컨테이너 정지 + exit code
#
# 어떤 체크든 실패하면 **즉시 중단(exit 2)** 하고 실패 항목을 출력한다 — 디버깅 후
# 처음부터 재시작하는 운영 방식(사용자 요청).
SP="$(dirname "$0")"
S="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o LogLevel=ERROR"
export DISPLAY=:0 SSH_ASKPASS_REQUIRE=force

b81() { SSH_ASKPASS="$SP/askpass-81.sh"  setsid -w ssh $S root@172.16.10.81 "$@" 2>/dev/null; }
p81() { SSH_ASKPASS="$SP/askpass-81.sh"  setsid -w scp $S root@172.16.10.81:"$1" "$2" >/dev/null 2>&1; }
b151(){ SSH_ASKPASS="$SP/askpass-151.sh" setsid -w ssh $S beyhpc@172.16.10.151 "$@" 2>/dev/null | grep -av setlocale; }

T_START="165 255"; T_STOP="271 255"; T_HOMEBAR="1899 13"; T_HOMEICON="41 110"
T_ADSW="329 276"; T_LFC="778 276"; T_RVIZ="1226 276"; T_VIEW="183 321"
# lfc_monitor 목록(알파벳 순: control → decision → perception)의 행 좌표.
# 행 간격 166px 실측. 서비스 행 Stop / 컨테이너 행 Start 를 각각 쓴다.
T_STOP_CTRL="255 301";  T_STOP_DEC="255 467";  T_STOP_PER="255 633"
T_START_CTRL="170 229"; T_START_DEC="170 395"; T_START_PER="170 561"

# lfc 페이지 재진입 — 목록을 스크롤 최상단으로 되돌린다.
#   재배포 후 core 가 AGL 서비스 3종("Services (no container)" 카드)까지 보고하면서
#   목록 높이가 뷰포트를 넘어 **스크롤 가능**해졌다. 그 상태에서 Stop 을 누르면 목록이
#   ~74px 밀려(실측) 고정 좌표 탭이 버튼 대신 제목을 때린다 → Start 무반응(26회차 실패).
#   페이지를 다시 열면 항상 스크롤 top 이므로 실측 좌표가 유효하다.
lfc_open() {
  # 페이지 재진입만으로는 스크롤이 초기화되지 않는다(앱이 offset 유지 — 실측).
  # 아래로 크게 두 번 끌어 목록을 최상단으로 되돌린 뒤에 탭해야 좌표가 유효하다.
  b81 "for i in 1 2; do python3 /root/tap.py swipe 590 300 590 950 >/dev/null 2>&1; sleep 1; done" >/dev/null
  sleep 2
}

shot() { b81 "bash /root/shot.sh >/dev/null 2>&1; cp /root/shot.png /root/$1" >/dev/null; p81 "/root/$1" "$2"; }

frames_check() {   # ego 표출(중앙 밝기) + 화면 변화(3D 뷰 프레임 차)
  python3 - "$1" "$2" <<'PY'
import sys
try:
    from PIL import Image, ImageChops
    a = Image.open(sys.argv[1]).convert('L'); b = Image.open(sys.argv[2]).convert('L')
    ca = sum(a.crop((955,520,1035,600)).getdata())/(80*80)
    cb = sum(b.crop((955,520,1035,600)).getdata())/(80*80)
    d = ImageChops.difference(a.crop((525,65,1460,1015)), b.crop((525,65,1460,1015)))
    print(f"{ca:.0f} {cb:.0f} {sum(d.getdata())/(d.width*d.height):.2f}")
except Exception:
    print("0 0 0")
PY
}
front_of() {       # 전면 서페이스: rviz2(어두운 3D 뷰) vs launcher(밝음)
  python3 - "$1" <<'PY'
import sys
try:
    from PIL import Image
    im = Image.open(sys.argv[1]).convert('L').crop((880,480,1120,700))
    m = sum(im.getdata())/(im.width*im.height)
    print('rviz2' if m < 90 else ('launcher' if m > 170 else f'?({m:.0f})'))
except Exception:
    print('?')
PY
}

abort() { echo "  ⛔ 실패($1) → 시나리오 중단 (디버깅 후 처음부터 재시작)"; echo "═══════ 중단: 회차 $2 · 누적 PASS=$3 ═══════"; exit 2; }

PASS=0; i=0
while true; do
  i=$((i+1)); t0=$(date +%s)
  echo "═══════════ 회차 $i ═══════════"

  # 0) 정규화: rviz2 정지 + 패널 페이지로
  if [ "$(b81 'docker ps --format "{{.Names}}" | grep -c "^rviz2$"')" = "1" ]; then
    b81 "python3 /root/tap.py $T_HOMEBAR >/dev/null 2>&1" >/dev/null; sleep 4
    b81 "python3 /root/tap.py $T_STOP >/dev/null 2>&1" >/dev/null; sleep 12
  fi
  b81 "python3 /root/tap.py $T_HOMEICON >/dev/null 2>&1" >/dev/null; sleep 3
  b81 "python3 /root/tap.py $T_RVIZ >/dev/null 2>&1" >/dev/null; sleep 4

  # 1) rviz2_panel Start
  b81 "python3 /root/tap.py $T_START >/dev/null 2>&1" >/dev/null
  up=""; ego=""; hbm=""
  for w in $(seq 1 24); do
    sleep 5
    [ -z "$up" ] && [ "$(b81 'docker ps --format "{{.Names}}" | grep -c "^rviz2$"')" = "1" ] && up=$(( $(date +%s) - t0 ))
    if [ -n "$up" ]; then
      log=$(b81 'docker logs rviz2 2>&1 | grep -aE "^▶|^⚠️"')
      [ -z "$ego" ] && echo "$log" | grep -qa "에고 추종으로 전환"    && ego=$(( $(date +%s) - t0 ))
      [ -z "$hbm" ] && echo "$log" | grep -qa "homebar 표시 시도 1/3" && hbm=$(( $(date +%s) - t0 ))
      [ -n "$ego" ] && [ -n "$hbm" ] && break
    fi
  done
  echo "  1 panel Start : up=${up:-FAIL}s ego뷰=${ego:-없음}s homebar마커=${hbm:-없음}s"
  [ -n "$up" ]  || abort "rviz2 기동" "$i" "$PASS"
  [ -n "$ego" ] || abort "ego 추종 뷰 마커 없음" "$i" "$PASS"
  [ -n "$hbm" ] || abort "homebar 표시 시도 마커 없음" "$i" "$PASS"

  # 1-b) rviz2 를 전면으로 (패널의 "View rviz2"). entrypoint 의 activate 만 믿으면
  #      런처가 전면에 남아 캡처가 rviz2 가 아닌 경우가 있다(실측: 밝기 238=런처).
  fr=""
  for try_n in 1 2; do
    b81 "python3 /root/tap.py $T_VIEW >/dev/null 2>&1" >/dev/null; sleep 8
    shot "L-$i-front.png" "$SP/L-$i-front.png"; fr=$(front_of "$SP/L-$i-front.png")
    [ "$fr" = "rviz2" ] && break
    echo "      (전면=$fr → View rviz2 재시도 $try_n/2)"
    b81 "python3 /root/tap.py $T_HOMEICON >/dev/null 2>&1" >/dev/null; sleep 3
    b81 "python3 /root/tap.py $T_RVIZ >/dev/null 2>&1" >/dev/null; sleep 4
  done
  echo "  1-b View rviz2: 전면=$fr"
  [ "$fr" = "rviz2" ] || abort "rviz2 전면 전환 실패($fr)" "$i" "$PASS"

  # 2) 자율주행 시뮬 + ego 이동 (주행 중 2프레임 비교)
  b151 'nohup env TRACK=16 bash /tmp/autoware-sim.sh > /tmp/scl.log 2>&1 & sleep 42; true' >/dev/null
  shot "L-$i-a.png" "$SP/L-$i-a.png"; sleep 18; shot "L-$i-b.png" "$SP/L-$i-b.png"
  read -r ca cb fdiff <<< "$(frames_check "$SP/L-$i-a.png" "$SP/L-$i-b.png")"
  sim=$(b151 'cat -v /tmp/scl.log')
  rte=$(echo "$sim" | grep -aoE "route:  success=(True|False)" | head -1 | grep -aoE "True|False")
  eng=$(echo "$sim" | grep -aoE "engage: success=(True|False)" | head -1 | grep -aoE "True|False")
  vel=$(echo "$sim" | grep -aoE "vel=[0-9.]+" | sed 's/vel=//' | sort -g | tail -1)
  disp=$(echo "$sim" | grep -aoE "x:[0-9.]+y:[0-9.]+" | python3 -c "
import sys,math
p=[l.strip() for l in sys.stdin if l.strip()]
def xy(s): return float(s.split('x:')[1].split('y:')[0]), float(s.split('y:')[1])
print(f'{math.hypot(*[b-a for a,b in zip(xy(p[0]),xy(p[-1]))]):.0f}' if len(p)>=2 else '0')")
  # 장시간 soak 중 decision 의 route_handler 가 상태가 꼬여 engage 가 거부되는 경우가
  # 있다(실측: 174회차까지 정상 → 175회차 거부, "route_handler: Failed to find a proper
  # route!" + 궤적 미발행). decision 재기동으로 회복되므로 **1회 자동 복구**를 시도하고,
  # 그래도 안 되면 중단해 디버깅한다. 복구 발생은 로그에 크게 남긴다.
  if [ "$eng" != "True" ]; then
    echo "      ⚠ engage 거부 → decision 재기동으로 자동 복구 시도"
    b151 'docker restart autoware-decision >/dev/null 2>&1' >/dev/null; sleep 90
    b151 'nohup env TRACK=16 bash /tmp/autoware-sim.sh > /tmp/scl.log 2>&1 & sleep 60; true' >/dev/null
    shot "L-$i-a.png" "$SP/L-$i-a.png"; sleep 18; shot "L-$i-b.png" "$SP/L-$i-b.png"
    read -r ca cb fdiff <<< "$(frames_check "$SP/L-$i-a.png" "$SP/L-$i-b.png")"
    sim=$(b151 'cat -v /tmp/scl.log')
    rte=$(echo "$sim" | grep -aoE "route:  success=(True|False)" | head -1 | grep -aoE "True|False")
    eng=$(echo "$sim" | grep -aoE "engage: success=(True|False)" | head -1 | grep -aoE "True|False")
    vel=$(echo "$sim" | grep -aoE "vel=[0-9.]+" | sed 's/vel=//' | sort -g | tail -1)
    disp=$(echo "$sim" | grep -aoE "x:[0-9.]+y:[0-9.]+" | python3 -c "
import sys,math
p=[l.strip() for l in sys.stdin if l.strip()]
def xy(s): return float(s.split('x:')[1].split('y:')[0]), float(s.split('y:')[1])
print(f'{math.hypot(*[b-a for a,b in zip(xy(p[0]),xy(p[-1]))]):.0f}' if len(p)>=2 else '0')")
    echo "      복구 결과: route=${rte:-?} engage=${eng:-?} 최고속도=${vel:-0}m/s 변위=${disp:-0}m"
  fi
  echo "  2 시뮬+ego    : route=${rte:-?} engage=${eng:-?} 최고속도=${vel:-0}m/s"
  echo "      ego 판정  : 표출 a=$ca b=$cb(>35) · 화면차=$fdiff(>3) · 변위=${disp:-0}m(>=10)"
  [ "$rte" = "True" ] || abort "route 실패" "$i" "$PASS"
  [ "$eng" = "True" ] || abort "engage 거부" "$i" "$PASS"
  awk -v a="$ca" -v b="$cb" 'BEGIN{exit !(a>35 && b>35)}' || abort "ego 미표출" "$i" "$PASS"
  awk -v d="$fdiff" 'BEGIN{exit !(d>3)}'                  || abort "ego 화면 정지" "$i" "$PASS"
  awk -v m="${disp:-0}" 'BEGIN{exit !(m>=10)}'            || abort "ego 변위 부족(${disp}m)" "$i" "$PASS"

  # 3) homebar 표시/동작
  before=$(b81 'docker logs rviz2 2>&1 | grep -ca "activate hmi_launcher + hide self"')
  b81 "python3 /root/tap.py $T_HOMEBAR >/dev/null 2>&1" >/dev/null; sleep 6
  after=$(b81 'docker logs rviz2 2>&1 | grep -ca "activate hmi_launcher + hide self"')
  shot "L-$i-home.png" "$SP/L-$i-home.png"; fr=$(front_of "$SP/L-$i-home.png")
  echo "  3 homebar     : activate 로그 ${before:-0}→${after:-0} · 탭 후 전면=$fr"
  [ "${after:-0}" -gt "${before:-0}" ] || abort "homebar 탭 무반응" "$i" "$PASS"
  [ "$fr" = "launcher" ]               || abort "homebar 탭 후 런처 전환 실패($fr)" "$i" "$PASS"

  # 4) adsw_monitor + Autoware 메시지 수신
  b81 "python3 /root/tap.py $T_HOMEICON >/dev/null 2>&1" >/dev/null; sleep 3
  b81 "python3 /root/tap.py $T_ADSW >/dev/null 2>&1" >/dev/null; sleep 12
  shot "L-$i-adsw.png" "$SP/L-$i-adsw.png"
  # adsw_monitor 의 실제 데이터 경로(151 rosbridge)에서 판정한다.
  # 보드 컨테이너에서 새 ros2 CLI 참가자를 만들면 디스커버리는 되는데(555 토픽)
  # 데이터가 전달되지 않는 현상이 있어(GUI 는 정상 수신) 그 경로로는 판정하지 않는다.
  hz=$(b151 'docker exec oss-mmf-ext-ros2 bash -lc "source /opt/ros/humble/setup.bash; timeout 10 ros2 topic hz /vehicle/status/velocity_status 2>&1 | grep -c \"average rate\""')
  sub=$(b151 'docker exec oss-mmf-ext-ros2 bash -lc "source /opt/ros/humble/setup.bash; timeout 12 ros2 topic info -v /vehicle/status/velocity_status 2>/dev/null | grep -c rosbridge_websocket"')
  echo "  4 adsw_monitor: Autoware 발행=${hz:-0}(1 기대) · rosbridge 구독=${sub:-0}(>=1 기대)"
  vrx=$(( ${hz:-0} + ${sub:-0} ))
  [ "${vrx:-0}" -ge 2 ] || abort "adsw_monitor Autoware 메시지 경로 이상" "$i" "$PASS"


  # 5) lfc_monitor + autoware **3 파티션 전체** Stop→Start
  #    정지는 의존 역순(control → decision → perception), 기동은 의존 순
  #    (perception=시뮬레이터 먼저 → decision → control).
  b81 "python3 /root/tap.py $T_HOMEICON >/dev/null 2>&1" >/dev/null; sleep 3
  b81 "python3 /root/tap.py $T_LFC >/dev/null 2>&1" >/dev/null; sleep 10
  lfc_open
  shot "L-$i-lfc.png" "$SP/L-$i-lfc.png"

  for t in "$T_STOP_CTRL" "$T_STOP_DEC" "$T_STOP_PER"; do
    lfc_open
    b81 "python3 /root/tap.py $t >/dev/null 2>&1" >/dev/null; sleep 10
  done
  sleep 25
  gone=$(b151 'docker ps --format "{{.Names}}" | grep -c "^autoware-"')
  shot "L-$i-lfc-stopped.png" "$SP/L-$i-lfc-stopped.png"

  # Stop 직후 앱이 해당 행을 "처리중"으로 잠근다 → 상태 확정 후에 Start 가 먹는다
  # (실측: 22초 뒤 탭은 무반응). 3개 각각 최대 2회 시도.
  for pair in "$T_START_PER:autoware-perception" "$T_START_DEC:autoware-decision" "$T_START_CTRL:autoware-control"; do
    t="${pair%%:*}"; name="${pair##*:}"
    for try_s in 1 2; do
      lfc_open
      b81 "python3 /root/tap.py $t >/dev/null 2>&1" >/dev/null; sleep 25
      n=$(b151 "docker ps --format '{{.Names}}' | grep -c '^${name}\$'")
      [ "${n:-0}" = "1" ] && break
      echo "      ($name Start 무반응 → 재시도 $try_s/2)"; sleep 10
    done
  done
  sleep 20
  back=$(b151 'docker ps --format "{{.Names}}" | grep -c "^autoware-"')
  echo "  5 lfc 제어    : Stop 후 실행수=${gone:-?}(0 기대) · Start 후 실행수=${back:-?}(3 기대)"
  [ "${gone:-9}" = "0" ] || abort "lfc_monitor Stop 미동작(남은 컨테이너 ${gone})" "$i" "$PASS"
  [ "${back:-0}" = "3" ] || abort "lfc_monitor Start 미동작(기동 ${back}/3)" "$i" "$PASS"

  # 5-b) 파티션 재기동 후 시뮬 재초기화.
  #      3 파티션을 모두 재생성했으므로 시뮬레이터는 초기 포즈가 없는 상태다.
  #      /initialpose3d 를 넣어 다음 회차 주행이 바로 가능하도록 만든다.
  b151 'docker exec -e ROS_DOMAIN_ID=42 autoware-perception bash -lc "source /opt/ros/humble/setup.bash; source /opt/autoware/setup.bash 2>/dev/null; timeout 15 ros2 topic pub -t 5 /initialpose3d geometry_msgs/msg/PoseWithCovarianceStamped \"{header: {frame_id: map}, pose: {pose: {position: {x: 3655.152, y: 73490.295, z: 0.0}, orientation: {z: 0.981391, w: 0.192022}}, covariance: [0.25,0,0,0,0,0, 0,0.25,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0.07]}}\" >/dev/null 2>&1"' >/dev/null
  sleep 10

  # 6) rviz2_panel Stop
  b81 "python3 /root/tap.py $T_HOMEICON >/dev/null 2>&1" >/dev/null; sleep 3
  b81 "python3 /root/tap.py $T_RVIZ >/dev/null 2>&1" >/dev/null; sleep 4
  b81 "python3 /root/tap.py $T_STOP >/dev/null 2>&1" >/dev/null
  stopped=""
  for w in $(seq 1 10); do sleep 5; [ "$(b81 'docker ps --format "{{.Names}}" | grep -c "^rviz2$"')" = "0" ] && { stopped=1; break; }; done
  ec=$(b81 'docker inspect rviz2 --format "{{.State.ExitCode}}" 2>/dev/null')
  echo "  6 panel Stop  : ${stopped:+ok}${stopped:-FAIL} exit=${ec:-?}"
  [ -n "$stopped" ] || abort "panel Stop 미동작" "$i" "$PASS"

  PASS=$((PASS+1))
  echo "  판정          : PASS ($(( $(date +%s) - t0 ))s) · 누적 PASS=$PASS"
done

#!/bin/bash
# PC(amd64) 시나리오 — 모니터 1번(DP-5, +0+1080) 에서 ext-agl → hmi_launcher → rviz2 검증.
#
# 보드(scenario_loop.sh) 와의 차이 — 정직하게:
#   · 표시 계층이 다르다: 보드는 agl-compositor + cage(+homebar), PC 는 호스트 X11 직행
#     (리포지토리 run-rviz2-x86.sh 가 문서화한 amd64 개발 경로). 따라서 **homebar 항목은
#     PC 에 존재하지 않아 판정에서 제외**하고, 앱 전환은 X11 창 활성화로 대체한다.
#   · 입력은 터치(/dev/input) 대신 xdotool XTEST 클릭(xtool 컨테이너).
#   · 캡처는 weston-screenshooter 대신 import -crop 1920x1080+0+1080.
#   · ROS/Autoware/앱 계층은 보드와 동일: 151 의 core/ext-ros2/Autoware 3 파티션을 그대로 쓴다.
#
# 회차 구성: 0 정규화 → 1 패널 Start(+창 배치) → 2 시뮬+ego 이동 → 3 adsw 데이터
#            → 4 lfc 3 파티션 Stop/Start → 4-b 초기포즈 → 5 패널 Stop
SP="$(dirname "$0")"
YOFF=1080                      # 모니터 1번의 절대 y 오프셋
S="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20 -o LogLevel=ERROR"
export DISPLAY=:0 SSH_ASKPASS_REQUIRE=force

b151(){ SSH_ASKPASS="$SP/askpass-151.sh" setsid -w ssh $S beyhpc@172.16.10.151 "$@" 2>/dev/null | grep -av setlocale; }
xt(){ docker run --rm --net host -e DISPLAY=:0 -v /tmp/.X11-unix:/tmp/.X11-unix xtool:local "$1" 2>/dev/null; }

# 창 활성화 + 모니터1 풀스크린 (WM_CLASS 로 선택 — 제목 매칭은 VS Code 오인 위험)
act(){ # act <wmclass-regex>
  xt "W=\$(wmctrl -lx | awk 'tolower(\$3) ~ /$1/ {print \$1}' | head -1)
      [ -z \"\$W\" ] && exit 1
      wmctrl -i -r \$W -e 0,0,$YOFF,1920,1080 >/dev/null 2>&1
      wmctrl -i -r \$W -b add,fullscreen >/dev/null 2>&1
      xdotool windowactivate \$W >/dev/null 2>&1
      sleep 1; echo \$W"
}
front(){ xt 'A=$(xdotool getactivewindow 2>/dev/null); xprop -id $A WM_CLASS 2>/dev/null | sed "s/.*= //"'; }
click(){ xt "xdotool mousemove $1 \$(( $2 + $YOFF )) click 1"; }
# lfc 목록은 뷰포트보다 길어 스크롤이 생기고, Stop 후 목록이 밀려 고정 좌표가 어긋난다
# (보드에서 실측: ~74px). 탭 직전에 아래로 크게 끌어 최상단으로 정규화한다.
scroll_top(){ xt "xdotool mousemove 590 $(( 320 + YOFF )) mousedown 1 mousemove 590 $(( 900 + YOFF )) sleep 0.3 mouseup 1"; sleep 1; }
shot(){ import -window root -crop 1920x1080+0+${YOFF} +repage "$SP/$1" 2>/dev/null; }

# 타일/버튼 좌표 (모니터1 로컬 좌표 — 보드와 동일 레이아웃)
T_HOME="41 110"; T_ADSW="329 276"; T_LFC="778 276"; T_RVIZ="1226 276"
# UI 재구성 후 실측: 액션이 한 줄(Start/Stop │ View/Launcher)이고 상태 스트립 높이가 고정돼
# **모든 상태에서 y=230 고정**이다(STOPPED+exit+변경시각이 표시된 상태에서도 동일 — 캡처 확인).
T_START="165 230"; T_STOP="271 230"
T_VIEW="412 230";  T_LAUNCHER="552 230"
# lfc 목록 (알파벳순 control→decision→perception): 컨테이너 Start / 서비스 Stop
T_START_CTRL="170 229"; T_START_DEC="170 395"; T_START_PER="170 561"
T_STOP_CTRL="255 301";  T_STOP_DEC="255 467";  T_STOP_PER="255 633"

frames_check(){ python3 - "$1" "$2" <<'PY'
import sys
try:
    from PIL import Image, ImageChops
    a=Image.open(sys.argv[1]).convert('L'); b=Image.open(sys.argv[2]).convert('L')
    ca=sum(a.crop((955,520,1035,600)).getdata())/(80*80)
    cb=sum(b.crop((955,520,1035,600)).getdata())/(80*80)
    d=ImageChops.difference(a.crop((525,65,1460,1015)), b.crop((525,65,1460,1015)))
    print(f"{ca:.0f} {cb:.0f} {sum(d.getdata())/(d.width*d.height):.2f}")
except Exception: print("0 0 0")
PY
}
abort(){ echo "  ⛔ 중단: $1 (회차 $2, 누적 PASS=$3)"; exit 2; }

PASS=0
for i in $(seq 1 "${LOOPS:-9999}"); do
  echo "═══════════ 회차 $i ═══════════"; t0=$(date +%s)

  # 0) 정규화 — rviz2 정지 후 런처 홈 → RViz2 타일
  docker stop rviz2 >/dev/null 2>&1
  act 'obigo' >/dev/null || abort "런처 창 없음" "$i" "$PASS"
  click $T_HOME; sleep 2; click $T_RVIZ; sleep 3

  # 1) 패널 Start
  click $T_START
  up=""; ov=""; ego=""
  for w in $(seq 1 25); do
    sleep 3
    [ -z "$up" ] && [ "$(docker ps --format '{{.Names}}' | grep -c '^rviz2$')" = "1" ] && up=$(( $(date +%s) - t0 ))
    if [ -n "$up" ]; then
      log=$(docker logs rviz2 2>&1 | grep -aE "^▶|^⚠️")
      [ -z "$ov" ]  && echo "$log" | grep -qa "autoware 오버레이 로드됨" && ov=1
      [ -z "$ego" ] && echo "$log" | grep -qa "에고 추종으로 전환"      && ego=1
      [ -n "$ov" ] && [ -n "$ego" ] && break
    fi
  done
  echo "  1 패널 Start  : up=${up:-FAIL}s 오버레이=${ov:+ok}${ov:-FAIL} ego뷰=${ego:+ok}${ego:-FAIL}"
  [ -n "$up" ] || abort "rviz2 컨테이너 기동 실패" "$i" "$PASS"
  [ -n "$ov" ] && [ -n "$ego" ] || abort "entrypoint 마커 누락" "$i" "$PASS"

  # 1-b) rviz2 창을 모니터1 로 (X11 이라 새 창은 기본 위치에 뜬다)
  for w in 1 2 3 4 5; do act 'rviz2' >/dev/null && break; sleep 3; done
  fr=$(front); echo "  1-b 창 배치    : 전면=$fr"
  case "$fr" in *rviz2*) ;; *) abort "rviz2 창 전면 전환 실패($fr)" "$i" "$PASS" ;; esac

  # 2) 자율주행 시뮬 + ego 실제 이동
  #    고정 대기(55s)는 쓰지 않는다 — 시뮬 스크립트의 모드 토글 폴링이 최대 6회(약 84s)
  #    걸릴 수 있어(실측: 13회차 실패) 그 전에 로그를 읽으면 engage 결과가 없다.
  #    engage 라인이 나올 때까지 폴링하고, 실패하면 decision 재기동 + 초기포즈 재주입으로
  #    한 번 self-heal 한 뒤 재시도한다(보드 시나리오와 동일 전략).
  eng=""; rte=""
  for attempt in 1 2; do
    b151 'nohup env TRACK=16 bash /tmp/autoware-sim.sh > /tmp/pcsc.log 2>&1 & sleep 2; true' >/dev/null
    for w in $(seq 1 34); do
      sleep 5
      eng=$(b151 'grep -aoE "engage: success=(True|False)" /tmp/pcsc.log 2>/dev/null | head -1 | grep -aoE "True|False"')
      [ -n "$eng" ] && break
    done
    rte=$(b151 'grep -aoE "route:  success=(True|False)" /tmp/pcsc.log 2>/dev/null | head -1 | grep -aoE "True|False"')
    [ "$eng" = "True" ] && break
    [ "$attempt" = 2 ] && break
    echo "      (engage=${eng:-무응답} → decision 재기동 + 초기포즈 재주입 후 재시도)"
    b151 'docker restart autoware-decision >/dev/null 2>&1' >/dev/null; sleep 35
    b151 'docker exec -e ROS_DOMAIN_ID=42 autoware-perception bash -lc "source /opt/ros/humble/setup.bash; source /opt/autoware/setup.bash 2>/dev/null; timeout 15 ros2 topic pub -t 5 /initialpose3d geometry_msgs/msg/PoseWithCovarianceStamped \"{header: {frame_id: map}, pose: {pose: {position: {x: 3655.152, y: 73490.295, z: 0.0}, orientation: {z: 0.981391, w: 0.192022}}, covariance: [0.25,0,0,0,0,0, 0,0.25,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0.07]}}\" >/dev/null 2>&1"' >/dev/null
    sleep 10
  done
  # engage 직후가 주행 구간 — 여기서 두 프레임을 잡아 ego 이동을 판정한다
  shot "PC-$i-a.png"; sleep 18; shot "PC-$i-b.png"
  read -r ca cb fd <<< "$(frames_check "$SP/PC-$i-a.png" "$SP/PC-$i-b.png")"
  sim=$(b151 'cat -v /tmp/pcsc.log')
  disp=$(echo "$sim" | grep -aoE "x:[0-9.]+y:[0-9.]+" | python3 -c "
import sys,math
p=[l.strip() for l in sys.stdin if l.strip()]
xy=lambda s:(float(s.split('x:')[1].split('y:')[0]), float(s.split('y:')[1]))
print(f'{math.hypot(*[b-a for a,b in zip(xy(p[0]),xy(p[-1]))]):.0f}' if len(p)>=2 else '0')")
  echo "  2 시뮬+ego    : route=${rte:-?} engage=${eng:-?} · 표출 a=$ca b=$cb(>35) · 화면차=$fd(>3) · 변위=${disp:-0}m(>=10)"
  [ "$rte" = "True" ] && [ "$eng" = "True" ] || abort "route/engage 실패" "$i" "$PASS"
  awk -v a="$ca" -v b="$cb" 'BEGIN{exit !(a>35 && b>35)}' || abort "ego 미표출" "$i" "$PASS"
  awk -v d="$fd" 'BEGIN{exit !(d>3)}'                      || abort "화면 정지(ego 이동 없음)" "$i" "$PASS"
  awk -v m="${disp:-0}" 'BEGIN{exit !(m>=10)}'             || abort "맵 변위 부족(${disp}m)" "$i" "$PASS"

  # 3) adsw_monitor — 화면 + 151 rosbridge 데이터 경로
  act 'obigo' >/dev/null; click $T_HOME; sleep 2; click $T_ADSW; sleep 5
  shot "PC-$i-adsw.png"
  hz=$(b151 'docker exec oss-mmf-ext-ros2 bash -lc "source /opt/ros/humble/setup.bash; timeout 10 ros2 topic hz /vehicle/status/velocity_status 2>&1 | grep -c \"average rate\""')
  sub=$(b151 'docker exec oss-mmf-ext-ros2 bash -lc "source /opt/ros/humble/setup.bash; timeout 12 ros2 topic info -v /vehicle/status/velocity_status 2>/dev/null | grep -c rosbridge_websocket"')
  echo "  3 adsw_monitor: Autoware 발행=${hz:-0}(1 기대) · rosbridge 구독=${sub:-0}(>=1 기대)"
  [ $(( ${hz:-0} + ${sub:-0} )) -ge 2 ] || abort "adsw 데이터 경로 이상" "$i" "$PASS"

  # 4) lfc_monitor — autoware 3 파티션 전체 Stop→Start
  click $T_HOME; sleep 2; click $T_LFC; sleep 6
  shot "PC-$i-lfc.png"
  for t in "$T_STOP_CTRL" "$T_STOP_DEC" "$T_STOP_PER"; do scroll_top; click $t; sleep 4; done
  # 고정 대기(25s) 대신 **조건 폴링** — 컨테이너 상태 통지가 on-change(약 2초)라 대부분
  # 즉시 잡힌다. 느릴 때만 기다리므로 평균이 빨라지고 최악 케이스 안전은 유지된다.
  gone=9
  for w in $(seq 1 14); do
    gone=$(b151 'docker ps --format "{{.Names}}" | grep -c "^autoware-"')
    [ "${gone:-9}" = "0" ] && break
    sleep 2
  done
  shot "PC-$i-lfc-stopped.png"
  for pair in "$T_START_PER:autoware-perception" "$T_START_DEC:autoware-decision" "$T_START_CTRL:autoware-control"; do
    t="${pair%%:*}"; name="${pair##*:}"
    for try_s in 1 2; do
      scroll_top; click $t; sleep 5
      n=0
      for w in $(seq 1 10); do
        n=$(b151 "docker ps --format '{{.Names}}' | grep -c '^${name}\$'")
        [ "${n:-0}" = "1" ] && break
        sleep 3
      done
      [ "${n:-0}" = "1" ] && break
      echo "      ($name Start 무반응 → 재시도 $try_s/2)"; sleep 6
    done
  done
  back=0
  for w in $(seq 1 8); do
    back=$(b151 'docker ps --format "{{.Names}}" | grep -c "^autoware-"')
    [ "${back:-0}" = "3" ] && break
    sleep 3
  done
  echo "  4 lfc 제어    : Stop 후=${gone:-?}(0 기대) · Start 후=${back:-?}(3 기대)"
  [ "${gone:-9}" = "0" ] || abort "lfc Stop 미동작(남은 ${gone})" "$i" "$PASS"
  [ "${back:-0}" = "3" ] || abort "lfc Start 미동작(${back}/3)" "$i" "$PASS"

  # 4-b) 파티션 재생성 후 시뮬레이터 초기 포즈 재주입
  b151 'docker exec -e ROS_DOMAIN_ID=42 autoware-perception bash -lc "source /opt/ros/humble/setup.bash; source /opt/autoware/setup.bash 2>/dev/null; timeout 15 ros2 topic pub -t 5 /initialpose3d geometry_msgs/msg/PoseWithCovarianceStamped \"{header: {frame_id: map}, pose: {pose: {position: {x: 3655.152, y: 73490.295, z: 0.0}, orientation: {z: 0.981391, w: 0.192022}}, covariance: [0.25,0,0,0,0,0, 0,0.25,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0, 0,0,0,0,0,0.07]}}" >/dev/null 2>&1"' >/dev/null
  sleep 5

  # 5) 패널 Stop
  click $T_HOME; sleep 2; click $T_RVIZ; sleep 3; click $T_STOP
  stopped=""
  for w in $(seq 1 12); do
    sleep 3
    [ "$(docker ps --format '{{.Names}}' | grep -c '^rviz2$')" = "0" ] && { stopped=1; break; }
  done
  ec=$(docker inspect rviz2 --format '{{.State.ExitCode}}' 2>/dev/null)
  echo "  5 패널 Stop   : ${stopped:+ok}${stopped:-FAIL} exit=${ec:-?}"
  [ -n "$stopped" ] || abort "패널 Stop 미동작" "$i" "$PASS"

  PASS=$((PASS+1)); echo "  판정          : PASS ($(( $(date +%s) - t0 ))s) · 누적 PASS=$PASS"
done

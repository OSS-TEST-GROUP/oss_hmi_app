#!/bin/bash
# rviz2-agl 컨테이너 엔트리포인트 (ADR-0018, F100) — cage 아키텍처
#
# cage(wlroots 키오스크)가 호스트 agl-compositor 의 wayland 클라이언트가 되어
# app_id="wlroots" 인 풀스크린 창을 만들고, 내장 XWayland 위에서 rviz2 를 실행한다.
# 창 표출은 호스트 쪽에서 활성화 필요: agl-shell-activator -a activate -p wlroots -o <output>
# (run-on-board.sh 가 자동 수행)
#
# ⚠️ cage 는 root 실행 거부 — docker run --user 1001:1001 (agl-driver 동일 uid) 필수.
set -e

# ── 표시 모드 판정 ────────────────────────────────────────────────────────────
# cage 모드(보드/AGL, 기본): 호스트 agl-compositor 의 wayland 소켓이 있을 때. 지금까지의
#   동작 그대로 — cage 키오스크 + XWayland + homebar + agl-shell 활성화.
# x11 모드(x86 개발 PC): wayland 소켓이 없고 DISPLAY 가 있을 때. agl-compositor 가 없는
#   PC 에서 cage 는 붙을 컴포지터가 없고, 이 이미지의 Qt 는 wayland QPA 플러그인이 없어
#   XWayland(xcb) 를 타는데 PC 에서는 X 인증이 맞지 않아 rviz2 가 죽는다(실측).
#   그래서 cage 를 건너뛰고 rviz2 를 호스트 X 에 직접 띄운다 — 리포지토리의
#   run-rviz2-x86.sh 가 entrypoint 를 오버라이드해 하던 것과 같은 경로를, 이미지 자체가
#   지원하게 만든 것이다(스크립트 없이 `docker run -e DISPLAY=:0` 로도 뜬다).
#   x11 모드에서는 agl-shell 이 없으므로 homebar/activate 는 수행하지 않는다.
DISPLAY_MODE=""
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ] \
   && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
    DISPLAY_MODE=cage
elif [ -n "${DISPLAY:-}" ]; then
    DISPLAY_MODE=x11
    echo "▶ wayland 소켓 없음 → X11 직행 모드 (DISPLAY=$DISPLAY, cage/homebar 건너뜀)"
else
    echo "❌ 표시 경로가 없다: wayland 소켓(${XDG_RUNTIME_DIR:-<unset>}/${WAYLAND_DISPLAY:-<unset>})" >&2
    echo "   도 없고 DISPLAY 도 비어 있다. 보드는 소켓 디렉토리를 마운트하고(run-on-board.sh)," >&2
    echo "   x86 PC 는 -e DISPLAY=:0 (--net=host 또는 /tmp/.X11-unix 마운트) 로 실행한다." >&2
    exit 1
fi

export HOME="${HOME:-/tmp}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"   # Phase 1: llvmpipe
export QT_X11_NO_MITSHM=1                                     # 컨테이너 X 공유메모리 이슈 회피
# ⚠️ WAYLAND_SOCKET 은 빈 값으로도 set 금지 — libwayland 가 fd 로 파싱 시도 (실측)
unset WAYLAND_SOCKET

# ── 크로스보드 DDS: 기본 라우트 NIC 만 광고 (멀티 NIC 대응) ──────────────────────
# 보드에 k8s(flannel/cni0) + veth 등 여러 인터페이스가 있으면 Fast DDS 가 **라우팅
# 불가한 IP(10.42.x.x 등)까지 locator 로 광고**한다. 그러면 상대 보드가 회신 경로를
# 못 잡아 통신이 비대칭이 된다 — 실측: 162 는 151 토픽을 보는데 151 은 162 를 못 봄
# → 토픽 목록만 보이고 서비스 호출/구독 데이터가 안 흐름.
# 기본 라우트 NIC 의 IP 만 interfaceWhiteList 로 제한한 프로파일을 생성해 주입한다.
# (`ip` 명령이 이미지에 없어 python3 로 감지 — ROS 이미지엔 python3 상시 존재)
# ⚠️ **기본값은 꺼짐(0)** 이다. 이 화이트리스트는 반대 방향의 비대칭을 만든다 —
# 81 보드 실측(2026-08-14): 프로파일이 걸리면 rviz2 **자신의 발행이 아무에게도 안 간다**.
#   · rviz2 는 151 토픽을 정상 구독·표시(맵/TF/상태 모두 정상)
#   · 그런데 `ros2 node list` 에 rviz2 노드가 **아예 안 뜨고**(0개),
#     화면에서 2D Pose Estimate / 2D Goal Pose 를 찍어도 /initialpose,
#     /planning/mission_planning/goal 이 Autoware 에 도달하지 않아 주행이 시작되지 않는다.
#   · DDS_NIC_WHITELIST=0 으로 끄면 노드가 그래프에 보이고(1개) UI 로 찍은 포즈·목표가
#     즉시 Autoware 에 전달된다(실측).
# useBuiltinTransports=false + 단일 UDP 화이트리스트 조합이 발신 로케이터 광고를 막는
# 것으로 보인다. 162 처럼 docker0 간섭으로 반대 증상이 나면 그 보드에서만 1 로 켠다.
# 켜려면 -e DDS_NIC_WHITELIST=1 . 사용자가 FASTRTPS_DEFAULT_PROFILES_FILE 를 직접
# 지정했으면 그 값을 존중하고 건드리지 않는다.
if [ "${DDS_NIC_WHITELIST:-0}" = "1" ] && [ -z "${FASTRTPS_DEFAULT_PROFILES_FILE:-}" ]; then
    _nic_ip="$(python3 - <<'PY' 2>/dev/null
import fcntl, socket, struct
def default_iface():
    with open("/proc/net/route") as f:
        for line in f.readlines()[1:]:
            c = line.split()
            if c[1] == "00000000":          # destination 0.0.0.0 → default route
                return c[0]
    return None
ifn = default_iface()
if ifn:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    # SIOCGIFADDR
    print(socket.inet_ntoa(fcntl.ioctl(s.fileno(), 0x8915,
          struct.pack("256s", ifn[:15].encode()))[20:24]))
PY
)"
    if [ -n "$_nic_ip" ]; then
        cat > /tmp/fastdds-nic.xml <<XML
<?xml version="1.0" encoding="UTF-8"?>
<dds xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
  <profiles>
    <transport_descriptors>
      <transport_descriptor>
        <transport_id>nic_only</transport_id>
        <type>UDPv4</type>
        <interfaceWhiteList><address>${_nic_ip}</address></interfaceWhiteList>
      </transport_descriptor>
    </transport_descriptors>
    <participant profile_name="nic_participant" is_default_profile="true">
      <rtps>
        <userTransports><transport_id>nic_only</transport_id></userTransports>
        <useBuiltinTransports>false</useBuiltinTransports>
      </rtps>
    </participant>
  </profiles>
</dds>
XML
        export FASTRTPS_DEFAULT_PROFILES_FILE=/tmp/fastdds-nic.xml
        echo "▶ DDS NIC 화이트리스트: ${_nic_ip} (Fast DDS locator 를 이 NIC 로 제한)"
        # CycloneDDS 를 쓰는 경우도 같은 이유로 인터페이스를 고정한다.
        [ -z "${CYCLONEDDS_URI:-}" ] && export CYCLONEDDS_URI="<CycloneDDS><Domain><General><Interfaces><NetworkInterface address=\"${_nic_ip}\"/></Interfaces></General></Domain></CycloneDDS>"
    else
        echo "⚠️ 기본 라우트 NIC IP 감지 실패 → DDS 화이트리스트 생략(기본 동작)" >&2
    fi
fi

source /opt/ros/humble/setup.bash
# Autoware 오버레이(autoware/tier4 msgs + rviz 플러그인)는 autoware 변형 이미지에만
# 존재한다. 있으면 소스해 rviz2 가 autoware_*_msgs 토픽을 subscribe/표시할 수 있게 한다.
# (기본 rviz2-agl 이미지엔 없음 → 이 블록은 no-op, 동일 entrypoint 재사용)
if [ -f /opt/autoware/setup.bash ]; then
    source /opt/autoware/setup.bash
    echo "▶ autoware 오버레이 로드됨 (autoware/tier4 rviz 플러그인 + msgs)"
fi

# 선택적 rviz2 레이아웃: -e RVIZ_CONFIG=<컨테이너 내 경로>.
# 예) /opt/autoware/share/autoware_launch/rviz/autoware.rviz (autoware 변형에 baked-in).
# 파일이 없으면 경고만 하고 기본 뷰로 계속 (경계 방어 — 잘못된 경로에 죽지 않음).
rviz_args=()
if [ -n "${RVIZ_CONFIG:-}" ]; then
    if [ -f "$RVIZ_CONFIG" ]; then
        # ── 초기 카메라를 에고 추종으로 ────────────────────────────────────────
        # autoware.rviz 의 기본 뷰는 TopDownOrtho + Target Frame=`viewer` 다. 그런데
        # `viewer` 는 Autoware 가 **맵 중심에 고정**해 발행하는 static 프레임이다
        # (실측: map→viewer = 3749.7, 73724.3). 에고가 거기서 멀어지면 화면 밖으로
        # 나가 "차량이 안 보인다"가 된다 (Scale 10 → 가시범위 약 93×95m, 실측에서
        # 에고가 230m 밖). 모델·메시는 정상 로드된 상태였고 카메라만의 문제.
        # Current View 의 Target Frame 만 base_link 로 바꿔 카메라가 에고를 따라가게
        # 한다. 저장된 뷰(ThirdPersonFollower / TopDownOrtho@viewer)는 그대로 남아
        # rviz Views 패널에서 선택 가능. 맵 중심 고정을 원하면 -e RVIZ_FOLLOW_EGO=0.
        if [ "${RVIZ_FOLLOW_EGO:-1}" = "1" ] && grep -q "Target Frame: viewer" "$RVIZ_CONFIG"; then
            # 첫 번째 것만 = Views: Current 블록 (Saved 목록은 건드리지 않음)
            if sed '0,/Target Frame: viewer/s//Target Frame: base_link/' \
                   "$RVIZ_CONFIG" > /tmp/rviz-follow.rviz 2>/dev/null; then
                RVIZ_CONFIG=/tmp/rviz-follow.rviz
                echo "▶ 초기 뷰를 에고 추종으로 전환(Target Frame: viewer → base_link)"
            fi
        fi

        # ── 2D Pose Estimate 툴을 /initialpose3d 로 ──────────────────────────
        # rviz 기본 SetInitialPose 툴은 `/initialpose` 로 발행하는데, planning
        # simulator 의 에고는 그 토픽으로 **이동하지 않는다**(보드 실측: 발행해도
        # kinematic_state 가 그대로. `/initialpose3d` 로 쏘면 즉시 이동).
        # 그래서 화면에서 2D Pose Estimate 를 찍어도 아무 일도 일어나지 않는다.
        # 툴 블록 안의 토픽만 바꿔 화면 조작이 실제로 먹게 한다. 끄려면
        # -e RVIZ_INITIALPOSE3D=0 (표준 localization 스택을 쓰는 실차 등).
        if [ "${RVIZ_INITIALPOSE3D:-1}" = "1" ] && grep -q "rviz_default_plugins/SetInitialPose" "$RVIZ_CONFIG"; then
            if awk '
                /- Class: rviz_default_plugins\/SetInitialPose/ { inpose = 1 }
                inpose && /^ *- Class:/ && !/SetInitialPose/     { inpose = 0 }
                inpose && /Value: \/initialpose$/ { sub(/\/initialpose$/, "/initialpose3d") }
                { print }
            ' "$RVIZ_CONFIG" > /tmp/rviz-pose3d.rviz 2>/dev/null \
               && grep -q "Value: /initialpose3d" /tmp/rviz-pose3d.rviz; then
                RVIZ_CONFIG=/tmp/rviz-pose3d.rviz
                echo "▶ 2D Pose Estimate 툴 토픽: /initialpose → /initialpose3d (시뮬레이터가 받는 토픽)"
            fi
        fi
        rviz_args+=(-d "$RVIZ_CONFIG")
        echo "▶ rviz2 config: $RVIZ_CONFIG"
    else
        echo "⚠️ RVIZ_CONFIG 파일 없음(컨테이너): $RVIZ_CONFIG → 기본 뷰 사용" >&2
    fi
fi

# ── 차량 파라미터(vehicle_info) 주입 ──────────────────────────────────────────
# 일부 autoware rviz 플러그인은 차량 치수를 파라미터로 읽는다. Autoware 는 rviz 를
# vehicle_info 파라미터와 함께 launch 하지만 우리는 `ros2 run` 이라 비어 있어
# 경고가 난다(실측: "Failed to get vehicle_info: parameter 'wheel_radius' is not
# initialized"). 오버레이에 들어 있는 차량 파라미터 파일을 그대로 넘겨 채운다.
# (`/**:` 네임스페이스라 노드명 무관) 끄려면 -e RVIZ_VEHICLE_PARAMS=0.
ros_args=()
_vp="${RVIZ_VEHICLE_PARAM_FILE:-/opt/autoware/share/sample_vehicle_description/config/vehicle_info.param.yaml}"
if [ "${RVIZ_VEHICLE_PARAMS:-1}" = "1" ] && [ -f "$_vp" ]; then
    ros_args+=(--ros-args --params-file "$_vp")
    echo "▶ vehicle_info 파라미터 주입: $_vp"
fi

# ── homebar (홈 버튼 오버레이) — 이 컨테이너에 통합 ─────────────────────────────
# 예전엔 별도 컨테이너였다. homebar 는 cage 와 무관한 호스트 agl-compositor 의 일반
# 클라이언트이므로 여기서 함께 띄운다(이미지 통합 이유는 Dockerfile.touch 참조).
#
# 생명주기가 rviz2 와 같아지면서 예전 타이밍 문제들이 사라진다:
#   - 부팅 시 "띄웠다 숨기기" 경합 없음 — 버튼은 rviz2 와 함께 생겨 바로 뜬다.
#   - rviz2 를 정지하면 버튼도 사라진다(유령 서페이스/스테일 상태 없음).
# agl-shell 은 ack 을 주지 않으므로(가시성 관측 불가) 순서를 homebar 자신의
# 매핑 마커(/tmp/homebar-mapped, homebar.c 가 첫 configure 후 기록)에 앵커한다.
# 끄려면 -e HOMEBAR=0 .
if [ "$DISPLAY_MODE" = "cage" ] && [ "${HOMEBAR:-1}" = "1" ] && [ -x /usr/local/bin/homebar ]; then
    HB_X="${HOMEBAR_X:-1890}"; HB_Y="${HOMEBAR_Y:-0}"
    rm -f /tmp/homebar-mapped /tmp/homebar-hidden
    /usr/local/bin/homebar &
    (
      S=127.0.0.1:14005; A=agl_shell_ipc.AglShellManagerService
      # 1) homebar 서페이스가 매핑될 때까지 대기(마커 = homebar.c 첫 configure 직후).
      i=0
      while [ ! -f /tmp/homebar-mapped ] && [ "$i" -lt 150 ]; do i=$((i+1)); sleep 0.1; done
      if [ ! -f /tmp/homebar-mapped ]; then
          echo "⚠️ homebar 서페이스 매핑 실패 → 버튼 없이 계속" >&2
          exit 0
      fi
      # 2) cage(rviz2) 서페이스가 뜨기를 기다린다. **순서가 핵심**: 컴포지터는 일반 앱
      #    활성화가 배타적이어서, homebar 를 먼저 float 해도 뒤늦게 매핑된 cage 가
      #    활성화되며 버튼이 밀려난다(실측). cage 는 자기 중첩 소켓
      #    ($XDG_RUNTIME_DIR/wayland-N, N != 호스트 소켓)을 만들므로 이를 신호로 쓴다.
      j=0
      while [ "$j" -lt 600 ]; do
          for s in "$XDG_RUNTIME_DIR"/wayland-*; do
              case "$s" in
                *.lock|*"$WAYLAND_DISPLAY") continue ;;
              esac
              [ -S "$s" ] && { cage_up=1; break; }
          done
          [ "${cage_up:-0}" = 1 ] && break
          j=$((j+1)); sleep 0.1
      done
      # 3) rviz2 가 그려질 시간을 조금 준 뒤, cage 를 앞으로 → homebar 를 그 위에 float.
      #    ack 이 없어(가시성 관측 불가) 간격을 두고 3회 멱등 재확인한다.
      sleep 3
      # cage 에 **풀화면 롤**을 준다. 기본(지원) 구성은 런처가 NORMAL 롤 + 자기활성화로
      # 풀화면을 차지하는 형태이고, 풀화면 롤이 일반 창보다 위 레이어여서 cage 도 같은
      # 롤을 받아야 런처 위로 올라온다(안 주면 "rviz2 가 안 뜬다"가 된다 — 보드 실측).
      # 런처를 AGL 배경(BG) 롤로 띄우는 구성에서는 0 으로 끈다(그 구성은 rviz2 실행 중
      # 런처가 터치를 받지 못해 제품 흐름에는 쓰지 않는다 — 가이드 참고).
      if [ "${AGL_SHELL_FULLSCREEN:-1}" = "1" ]; then
          grpcurl -plaintext -d "{\"app_id\":\"wlroots\"}" "$S" "$A"/SetAppFullscreen >/dev/null 2>&1
      fi
      for attempt in 1 2 3; do
          # 사용자가 이미 홈으로 복귀했으면(homebar 가 표식을 남긴다) 재시도를 멈춘다.
          # 안 그러면 방금 숨긴 버튼을 런처 위에 도로 띄운다(실측 2026-08-18).
          [ -f /tmp/homebar-hidden ] && break
          grpcurl -plaintext -d "{\"app_id\":\"wlroots\",\"output_name\":\"${AGL_OUTPUT:-DP-1}\"}" "$S" "$A"/ActivateApp >/dev/null 2>&1
          sleep 1
          # sleep 1 사이에 사용자가 홈으로 갔을 수 있다 — 회차 진입 때 한 번만 보면
          # **진행 중인 회차**가 방금 숨긴 버튼을 도로 띄운다(실측 2026-08-18:
          # 탭 05:20:26 → 표시 시도 2/3 이 05:20:27, 버튼 t=674ms 재등장).
          [ -f /tmp/homebar-hidden ] && break
          grpcurl -plaintext -d "{\"app_id\":\"homebar\",\"output_name\":\"${AGL_OUTPUT:-DP-1}\"}" "$S" "$A"/ActivateApp >/dev/null 2>&1
          grpcurl -plaintext -d "{\"app_id\":\"homebar\",\"x_pos\":$HB_X,\"y_pos\":$HB_Y}" "$S" "$A"/SetAppFloat >/dev/null 2>&1
          grpcurl -plaintext -d "{\"app_id\":\"homebar\",\"x\":$HB_X,\"y\":$HB_Y}" "$S" "$A"/SetAppPosition >/dev/null 2>&1
          # 호출과 표식 생성이 겹치는 100ms 급 창까지 닫는다 — 띄운 뒤 확인해 되돌린다.
          if [ -f /tmp/homebar-hidden ]; then
              grpcurl -plaintext -d "{\"app_id\":\"homebar\"}" "$S" "$A"/DeactivateApp >/dev/null 2>&1
              break
          fi
          echo "▶ homebar 표시 시도 ${attempt}/3 (${HB_X},${HB_Y}) — 탭하면 런처로 복귀"
          sleep 12
      done
    ) &
fi

# --ros-args 는 ROS 인자 파싱 규칙상 **맨 끝**에 와야 한다(뒤에 오는 건 모두 ROS 인자).
if [ "$DISPLAY_MODE" = "cage" ]; then
    echo "▶ cage + rviz2 시작 (host socket: $WAYLAND_DISPLAY, SW-GL=$LIBGL_ALWAYS_SOFTWARE)"
    exec cage -- ros2 run rviz2 rviz2 "${rviz_args[@]}" "$@" "${ros_args[@]}"
else
    echo "▶ rviz2 시작 (호스트 X11 직행, DISPLAY=$DISPLAY, SW-GL=$LIBGL_ALWAYS_SOFTWARE)"
    exec ros2 run rviz2 rviz2 "${rviz_args[@]}" "$@" "${ros_args[@]}"
fi

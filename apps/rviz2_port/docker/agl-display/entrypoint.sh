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

: "${XDG_RUNTIME_DIR:?run-on-board.sh 가 호스트 소켓 디렉토리를 마운트해 지정해야 함}"
: "${WAYLAND_DISPLAY:?호스트 agl-compositor 소켓 이름 필요 (예: wayland-0)}"

if [ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
    echo "❌ 호스트 wayland 소켓 없음: $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" >&2
    exit 1
fi

export HOME="${HOME:-/tmp}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"   # Phase 1: llvmpipe
export QT_X11_NO_MITSHM=1                                     # 컨테이너 X 공유메모리 이슈 회피
# ⚠️ WAYLAND_SOCKET 은 빈 값으로도 set 금지 — libwayland 가 fd 로 파싱 시도 (실측)
unset WAYLAND_SOCKET

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
        rviz_args+=(-d "$RVIZ_CONFIG")
        echo "▶ rviz2 config: $RVIZ_CONFIG"
    else
        echo "⚠️ RVIZ_CONFIG 파일 없음(컨테이너): $RVIZ_CONFIG → 기본 뷰 사용" >&2
    fi
fi

echo "▶ cage + rviz2 시작 (host socket: $WAYLAND_DISPLAY, SW-GL=$LIBGL_ALWAYS_SOFTWARE)"
exec cage -- ros2 run rviz2 rviz2 "${rviz_args[@]}" "$@"

#!/bin/bash
# 보드(AGL, Orin AGX)에서 rviz2-agl 컨테이너 실행 + 창 활성화 (ADR-0018, F100)
#
# 사용: ./run-on-board.sh [rviz2 추가 인자...]
#   ROS_DOMAIN_ID=5 ./run-on-board.sh
#   RVIZ_IMAGE=rviz2-agl:latest ./run-on-board.sh
set -e

RVIZ_IMAGE="${RVIZ_IMAGE:-rviz2-agl:latest}"
NAME=rviz2-agl-run

# 1) agl-compositor 의 wayland 소켓 자동 탐지
SOCK=""
for d in /run/user/*; do
    for s in "$d"/wayland-*; do
        [ -S "$s" ] || continue
        case "$s" in *.lock) continue ;; esac
        SOCK="$s"; break 2
    done
done
[ -n "$SOCK" ] || { echo "❌ wayland 소켓 없음 (/run/user/*/wayland-*) — agl-compositor 확인"; exit 1; }
RUNDIR="$(dirname "$SOCK")"
WLNAME="$(basename "$SOCK")"
SOCK_UID="$(stat -c %u "$SOCK")"
echo "▶ wayland 소켓: $SOCK (uid=$SOCK_UID)"

# 2) 컨테이너 실행 — 소켓 소유자 uid 로 (cage 는 root 거부 + 소켓 쓰기 권한 정합)
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" \
    --net=host --ipc=host \
    --user "$SOCK_UID:$SOCK_UID" \
    -v "$RUNDIR":/host-xdg \
    -e XDG_RUNTIME_DIR=/host-xdg \
    -e WAYLAND_DISPLAY="$WLNAME" \
    -e HOME=/tmp \
    -e ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}" \
    "$RVIZ_IMAGE" "$@"

# 3) agl-compositor 에서 cage 창(app_id=wlroots) 활성화
#    (agl-shell 은 app_id 기반 활성화 — activate-by-default=false 인 표준 AGL 설정 대응)
export XDG_RUNTIME_DIR="$RUNDIR" WAYLAND_DISPLAY="$WLNAME"
OUTPUT="$(agl-shell-activator -a getoutputs 2>/dev/null | awk 'NF{print $1; exit}')"
OUTPUT="${OUTPUT:-DP-1}"
echo "▶ 창 활성화 대기 후 activate (output=$OUTPUT)"
for i in $(seq 1 20); do
    sleep 1
    agl-shell-activator -a activate -p wlroots -o "$OUTPUT" >/dev/null 2>&1 || true
    docker ps -q --filter name="$NAME" | grep -q . || { echo "❌ 컨테이너 종료됨:"; docker logs "$NAME" 2>&1 | tail -10; exit 1; }
done
echo "✅ 실행 중 — 화면에 rviz2 가 보여야 함. 중지: docker rm -f $NAME"
echo "   (홈스크린 복귀 후 재표출: agl-shell-activator -a activate -p wlroots -o $OUTPUT)"

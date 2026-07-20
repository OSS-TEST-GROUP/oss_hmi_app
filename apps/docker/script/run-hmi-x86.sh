#!/bin/bash
# =============================================================================
# run-hmi-x86.sh — 임의의 x86_64 리눅스 PC 에서 amd64 hmi_launcher(GTK/X11) 실행
#
# amd64 이미지는 GTK/X11 기반 Flutter 리눅스 앱이다. 보드(arm64, flutter-auto/
# Wayland) 와 달리 호스트의 X 디스플레이에 붙어 창을 띄운다. 다른 PC 로 옮길 때
# 바꿔야 하는 것(rosbridge URL / DISPLAY / uid / GPU)을 이 스크립트가 흡수한다.
#
# 사용:
#   bash run-hmi-x86.sh
#   ROSBRIDGE_URL=ws://172.16.10.151:9090 bash run-hmi-x86.sh   # 보드 rosbridge 로
#   GPU=nvidia bash run-hmi-x86.sh                              # NVIDIA GPU 강제
#   GPU=none   bash run-hmi-x86.sh                              # 소프트웨어 GL 강제
#   LAUNCHER_BOT=1 AGENT_HOST=127.0.0.1 AGENT_PORT=50051 bash run-hmi-x86.sh
#   CONFIG_FILE=~/my-launcher.json bash run-hmi-x86.sh          # 직접 만든 config 마운트
#
# Env (모두 선택):
#   IMAGE          이미지 (기본 registry.obigo.com/oss/oss-hmi-launcher:latest)
#   ROSBRIDGE_URL  rosbridge WebSocket URL (기본 ws://localhost:9090)
#   DISPLAY_ID     X 디스플레이 (기본 $DISPLAY, 없으면 :0)
#   HMI_UID        런타임 uid (기본 현재 사용자 $(id -u))
#   GPU            auto|nvidia|none (기본 auto — nvidia 감지 시 사용)
#   LAUNCHER_BOT   0|1  (기본 0 — v_agentos 데몬 없으면 봇 숨김)
#   AGENT_HOST     런처봇 데몬 호스트 (LAUNCHER_BOT=1 일 때)
#   AGENT_PORT     런처봇 데몬 포트 (기본 50051)
#   CONFIG_FILE    직접 마운트할 launcher_config.json 경로 (지정 시 ROSBRIDGE_URL 무시)
#   PULL           1|0  (기본 1 — 최신 이미지 pull, 미인증/오프라인이면 스킵)
# =============================================================================
set -e

IMAGE="${IMAGE:-registry.obigo.com/oss/oss-hmi-launcher:latest}"
ROSBRIDGE_URL="${ROSBRIDGE_URL:-ws://localhost:9090}"
DISPLAY_ID="${DISPLAY_ID:-${DISPLAY:-:0}}"
HMI_UID="${HMI_UID:-$(id -u)}"
GPU="${GPU:-auto}"
LAUNCHER_BOT="${LAUNCHER_BOT:-0}"
AGENT_PORT="${AGENT_PORT:-50051}"
NAME="hmi_launcher"
RUNTIME_DIR="/run/user/${HMI_UID}"

echo "[run-hmi-x86] image=$IMAGE"
echo "[run-hmi-x86] rosbridge=$ROSBRIDGE_URL  display=$DISPLAY_ID  uid=$HMI_UID  gpu=$GPU  bot=$LAUNCHER_BOT"

# ── 최신 이미지 pull (graceful) ──────────────────────────────────────────────
if [ "${PULL:-1}" = "1" ]; then
  docker pull "$IMAGE" >/dev/null 2>&1 \
    && echo "[run-hmi-x86] pulled $IMAGE" \
    || echo "[run-hmi-x86] pull 스킵/실패 → 로컬 이미지 사용: $IMAGE"
fi

# ── X 디스플레이 접근 허용 ───────────────────────────────────────────────────
if command -v xhost >/dev/null 2>&1; then
  xhost +local:docker >/dev/null 2>&1 || xhost +local: >/dev/null 2>&1 || true
  echo "[run-hmi-x86] xhost +local: (X 접근 허용)"
else
  echo "[run-hmi-x86] ⚠ xhost 없음 — 컨테이너가 X 에 못 붙으면 'xhost +local:' 수동 실행"
fi

# ── config: CONFIG_FILE 우선, 없으면 ROSBRIDGE_URL 로 생성 ────────────────────
CONFIG_MOUNT=()
if [ -n "${CONFIG_FILE:-}" ] && [ -f "${CONFIG_FILE}" ]; then
  CONFIG_MOUNT=(-v "$(readlink -f "$CONFIG_FILE"):/app/config/launcher_config.json:ro")
  echo "[run-hmi-x86] config 마운트: $CONFIG_FILE"
else
  GEN_CFG="${HMI_CONFIG_OUT:-/tmp/hmi-launcher-config.json}"
  cat > "$GEN_CFG" <<JSON
{
  "rosbridge": { "url": "${ROSBRIDGE_URL}" },
  "statusTopic": "/app_status/hmi_launcher",
  "rosReconnectIntervalSec": 2,
  "heartbeatIntervalSec": 1
}
JSON
  CONFIG_MOUNT=(-v "${GEN_CFG}:/app/config/launcher_config.json:ro")
  echo "[run-hmi-x86] config 생성: $GEN_CFG (rosbridge=$ROSBRIDGE_URL)"
fi

# ── GPU: auto 감지 / nvidia 강제 / none ──────────────────────────────────────
GPU_ARGS=()
use_nvidia=0
case "$GPU" in
  nvidia) use_nvidia=1 ;;
  none)   use_nvidia=0 ;;
  auto)
    if command -v nvidia-smi >/dev/null 2>&1 \
       && docker info 2>/dev/null | grep -qiE "Runtimes:.*nvidia|nvidia"; then
      use_nvidia=1
    fi ;;
esac
if [ "$use_nvidia" = "1" ]; then
  GPU_ARGS=(--gpus all)
  echo "[run-hmi-x86] NVIDIA GPU 사용 (--gpus all)"
else
  echo "[run-hmi-x86] 소프트웨어 GL (mesa) — GPU 미사용"
fi

# ── 런처봇(AI) env ───────────────────────────────────────────────────────────
BOT_ENV=()
if [ "$LAUNCHER_BOT" = "1" ]; then
  [ -n "${AGENT_HOST:-}" ] && BOT_ENV+=(-e "AGENT_HOST=${AGENT_HOST}")
  BOT_ENV+=(-e "AGENT_PORT=${AGENT_PORT}")
  echo "[run-hmi-x86] 런처봇 활성 (agent ${AGENT_HOST:-localhost}:${AGENT_PORT})"
else
  BOT_ENV=(-e LAUNCHER_BOT_ENABLED=0)
  echo "[run-hmi-x86] 런처봇 비활성 (LAUNCHER_BOT_ENABLED=0)"
fi

# ── 기존 컨테이너 정리 (hook 정책상 rm -f 대신 stop+rm) ──────────────────────
docker stop "$NAME" 2>/dev/null || true
docker rm "$NAME" 2>/dev/null || true

# ── 실행 ─────────────────────────────────────────────────────────────────────
docker run -d --name "$NAME" --restart unless-stopped \
  --network host \
  "${GPU_ARGS[@]}" \
  -e DISPLAY="$DISPLAY_ID" \
  -e XDG_RUNTIME_DIR="$RUNTIME_DIR" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "${RUNTIME_DIR}:${RUNTIME_DIR}" \
  "${CONFIG_MOUNT[@]}" \
  "${BOT_ENV[@]}" \
  "$IMAGE"

echo "[run-hmi-x86] done."
docker ps --format "  {{.Names}}\t{{.Image}}\t{{.Status}}" | grep -E "$NAME" || true
echo "[run-hmi-x86] 로그: docker logs -f $NAME"

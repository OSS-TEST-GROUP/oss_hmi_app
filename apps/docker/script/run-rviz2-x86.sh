#!/bin/bash
# Run the multi-arch rviz2-agl image on an x86_64 dev PC (amd64), for dev/CI.
#
# The board (arm64/AGL) runs the cage-based entrypoint against agl-compositor
# (see rviz2_port/docker/agl-display/run-on-board.sh + ext-agl registration).
# On an x86 dev PC there is usually no agl-compositor, so this script overrides
# the cage entrypoint and runs rviz2 directly on the host X11 display — the
# simplest reliable dev path (mirrors run-hmi-x86.sh for the Flutter launcher).
#
# Usage:
#   bash docker/script/run-rviz2-x86.sh
#   GPU=nvidia bash docker/script/run-rviz2-x86.sh          # NVIDIA (nvidia-container-toolkit)
#   GPU=none   bash docker/script/run-rviz2-x86.sh          # force software GL (llvmpipe)
#   ROS_DOMAIN_ID=5 bash docker/script/run-rviz2-x86.sh
#   IMAGE=registry.obigo.com/oss/rviz2-agl:latest bash docker/script/run-rviz2-x86.sh
#
# Env: IMAGE, GPU(auto|nvidia|none), ROS_DOMAIN_ID, DISPLAY
set -e

IMAGE="${IMAGE:-registry.obigo.com/oss/rviz2-agl:latest}"
NAME="${NAME:-rviz2-agl-x86}"
DISPLAY="${DISPLAY:-:0}"
GPU="${GPU:-auto}"
ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"

# GPU flag resolution
GPU_ARGS=()
SW_GL=1
if [ "$GPU" = "auto" ]; then
  command -v nvidia-smi >/dev/null 2>&1 && GPU=nvidia || GPU=none
fi
if [ "$GPU" = "nvidia" ]; then
  GPU_ARGS=(--gpus all); SW_GL=0
  echo "[rviz2-x86] GPU: nvidia (hardware GL)"
else
  echo "[rviz2-x86] GPU: none (software GL / llvmpipe)"
fi

# Allow local X clients (container connects to host X server).
command -v xhost >/dev/null 2>&1 && xhost +local: >/dev/null 2>&1 || true

echo "[rviz2-x86] image=${IMAGE} DISPLAY=${DISPLAY} ROS_DOMAIN_ID=${ROS_DOMAIN_ID}"
docker rm -f "$NAME" >/dev/null 2>&1 || true

exec docker run --rm --name "$NAME" \
  --net=host --ipc=host \
  "${GPU_ARGS[@]}" \
  -e DISPLAY="$DISPLAY" \
  -e LIBGL_ALWAYS_SOFTWARE="$SW_GL" \
  -e QT_X11_NO_MITSHM=1 \
  -e ROS_DOMAIN_ID="$ROS_DOMAIN_ID" \
  -e HOME=/tmp \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  --entrypoint bash \
  "$IMAGE" \
  -lc 'source /opt/ros/humble/setup.bash && exec ros2 run rviz2 rviz2 "$@"' -- "$@"

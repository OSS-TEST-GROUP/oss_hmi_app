#!/bin/sh
# homebar-up.sh — start the floating "home" button overlay on the AGL board.
#
# The homebar is a normal xdg_toplevel app; agl-shell only allows one primary
# shell client (grpc-server) + one ext/doas client (launcher), so homebar cannot
# be an agl-shell panel. Instead we run it as a normal app and float it on top
# via agl-shell-activator (host CLI — more reliable than an in-container grpc
# call for the initial activate+float).
#
# Run at boot (after agl-compositor is up), e.g. from run-ext-agl.sh or a
# systemd unit. Idempotent: re-running re-floats an existing homebar.
#
# Env: OUTPUT (default DP-1)
set -eu

OUTPUT="${OUTPUT:-DP-1}"
IMAGE="homebar:latest"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1001}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

# Start the container if not already running.
if ! docker ps --format '{{.Names}}' | grep -qx homebar; then
  docker rm homebar >/dev/null 2>&1 || true
  docker run -d --restart unless-stopped --name homebar --net=host --user 1001:1001 \
    -v /run/user/1001:/host-xdg -e XDG_RUNTIME_DIR=/host-xdg \
    -e WAYLAND_DISPLAY=wayland-0 "$IMAGE" >/dev/null
fi

# Show it. The FIRST float after a fresh start is flaky (the surface is still
# transitioning from the compositor's maximized default), so retry activate+float
# a few times until it sticks. Then place it bottom-right via SetAppPosition
# (grpc — the activator CLI has no x/y flags). Once shown+placed it persists
# across app switches.
sleep 5
for i in 1 2 3 4 5 6; do
  agl-shell-activator -a activate -p homebar -o "$OUTPUT" >/dev/null 2>&1 || true
  sleep 1
  agl-shell-activator -a float    -p homebar -o "$OUTPUT" >/dev/null 2>&1 || true
  sleep 1
done
# bottom-right corner (1920x1080 output, 50x50 circular button)
docker exec homebar grpcurl -plaintext \
  -d '{"app_id":"homebar","x":1846,"y":1006}' \
  127.0.0.1:14005 agl_shell_ipc.AglShellManagerService/SetAppPosition >/dev/null 2>&1 || true
echo "[homebar-up] homebar floated + positioned on $OUTPUT"

#!/bin/sh
# homebar container entrypoint.
#
# Runs the homebar display client (a plain xdg_toplevel app) and then, from
# inside the container, shows + floats it on top via the agl-shell gRPC service
# (grpcurl → 127.0.0.1:14005, reachable thanks to --net=host). Self-contained so
# adsw_manager can start it at boot with no external float step.
#
# Env (optional): AGL_OUTPUT (default DP-1), HOMEBAR_X/HOMEBAR_Y (float pos).
set -u

S=127.0.0.1:14005
A=agl_shell_ipc.AglShellManagerService
OUT="${AGL_OUTPUT:-DP-1}"
X="${HOMEBAR_X:-1846}"
Y="${HOMEBAR_Y:-24}"

float_once() {
  grpcurl -plaintext -d "{\"app_id\":\"homebar\",\"x_pos\":$X,\"y_pos\":$Y}" \
    "$S" "$A"/SetAppFloat >/dev/null 2>&1
}

/usr/local/bin/homebar &
HB=$!

# Let the surface settle (it un-maximizes itself), then show + float it. The
# initial show can be racy, so retry a few times; once shown it persists.
sleep 4
for i in 1 2 3 4 5 6; do
  grpcurl -plaintext -d "{\"app_id\":\"homebar\",\"output_name\":\"$OUT\"}" \
    "$S" "$A"/ActivateApp >/dev/null 2>&1
  sleep 1
  float_once
  sleep 1
done
grpcurl -plaintext -d "{\"app_id\":\"homebar\",\"x\":$X,\"y\":$Y}" \
  "$S" "$A"/SetAppPosition >/dev/null 2>&1
echo "[homebar] shown + floated at $X,$Y on $OUT"

# Watchdog: re-assert the float periodically (float only — no re-activate, so no
# flicker) to self-heal if the overlay is dropped. Ends when the client exits.
while kill -0 "$HB" 2>/dev/null; do
  sleep 30
  float_once
done
wait "$HB"

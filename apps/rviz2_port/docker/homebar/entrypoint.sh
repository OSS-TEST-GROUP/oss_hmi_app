#!/bin/sh
# homebar container entrypoint.
#
# Runs the homebar display client (a plain xdg_toplevel app), settles its float
# once (the first float after a fresh start is racy), then HIDES it. The button
# is NOT shown on the launcher — rviz2_monitor shows it (via gRPC) when it
# activates rviz2, and hides it again when returning home. Tapping the button
# also hides it (homebar.c go_home). Self-contained for adsw boot start.
#
# Env (optional): AGL_OUTPUT (default DP-1), HOMEBAR_X/HOMEBAR_Y (float pos).
set -u

S=127.0.0.1:14005
A=agl_shell_ipc.AglShellManagerService
OUT="${AGL_OUTPUT:-DP-1}"
X="${HOMEBAR_X:-1890}"
Y="${HOMEBAR_Y:-0}"

/usr/local/bin/homebar &
HB=$!

# Settle the overlay (activate+float retried — first show is racy), then hide it.
# Once settled, the later show/hide toggles from rviz2_monitor are reliable.
sleep 4
for i in 1 2 3 4 5 6; do
  grpcurl -plaintext -d "{\"app_id\":\"homebar\",\"output_name\":\"$OUT\"}" "$S" "$A"/ActivateApp >/dev/null 2>&1
  sleep 1
  grpcurl -plaintext -d "{\"app_id\":\"homebar\",\"x_pos\":$X,\"y_pos\":$Y}" "$S" "$A"/SetAppFloat >/dev/null 2>&1
  sleep 1
done
grpcurl -plaintext -d "{\"app_id\":\"homebar\",\"x\":$X,\"y\":$Y}" "$S" "$A"/SetAppPosition >/dev/null 2>&1
# Hide — boot foreground is the launcher, where the button must not appear.
grpcurl -plaintext -d '{"app_id":"homebar"}' "$S" "$A"/DeactivateApp >/dev/null 2>&1
echo "[homebar] settled + hidden (rviz2_monitor shows it over rviz2)"

wait "$HB"

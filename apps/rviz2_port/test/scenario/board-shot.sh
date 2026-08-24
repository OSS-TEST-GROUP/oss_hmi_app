#!/bin/bash
# 보드 화면 캡처 → /root/shot.png (호스트 weston-screenshooter, DOCKER_GUIDE.md:593)
rm -f /tmp/wayland-screenshot-*.png 2>/dev/null
su -s /bin/sh agl-driver -c "cd /tmp && XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 timeout 20 weston-screenshooter" >/dev/null 2>&1
f=$(ls -t /tmp/wayland-screenshot-*.png 2>/dev/null | head -1)
[ -n "$f" ] && cp "$f" /root/shot.png && echo "OK $(stat -c%s /root/shot.png)" || echo "FAIL"

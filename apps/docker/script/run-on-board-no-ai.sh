#!/bin/sh
# =============================================================================
# Orin AGX (AGL / Jetson) 보드에서 oss-hmi-launcher 를 "AI 기능 제외" 로 실행
# =============================================================================
# run-on-board-arm64.sh 와 동일한 이미지를 쓰되, LAUNCHER_BOT_ENABLED=0 으로
# 런처봇(STT/Agent/TTS 연동)을 비활성화한다. 결과: 순수 앱 런처(홈 그리드 +
# 임베디드 모니터 앱 + 설정)만 노출되고 봇 진입점(어시스턴트/음성/AI-SDK 토글)은
# 숨겨진다.
#
# v-agentos 데몬(:50051) 불필요:
#   - LAUNCHER_BOT_ENABLED=0 이면 기동 시 데몬 probe 자체를 건너뛴다.
#   - 따라서 이 배포에는 v_agentos_daemon 컨테이너를 함께 띄울 필요가 없다.
#   - (env 를 안 줘도 데몬이 없으면 probe 실패로 봇이 숨겨지지만, 명시적으로
#      0 을 주면 의도가 분명하고 probe 지연도 없다.)
#
# 사용:  scp 로 보드에 복사 후  →  sh run-on-board-no-ai.sh
# 전제:  agl-compositor(wayland-0) 가 떠 있고, 이미지가 `docker load` 되어 있을 것.
# =============================================================================
set -e
IMAGE="${IMAGE:-oss-hmi-launcher:3.32.5}"
APP_VER="${APP_VER:-3.32.5}"
WL_UID="${WL_UID:-1001}"                    # agl-driver
WL_DISP="${WL_DISP:-wayland-0}"

# wayland 소켓 경로 자동 감지 (run-on-board-arm64.sh 와 동일 로직).
RUNTIME_DIR=""
i=0
while [ $i -lt 40 ]; do
  if [ -S "/run/${WL_DISP}" ]; then RUNTIME_DIR="/run"; break
  elif [ -S "/run/user/${WL_UID}/${WL_DISP}" ]; then RUNTIME_DIR="/run/user/${WL_UID}"; break
  else
    FOUND="$(find /run -maxdepth 3 -name "${WL_DISP}" -type s 2>/dev/null | head -1)"
    if [ -n "$FOUND" ]; then RUNTIME_DIR="$(dirname "$FOUND")"; break; fi
  fi
  i=$((i+1)); sleep 1
done
if [ -z "$RUNTIME_DIR" ]; then
  echo "[!] wayland 소켓(${WL_DISP}) 을 /run 에서 찾지 못함 — 컴포지터가 떠 있는지 확인"; exit 1
fi
echo "[*] wayland 소켓: ${RUNTIME_DIR}/${WL_DISP}"

# NVIDIA/GL 드라이버 스택 스테이징 (run-on-board-arm64.sh 와 동일).
if [ ! -e /opt/nv-gl/libEGL_nvidia.so.0 ]; then
  echo "[*] /opt/nv-gl 에 NVIDIA/GL 드라이버 스택 스테이징..."
  mkdir -p /opt/nv-gl
  cp -an /usr/lib/libEGL* /usr/lib/libGL.so* /usr/lib/libGLES* /usr/lib/libGLdispatch* \
         /usr/lib/libOpenGL* /usr/lib/libgbm.so* /usr/lib/libdrm.so.2* \
         /usr/lib/libwayland-egl.so.1* /usr/lib/libwayland-client.so.0* /usr/lib/libwayland-server.so.0* \
         /usr/lib/libnv*.so* /opt/nv-gl/ 2>/dev/null || true
fi

# 기존 컨테이너 제거 후 실행 — LAUNCHER_BOT_ENABLED=0 추가가 유일한 차이점.
docker rm -f oss-hmi-launcher 2>/dev/null || true
docker run -d --name oss-hmi-launcher --restart unless-stopped --privileged --network host \
  --user "${WL_UID}:${WL_UID}" --group-add 44 --group-add 1008 \
  -v "${RUNTIME_DIR}/${WL_DISP}:${RUNTIME_DIR}/${WL_DISP}" \
  -v /usr/bin/flutter-auto:/usr/bin/flutter-auto:ro \
  -v "/usr/share/flutter/${APP_VER}/release/lib/libflutter_engine.so:/usr/share/flutter/${APP_VER}/release/lib/libflutter_engine.so:ro" \
  -v "/usr/share/flutter/${APP_VER}/release/data/icudtl.dat:/usr/share/flutter/icudtl.dat:ro" \
  -v /opt/nv-gl:/opt/nv-gl:ro \
  -v /usr/share/glvnd/egl_vendor.d:/usr/share/glvnd/egl_vendor.d:ro \
  -v /usr/share/egl/egl_external_platform.d:/usr/share/egl/egl_external_platform.d:ro \
  -e LD_LIBRARY_PATH=/opt/nv-gl -e HOME=/tmp \
  -e XDG_RUNTIME_DIR="${RUNTIME_DIR}" -e WAYLAND_DISPLAY=${WL_DISP} \
  -e LAUNCHER_BOT_ENABLED=0 \
  "${IMAGE}" --window-type BG

echo "[+] oss-hmi-launcher 시작됨 (AI 제외 — LAUNCHER_BOT_ENABLED=0, window-type=BG)."
echo "    봇/음성/AI-SDK UI 는 숨겨지고 순수 앱 런처로 동작합니다."
echo "    상태:  docker ps --filter name=oss-hmi-launcher"
echo "    로그:  docker logs -f oss-hmi-launcher"
echo "    중지:  docker rm -f oss-hmi-launcher"

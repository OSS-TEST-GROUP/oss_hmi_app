#!/bin/sh
# =============================================================================
# Orin AGX (AGL / Jetson) 보드에서 oss-hmi-launcher 도커 컨테이너 실행 헬퍼
# =============================================================================
# 이 이미지(Dockerfile.arm64, ubuntu:24.04 = glibc 2.39 = 보드 정합)는 앱 번들만
# 담고 있다. flutter-auto 바이너리 / Flutter 엔진 / ICU 데이터 / NVIDIA Tegra GL
# 드라이버 스택은 보드 rootfs 의 것을 런타임에 마운트한다(드라이버는 보드 커널과
# 버전이 묶여 있으므로 이미지에 넣지 않는다).
#
# 사용:  scp 로 보드에 복사 후  →  sh run-on-board-arm64.sh
# 전제:  agl-compositor(wayland-0) 가 떠 있고, 이미지가 `docker load` 되어 있을 것.
# =============================================================================
set -e
IMAGE="${IMAGE:-oss-hmi-launcher:3.32.5}"
APP_VER="${APP_VER:-3.32.5}"
WL_UID="${WL_UID:-1001}"                    # agl-driver (wayland-0 소유자)
RUNTIME_DIR="/run/user/${WL_UID}"

# 1) NVIDIA/GL 드라이버 스택을 컨테이너용 디렉토리로 스테이징.
#    libc/bash 의존성(libc.so.6 등)은 제외 — 전체 /usr/lib 를 LD_LIBRARY_PATH 에
#    걸면 컨테이너 bash 가 보드 libc/vDSO 를 끌어와 깨진다(__kernel_gettimeofday).
#    필요한 것: glvnd(libEGL/GLES/GLdispatch/OpenGL), NVIDIA 벤더(libEGL_nvidia,
#    eglcore/glsi/rmapi), Tegra SoC(libnvsocsys/libnvtegrahv/libnvimp/libnvrm_*/
#    libnvos), gbm/drm, wayland-egl/client/server.
if [ ! -e /opt/nv-gl/libEGL_nvidia.so.0 ]; then
  echo "[*] /opt/nv-gl 에 NVIDIA/GL 드라이버 스택 스테이징..."
  mkdir -p /opt/nv-gl
  cp -an /usr/lib/libEGL* /usr/lib/libGL.so* /usr/lib/libGLES* /usr/lib/libGLdispatch* \
         /usr/lib/libOpenGL* /usr/lib/libgbm.so* /usr/lib/libdrm.so.2* \
         /usr/lib/libwayland-egl.so.1* /usr/lib/libwayland-client.so.0* /usr/lib/libwayland-server.so.0* \
         /usr/lib/libnv*.so* /opt/nv-gl/ 2>/dev/null || true
fi

# 2) 기존 컨테이너 제거 후 실행
docker rm -f oss-hmi-launcher 2>/dev/null || true
docker run -d --name oss-hmi-launcher --restart unless-stopped --privileged --network host \
  --user "${WL_UID}:${WL_UID}" --group-add 44 --group-add 1008 \
  -v "${RUNTIME_DIR}:${RUNTIME_DIR}" \
  -v /usr/bin/flutter-auto:/usr/bin/flutter-auto:ro \
  -v "/usr/share/flutter/${APP_VER}/release/lib/libflutter_engine.so:/usr/share/flutter/${APP_VER}/release/lib/libflutter_engine.so:ro" \
  -v "/usr/share/flutter/${APP_VER}/release/data/icudtl.dat:/usr/share/flutter/icudtl.dat:ro" \
  -v /opt/nv-gl:/opt/nv-gl:ro \
  -v /usr/share/glvnd/egl_vendor.d:/usr/share/glvnd/egl_vendor.d:ro \
  -v /usr/share/egl/egl_external_platform.d:/usr/share/egl/egl_external_platform.d:ro \
  -e LD_LIBRARY_PATH=/opt/nv-gl -e HOME=/tmp \
  -e XDG_RUNTIME_DIR="${RUNTIME_DIR}" -e WAYLAND_DISPLAY=wayland-0 \
  "${IMAGE}"

echo "[+] oss-hmi-launcher 시작됨."
echo "    상태:  docker ps --filter name=oss-hmi-launcher"
echo "    로그:  docker logs -f oss-hmi-launcher"
echo "    중지:  docker rm -f oss-hmi-launcher"

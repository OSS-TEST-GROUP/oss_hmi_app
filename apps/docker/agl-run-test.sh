#!/bin/bash
# QEMU arm64 테스트용: Weston Wayland + flutter-auto 실행
# VNC_PORT(기본 5900)가 설정되면 VNC 백엔드(포트 접속), 없으면 헤드리스 백엔드 사용
# (X11 백엔드는 arm64 QEMU ↔ 호스트 간 MIT-SHM 불가로 사용 안 함)
set -e

APP_NAME=${APP_NAME:-adsw_monitor}
APP_VERSION=${APP_VERSION:-3.32.2}
BUNDLE_PATH=${BUNDLE_PATH:-/usr/share/flutter/${APP_NAME}/${APP_VERSION}/release}
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/1001}
WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}

export XDG_RUNTIME_DIR WAYLAND_DISPLAY

mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

echo "[INFO] flutter-auto : $(which flutter-auto)"
echo "[INFO] bundle       : ${BUNDLE_PATH}"
echo "[INFO] WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
echo "[INFO] XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"

if [ ! -d "${BUNDLE_PATH}" ]; then
    echo "[ERROR] 번들 디렉토리를 찾을 수 없습니다: ${BUNDLE_PATH}"
    exit 1
fi

# Weston 컴포지터 시작
# VNC_PORT가 설정되면 VNC 백엔드(libneatvnc, SHM 불필요), 없으면 헤드리스
VNC_PORT=${VNC_PORT:-0}
WESTON_WIDTH=${WESTON_WIDTH:-1920}
WESTON_HEIGHT=${WESTON_HEIGHT:-720}

if [ "${VNC_PORT}" -gt 0 ] 2>/dev/null; then
    # LISTEN 상태 포트만 확인 (TIME_WAIT 등 제외)
    if ss -tlnH 2>/dev/null | awk '{print $4}' | grep -q ":${VNC_PORT}$"; then
        echo "[ERROR] 포트 ${VNC_PORT}이 이미 사용 중입니다. 기존 컨테이너를 먼저 중지하세요:"
        echo "        docker stop adsw_monitor_arm64_test"
        exit 1
    fi
    echo "[INFO] Weston VNC 백엔드 시작 (포트 ${VNC_PORT}, ${WESTON_WIDTH}x${WESTON_HEIGHT})..."
    # VNC 백엔드는 TLS 인증서 필수 — 자체서명 인증서 생성
    VNC_TLS_DIR="/tmp/weston-vnc-tls"
    mkdir -p "${VNC_TLS_DIR}"
    openssl req -x509 -newkey rsa:2048 -days 3650 -nodes \
        -keyout "${VNC_TLS_DIR}/key.pem" \
        -out "${VNC_TLS_DIR}/cert.pem" \
        -subj "/CN=weston-vnc" \
        2>/dev/null
    env -u LIBGL_ALWAYS_SOFTWARE -u MESA_LOADER_DRIVER_OVERRIDE \
    weston --backend=vnc-backend.so \
           --renderer=pixman \
           --width="${WESTON_WIDTH}" \
           --height="${WESTON_HEIGHT}" \
           --socket="${WAYLAND_DISPLAY}" \
           --idle-time=0 \
           --no-config \
           --port="${VNC_PORT}" \
           --vnc-tls-cert="${VNC_TLS_DIR}/cert.pem" \
           --vnc-tls-key="${VNC_TLS_DIR}/key.pem" &
else
    echo "[INFO] Weston 헤드리스 컴포지터 시작..."
    env -u LIBGL_ALWAYS_SOFTWARE -u MESA_LOADER_DRIVER_OVERRIDE \
    weston --backend=headless-backend.so \
           --socket="${WAYLAND_DISPLAY}" \
           --idle-time=0 \
           --no-config &
fi
WESTON_PID=$!

# Wayland 소켓 생성 대기 (최대 5초)
for i in $(seq 1 10); do
    if [ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]; then
        break
    fi
    sleep 0.5
done

if [ ! -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]; then
    echo "[ERROR] Weston 시작 실패 (소켓 없음: ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY})"
    kill "${WESTON_PID}" 2>/dev/null || true
    exit 1
fi

echo "[INFO] Weston 시작 완료 (PID=${WESTON_PID})"

# Weston 종료 시 컨테이너도 종료
cleanup() {
    echo "[INFO] 종료 중..."
    kill "${WESTON_PID}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# flutter-auto: QEMU arm64 이진, GPU 없을 때 소프트웨어 렌더링 강제
exec env LIBGL_ALWAYS_SOFTWARE=${LIBGL_ALWAYS_SOFTWARE:-1} \
         MESA_LOADER_DRIVER_OVERRIDE=${MESA_LOADER_DRIVER_OVERRIDE:-softpipe} \
    /usr/bin/flutter-auto \
    -b "${BUNDLE_PATH}" \
    --xdg-shell-app-id "${APP_NAME}" \
    "$@"

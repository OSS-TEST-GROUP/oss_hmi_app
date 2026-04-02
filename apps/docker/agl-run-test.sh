#!/bin/bash
# QEMU arm64 테스트용: Weston 헤드리스 Wayland + flutter-auto 실행
set -e

APP_NAME=${APP_NAME:-adsw_monitor}
APP_VERSION=${APP_VERSION:-3.32.2}
BUNDLE_PATH=${BUNDLE_PATH:-/usr/share/flutter/${APP_NAME}/${APP_VERSION}/release}
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/1001}
WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}

export XDG_RUNTIME_DIR WAYLAND_DISPLAY

# QEMU 환경에서 GPU 없을 때 소프트웨어 렌더링으로 폴백
export LIBGL_ALWAYS_SOFTWARE=${LIBGL_ALWAYS_SOFTWARE:-1}
export MESA_LOADER_DRIVER_OVERRIDE=${MESA_LOADER_DRIVER_OVERRIDE:-softpipe}

mkdir -p "${XDG_RUNTIME_DIR}"

echo "[INFO] flutter-auto : $(which flutter-auto)"
echo "[INFO] bundle       : ${BUNDLE_PATH}"
echo "[INFO] WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
echo "[INFO] XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"

if [ ! -d "${BUNDLE_PATH}" ]; then
    echo "[ERROR] 번들 디렉토리를 찾을 수 없습니다: ${BUNDLE_PATH}"
    exit 1
fi

# Weston 헤드리스 컴포지터 시작
echo "[INFO] Weston 헤드리스 컴포지터 시작..."
weston --backend=headless-backend.so \
       --socket="${WAYLAND_DISPLAY}" \
       --idle-time=0 \
       --no-config &
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

exec /usr/bin/flutter-auto \
    -b "${BUNDLE_PATH}" \
    --xdg-shell-app-id "${APP_NAME}" \
    "$@"

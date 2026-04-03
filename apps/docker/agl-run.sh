#!/bin/bash
# AGL flutter-auto 실행 스크립트
set -e

FLUTTER_AUTO=${FLUTTER_AUTO_BIN:-/usr/bin/flutter-auto}
BUNDLE_PATH=${BUNDLE_PATH:-/usr/share/flutter/${APP_NAME}/${APP_VERSION}/release}
APP_ID=${APP_NAME:-adsw_monitor}

if [ ! -f "${FLUTTER_AUTO}" ]; then
    echo "[ERROR] flutter-auto 를 찾을 수 없습니다: ${FLUTTER_AUTO}"
    echo ""
    echo "다음 중 하나로 해결하세요:"
    echo "  1. 호스트에서 볼륨 마운트:"
    echo "     docker run -v /usr/bin/flutter-auto:${FLUTTER_AUTO} ..."
    echo "  2. 환경변수로 경로 지정:"
    echo "     docker run -e FLUTTER_AUTO_BIN=/path/to/flutter-auto ..."
    exit 1
fi

if [ ! -d "${BUNDLE_PATH}" ]; then
    echo "[ERROR] 번들 디렉토리를 찾을 수 없습니다: ${BUNDLE_PATH}"
    exit 1
fi

echo "[INFO] flutter-auto : ${FLUTTER_AUTO}"
echo "[INFO] bundle       : ${BUNDLE_PATH}"
echo "[INFO] app-id       : ${APP_ID}"
echo "[INFO] WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
echo "[INFO] XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"

exec "${FLUTTER_AUTO}" \
    -b "${BUNDLE_PATH}" \
    --xdg-shell-app-id "${APP_ID}" \
    "$@"

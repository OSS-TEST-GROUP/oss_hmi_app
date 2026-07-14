#!/bin/bash
# AGL SDK 빌더 이미지에서 arm64 테스트 런타임에 필요한 바이너리를 추출합니다.
# 사전 조건: adsw_monitor_builder:arm64 이미지가 빌드되어 있어야 합니다.
# 실행 위치: apps/ 디렉토리
set -e

AGL_SYSROOT="/opt/agl-sdk/sysroots/aarch64-agl-linux"
BUILDER_IMAGE="adsw_monitor_builder:arm64"
OUT="output/agl-binaries"
FLUTTER_VER="3.32.2"

echo "[INFO] AGL 바이너리 추출 시작 (이미지: ${BUILDER_IMAGE})"

if ! docker image inspect "${BUILDER_IMAGE}" > /dev/null 2>&1; then
    echo "[ERROR] ${BUILDER_IMAGE} 이미지가 없습니다."
    echo "        먼저 빌더 이미지를 빌드하세요:"
    echo "        docker compose --profile build build adsw_monitor_builder_arm64"
    exit 1
fi

mkdir -p "${OUT}/bin"
mkdir -p "${OUT}/lib"
mkdir -p "${OUT}/flutter/${FLUTTER_VER}/release/lib"
mkdir -p "${OUT}/flutter/${FLUTTER_VER}/release/data"

extract() {
    local src="$1"
    local dst="$2"
    echo "[INFO] 추출: ${src}"
    docker run --rm --entrypoint bash "${BUILDER_IMAGE}" -c "cat ${src}" > "${dst}"
}

extract "${AGL_SYSROOT}/usr/bin/flutter-auto" \
        "${OUT}/bin/flutter-auto"
chmod +x "${OUT}/bin/flutter-auto"

extract "${AGL_SYSROOT}/usr/share/flutter/${FLUTTER_VER}/release/lib/libflutter_engine.so" \
        "${OUT}/flutter/${FLUTTER_VER}/release/lib/libflutter_engine.so"

extract "${AGL_SYSROOT}/usr/share/flutter/${FLUTTER_VER}/release/data/icudtl.dat" \
        "${OUT}/flutter/${FLUTTER_VER}/release/data/icudtl.dat"

extract "${AGL_SYSROOT}/usr/lib/libc++.so.1.0" \
        "${OUT}/lib/libc++.so.1.0"

extract "${AGL_SYSROOT}/usr/lib/libc++abi.so.1.0" \
        "${OUT}/lib/libc++abi.so.1.0"

echo "[INFO] 완료: ${OUT}/"
ls -lh "${OUT}/bin/" "${OUT}/lib/" "${OUT}/flutter/${FLUTTER_VER}/release/lib/" "${OUT}/flutter/${FLUTTER_VER}/release/data/"

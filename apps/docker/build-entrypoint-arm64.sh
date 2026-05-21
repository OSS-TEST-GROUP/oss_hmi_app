#!/bin/bash
# AGL SDK 환경을 source한 뒤 AOT 빌드 스크립트를 실행합니다.
set -e

# Mark every Flutter clone safe for whichever UID compose runs us as.
# Two of them: /opt/flutter (the in-image one used by `flutter pub get`
# before the AGL toolchain takes over) and the AGL-bundled Flutter under
# the x86_64-aglsdk-linux sysroot (used by create_aot_with_yocto_sdk.py
# during `flutter clean` / build).  HOME=/tmp via compose env so
# --global writes to a path we can actually create.
git config --global --add safe.directory /opt/flutter 2>/dev/null || true
git config --global --add safe.directory \
    /opt/agl-sdk/sysroots/x86_64-aglsdk-linux/usr/share/flutter/sdk \
    2>/dev/null || true

ENV_SETUP="${AGL_SDK_INSTALL_DIR}/environment-setup-aarch64-agl-linux"

if [ ! -f "${ENV_SETUP}" ]; then
    echo "[ERROR] AGL SDK 환경 파일을 찾을 수 없습니다: ${ENV_SETUP}"
    echo "        AGL_SDK_INSTALL_DIR=${AGL_SDK_INSTALL_DIR}"
    exit 1
fi

echo "[INFO] AGL SDK 환경 로드: ${ENV_SETUP}"
# shellcheck disable=SC1090
source "${ENV_SETUP}"

echo "[INFO] 타겟 아키텍처: $(echo ${CC} | grep -o 'aarch64[^-]*' || echo 'aarch64')"
echo "[INFO] OECORE_NATIVE_SYSROOT=${OECORE_NATIVE_SYSROOT}"
echo "[INFO] SDKTARGETSYSROOT=${SDKTARGETSYSROOT}"

# --output-dir 은 이 스크립트 전용 인자 (create_aot_with_yocto_sdk.py 에 전달하지 않음)
APP_PATH="/workspace/app"
OUTPUT_DIR="/workspace/output"
APP_PATH_SEEN="false"
PASS_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --output-dir=*) OUTPUT_DIR="${arg#*=}" ;;
        --app-path=*)
            APP_PATH="${arg#*=}"
            APP_PATH_SEEN="true"
            PASS_ARGS+=("$arg")
            ;;
        *) PASS_ARGS+=("$arg") ;;
    esac
done

# Allow `docker compose run --rm <builder>` with no args (compose mounts
# the app under /workspace/app and the output under /workspace/output, so
# the defaults above always work — feed them to create_aot_with_yocto_sdk
# explicitly since the underlying python script requires --app-path).
if [ "${APP_PATH_SEEN}" = "false" ]; then
    PASS_ARGS+=("--app-path=${APP_PATH}")
fi

APP_NAME=$(grep '^name:' "${APP_PATH}/pubspec.yaml" | awk '{print $2}')
echo "[INFO] APP_NAME=${APP_NAME}"
echo "[INFO] OUTPUT_DIR=${OUTPUT_DIR}"

python3 /usr/local/bin/create_aot_with_yocto_sdk.py "${PASS_ARGS[@]}"

# create_aot_with_yocto_sdk.py 는 {app_path}/{app_name}-release.tar.gz 로 생성
SRC_TAR="${APP_PATH}/${APP_NAME}-release.tar.gz"
if [ -f "${SRC_TAR}" ]; then
    if [ -n "${OUTPUT_DIR}" ]; then
        mkdir -p "${OUTPUT_DIR}"
        mv "${SRC_TAR}" "${OUTPUT_DIR}/${APP_NAME}-arm64-release.tar.gz"
        echo "[INFO] Output: ${OUTPUT_DIR}/${APP_NAME}-arm64-release.tar.gz"
    else
        mv "${SRC_TAR}" "${APP_PATH}/${APP_NAME}-arm64-release.tar.gz"
        echo "[INFO] Output: ${APP_PATH}/${APP_NAME}-arm64-release.tar.gz"
    fi
else
    echo "[WARN] 빌드 결과물을 찾을 수 없습니다: ${SRC_TAR}"
fi

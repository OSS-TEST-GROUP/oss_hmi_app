#!/bin/bash
set -e

# x86_64 Flutter Linux release build entrypoint

# Compose runs this container as ${USER_UID}:${USER_GID} so artifacts in
# the bind-mounted output/ end up owned by the host user. The Flutter
# clone at /opt/flutter is root-owned (image build time), so any git op
# (flutter clean / pub get) trips "dubious ownership" unless we mark it
# safe for whichever UID we're now running as. --global writes into
# $HOME/.gitconfig (HOME=/tmp via compose env, always writable).
git config --global --add safe.directory /opt/flutter 2>/dev/null || true

APP_PATH="/workspace/app"
OUTPUT_DIR="/workspace/output"

# 인수 파싱
while [[ $# -gt 0 ]]; do
    case "$1" in
        --app-path=*)   APP_PATH="${1#*=}"; shift ;;
        --app-path)     APP_PATH="$2"; shift 2 ;;
        --output-dir=*) OUTPUT_DIR="${1#*=}"; shift ;;
        --output-dir)   OUTPUT_DIR="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

APP_NAME=$(grep '^name:' "$APP_PATH/pubspec.yaml" | awk '{print $2}')
echo "=== x86_64 Flutter Linux Build ==="
echo "  APP_PATH   : $APP_PATH"
echo "  OUTPUT_DIR : $OUTPUT_DIR"
echo "  APP_NAME   : $APP_NAME"

cd "$APP_PATH"

# 이전 빌드 캐시 정리 (호스트/컨테이너 경로 불일치 방지)
flutter clean

# pub get
flutter pub get

# x86_64 release build
flutter build linux --release

# 번들 경로
BUNDLE_DIR="$APP_PATH/build/linux/x64/release/bundle"

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "ERROR: Bundle not found at $BUNDLE_DIR"
    exit 1
fi

# 출력 디렉토리 생성
mkdir -p "$OUTPUT_DIR"

# tar.gz 패키징
OUTPUT_FILE="$OUTPUT_DIR/${APP_NAME}-x86_64-release.tar.gz"
tar -czf "$OUTPUT_FILE" -C "$BUNDLE_DIR" .

echo "=== Build complete ==="
echo "  Output: $OUTPUT_FILE"

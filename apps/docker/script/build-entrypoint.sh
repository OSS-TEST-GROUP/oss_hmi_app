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

# pub get — **lock 을 고쳐 쓰지 않는다**(--enforce-lockfile).
#
# 왜: 예전엔 그냥 `flutter pub get` 이었다. 커밋된 lock 이 이 빌더의 Flutter 로 풀리지
# 않으면 pub 이 **조용히 lock 을 다시 써서** 워크트리를 더럽혔고, 그 상태가 이미지 빌드
# 스크립트의 재현성 가드에 "커밋되지 않은 변경"으로 뒤늦게 걸렸다(원인과 무관해 보이는
# 자리에서 터진다). 실측 2026-08-18: 8 앱 중 6 개의 lock 이 이 상태였다 —
# Flutter SDK 가 핀으로 묶는 analyzer/_fe_analyzer_shared/meta/test_api 가 어긋나 있었고,
# lock 이 Flutter 핀 밖(예: `dart pub get`)에서 만들어졌기 때문이다.
#
# 이제는 불일치를 **여기서 바로** 실패시킨다. 해결법은 아래 메시지대로 이 빌더 안에서
# lock 을 만들어 커밋하는 것이다 (x86/arm64 빌더는 같은 해를 낸다 — 실측).
if ! flutter pub get --enforce-lockfile; then
    cat >&2 <<'EOM'

╭─ pubspec.lock 이 이 빌더의 Flutter 로 풀리지 않습니다 ─────────────────────────
│ 로컬에서 `dart pub get` 으로 lock 을 만들면 Flutter SDK 핀(analyzer/meta/
│ test_api 등)을 보지 않아 어긋납니다. lock 은 **빌더 안에서** 갱신하세요:
│
│   cd apps && docker compose -f docker/compose/docker-compose.yml --profile build │     run --rm --entrypoint bash <APP>_builder_x86 │     -c 'cd /workspace/apps/<APP> && flutter pub get'
│
│ 그 결과 pubspec.lock 을 커밋한 뒤 다시 빌드하세요.
╰───────────────────────────────────────────────────────────────────────────────
EOM
    exit 1
fi

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

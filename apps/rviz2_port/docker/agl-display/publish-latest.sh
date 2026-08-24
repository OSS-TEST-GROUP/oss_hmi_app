#!/usr/bin/env bash
# rviz2-agl:latest 발행 — **전 기능 이미지만** 올라가도록 검증한 뒤 태그를 옮긴다.
#
# 보드는 :latest 를 pull 해서 쓴다. 그래서 :latest 에는 터치(소스빌드 wayland/wlroots/cage)
# · homebar · grpcurl · Autoware 오버레이가 모두 들어 있어야 한다. 2026-08-13 에 베이스
# 빌드가 :latest 를 덮어 이 넷이 전부 사라진 적이 있다(보드 실측: 터치·홈버튼·오버레이 불가).
#
# 사용법:
#   ./publish-latest.sh <스냅샷태그>
#   ./publish-latest.sh autoware-develop-20260811-5ef55ee
#   VERIFY_ONLY=1 ./publish-latest.sh <태그>     # 검증만 하고 태그는 안 옮긴다
#
# 전제: <스냅샷태그> 는 Dockerfile.all 로 **각 아키 네이티브 빌드 → per-arch push →
#       imagetools 결합**한 멀티아치 매니페스트다(README '빌드' 절).
set -euo pipefail

REG="${REG:-registry.obigo.com/oss}"
IMAGE="${IMAGE:-rviz2-agl}"
SRC_TAG="${1:-}"
[ -n "$SRC_TAG" ] || { echo "사용법: $0 <스냅샷태그>" >&2; exit 1; }
SRC="${REG}/${IMAGE}:${SRC_TAG}"

# :latest 가 반드시 담고 있어야 하는 것 — 하나라도 없으면 발행하지 않는다.
REQUIRED=(
    /usr/local/bin/cage        # 터치·키오스크(중첩 wlroots 컴포지터)
    /usr/local/bin/homebar     # 홈 버튼 오버레이
    /usr/local/bin/grpcurl     # agl-shell 활성화(:14005)
    /opt/autoware/setup.bash   # Autoware 오버레이(msgs + rviz 플러그인 + autoware.rviz)
    /entrypoint.sh
)

verify_arch() {   # $1 = linux/amd64 | linux/arm64
    local plat="$1" cid missing=0
    echo "── ${plat} 검증 ──"
    docker pull -q --platform "$plat" "$SRC" >/dev/null
    cid=$(docker create --platform "$plat" "$SRC")
    for f in "${REQUIRED[@]}"; do
        if docker cp "${cid}:${f}" - >/dev/null 2>&1; then
            echo "   ✅ $f"
        else
            echo "   ❌ $f — 없음"; missing=$((missing+1))
        fi
    done
    docker rm "$cid" >/dev/null
    return $missing
}

fail=0
verify_arch linux/amd64 || fail=$((fail+$?))
verify_arch linux/arm64 || fail=$((fail+$?))

if [ "$fail" -ne 0 ]; then
    echo ""
    echo "ERROR: 필수 구성 ${fail}건 누락 — :latest 를 옮기지 않는다." >&2
    echo "       베이스 빌드(Dockerfile)를 올린 것은 아닌지 확인하라. 정본은 Dockerfile.all." >&2
    exit 1
fi

if [ "${VERIFY_ONLY:-0}" = "1" ]; then
    echo ""; echo "검증만 수행(VERIFY_ONLY=1) — 태그는 그대로 둔다."; exit 0
fi

echo ""
echo "=== :latest → ${SRC_TAG} 로 이동 ==="
docker buildx imagetools create -t "${REG}/${IMAGE}:latest" "$SRC"
docker buildx imagetools inspect "${REG}/${IMAGE}:latest" | grep -iE "^Name|Platform" | sed 's/^/  /'

#!/usr/bin/env bash
# build_rviz2_local.sh — rviz2 AGL 이미지 3변형을 **로컬 PC 에서** 빌드+푸시.
#
# **표준(로컬 PC) 빌드 경로**다 — 보드 불필요, dev 환경에 독립적. arm64 는 buildx + QEMU
# 로 에뮬레이션하므로 네이티브보다 느리다(특히 touch 는 소스빌드라 수 시간). arm64 보드가
# 있고 닿을 때는 build_rviz2_autoware.sh(보드 SSH, **선택적 고속 경로**)로 autoware 빌드를
# 가속할 수 있으나 필수는 아니다.
#
# **권장: `all`** — Dockerfile.all 하나로 :latest 를 끝까지 만든다(중간 태그 불필요, 빌드
#   도구가 최종 이미지에서 빠져 약 210MB 작다). 아래 3-변형 체인은 하위호환용으로 남겨둔다.
#
# 빌드 체인(레거시):  base(ros+rviz2+cage) → touch(+wayland/wlroots/cage 소스빌드) → autoware(+오버레이)
#
# 태그 규약(팀 통일 + 변형 구분):
#   base      → :base   + :base-<branch>-<date>-<shortsha>
#   touch     → :touch  + :touch-<branch>-<date>-<shortsha>
#   autoware  → :latest + :autoware-<branch>-<date>-<shortsha>  (런타임 기본 이미지)
#   ※ 변형 접두사가 없으면 같은 커밋에서 base/touch/autoware 스냅샷이 **서로 덮어쓴다**.
#      (팀 스크립트 build_rviz2_multiarch.sh / build_rviz2_autoware.sh 의 SNAP_PREFIX 와 동일 규칙)
#
# 규약 공통: 커밋 안 된 tracked 변경 차단(dirty block), default 브랜치에서만 push,
#            OCI 라벨 5종 + com.obigo.* 주입.
#
# 사용(oss_hmi_app 작업트리 어디서나):
#   apps/docker/script/build_rviz2_local.sh base
#   apps/docker/script/build_rviz2_local.sh touch       # 오래 걸림(QEMU 소스빌드)
#   apps/docker/script/build_rviz2_local.sh autoware
#
# Env: REGISTRY(registry.obigo.com) IMAGE(oss/rviz2-agl) BUILDER(mmf-buildx)
#      PLATFORMS(base 만 기본 amd64+arm64; touch/autoware 는 arm64 고정)
#      DEFAULT_BRANCH(develop)
set -euo pipefail

VARIANT="${1:-}"
case "$VARIANT" in
  all|base|touch|autoware) ;;
  *) echo "사용법: $0 <all|base|touch|autoware>   (all = 단일 Dockerfile, 권장)" >&2; exit 2 ;;
esac

REGISTRY="${REGISTRY:-registry.obigo.com}"
IMAGE="${IMAGE:-oss/rviz2-agl}"
BUILDER="${BUILDER:-mmf-buildx}"

cd "$(dirname "$0")/../.."            # → apps/
CTX="rviz2_port/docker/agl-display"
R="${REGISTRY}/${IMAGE}"

# ── dirty 차단 ────────────────────────────────────────────────────────────
if ! git diff --quiet HEAD 2>/dev/null; then
  echo "ERROR: 커밋되지 않은 변경이 있습니다 — 커밋 후 실행하세요(스냅샷 재현성)." >&2
  git --no-pager diff --stat HEAD >&2 || true
  exit 1
fi

GIT_REV="$(git rev-parse HEAD)"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD | sed 's/[^A-Za-z0-9._-]/-/g')"
GIT_SHORT="$(git rev-parse --short HEAD)"

# ── default 브랜치 가드 ───────────────────────────────────────────────────
DEFAULT_BRANCH="${DEFAULT_BRANCH:-develop}"
if [ "${GIT_BRANCH}" != "${DEFAULT_BRANCH}" ]; then
  echo "ERROR: 현재 브랜치 '${GIT_BRANCH}' — push 는 default 브랜치 '${DEFAULT_BRANCH}' 에서만 허용." >&2
  exit 1
fi

BUILD_DATE_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DATE_UTC="$(date -u +%Y%m%d)"

# ── 변형별 Dockerfile / 태그 / 플랫폼 ─────────────────────────────────────
case "$VARIANT" in
  all)
    DF="${CTX}/Dockerfile.all"
    MAIN_TAG="latest"              # 런타임 기본 이미지 — 단일 파일이 곧 최종 산출물
    SNAP="autoware-${GIT_BRANCH}-${DATE_UTC}-${GIT_SHORT}"
    # 각 아키 네이티브 빌드 후 imagetools 로 결합하는 것을 권장(QEMU 소스빌드는 수 시간).
    PLATFORMS="${PLATFORMS:-linux/arm64}"
    ;;
  base)
    DF="${CTX}/Dockerfile"
    MAIN_TAG="base"
    SNAP="base-${GIT_BRANCH}-${DATE_UTC}-${GIT_SHORT}"
    PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"   # base 는 arch 무관 → 멀티아치
    ;;
  touch)
    DF="${CTX}/Dockerfile.touch"
    MAIN_TAG="touch"
    SNAP="touch-${GIT_BRANCH}-${DATE_UTC}-${GIT_SHORT}"
    # 라이브러리 경로가 아키 무관으로 바뀌어 amd64 도 빌드된다(두 트리플릿 나열).
    # 기본은 arm64(보드) — 로컬 QEMU arm64 소스빌드는 매우 느리므로 필요할 때만 확장.
    PLATFORMS="${PLATFORMS:-linux/arm64}"
    ;;
  autoware)
    DF="${CTX}/Dockerfile.autoware"
    MAIN_TAG="latest"              # 런타임 기본 이미지
    # build_rviz2_autoware.sh 와 동일하게 autoware 접두사(SNAP_PREFIX 기본값 autoware).
    SNAP="autoware-${GIT_BRANCH}-${DATE_UTC}-${GIT_SHORT}"
    # 오버레이를 멀티아치 파티션 이미지에서 직접 COPY 하므로 amd64 도 가능해졌다.
    PLATFORMS="${PLATFORMS:-linux/arm64}"
    ;;
esac

[ -f "$DF" ] || { echo "ERR: $DF 없음 (apps/ 기준 경로 확인)" >&2; exit 1; }

echo "=== rviz2 ${VARIANT} 빌드 (로컬 QEMU) ==="
echo "    dockerfile : ${DF}"
echo "    platforms  : ${PLATFORMS}"
echo "    tags       : ${R}:${MAIN_TAG}  +  ${R}:${SNAP}"

docker buildx create --name "${BUILDER}" --driver docker-container --use 2>/dev/null \
  || docker buildx use "${BUILDER}"

docker buildx build \
  --platform="${PLATFORMS}" \
  -f "${DF}" \
  --label "org.opencontainers.image.revision=${GIT_REV}" \
  --label "org.opencontainers.image.source=github.com/obigo-gov/oss_hmi_app" \
  --label "org.opencontainers.image.ref.name=${GIT_BRANCH}" \
  --label "org.opencontainers.image.created=${BUILD_DATE_UTC}" \
  --label "org.opencontainers.image.version=${SNAP}" \
  --label "com.obigo.built-from-repo=oss_hmi_app" \
  --label "com.obigo.built-from-path=apps/${DF}" \
  --push -t "${R}:${MAIN_TAG}" -t "${R}:${SNAP}" \
  "${CTX}"

echo ""
echo "=== Done ==="
echo "  pushed: ${R}:${MAIN_TAG}"
echo "  pushed: ${R}:${SNAP}"
echo "  확인:   docker buildx imagetools inspect ${R}:${MAIN_TAG}"

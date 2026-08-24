#!/usr/bin/env bash
# build_rviz2_autoware.sh — rviz2 AGL "autoware" 변형 이미지 빌드+푸시.
#
# 통일 규약(RVIZ2_IMAGE_TAG_ALIGNMENT.md)을 적용한다:
#   - dirty 차단: 커밋 안 된 tracked 변경이 있으면 중단(untracked 빌드 산출물은 무시).
#   - 불변 스냅샷 태그: <branch>-<date(UTC)>-<shortsha>  (예: feature-rviz2-20260729-abc1234)
#   - :${TAG}(기본 latest) 와 스냅샷 태그를 함께 push.
#   - OCI 라벨 5종(--label) 을 빌드 스크립트에서 주입(Dockerfile ARG/LABEL 대신).
#
# ⚠️ 이 스크립트는 **선택적 고속 경로**다 — arm64 보드에 ssh 로 접속해 보드의 네이티브
#    docker 로 빌드/푸시한다. **로컬 PC 빌드가 아니다.** arm64 보드가 있고 닿을 때만 쓴다.
#
#    ✅ 표준(로컬 PC) 빌드는  build_rviz2_local.sh autoware  다 — 보드 불필요, dev 환경에
#       독립적이며 동일한 :latest + 스냅샷을 산출한다. 로컬은 buildx + QEMU 라 네이티브보다
#       느리지만(550MB 오버레이 COPY + apt), 보드-네이티브 경로는 그 속도 최적화일 뿐
#       필수가 아니다.
#
# 전제:
#   - BOARD 에 docker + registry 로그인 완료(docker login registry.obigo.com -u ossuser).
#   - Autoware 오버레이 준비 작업 **없음**. Dockerfile.autoware 가 파티션 이미지
#     (ghcr.io/oss-test-group/autoware-partition:adsw-perception, 멀티아치)에서 /opt/autoware
#     를 직접 COPY 한다 — 별도 autoware-overlay 추출/푸시 단계가 제거됐다.
#     빌드 호스트가 그 파티션 이미지를 당길 수 있어야 한다(5.7GB, 최초 1회).
#   - FROM 베이스 :touch 이미지가 BOARD 에 존재(build_rviz2_multiarch.sh 로 생성).
#
# 사용(oss_hmi_app 작업트리 내 어디서나) — BOARD 필수(하드코딩 기본값 없음):
#   BOARD=root@<board-host> apps/docker/script/build_rviz2_autoware.sh
#   BOARD=root@<board-host> TAG=verify apps/docker/script/build_rviz2_autoware.sh
#
# Env: BOARD(**필수** — root@<host>. arm64 보드 SSH 대상. dev 환경마다 다르므로
#           하드코딩 기본값을 두지 않는다. 미설정 시 중단하고 로컬 표준 경로를 안내)
#      REGISTRY(registry.obigo.com) IMAGE(oss/rviz2-agl) TAG(latest)
#      BUILD_DIR(보드 빌드 컨텍스트 경로)
#      SSH/SCP — ssh/scp 커맨드 오버라이드(옵션 주입용, 예: SSH="ssh -o BatchMode=yes ...")
set -euo pipefail

REGISTRY="${REGISTRY:-registry.obigo.com}"
IMAGE="${IMAGE:-oss/rviz2-agl}"
TAG="${TAG:-latest}"
# BOARD 는 dev 환경마다 다르므로 하드코딩 기본값을 두지 않는다(stale IP 방지).
BOARD="${BOARD:-}"
if [ -z "${BOARD}" ]; then
  echo "ERROR: BOARD 가 설정되지 않았습니다 (예: BOARD=root@<board-host>)." >&2
  echo "       이 스크립트는 arm64 보드에서 네이티브로 빌드하는 선택적 고속 경로입니다." >&2
  echo "       표준 로컬 PC 빌드는 보드 없이:  apps/docker/script/build_rviz2_local.sh autoware" >&2
  exit 2
fi
BUILD_DIR="${BUILD_DIR:-/root/rviz2-autoware-build}"
SSH="${SSH:-ssh}"
SCP="${SCP:-scp}"

# 저장소 루트로 이동(git + Dockerfile 경로 기준). 스크립트는 apps/docker/script/ 에 있다.
cd "$(dirname "$0")/../.."          # → apps/
CTX="rviz2_port/docker/agl-display" # Dockerfile.autoware + entrypoint.sh 위치

# ── dirty 차단 (규약) — tracked 변경이 커밋 안 됐으면 중단. untracked 는 무시. ──────────
if ! git diff --quiet HEAD 2>/dev/null; then
  echo "❌ 커밋 안 된 변경이 있습니다. 스냅샷 태그의 무결성을 위해 커밋 후 실행하세요." >&2
  git --no-pager diff --stat HEAD >&2 || true
  exit 1
fi

# ── git 메타 + 스냅샷 태그(UTC) ──────────────────────────────────────────────────
GIT_REV="$(git rev-parse HEAD)"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD | sed 's/[^A-Za-z0-9._-]/-/g')"
GIT_SHORT="$(git rev-parse --short HEAD)"

# ── default-branch 가드 (규약) ────────────────────────────────────────────────
# :latest + 스냅샷 태그 push 는 default 브랜치(develop)에서만 허용한다.
# feature/기타 브랜치에서 실수로 :latest 를 덮어쓰는 것을 방지 (DEFAULT_BRANCH 로 조정).
DEFAULT_BRANCH="${DEFAULT_BRANCH:-develop}"
if [ "${GIT_BRANCH}" != "${DEFAULT_BRANCH}" ]; then
  echo "ERROR: 현재 브랜치 '${GIT_BRANCH}' — :latest + 스냅샷 push 는 default 브랜치 '${DEFAULT_BRANCH}' 에서만 허용됩니다." >&2
  echo "       '${DEFAULT_BRANCH}' 로 머지 후 그 브랜치에서 빌드하세요." >&2
  exit 1
fi
BUILD_DATE_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# 스냅샷 prefix — 같은 소스(같은 커밋)로 여러 변종 이미지를 같은 리포지토리에 push 할 때
# 스냅샷 태그가 서로 덮어쓰는 것을 막는다.
#   이 스크립트는 autoware 변종 전용이므로 **기본값 autoware** 를 쓴다.
#     → autoware-develop-20260801-abc1234
#   SNAP_PREFIX 를 명시하면 그 값이 우선한다. SNAP_PREFIX="" 로 강제로 없앨 수도 있다.
SNAP_PREFIX="${SNAP_PREFIX-autoware}"
SNAP_PREFIX="$(printf '%s' "${SNAP_PREFIX}" | sed 's/[^A-Za-z0-9._-]/-/g')"
SNAP="${SNAP_PREFIX:+${SNAP_PREFIX}-}${GIT_BRANCH}-$(date -u +%Y%m%d)-${GIT_SHORT}"

R="${REGISTRY}/${IMAGE}"
echo "=== rviz2 autoware build (arm64 native @ ${BOARD}) ==="
echo "    ${R}:${TAG}  +  ${R}:${SNAP}"

# OCI 표준 5종 + com.obigo 커스텀(유지 허용). 빌드 시 --label 로 주입.
LABELS=(
  --label "org.opencontainers.image.revision=${GIT_REV}"
  --label "org.opencontainers.image.source=github.com/obigo-gov/oss_hmi_app"
  --label "org.opencontainers.image.ref.name=${GIT_BRANCH}"
  --label "org.opencontainers.image.created=${BUILD_DATE_UTC}"
  --label "org.opencontainers.image.version=${SNAP}"
  --label "com.obigo.built-from-repo=oss_hmi_app"
  --label "com.obigo.built-from-path=apps/${CTX}/Dockerfile.autoware"
)

# ── 컨텍스트 전송(Dockerfile.autoware + entrypoint) → 보드 네이티브 빌드 → push ──────
$SSH "$BOARD" "mkdir -p '$BUILD_DIR'"
$SCP "$CTX/Dockerfile.autoware" "$CTX/entrypoint.sh" "$BOARD:$BUILD_DIR/"

# shellcheck disable=SC2029  # LABELS/변수는 로컬에서 확장해 원격에 전달(의도)
$SSH "$BOARD" "cd '$BUILD_DIR' && DOCKER_BUILDKIT=0 docker build -f Dockerfile.autoware \
  ${LABELS[*]} \
  -t '${R}:${TAG}' -t '${R}:${SNAP}' . \
  && docker push '${R}:${TAG}' \
  && docker push '${R}:${SNAP}'"

echo ""
echo "=== Done ==="
echo "  pushed: ${R}:${TAG}"
echo "  pushed: ${R}:${SNAP}"
echo "  labels: revision=${GIT_REV} ref.name=${GIT_BRANCH} version=${SNAP} created=${BUILD_DATE_UTC}"
echo "  확인:   docker image inspect ${R}:${TAG} -f '{{json .Config.Labels}}'"

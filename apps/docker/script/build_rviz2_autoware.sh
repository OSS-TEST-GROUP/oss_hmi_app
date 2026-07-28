#!/usr/bin/env bash
# build_rviz2_autoware.sh — rviz2 AGL "autoware" 변형 이미지 빌드+푸시.
#
# 통일 규약(RVIZ2_IMAGE_TAG_ALIGNMENT.md)을 적용한다:
#   - dirty 차단: 커밋 안 된 tracked 변경이 있으면 중단(untracked 빌드 산출물은 무시).
#   - 불변 스냅샷 태그: <branch>-<date(UTC)>-<shortsha>  (예: feature-rviz2-20260729-abc1234)
#   - :${TAG}(기본 latest) 와 스냅샷 태그를 함께 push.
#   - OCI 라벨 5종(--label) 을 빌드 스크립트에서 주입(Dockerfile ARG/LABEL 대신).
#
# ⚠️ multiarch 스크립트(build_rviz2_multiarch.sh)와 달리 이 이미지는 **arm64 전용**이고,
#    550MB autoware 오버레이 COPY + apt 라 QEMU 는 너무 느리다 → **Orin 보드에서 네이티브
#    빌드**한다(ssh/scp). 즉 로컬 buildx 가 아니라 원격 arm64 도커로 빌드/푸시한다.
#
# 전제:
#   - BOARD 에 docker + registry 로그인 완료(docker login registry.obigo.com -u ossuser).
#   - registry 에 autoware-overlay 이미지 존재(Dockerfile.autoware 의 COPY --from). 갱신은
#     RVIZ2_GUIDE.md 부록 B-5 참조(151 에서 슬림 오버레이 push).
#   - FROM 베이스 :touch 이미지가 BOARD 에 존재(build_rviz2_multiarch.sh 로 생성).
#
# 사용(oss_hmi_app 작업트리 내 어디서나):
#   apps/docker/script/build_rviz2_autoware.sh
#   TAG=verify BOARD=root@172.16.10.162 apps/docker/script/build_rviz2_autoware.sh
#
# Env: REGISTRY(registry.obigo.com) IMAGE(oss/rviz2-agl) TAG(latest)
#      BOARD(root@172.16.10.162) BUILD_DIR(보드 빌드 컨텍스트 경로)
set -euo pipefail

REGISTRY="${REGISTRY:-registry.obigo.com}"
IMAGE="${IMAGE:-oss/rviz2-agl}"
TAG="${TAG:-latest}"
BOARD="${BOARD:-root@172.16.10.162}"
BUILD_DIR="${BUILD_DIR:-/root/rviz2-autoware-build}"

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
BUILD_DATE_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SNAP="${GIT_BRANCH}-$(date -u +%Y%m%d)-${GIT_SHORT}"

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
ssh "$BOARD" "mkdir -p '$BUILD_DIR'"
scp "$CTX/Dockerfile.autoware" "$CTX/entrypoint.sh" "$BOARD:$BUILD_DIR/"

# shellcheck disable=SC2029  # LABELS/변수는 로컬에서 확장해 원격에 전달(의도)
ssh "$BOARD" "cd '$BUILD_DIR' && DOCKER_BUILDKIT=0 docker build -f Dockerfile.autoware \
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

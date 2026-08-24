#!/usr/bin/env bash
# Autoware 오버레이(/opt/autoware) 를 **rviz2 가 실제로 쓰는 것만** 남기고 줄인다.
#
# 손으로 만든 제외 목록은 파티션이 갱신될 때마다 어긋난다(예전 autoware-overlay 이미지의
# 실패 이유). 그래서 이 스크립트는 목록을 갖지 않고 **트리 자신에서 유도**한다:
#
#   1) 유지할 패키지 = rviz 플러그인 등록 패키지(ament_index/rviz_common__pluginlib__plugin)
#                    ∪ 메시지 패키지(ament_index/rosidl_interfaces)
#                    ∪ *_description (URDF 의 package:// 메시 해석 — 차량/센서 모델 표출)
#                    ∪ .rviz 설정을 담은 launch 패키지
#   2) 유지할 라이브러리 = 위 패키지의 .so 에서 시작해 **ldd 클로저**(트리 내부 의존만)
#   3) 버리는 것 = include/(헤더), 노드 실행 파일, 위 집합에 없는 패키지의 share/lib
#
# 파티션이 새 플러그인·새 msgs 를 추가하면 그것들이 자동으로 유지 집합에 들어온다.
#
# 사용법:  prune-autoware-overlay.sh [원본트리] [출력트리]      (기본 /opt/autoware → /out)
#          DRY_RUN=1 로 실행하면 복사 없이 크기만 계산한다.
set -euo pipefail

SRC="${1:-/opt/autoware}"
OUT="${2:-/out}"
DRY_RUN="${DRY_RUN:-0}"

RI="$SRC/share/ament_index/resource_index"
[ -d "$RI" ] || { echo "[ERROR] ament index 없음: $RI" >&2; exit 1; }

# ── 1) 유지 패키지 집합 ──────────────────────────────────────────────────────
keep_pkgs=$(
    {
        ls "$RI/rviz_common__pluginlib__plugin" 2>/dev/null || true   # rviz 플러그인
        ls "$RI/rosidl_interfaces"              2>/dev/null || true   # 메시지 타입
        ls "$SRC/share" | grep -E '_description$'                     # URDF/메시 자원
        ls "$SRC/share" | grep -E '_launch$'                          # .rviz 설정 보유
    } | sort -u
)
echo "[INFO] 유지 패키지: $(echo "$keep_pkgs" | wc -l) 개"

# ── 2) 유지 라이브러리: 시작 집합 → ldd 클로저 ───────────────────────────────
# 시작 집합 = 유지 패키지가 제공하는 .so (lib/lib<pkg>*.so 와 lib/<pkg>/*.so 양쪽 레이아웃)
tmp=$(mktemp -d)
: > "$tmp/seed"
while read -r p; do
    [ -n "$p" ] || continue
    find "$SRC/lib" -maxdepth 1 -name "lib${p}*.so*" >> "$tmp/seed" 2>/dev/null || true
    [ -d "$SRC/lib/$p" ] && find "$SRC/lib/$p" -name "*.so*" >> "$tmp/seed" 2>/dev/null || true
done <<< "$keep_pkgs"
sort -u "$tmp/seed" -o "$tmp/seed"
echo "[INFO] 시작 .so: $(wc -l < "$tmp/seed") 개"

# ldd 클로저 — 트리 안(SRC/lib) 의존만 따라간다. 트리 밖(/opt/ros, /usr/lib)은 이미지가 제공.
# ⚠️ **LD_LIBRARY_PATH 를 반드시 준다.** 없으면 트리 내부 의존이 "not found" 로 떠서 클로저가
#    한 건도 늘지 않고(실측 353→353), 남긴 플러그인이 런타임에 dlopen 실패한다.
#    "not found" 로 나온 soname 도 트리 안에 있으면 유지 대상으로 되살린다.
deps_of() {
    LD_LIBRARY_PATH="$SRC/lib" ldd "$1" 2>/dev/null | awk -v d="$SRC/lib" '
        $3 ~ "^"d       { print $3 }
        /=> not found/  { print d "/" $1 }'
}
cp "$tmp/seed" "$tmp/keep_so"
while :; do
    before=$(wc -l < "$tmp/keep_so")
    : > "$tmp/cand"
    while read -r so; do deps_of "$so" >> "$tmp/cand" || true; done < "$tmp/keep_so"
    # 실제로 존재하는 경로만 추가 (없는 soname 은 이미지 밖 의존 → 무시)
    sort -u "$tmp/cand" | while IFS= read -r cand; do
        if [ -e "$cand" ]; then echo "$cand"; fi
    done >> "$tmp/keep_so"
    sort -u "$tmp/keep_so" -o "$tmp/keep_so"
    [ "$(wc -l < "$tmp/keep_so")" -eq "$before" ] && break
done
echo "[INFO] ldd 클로저 후 .so: $(wc -l < "$tmp/keep_so") 개"

# ── 3) 크기 계산 / 복사 ─────────────────────────────────────────────────────
size_of() { du -sm "$@" 2>/dev/null | awk '{s+=$1} END {print s+0}'; }

share_keep=()
while read -r p; do
    [ -d "$SRC/share/$p" ] && share_keep+=("$SRC/share/$p")
done <<< "$keep_pkgs"

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY] 원본            : $(size_of "$SRC") MB"
    echo "[DRY] 유지 share      : $(size_of "${share_keep[@]}") MB"
    echo "[DRY] 유지 lib(.so)   : $(xargs -a "$tmp/keep_so" du -cm 2>/dev/null | tail -1 | cut -f1) MB"
    rm -rf "$tmp"
    exit 0
fi

# ⚠️ 여기서 share 하위를 미리 만들면 안 된다 — `cp -a src/share/ament_index $OUT/share/ament_index`
#    가 이미 존재하는 디렉토리 **안으로** 중첩 복사돼(ament_index/ament_index/…) 인덱스가
#    통째로 사라진다(실측: 플러그인 0개 인식).
mkdir -p "$OUT/lib" "$OUT/share"

# 3-a) 라이브러리 (심볼릭 링크 유지)
while read -r so; do
    rel="${so#$SRC/}"
    mkdir -p "$OUT/$(dirname "$rel")"
    cp -a "$so" "$OUT/$rel"
done < "$tmp/keep_so"

# 3-b) share — **패키지 디렉토리만 걸러내고 인프라 디렉토리는 그대로 둔다**.
#      패키지 목록의 정본은 `share/colcon-core/packages`(merged install 에서 colcon 의
#      _local_setup_util_sh.py 가 읽는 곳)다. 이 디렉토리를 버렸을 때 util 이 패키지를
#      0개로 보고 환경을 아예 만들지 않아 AMENT_PREFIX_PATH 에 트리가 등록되지 않았고,
#      rviz 가 Autoware 플러그인을 하나도 못 찾았다(실측).
pkg_index="$SRC/share/colcon-core/packages"
for d in "$SRC/share"/*; do
    name=$(basename "$d")
    if [ -e "$pkg_index/$name" ]; then
        # 패키지 → 유지 집합에만 포함
        grep -qxF "$name" <<< "$keep_pkgs" && cp -a "$d" "$OUT/share/$name"
    else
        # 인프라(ament_index, colcon-core …) → 유지, 내용은 아래에서 필터
        cp -a "$d" "$OUT/share/$name"
    fi
done
# colcon 패키지 목록도 유지 집합으로 줄인다(없는 패키지를 source 하려다 경고가 뜬다)
if [ -d "$OUT/share/colcon-core/packages" ]; then
    for f in "$OUT/share/colcon-core/packages"/*; do
        grep -qxF "$(basename "$f")" <<< "$keep_pkgs" || rm -f "$f"
    done
fi

# 3-c) ament index — 위에서 통째로 복사됐으므로 유지 집합 밖 항목만 지운다
#      (rviz 의 pluginlib 조회와 package:// 해석이 이 인덱스를 쓴다)
for kind in "$OUT/share/ament_index/resource_index"/*; do
    [ -d "$kind" ] || continue
    for f in "$kind"/*; do
        [ -e "$f" ] || continue
        grep -qxF "$(basename "$f")" <<< "$keep_pkgs" || rm -f "$f"
    done
done

# 3-c2) 파이썬 모듈 — `local/lib/python3.*/dist-packages/<pkg>` (유지 패키지만).
#      rviz2 자체는 C++ 타입서포트(.so)만 쓰므로 없어도 화면은 정상이다. 그런데 이게
#      빠지면 **컨테이너 안에서 ros2 CLI 가 Autoware 타입을 다루지 못한다**(실측:
#      `ros2 service call … autoware_adapi_v1_msgs/srv/…` → "The passed service type is
#      invalid", `ros2 topic echo /api/…` → 무응답). 보드에서 진단·자동화를 할 수 없게
#      되므로 유지 패키지의 파이썬 모듈만 남긴다(msgs 80 개 기준 수 MB 수준).
for _pydir in "$SRC"/local/lib/python3.*/dist-packages; do
    [ -d "$_pydir" ] || continue
    _rel="${_pydir#$SRC/}"
    mkdir -p "$OUT/$_rel"
    for _p in "$_pydir"/*; do
        _n=$(basename "$_p")
        # 패키지 디렉토리는 유지 집합만, 그 밖(.pth 등)은 그대로 둔다
        if [ -d "$_p" ]; then
            grep -qxF "$_n" <<< "$keep_pkgs" && cp -a "$_p" "$OUT/$_rel/$_n"
        else
            cp -a "$_p" "$OUT/$_rel/$_n"
        fi
    done
done

# 3-d) 최상위 파일 전부 (setup 스크립트 + 숨김 마커).
#      ⚠️ 목록으로 고르지 않는다 — `.colcon_install_layout`(내용 "merged") 하나가 빠졌을 때
#      colcon 의 local_setup 이 프리픽스를 등록하지 못해 AMENT_PREFIX_PATH 에 트리가 들어가지
#      않았고, rviz 가 Autoware 플러그인을 **하나도** 찾지 못했다(실측). 파일은 전부 가볍다.
find "$SRC" -maxdepth 1 -type f -exec cp -a {} "$OUT/" \;

echo "[INFO] 결과: $(size_of "$OUT") MB (원본 $(size_of "$SRC") MB)"
rm -rf "$tmp"

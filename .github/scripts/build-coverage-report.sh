#!/usr/bin/env bash
# 앱별 커버리지 artifact 들을 하나의 리포트 묶음으로 합친다.
#
# 사용: build-coverage-report.sh <cov-dir> <out-dir> <genhtml>
#   cov-dir : coverage-<app>/lcov.info 들이 있는 디렉토리
#             (actions/download-artifact 가 pattern: coverage-* 로 내려받은 모양)
#   out-dir : 결과를 쓸 디렉토리
#   genhtml : 사용할 genhtml 경로 (lcov 1.x — 2.0 은 브랜치를 못 담는다)
#
# 결과 구조:
#   <out-dir>/index.html        앱별 요약 + 각 리포트 링크 (랜딩)
#   <out-dir>/all/              전체 통합 리포트
#   <out-dir>/<app>/            앱별 리포트 (unit-test job 산출물 그대로)
#   <out-dir>/lcov/<app>.info   원본 lcov + merged.info
#
# 통합 리포트를 만들 때 SF 경로에 apps/<app>/ 를 붙인다. 앱마다 경로가
# lib/... 로 같아서 그대로 합치면 서로 덮어쓰기 때문이다. 리포지토리 루트에서
# 실행해야 genhtml 이 소스를 찾을 수 있다.
set -euo pipefail

COV_DIR=${1:?cov-dir}
OUT_DIR=${2:?out-dir}
GENHTML=${3:?genhtml}

mkdir -p "$OUT_DIR/lcov"
MERGED="$OUT_DIR/lcov/merged.info"
: > "$MERGED"

apps=()
for d in "$COV_DIR"/coverage-*; do
  [ -d "$d" ] || continue
  app=$(basename "$d"); app=${app#coverage-}
  # 'coverage-all' 은 이 job 이 만드는 집계 artifact 다. job 재실행 시 download
  # 패턴(coverage-*)이 그것까지 내려받으므로 앱으로 오인하지 않게 뺀다.
  [ "$app" = all ] && continue
  [ -f "$d/lcov.info" ] || { echo "::warning::$app: lcov.info 없음 — 건너뜀"; continue; }
  apps+=("$app")
  cp "$d/lcov.info" "$OUT_DIR/lcov/$app.info"
  sed "s#^SF:#SF:apps/$app/#" "$d/lcov.info" >> "$MERGED"
  if [ -d "$d/html" ]; then
    mkdir -p "$OUT_DIR/$app"
    cp -r "$d/html/." "$OUT_DIR/$app/"
  fi
done

if [ ${#apps[@]} -eq 0 ]; then
  echo "::error::커버리지 artifact 를 하나도 찾지 못했다"
  exit 1
fi

perl "$GENHTML" "$MERGED" -o "$OUT_DIR/all" \
  --branch-coverage --legend --title "HMI 전체 (자동생성 코드 제외)" >/dev/null

# lcov.info 하나의 라인/브랜치 비율을 "라인% 라인hit 라인total 브랜치% ..." 로 출력.
# BRDA(분기별)에서 직접 집계한다 — flutter 는 BRF/BRH 요약을 내보내지 않는다.
rates() {
  awk '
    /^LF:/   { split($0, a, ":"); lf += a[2] }
    /^LH:/   { split($0, a, ":"); lh += a[2] }
    /^BRDA:/ { brf++; split(substr($0, 6), b, ","); if (b[4] != "-" && b[4] != "0") brh++ }
    END {
      printf "%.1f %d %d %.1f %d %d\n",
        (lf ? lh * 100 / lf : 0), lh, lf, (brf ? brh * 100 / brf : 0), brh, brf
    }' "$1"
}

# 랜딩 페이지 + job summary 용 표를 함께 만든다.
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
{
  echo "### 커버리지 통합 (자동생성 코드 제외)"
  echo
  echo "| 앱 | 라인 | 브랜치 |"
  echo "|---|---|---|"
} >> "$SUMMARY"

{
  cat <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>HMI 커버리지 리포트</title>
<style>
  body { font: 14px/1.6 -apple-system, "Noto Sans KR", sans-serif; margin: 40px auto; max-width: 860px; color: #1a1a1a; }
  h1 { font-size: 22px; margin-bottom: 4px; }
  p.meta { color: #666; margin-top: 0; }
  table { border-collapse: collapse; width: 100%; margin: 20px 0; }
  th, td { padding: 8px 10px; border-bottom: 1px solid #e5e5e5; text-align: left; }
  th { background: #f7f7f7; font-weight: 600; }
  td.num { text-align: right; font-variant-numeric: tabular-nums; }
  tr.total td { font-weight: 700; border-top: 2px solid #999; }
  .low { color: #b00020; } .mid { color: #a06000; } .high { color: #0a7d3c; }
  a { color: #0b5fbf; }
  .note { color: #666; font-size: 13px; }
</style>
<h1>HMI 커버리지 리포트</h1>
<p class="meta">각 앱 리포트와 전체 통합 리포트. 자동생성 코드(protobuf/gRPC)는 분모에서 제외했다.</p>
<table>
<tr><th>앱</th><th>라인</th><th>브랜치</th><th>리포트</th></tr>
HTML

  cls() { awk -v r="$1" 'BEGIN { print (r < 75 ? "low" : (r < 90 ? "mid" : "high")) }'; }

  for app in "${apps[@]}"; do
    read -r lr lh lf br bh bf <<< "$(rates "$OUT_DIR/lcov/$app.info")"
    echo "<tr><td>$app</td>"
    echo "<td class=\"num $(cls "$lr")\">${lr}% <span class=note>($lh/$lf)</span></td>"
    echo "<td class=\"num $(cls "$br")\">${br}% <span class=note>($bh/$bf)</span></td>"
    echo "<td><a href=\"$app/index.html\">열기</a></td></tr>"
    echo "| $app | ${lr}% ($lh/$lf) | ${br}% ($bh/$bf) |" >> "$SUMMARY"
  done

  read -r lr lh lf br bh bf <<< "$(rates "$MERGED")"
  echo "<tr class=total><td>전체</td>"
  echo "<td class=\"num $(cls "$lr")\">${lr}% <span class=note>($lh/$lf)</span></td>"
  echo "<td class=\"num $(cls "$br")\">${br}% <span class=note>($bh/$bf)</span></td>"
  echo "<td><a href=\"all/index.html\">열기</a></td></tr>"
  echo "</table>"
  echo "<p class=note>Functions 열이 비어 있는 것은 정상이다 — dart/flutter 커버리지는 함수 단위 데이터를 생성하지 않는다.</p>"
  echo "<p class=note>원본 lcov 파일: <a href=\"lcov/\">lcov/</a></p>"
  echo "| **전체** | **${lr}% ($lh/$lf)** | **${br}% ($bh/$bf)** |" >> "$SUMMARY"
} > "$OUT_DIR/index.html"

echo "리포트 생성 완료: $OUT_DIR (앱 ${#apps[@]}개)"

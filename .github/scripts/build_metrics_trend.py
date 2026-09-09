#!/usr/bin/env python3
"""정적분석/커버리지 지표의 커밋별 추이 리포트를 만든다.

사용: build_metrics_trend.py <analyze-dir> <coverage-dir> <history.json> <out-dir>
                             [--append COMMIT DATE]

  analyze-dir  : analyze-all artifact 를 푼 디렉토리 (raw/<app>.txt 사용)
  coverage-dir : coverage-all artifact 를 푼 디렉토리 (lcov/<app>.info 사용)
  history.json : 누적 히스토리 (없으면 빈 히스토리로 시작)
  out-dir      : 리포트를 쓸 디렉토리
  --append     : 이 실행의 지표를 history.json 에 추가한다(develop 에서만 쓴다).
                 지정하지 않으면 히스토리는 건드리지 않고, 현재 값만 마지막
                 점으로 그려 넣는다 — feature 브랜치에서도 추이를 볼 수 있다.

GitHub Actions 에는 run 간 히스토리 보관이 없다(젠킨스 마스터와 다르다). 그래서
ci-metrics 브랜치의 이 파일이 유일한 저장소다.
"""
import html
import json
import math
import os
import re
import sys
from collections import Counter

ANALYZE_LINE = re.compile(r'^\[(?P<sev>\w+)\]')
SEV = ('error', 'warning', 'info')


# ── 지표 수집 ────────────────────────────────────────────────────────────
def analyze_counts(raw_dir):
    out = {}
    if not os.path.isdir(raw_dir):
        return out
    for fn in sorted(os.listdir(raw_dir)):
        if not fn.endswith('.txt'):
            continue
        app = fn[:-4]
        c = Counter()
        with open(os.path.join(raw_dir, fn), encoding='utf-8', errors='replace') as fh:
            for line in fh:
                m = ANALYZE_LINE.match(line.strip())
                if m:
                    c[m.group('sev').lower()] += 1
        out[app] = {s: c.get(s, 0) for s in SEV}
    return out


def lcov_rates(path):
    """lcov.info → (라인hit, 라인total, 브랜치hit, 브랜치total).

    flutter 는 BRF/BRH 요약을 내보내지 않으므로 BRDA 에서 직접 센다.
    """
    lh = lf = bh = bf = 0
    with open(path, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            if line.startswith('LF:'):
                lf += int(line[3:])
            elif line.startswith('LH:'):
                lh += int(line[3:])
            elif line.startswith('BRDA:'):
                bf += 1
                parts = line[5:].strip().split(',')
                if len(parts) >= 4 and parts[3] not in ('-', '0'):
                    bh += 1
    return lh, lf, bh, bf


def coverage_counts(lcov_dir):
    out = {}
    if not os.path.isdir(lcov_dir):
        return out
    for fn in sorted(os.listdir(lcov_dir)):
        if not fn.endswith('.info') or fn == 'merged.info':
            continue
        lh, lf, bh, bf = lcov_rates(os.path.join(lcov_dir, fn))
        out[fn[:-5]] = {'lh': lh, 'lf': lf, 'bh': bh, 'bf': bf}
    return out


def collect(analyze_dir, coverage_dir, commit, date):
    a = analyze_counts(os.path.join(analyze_dir, 'raw'))
    c = coverage_counts(os.path.join(coverage_dir, 'lcov'))
    apps = sorted(set(a) | set(c))
    rec = {'commit': commit, 'date': date, 'apps': {}}
    tot = Counter()
    for app in apps:
        e = dict(a.get(app, {s: 0 for s in SEV}))
        e.update(c.get(app, {'lh': 0, 'lf': 0, 'bh': 0, 'bf': 0}))
        rec['apps'][app] = e
        for k, v in e.items():
            tot[k] += v
    rec['total'] = dict(tot)
    return rec


# ── SVG 꺾은선 ───────────────────────────────────────────────────────────
def line_chart(series, records, y_max=None, y_suffix='', title='', integer=False):
    """series: [(라벨, 색, [값...])] — 값은 records 와 같은 길이.

    integer=True 면 y 축 눈금을 정수로 맞춘다. 이슈 개수처럼 값이 작은 정수일 때
    실수 눈금을 %.0f 로 찍으면 "1 1 1 0 0" 처럼 라벨이 중복된다.
    """
    W, H = 900, 260
    PAD_L, PAD_R, PAD_T, PAD_B = 52, 130, 18, 42
    pw, ph = W - PAD_L - PAD_R, H - PAD_T - PAD_B
    n = len(records)

    vals = [v for _, _, ys in series for v in ys if v is not None]
    if y_max is not None:
        top = y_max
    elif integer:
        # 눈금 5개(0..top, 4등분)가 모두 정수가 되도록 4의 배수로 올린다.
        top = max(4, math.ceil(max([*vals, 0]) * 1.15))
        top = math.ceil(top / 4) * 4
    else:
        top = max([*vals, 1]) * 1.15
    top = max(top, 1)

    def x(i):
        return PAD_L + (pw / 2 if n == 1 else pw * i / (n - 1))

    def y(v):
        return PAD_T + ph - (v / top) * ph

    p = [f'<svg viewBox="0 0 {W} {H}" width="100%" role="img" aria-label="{html.escape(title)}">']
    p.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="#fff"/>')
    # 가로 격자 + y 라벨
    for k in range(5):
        v = top * k / 4
        yy = y(v)
        p.append(f'<line x1="{PAD_L}" y1="{yy:.1f}" x2="{PAD_L + pw}" y2="{yy:.1f}" '
                 f'stroke="#eee" stroke-width="1"/>')
        p.append(f'<text x="{PAD_L - 8}" y="{yy + 4:.1f}" font-size="11" fill="#888" '
                 f'text-anchor="end">{v:.0f}{y_suffix}</text>')
    # x 라벨 (최대 8개만)
    step = max(1, n // 8)
    for i, r in enumerate(records):
        if i % step and i != n - 1:
            continue
        p.append(f'<text x="{x(i):.1f}" y="{PAD_T + ph + 16}" font-size="10" fill="#888" '
                 f'text-anchor="middle">{html.escape(r["commit"][:7])}</text>')
        p.append(f'<text x="{x(i):.1f}" y="{PAD_T + ph + 30}" font-size="9" fill="#bbb" '
                 f'text-anchor="middle">{html.escape(r["date"][5:10])}</text>')
    # 선 + 점
    for li, (label, color, ys) in enumerate(series):
        pts = [(x(i), y(v)) for i, v in enumerate(ys) if v is not None]
        if len(pts) > 1:
            d = ' '.join(f'{px:.1f},{py:.1f}' for px, py in pts)
            p.append(f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="2"/>')
        for px, py in pts:
            p.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="3" fill="{color}"/>')
        ly = PAD_T + 14 + li * 18
        p.append(f'<line x1="{PAD_L + pw + 14}" y1="{ly}" x2="{PAD_L + pw + 34}" y2="{ly}" '
                 f'stroke="{color}" stroke-width="2"/>')
        last = next((v for v in reversed(ys) if v is not None), None)
        shown = f'{last:.1f}{y_suffix}' if isinstance(last, float) else f'{last}{y_suffix}'
        p.append(f'<text x="{PAD_L + pw + 40}" y="{ly + 4}" font-size="11" fill="#333">'
                 f'{html.escape(label)} <tspan fill="#888">{shown}</tspan></text>')
    p.append('</svg>')
    return '\n'.join(p)


# ── 리포트 ──────────────────────────────────────────────────────────────
CSS = """
body { font: 14px/1.6 -apple-system, "Noto Sans KR", sans-serif; margin: 40px auto; max-width: 1000px; color: #1a1a1a; }
h1 { font-size: 22px; margin-bottom: 4px; } h2 { font-size: 16px; margin: 30px 0 6px; }
p.meta, .note { color: #666; } p.meta { margin-top: 0; } .note { font-size: 13px; }
table { border-collapse: collapse; width: 100%; margin: 14px 0; }
th, td { padding: 7px 10px; border-bottom: 1px solid #e5e5e5; text-align: left; }
th { background: #f7f7f7; font-weight: 600; }
td.num { text-align: right; font-variant-numeric: tabular-nums; }
tr.total td { font-weight: 700; border-top: 2px solid #999; }
.good { color: #0a7d3c; font-weight: 600; } .normal { color: #a06000; font-weight: 600; }
.bad { color: #b00020; font-weight: 600; }
figure { margin: 0; border: 1px solid #e5e5e5; border-radius: 6px; padding: 6px; }
"""


def health(line_pct, issues):
    """젠킨스 health report 흉내 — 기준은 팀에서 조정하면 된다."""
    if issues > 0 or line_pct < 60:
        return 'bad', '주의'
    if line_pct < 80:
        return 'normal', '보통'
    return 'good', '좋음'


def pct(hit, total):
    return (hit * 100 / total) if total else 0.0


def render(records, out_dir, appended):
    os.makedirs(out_dir, exist_ok=True)
    cur = records[-1]
    apps = sorted(cur['apps'])

    def tot_series(key):
        return [r['total'].get(key, 0) for r in records]

    analyze_svg = line_chart(
        [('error', '#b00020', tot_series('error')),
         ('warning', '#e08b00', tot_series('warning')),
         ('info', '#7a7a7a', tot_series('info'))],
        records, title='정적분석 이슈 추이', integer=True)

    cov_svg = line_chart(
        [('라인', '#0b5fbf', [pct(r['total'].get('lh', 0), r['total'].get('lf', 0)) for r in records]),
         ('브랜치', '#0a7d3c', [pct(r['total'].get('bh', 0), r['total'].get('bf', 0)) for r in records])],
        records, y_max=100, y_suffix='%', title='커버리지 추이')

    p = [
        '<!doctype html><meta charset="utf-8">',
        f'<title>HMI CI 지표 추이</title><style>{CSS}</style>',
        '<h1>HMI CI 지표 추이</h1>',
        f'<p class="meta">커밋 {len(records)}개 · 최신 <code>{html.escape(cur["commit"][:7])}</code>'
        f' ({html.escape(cur["date"])})'
        + ('' if appended else ' · <em>이번 실행은 히스토리에 적재하지 않았다(develop 머지 시에만 적재)</em>')
        + '</p>',
        '<h2>정적분석 이슈 (전체 합계)</h2>',
        f'<figure>{analyze_svg}</figure>',
        '<h2>커버리지 (전체 합계)</h2>',
        f'<figure>{cov_svg}</figure>',
        '<h2>최신 커밋 앱별 현황</h2>',
        '<table><tr><th>앱</th><th>error</th><th>warning</th><th>info</th>'
        '<th>라인</th><th>브랜치</th><th>상태</th></tr>',
    ]
    tt = Counter()
    for app in apps:
        e = cur['apps'][app]
        for k, v in e.items():
            tt[k] += v
        lp, bp = pct(e.get('lh', 0), e.get('lf', 0)), pct(e.get('bh', 0), e.get('bf', 0))
        cls, label = health(lp, sum(e.get(s, 0) for s in SEV))
        p.append(
            f'<tr><td>{html.escape(app)}</td>'
            + ''.join(f'<td class="num">{e.get(s, 0)}</td>' for s in SEV)
            + f'<td class="num">{lp:.1f}%</td><td class="num">{bp:.1f}%</td>'
            f'<td class="{cls}">{label}</td></tr>')
    lp, bp = pct(tt['lh'], tt['lf']), pct(tt['bh'], tt['bf'])
    cls, label = health(lp, sum(tt[s] for s in SEV))
    p.append('<tr class="total"><td>전체</td>'
             + ''.join(f'<td class="num">{tt[s]}</td>' for s in SEV)
             + f'<td class="num">{lp:.1f}%</td><td class="num">{bp:.1f}%</td>'
             f'<td class="{cls}">{label}</td></tr></table>')
    p.append('<p class="note">상태 기준: 이슈 0건 + 라인 80% 이상 = 좋음, 60% 이상 = 보통, '
             '그 외 = 주의. 기준은 이 스크립트의 health() 에서 조정한다.</p>')
    p.append('<p class="note">커버리지 분모는 자동생성 코드를 제외하며, 테스트가 import 하지 '
             '않은 파일은 집계에서 빠진다(ci.yml 주석 참고).</p>')
    with open(os.path.join(out_dir, 'index.html'), 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(p) + '\n')
    with open(os.path.join(out_dir, 'history.json'), 'w', encoding='utf-8') as fh:
        json.dump(records, fh, ensure_ascii=False, indent=1)


def main():
    args = sys.argv[1:]
    append = None
    if '--append' in args:
        i = args.index('--append')
        append = (args[i + 1], args[i + 2])
        args = args[:i] + args[i + 3:]
    analyze_dir, coverage_dir, hist_path, out_dir = args[:4]

    records = []
    if os.path.exists(hist_path):
        with open(hist_path, encoding='utf-8') as fh:
            try:
                records = json.load(fh)
            except json.JSONDecodeError:
                print(f'::warning::{hist_path} 를 읽을 수 없다 — 빈 히스토리로 시작한다')

    commit, date = append if append else (
        os.environ.get('GITHUB_SHA', 'local')[:40],
        os.environ.get('RUN_DATE', 'now'))
    rec = collect(analyze_dir, coverage_dir, commit, date)

    records = [r for r in records if r.get('commit') != rec['commit']]
    records.append(rec)
    render(records, out_dir, appended=bool(append))

    if append:
        with open(hist_path, 'w', encoding='utf-8') as fh:
            json.dump(records, fh, ensure_ascii=False, indent=1)
        print(f'히스토리 적재: {hist_path} (총 {len(records)}개 커밋)')
    else:
        print(f'추이 리포트 생성 (히스토리 미적재, 표시용 {len(records)}개 커밋)')

    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        t = rec['total']
        with open(summary, 'a', encoding='utf-8') as fh:
            fh.write('### CI 지표 추이\n\n')
            fh.write(f'커밋 {len(records)}개 누적. 최신 `{rec["commit"][:7]}`\n\n')
            fh.write('| 지표 | 값 |\n|---|---|\n')
            fh.write(f'| 정적분석 error / warning / info | {t.get("error",0)} / '
                     f'{t.get("warning",0)} / {t.get("info",0)} |\n')
            fh.write(f'| 라인 커버리지 | {pct(t.get("lh",0), t.get("lf",0)):.1f}% |\n')
            fh.write(f'| 브랜치 커버리지 | {pct(t.get("bh",0), t.get("bf",0)):.1f}% |\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())

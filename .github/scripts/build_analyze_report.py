#!/usr/bin/env python3
"""앱별 flutter analyze 결과를 하나의 리포트 묶음으로 합친다.

사용: build_analyze_report.py <in-dir> <out-dir>
  in-dir : analyze-<app>/analyze.txt 들이 있는 디렉토리
           (actions/download-artifact 가 pattern: analyze-* 로 내려받은 모양)
  out-dir: 결과를 쓸 디렉토리

`flutter analyze --write=<file>` 의 한 줄 형식:
    [severity] 메시지 (절대경로:줄:칸)
콘솔 출력과 달리 lint 룰 이름은 포함되지 않는다. 경로는 절대경로라 러너의
작업 디렉토리 접두어를 떼어 저장소 상대경로로 바꾼다.

결과 구조:
    <out-dir>/index.html      앱별 심각도 집계 + 링크 (랜딩)
    <out-dir>/<app>.html      앱별 이슈 목록 (파일별 그룹)
    <out-dir>/raw/<app>.txt   원본 출력
"""
import html
import os
import re
import sys
from collections import Counter, defaultdict

LINE = re.compile(r'^\[(?P<sev>\w+)\]\s+(?P<msg>.*?)\s+\((?P<path>[^()]+):(?P<line>\d+):(?P<col>\d+)\)\s*$')
SEVERITIES = ('error', 'warning', 'info')

CSS = """
body { font: 14px/1.6 -apple-system, "Noto Sans KR", sans-serif; margin: 40px auto; max-width: 1000px; color: #1a1a1a; }
h1 { font-size: 22px; margin-bottom: 4px; } h2 { font-size: 16px; margin-top: 28px; }
p.meta, .note { color: #666; } p.meta { margin-top: 0; } .note { font-size: 13px; }
table { border-collapse: collapse; width: 100%; margin: 18px 0; }
th, td { padding: 7px 10px; border-bottom: 1px solid #e5e5e5; text-align: left; vertical-align: top; }
th { background: #f7f7f7; font-weight: 600; }
td.num { text-align: right; font-variant-numeric: tabular-nums; }
tr.total td { font-weight: 700; border-top: 2px solid #999; }
.error { color: #b00020; font-weight: 600; } .warning { color: #a06000; } .info { color: #555; }
.zero { color: #0a7d3c; } a { color: #0b5fbf; } code { font-size: 13px; color: #333; }
"""


def parse(path):
    """analyze.txt → (이슈 리스트, 파싱 실패 줄 리스트)"""
    issues, unparsed = [], []
    if not os.path.exists(path):
        return issues, unparsed
    with open(path, encoding='utf-8', errors='replace') as fh:
        for raw in fh:
            raw = raw.rstrip('\n')
            if not raw.strip():
                continue
            m = LINE.match(raw)
            if not m:
                unparsed.append(raw)
                continue
            d = m.groupdict()
            issues.append({
                'sev': d['sev'].lower(),
                'msg': d['msg'],
                'path': d['path'],
                'line': int(d['line']),
                'col': int(d['col']),
            })
    return issues, unparsed


def trim(p, app):
    """절대경로를 apps/<app>/... 로 줄인다."""
    marker = f'/apps/{app}/'
    i = p.find(marker)
    return f'apps/{app}/' + p[i + len(marker):] if i >= 0 else p


def app_page(app, issues, unparsed, out_dir):
    by_file = defaultdict(list)
    for it in issues:
        by_file[it['path']].append(it)
    parts = [
        '<!doctype html><meta charset="utf-8">',
        f'<title>정적분석 — {html.escape(app)}</title><style>{CSS}</style>',
        f'<h1>정적분석 — {html.escape(app)}</h1>',
        '<p class="meta"><a href="index.html">← 전체 요약</a>'
        f' · 원본: <a href="raw/{html.escape(app)}.txt">analyze.txt</a></p>',
    ]
    if not issues:
        parts.append('<p class="zero"><strong>이슈 없음.</strong></p>')
    for f in sorted(by_file):
        items = sorted(by_file[f], key=lambda i: (i['line'], i['col']))
        parts.append(f'<h2><code>{html.escape(trim(f, app))}</code></h2>')
        parts.append('<table><tr><th>심각도</th><th>위치</th><th>메시지</th></tr>')
        for it in items:
            parts.append(
                f'<tr><td class="{it["sev"]}">{it["sev"]}</td>'
                f'<td><code>{it["line"]}:{it["col"]}</code></td>'
                f'<td>{html.escape(it["msg"])}</td></tr>')
        parts.append('</table>')
    if unparsed:
        parts.append('<h2>형식을 해석하지 못한 줄</h2><table>')
        for u in unparsed:
            parts.append(f'<tr><td><code>{html.escape(u)}</code></td></tr>')
        parts.append('</table>')
    with open(os.path.join(out_dir, f'{app}.html'), 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(parts) + '\n')


def main():
    in_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(os.path.join(out_dir, 'raw'), exist_ok=True)

    # 'analyze-all' 은 이 job 이 만드는 집계 artifact 다. job 을 재실행하면
    # download 패턴(analyze-*)이 그것까지 내려받으므로 앱으로 오인하지 않게 뺀다.
    apps = sorted(
        d[len('analyze-'):] for d in os.listdir(in_dir)
        if d.startswith('analyze-') and d != 'analyze-all'
        and os.path.isdir(os.path.join(in_dir, d)))
    if not apps:
        print('::error::정적분석 artifact 를 하나도 찾지 못했다', file=sys.stderr)
        return 1

    rows, totals, any_unparsed = [], Counter(), False
    for app in apps:
        src = os.path.join(in_dir, f'analyze-{app}', 'analyze.txt')
        issues, unparsed = parse(src)
        any_unparsed = any_unparsed or bool(unparsed)
        if os.path.exists(src):
            with open(src, encoding='utf-8', errors='replace') as s, \
                 open(os.path.join(out_dir, 'raw', f'{app}.txt'), 'w', encoding='utf-8') as d:
                d.write(s.read())
        c = Counter(i['sev'] for i in issues)
        totals.update(c)
        rows.append((app, c, len(issues)))
        app_page(app, issues, unparsed, out_dir)

    def cell(n):
        return f'<td class="num {"zero" if n == 0 else ""}">{n}</td>'

    parts = [
        '<!doctype html><meta charset="utf-8">',
        f'<title>HMI 정적분석 리포트</title><style>{CSS}</style>',
        '<h1>HMI 정적분석 리포트</h1>',
        '<p class="meta"><code>flutter analyze</code> 결과. 전 앱이 동일한 룰셋'
        '(<code>package:flutter_lints/flutter.yaml</code>)을 쓰므로 앱 간 비교가 가능하다.</p>',
        '<table><tr><th>앱</th><th>error</th><th>warning</th><th>info</th>'
        '<th>합계</th><th>상세</th></tr>',
    ]
    for app, c, n in rows:
        parts.append(
            f'<tr><td>{html.escape(app)}</td>'
            + ''.join(cell(c.get(s, 0)) for s in SEVERITIES)
            + cell(n)
            + f'<td><a href="{html.escape(app)}.html">열기</a></td></tr>')
    grand = sum(n for _, _, n in rows)
    parts.append(
        '<tr class="total"><td>전체</td>'
        + ''.join(cell(totals.get(s, 0)) for s in SEVERITIES)
        + cell(grand) + '<td></td></tr></table>')
    parts.append('<p class="note">error/warning 이 있으면 정적분석 job 이 실패한다. '
                 'info 는 실패시키지 않는다(fatal-infos 미사용).</p>')
    if any_unparsed:
        parts.append('<p class="note">일부 줄의 형식을 해석하지 못했다 — 앱 상세 페이지 하단 참고.</p>')
    with open(os.path.join(out_dir, 'index.html'), 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(parts) + '\n')

    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as fh:
            fh.write('### 정적분석 (flutter analyze)\n\n')
            fh.write('| 앱 | error | warning | info | 합계 |\n|---|---|---|---|---|\n')
            for app, c, n in rows:
                fh.write(f'| {app} | {c.get("error", 0)} | {c.get("warning", 0)} '
                         f'| {c.get("info", 0)} | {n} |\n')
            fh.write(f'| **전체** | **{totals.get("error", 0)}** | **{totals.get("warning", 0)}** '
                     f'| **{totals.get("info", 0)}** | **{grand}** |\n')

    print(f'정적분석 리포트 생성 완료: {out_dir} (앱 {len(apps)}개, 이슈 {grand}건)')
    return 0


if __name__ == '__main__':
    sys.exit(main())

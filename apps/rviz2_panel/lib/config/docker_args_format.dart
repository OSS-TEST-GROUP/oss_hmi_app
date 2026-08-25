/// `dockerRunArgs` 의 **화면 표현 ↔ 토큰 목록** 변환.
///
/// 파일에는 docker 가 받는 그대로 토큰이 하나씩 들어간다(`"--user", "1001:1001"`).
/// 화면에서는 그렇게 보이면 읽기 어려워서 **인자 하나가 한 줄**이 되도록 묶는다:
///
///     --net=host
///     --user 1001:1001
///     -e XDG_RUNTIME_DIR=/host-xdg
///
/// 왕복(text → args → text)이 안정적이어야 저장·재진입이 값을 흔들지 않는다.
library;

/// 토큰 목록 → 화면 텍스트. 플래그 뒤에 값이 오면 한 줄로 묶는다.
String dockerArgsToText(List<String> args) {
  final lines = <String>[];
  for (var i = 0; i < args.length; i++) {
    final tok = args[i];
    final next = i + 1 < args.length ? args[i + 1] : null;
    if (tok.startsWith('-') && next != null && !next.startsWith('-')) {
      lines.add('$tok $next');
      i++;
    } else {
      lines.add(tok);
    }
  }
  return lines.join('\n');
}

/// 화면 텍스트 → 토큰 목록. 줄 안의 공백이 토큰 경계다.
List<String> dockerArgsFromText(String text) => text
    .split('\n')
    .expand((line) => line.trim().split(RegExp(r'\s+')))
    .where((t) => t.isNotEmpty)
    .toList();

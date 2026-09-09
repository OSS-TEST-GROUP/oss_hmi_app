// QA(docs/qa): HangulComposer 미커버 분기 — 초+초, bare vowel, 결합불가 모음, 복합모음 백스페이스.
import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/presentation/keyboard/hangul_composer.dart';

void main() {
  test('초성+초성(모음 없이): 앞 자음 확정 후 새로 시작', () {
    final c = HangulComposer();
    var r = c.feed('ㄱ');
    expect(r.composing, 'ㄱ');
    r = c.feed('ㄴ'); // 초 다음 초 → ㄱ 확정, ㄴ 시작
    expect(r.committed, 'ㄱ');
    expect(r.composing, 'ㄴ');
  });

  test('bare vowel: 초성 없이 모음 입력 → 그대로 방출', () {
    final c = HangulComposer();
    final r = c.feed('ㅏ');
    expect(r.committed, 'ㅏ');
    expect(r.composing, '');
    expect(c.isComposing, isFalse);
  });

  test('완성 음절 뒤 결합 불가 모음 → 음절 확정 + 모음 방출', () {
    final c = HangulComposer();
    c.feed('ㄱ');
    c.feed('ㅏ'); // 가
    final r = c.feed('ㅓ'); // ㅏ+ㅓ 결합 불가
    expect(r.committed, contains('가'));
    expect(r.committed, contains('ㅓ'));
  });

  test('복합모음 백스페이스: ㅘ → ㅗ 로 peel', () {
    final c = HangulComposer();
    c.feed('ㄱ');
    c.feed('ㅗ');
    c.feed('ㅏ'); // ㅗ+ㅏ = ㅘ → 과
    expect(c.current, '과');
    final r = c.backspace();
    expect(r.composing, '고'); // ㅘ→ㅗ
  });

  test('HangulResult.toString 은 committed/composing 포함', () {
    const r = HangulResult('가', '나');
    expect(r.toString(), contains('가'));
    expect(r.toString(), contains('나'));
  });

  test('commit / reset 상태 정리', () {
    final c = HangulComposer();
    c.feed('ㅎ');
    c.feed('ㅏ');
    expect(c.commit(), '하');
    expect(c.isComposing, isFalse);
    c.feed('ㅁ');
    c.reset();
    expect(c.isComposing, isFalse);
  });
}

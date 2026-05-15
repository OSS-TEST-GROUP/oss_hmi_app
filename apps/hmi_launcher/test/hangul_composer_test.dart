import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/presentation/keyboard/hangul_composer.dart';

String _feedAll(HangulComposer c, List<String> jamos) {
  final buf = StringBuffer();
  for (final j in jamos) {
    final r = c.feed(j);
    buf.write(r.committed);
  }
  return buf.toString() + c.current;
}

void main() {
  group('HangulComposer.feed', () {
    test('초 + 중 → full syllable', () {
      final c = HangulComposer();
      expect(_feedAll(c, ['ㅎ', 'ㅏ']), '하');
    });

    test('초 + 중 + 종 → completed syllable', () {
      final c = HangulComposer();
      expect(_feedAll(c, ['ㅎ', 'ㅏ', 'ㄴ']), '한');
    });

    test('"한글" (two syllables with 자음 넘김 not involved)', () {
      final c = HangulComposer();
      expect(_feedAll(c, ['ㅎ', 'ㅏ', 'ㄴ', 'ㄱ', 'ㅡ', 'ㄹ']), '한글');
    });

    test('compound vowel: ㅗ + ㅏ → ㅘ (so 고 + ㅏ → 과)', () {
      final c = HangulComposer();
      expect(_feedAll(c, ['ㄱ', 'ㅗ', 'ㅏ']), '과');
    });

    test('compound final: ㄹ + ㄱ → ㄺ (ㄹ is final then ㄱ joins)', () {
      final c = HangulComposer();
      expect(_feedAll(c, ['ㄷ', 'ㅏ', 'ㄹ', 'ㄱ']), '닭');
    });

    test('자음 넘김: 앉 + ㅏ → 안자 (compound jong splits)', () {
      final c = HangulComposer();
      expect(
        _feedAll(c, ['ㅇ', 'ㅏ', 'ㄴ', 'ㅈ', 'ㅏ']),
        '안자',
      );
    });

    test('자음 넘김: 한 + ㅏ → 하나 (simple jong moves)', () {
      final c = HangulComposer();
      expect(_feedAll(c, ['ㅎ', 'ㅏ', 'ㄴ', 'ㅏ']), '하나');
    });

    test('double consonant that cannot be jong flushes syllable', () {
      // 가 + ㄸ → commit 가, start new cho ㄸ. Then ㅏ completes 따.
      final c = HangulComposer();
      expect(_feedAll(c, ['ㄱ', 'ㅏ', 'ㄸ', 'ㅏ']), '가따');
    });

    test('non-jamo input flushes syllable and emits raw', () {
      final c = HangulComposer();
      final before = _feedAll(c, ['ㅎ', 'ㅏ']);
      expect(before, '하');
      final r = c.feed(' ');
      expect(r.committed, '하 ');
      expect(r.composing, '');
      expect(c.isComposing, isFalse);
    });
  });

  group('HangulComposer.backspace', () {
    test('peels jong, then jung, then cho', () {
      final c = HangulComposer();
      _feedAll(c, ['ㅎ', 'ㅏ', 'ㄴ']); // 한
      expect(c.current, '한');

      c.backspace();
      expect(c.current, '하');

      c.backspace();
      expect(c.current, 'ㅎ');

      c.backspace();
      expect(c.current, '');
      expect(c.isComposing, isFalse);
    });

    test('peels a compound jong back to its head', () {
      final c = HangulComposer();
      _feedAll(c, ['ㄷ', 'ㅏ', 'ㄹ', 'ㄱ']); // 닭 (ㄺ)
      expect(c.current, '닭');

      c.backspace();
      expect(c.current, '달');
    });

    test('peels a compound vowel back to its head', () {
      final c = HangulComposer();
      _feedAll(c, ['ㄱ', 'ㅗ', 'ㅏ']); // 과 (ㅘ)
      expect(c.current, '과');

      c.backspace();
      expect(c.current, '고');
    });
  });

  group('HangulComposer.commit', () {
    test('returns the current syllable and clears state', () {
      final c = HangulComposer();
      _feedAll(c, ['ㅎ', 'ㅏ']);
      expect(c.commit(), '하');
      expect(c.isComposing, isFalse);
      expect(c.current, '');
    });
  });
}

/// Finite state machine that assembles Hangul syllables from 두벌식 jamo
/// inputs.
///
/// Callers feed one compatibility jamo at a time via [feed]. The composer
/// tracks the in-progress syllable (초성 / 중성 / 종성) and returns a
/// [HangulResult] describing which characters should be committed to the
/// left of the composing position and which single character is the new
/// syllable under construction.
///
/// The implementation follows standard Korean IME behaviour:
///   - Vowels combine (ㅗ+ㅏ → ㅘ) and consonants combine in final
///     position (ㄹ+ㄱ → ㄺ).
///   - When a vowel arrives while a 종성 is set, the jong is split and
///     its tail moves to become the 초성 of a new syllable ("자음 넘김").
///   - [backspace] peels one jamo level at a time during composition.
class HangulComposer {
  // ── Compatibility jamo index tables ─────────────────────────────
  static const List<String> _cho = [
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
    'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
  ];
  static const List<String> _jung = [
    'ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ',
    'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ',
    'ㅣ',
  ];
  static const List<String> _jong = [
    '', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ',
    'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ',
    'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
  ];

  // Compound vowels: (first jung, trailing jung) → combined jung char.
  static const Map<String, Map<String, String>> _jungCombine = {
    'ㅗ': {'ㅏ': 'ㅘ', 'ㅐ': 'ㅙ', 'ㅣ': 'ㅚ'},
    'ㅜ': {'ㅓ': 'ㅝ', 'ㅔ': 'ㅞ', 'ㅣ': 'ㅟ'},
    'ㅡ': {'ㅣ': 'ㅢ'},
  };

  // Compound finals: (first jong, trailing consonant) → combined jong.
  static const Map<String, Map<String, String>> _jongCombine = {
    'ㄱ': {'ㅅ': 'ㄳ'},
    'ㄴ': {'ㅈ': 'ㄵ', 'ㅎ': 'ㄶ'},
    'ㄹ': {
      'ㄱ': 'ㄺ', 'ㅁ': 'ㄻ', 'ㅂ': 'ㄼ', 'ㅅ': 'ㄽ',
      'ㅌ': 'ㄾ', 'ㅍ': 'ㄿ', 'ㅎ': 'ㅀ',
    },
    'ㅂ': {'ㅅ': 'ㅄ'},
  };

  // When a vowel arrives while a compound jong is set, the trailing
  // consonant is peeled off and moves to the new syllable's 초성 — the
  // map records how to split each compound jong back into a stay/move
  // pair.
  static const Map<String, List<String>> _jongSplit = {
    'ㄳ': ['ㄱ', 'ㅅ'],
    'ㄵ': ['ㄴ', 'ㅈ'],
    'ㄶ': ['ㄴ', 'ㅎ'],
    'ㄺ': ['ㄹ', 'ㄱ'],
    'ㄻ': ['ㄹ', 'ㅁ'],
    'ㄼ': ['ㄹ', 'ㅂ'],
    'ㄽ': ['ㄹ', 'ㅅ'],
    'ㄾ': ['ㄹ', 'ㅌ'],
    'ㄿ': ['ㄹ', 'ㅍ'],
    'ㅀ': ['ㄹ', 'ㅎ'],
    'ㅄ': ['ㅂ', 'ㅅ'],
  };

  int? _choIdx;
  int? _jungIdx;
  int _jongIdx = 0;

  bool get isComposing => _choIdx != null || _jungIdx != null;

  /// The single syllable (or bare jamo) currently under construction.
  /// Empty when no composition is active.
  String get current {
    if (_choIdx != null && _jungIdx != null) {
      return String.fromCharCode(
        0xAC00 + _choIdx! * 588 + _jungIdx! * 28 + _jongIdx,
      );
    }
    if (_choIdx != null) return _cho[_choIdx!];
    if (_jungIdx != null) return _jung[_jungIdx!];
    return '';
  }

  /// Feed one compatibility jamo into the composer.
  HangulResult feed(String jamo) {
    if (_isChoJamo(jamo)) return _feedConsonant(jamo);
    if (_jung.contains(jamo)) return _feedVowel(jamo);
    // Non-Hangul input flushes the syllable then emits the raw character.
    final flushed = current;
    _reset();
    return HangulResult(flushed + jamo, '');
  }

  HangulResult _feedConsonant(String jamo) {
    if (_choIdx == null) {
      _choIdx = _cho.indexOf(jamo);
      return HangulResult('', current);
    }
    if (_jungIdx == null) {
      // 초 + 초: commit the standalone 초 and start fresh.
      final committed = current;
      _reset();
      _choIdx = _cho.indexOf(jamo);
      return HangulResult(committed, current);
    }
    if (_jongIdx == 0) {
      final asJong = _jong.indexOf(jamo);
      if (asJong > 0) {
        _jongIdx = asJong;
        return HangulResult('', current);
      }
      // Jamo can't be a jong (e.g. ㄸ/ㅃ/ㅉ). Flush and restart.
      final committed = current;
      _reset();
      _choIdx = _cho.indexOf(jamo);
      return HangulResult(committed, current);
    }
    // 초+중+종: try compound jong.
    final currentJong = _jong[_jongIdx];
    final compound = _jongCombine[currentJong]?[jamo];
    if (compound != null) {
      _jongIdx = _jong.indexOf(compound);
      return HangulResult('', current);
    }
    final committed = current;
    _reset();
    _choIdx = _cho.indexOf(jamo);
    return HangulResult(committed, current);
  }

  HangulResult _feedVowel(String jamo) {
    if (_choIdx == null && _jungIdx == null) {
      // Bare vowel — no syllable forms, emit as standalone.
      return HangulResult(jamo, '');
    }
    if (_choIdx != null && _jungIdx == null) {
      _jungIdx = _jung.indexOf(jamo);
      return HangulResult('', current);
    }
    if (_jongIdx == 0) {
      final currentJung = _jung[_jungIdx!];
      final compound = _jungCombine[currentJung]?[jamo];
      if (compound != null) {
        _jungIdx = _jung.indexOf(compound);
        return HangulResult('', current);
      }
      // Vowel after a complete 초+중 that can't combine: flush and emit
      // the trailing vowel as a standalone jamo.
      final committed = current;
      _reset();
      return HangulResult(committed + jamo, '');
    }
    // 자음 넘김: the last segment of the 종성 jumps to be the 초성 of a
    // new syllable built with this vowel.
    final jongStr = _jong[_jongIdx];
    final split = _jongSplit[jongStr];
    final stayJong = split != null ? split[0] : '';
    final moveCho = split != null ? split[1] : jongStr;
    _jongIdx = stayJong.isEmpty ? 0 : _jong.indexOf(stayJong);
    final committed = current;
    _choIdx = _cho.indexOf(moveCho);
    _jungIdx = _jung.indexOf(jamo);
    _jongIdx = 0;
    return HangulResult(committed, current);
  }

  /// Remove one jamo from the current composition. Returns a result so
  /// callers can redraw the composing char identically to [feed]. When no
  /// composition is active, returns an empty result and the caller should
  /// fall back to a regular delete.
  HangulResult backspace() {
    if (!isComposing) return const HangulResult('', '');
    if (_jongIdx > 0) {
      final jongStr = _jong[_jongIdx];
      final split = _jongSplit[jongStr];
      _jongIdx = split != null ? _jong.indexOf(split[0]) : 0;
      return HangulResult('', current);
    }
    if (_jungIdx != null) {
      final jungStr = _jung[_jungIdx!];
      final head = _firstPartOfCompoundJung(jungStr);
      _jungIdx = head == null ? null : _jung.indexOf(head);
      return HangulResult('', current);
    }
    _choIdx = null;
    return const HangulResult('', '');
  }

  /// Finalise the pending syllable. Returns the text that was on screen
  /// (the caller may or may not need to re-insert it — in practice the
  /// composing glyph already sits in the buffer, so this only resets
  /// internal state).
  String commit() {
    final s = current;
    _reset();
    return s;
  }

  void reset() => _reset();

  void _reset() {
    _choIdx = null;
    _jungIdx = null;
    _jongIdx = 0;
  }

  // ── Helpers ─────────────────────────────────────────────────────

  static bool _isChoJamo(String j) => _cho.contains(j);

  static String? _firstPartOfCompoundJung(String jung) {
    for (final head in _jungCombine.keys) {
      final combos = _jungCombine[head]!;
      for (final entry in combos.entries) {
        if (entry.value == jung) return head;
      }
    }
    // Not compound — collapse to nothing (caller treats as "jung removed").
    return null;
  }
}

/// The outcome of feeding a single jamo into [HangulComposer].
class HangulResult {
  const HangulResult(this.committed, this.composing);

  /// Text that should land immediately before the composing position —
  /// syllables that were finalised by this step.
  final String committed;

  /// The current in-progress syllable (zero or one character).
  final String composing;

  @override
  String toString() =>
      'HangulResult(committed="$committed", composing="$composing")';
}

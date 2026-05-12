import 'package:flutter/material.dart';

typedef VirtualKeyboardTextEdit =
    void Function(String value, {int replaceBackCount});

class VirtualKeyboard extends StatefulWidget {
  const VirtualKeyboard({
    super.key,
    required this.onTextInput,
    required this.onBackspace,
    required this.onSpace,
    required this.onHide,
    required this.onSubmit,
  });

  final VirtualKeyboardTextEdit onTextInput;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final VoidCallback onHide;
  final VoidCallback onSubmit;

  @override
  State<VirtualKeyboard> createState() => _VirtualKeyboardState();
}

class _VirtualKeyboardState extends State<VirtualKeyboard> {
  bool _shiftEnabled = false;
  bool _koreanEnabled = true;
  bool _symbolsEnabled = false;
  final _hangulComposer = _HangulComposer();

  static const List<List<_KeyboardKeyValue>> _englishRows = [
    [
      _KeyboardKeyValue(normal: 'q', shifted: 'Q'),
      _KeyboardKeyValue(normal: 'w', shifted: 'W'),
      _KeyboardKeyValue(normal: 'e', shifted: 'E'),
      _KeyboardKeyValue(normal: 'r', shifted: 'R'),
      _KeyboardKeyValue(normal: 't', shifted: 'T'),
      _KeyboardKeyValue(normal: 'y', shifted: 'Y'),
      _KeyboardKeyValue(normal: 'u', shifted: 'U'),
      _KeyboardKeyValue(normal: 'i', shifted: 'I'),
      _KeyboardKeyValue(normal: 'o', shifted: 'O'),
      _KeyboardKeyValue(normal: 'p', shifted: 'P'),
    ],
    [
      _KeyboardKeyValue(normal: 'a', shifted: 'A'),
      _KeyboardKeyValue(normal: 's', shifted: 'S'),
      _KeyboardKeyValue(normal: 'd', shifted: 'D'),
      _KeyboardKeyValue(normal: 'f', shifted: 'F'),
      _KeyboardKeyValue(normal: 'g', shifted: 'G'),
      _KeyboardKeyValue(normal: 'h', shifted: 'H'),
      _KeyboardKeyValue(normal: 'j', shifted: 'J'),
      _KeyboardKeyValue(normal: 'k', shifted: 'K'),
      _KeyboardKeyValue(normal: 'l', shifted: 'L'),
    ],
    [
      _KeyboardKeyValue(normal: 'z', shifted: 'Z'),
      _KeyboardKeyValue(normal: 'x', shifted: 'X'),
      _KeyboardKeyValue(normal: 'c', shifted: 'C'),
      _KeyboardKeyValue(normal: 'v', shifted: 'V'),
      _KeyboardKeyValue(normal: 'b', shifted: 'B'),
      _KeyboardKeyValue(normal: 'n', shifted: 'N'),
      _KeyboardKeyValue(normal: 'm', shifted: 'M'),
    ],
  ];

  static const List<List<_KeyboardKeyValue>> _koreanRows = [
    [
      _KoreanKey(normal: 'ㅂ', shifted: 'ㅃ'),
      _KoreanKey(normal: 'ㅈ', shifted: 'ㅉ'),
      _KoreanKey(normal: 'ㄷ', shifted: 'ㄸ'),
      _KoreanKey(normal: 'ㄱ', shifted: 'ㄲ'),
      _KoreanKey(normal: 'ㅅ', shifted: 'ㅆ'),
      _KoreanKey(normal: 'ㅛ'),
      _KoreanKey(normal: 'ㅕ'),
      _KoreanKey(normal: 'ㅑ'),
      _KoreanKey(normal: 'ㅐ', shifted: 'ㅒ'),
      _KoreanKey(normal: 'ㅔ', shifted: 'ㅖ'),
    ],
    [
      _KoreanKey(normal: 'ㅁ'),
      _KoreanKey(normal: 'ㄴ'),
      _KoreanKey(normal: 'ㅇ'),
      _KoreanKey(normal: 'ㄹ'),
      _KoreanKey(normal: 'ㅎ'),
      _KoreanKey(normal: 'ㅗ'),
      _KoreanKey(normal: 'ㅓ'),
      _KoreanKey(normal: 'ㅏ'),
      _KoreanKey(normal: 'ㅣ'),
    ],
    [
      _KoreanKey(normal: 'ㅋ'),
      _KoreanKey(normal: 'ㅌ'),
      _KoreanKey(normal: 'ㅊ'),
      _KoreanKey(normal: 'ㅍ'),
      _KoreanKey(normal: 'ㅠ'),
      _KoreanKey(normal: 'ㅜ'),
      _KoreanKey(normal: 'ㅡ'),
    ],
  ];

  static const List<List<_KeyboardKeyValue>> _symbolRows = [
    [
      _KeyboardKeyValue(normal: '1', shifted: '!'),
      _KeyboardKeyValue(normal: '2', shifted: '@'),
      _KeyboardKeyValue(normal: '3', shifted: '#'),
      _KeyboardKeyValue(normal: '4', shifted: r'$'),
      _KeyboardKeyValue(normal: '5', shifted: '%'),
      _KeyboardKeyValue(normal: '6', shifted: '^'),
      _KeyboardKeyValue(normal: '7', shifted: '&'),
      _KeyboardKeyValue(normal: '8', shifted: '*'),
      _KeyboardKeyValue(normal: '9', shifted: '('),
      _KeyboardKeyValue(normal: '0', shifted: ')'),
    ],
    [
      _KeyboardKeyValue(normal: '-', shifted: '_'),
      _KeyboardKeyValue(normal: '/', shifted: r'\'),
      _KeyboardKeyValue(normal: ':', shifted: ';'),
      _KeyboardKeyValue(normal: "'", shifted: '"'),
      _KeyboardKeyValue(normal: '(', shifted: '['),
      _KeyboardKeyValue(normal: ')', shifted: ']'),
      _KeyboardKeyValue(normal: '?', shifted: '¿'),
      _KeyboardKeyValue(normal: '+', shifted: '='),
      _KeyboardKeyValue(normal: '.', shifted: ','),
    ],
    [
      _KeyboardKeyValue(normal: '~', shifted: '`'),
      _KeyboardKeyValue(normal: '<', shifted: '{'),
      _KeyboardKeyValue(normal: '>', shifted: '}'),
      _KeyboardKeyValue(normal: '₩', shifted: '|'),
      _KeyboardKeyValue(normal: '·', shifted: '•'),
      _KeyboardKeyValue(normal: '!', shifted: '¡'),
      _KeyboardKeyValue(normal: ',', shifted: '.'),
    ],
  ];

  static const List<String> _commandWords = [
    '앱',
    '실행',
    '열어줘',
    '내비',
    '뮤직',
    '전화',
    '집',
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 900;
    final rows = _symbolsEnabled
        ? _symbolRows
        : _koreanEnabled
        ? _koreanRows
        : _englishRows;

    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16,
          compact ? 12 : 16,
          compact ? 12 : 16,
          compact ? 12 : 16,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD0D1D2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commandWords
                  .map(
                    (word) => _ActionKey(
                      label: word,
                      onTap: () {
                        _hangulComposer.reset();
                        widget.onTextInput(word);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: row
                      .map(
                        (key) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _KeyButton(
                              label: _keyLabel(key),
                              onTap: () {
                                _handleCharacterInput(_keyValue(key));
                                if (_shiftEnabled) {
                                  setState(() {
                                    _shiftEnabled = false;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  flex: compact ? 2 : 1,
                  child: _KeyButton(
                    label: _languageLabel,
                    onTap: () {
                      _hangulComposer.reset();
                      setState(() {
                        _symbolsEnabled = false;
                        _koreanEnabled = !_koreanEnabled;
                        _shiftEnabled = false;
                      });
                    },
                    accent: const Color(0xFFEEEEEE),
                    foreground: const Color(0xFF171A20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: compact ? 2 : 1,
                  child: _KeyButton(
                    label: _symbolsEnabled ? 'ABC' : '#+=',
                    onTap: () {
                      _hangulComposer.reset();
                      setState(() {
                        _symbolsEnabled = !_symbolsEnabled;
                        _shiftEnabled = false;
                      });
                    },
                    accent: const Color(0xFFEEEEEE),
                    foreground: const Color(0xFF171A20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: compact ? 2 : 1,
                  child: _KeyButton(
                    label: _shiftEnabled ? '⇧' : 'SHIFT',
                    onTap: () {
                      setState(() {
                        _shiftEnabled = !_shiftEnabled;
                      });
                    },
                    accent: const Color(0xFFEEEEEE),
                    foreground: const Color(0xFF171A20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: _KeyButton(
                    label: 'SPACE',
                    onTap: () {
                      _hangulComposer.reset();
                      widget.onSpace();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: compact ? 2 : 1,
                  child: _KeyButton(
                    label: '⌫',
                    onTap: _handleBackspace,
                    accent: const Color(0xFFEEEEEE),
                    foreground: const Color(0xFF171A20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _KeyButton(
                    label: 'HIDE',
                    onTap: () {
                      _hangulComposer.reset();
                      widget.onHide();
                    },
                    accent: const Color(0xFFEEEEEE),
                    foreground: const Color(0xFF393C41),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KeyButton(
                    label: 'SEND',
                    onTap: () {
                      _hangulComposer.reset();
                      widget.onSubmit();
                    },
                    accent: const Color(0xFF3E6AE1),
                    foreground: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _keyLabel(_KeyboardKeyValue key) =>
      _shiftEnabled ? key.shifted : key.normal;

  String _keyValue(_KeyboardKeyValue key) =>
      _shiftEnabled ? key.shifted : key.normal;

  String get _languageLabel {
    if (_symbolsEnabled) {
      return _koreanEnabled ? '한글' : 'ENG';
    }
    return _koreanEnabled ? '한글' : 'ENG';
  }

  void _handleCharacterInput(String value) {
    if (_symbolsEnabled || !_koreanEnabled) {
      _hangulComposer.reset();
      widget.onTextInput(value);
      return;
    }

    final edit = _hangulComposer.input(value);
    widget.onTextInput(edit.text, replaceBackCount: edit.replaceBackCount);
  }

  void _handleBackspace() {
    if (_koreanEnabled) {
      final edit = _hangulComposer.backspace();
      if (edit != null) {
        widget.onTextInput(edit.text, replaceBackCount: edit.replaceBackCount);
        return;
      }
    }

    _hangulComposer.reset();
    widget.onBackspace();
  }
}

class _KeyboardKeyValue {
  const _KeyboardKeyValue({required this.normal, String? shifted})
    : shifted = shifted ?? normal;

  final String normal;
  final String shifted;
}

class _KoreanKey extends _KeyboardKeyValue {
  const _KoreanKey({required super.normal, super.shifted});
}

class _TextEdit {
  const _TextEdit(this.text, this.replaceBackCount);

  final String text;
  final int replaceBackCount;
}

class _HangulComposer {
  static const _choseong = [
    'ㄱ',
    'ㄲ',
    'ㄴ',
    'ㄷ',
    'ㄸ',
    'ㄹ',
    'ㅁ',
    'ㅂ',
    'ㅃ',
    'ㅅ',
    'ㅆ',
    'ㅇ',
    'ㅈ',
    'ㅉ',
    'ㅊ',
    'ㅋ',
    'ㅌ',
    'ㅍ',
    'ㅎ',
  ];

  static const _jungseong = [
    'ㅏ',
    'ㅐ',
    'ㅑ',
    'ㅒ',
    'ㅓ',
    'ㅔ',
    'ㅕ',
    'ㅖ',
    'ㅗ',
    'ㅘ',
    'ㅙ',
    'ㅚ',
    'ㅛ',
    'ㅜ',
    'ㅝ',
    'ㅞ',
    'ㅟ',
    'ㅠ',
    'ㅡ',
    'ㅢ',
    'ㅣ',
  ];

  static const _jongseong = [
    '',
    'ㄱ',
    'ㄲ',
    'ㄳ',
    'ㄴ',
    'ㄵ',
    'ㄶ',
    'ㄷ',
    'ㄹ',
    'ㄺ',
    'ㄻ',
    'ㄼ',
    'ㄽ',
    'ㄾ',
    'ㄿ',
    'ㅀ',
    'ㅁ',
    'ㅂ',
    'ㅄ',
    'ㅅ',
    'ㅆ',
    'ㅇ',
    'ㅈ',
    'ㅊ',
    'ㅋ',
    'ㅌ',
    'ㅍ',
    'ㅎ',
  ];

  static const _combinedVowels = {
    'ㅗㅏ': 'ㅘ',
    'ㅗㅐ': 'ㅙ',
    'ㅗㅣ': 'ㅚ',
    'ㅜㅓ': 'ㅝ',
    'ㅜㅔ': 'ㅞ',
    'ㅜㅣ': 'ㅟ',
    'ㅡㅣ': 'ㅢ',
  };

  static const _combinedFinals = {
    'ㄱㅅ': 'ㄳ',
    'ㄴㅈ': 'ㄵ',
    'ㄴㅎ': 'ㄶ',
    'ㄹㄱ': 'ㄺ',
    'ㄹㅁ': 'ㄻ',
    'ㄹㅂ': 'ㄼ',
    'ㄹㅅ': 'ㄽ',
    'ㄹㅌ': 'ㄾ',
    'ㄹㅍ': 'ㄿ',
    'ㄹㅎ': 'ㅀ',
    'ㅂㅅ': 'ㅄ',
  };

  static const _splitFinals = {
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

  static const _choseongIndex = {
    'ㄱ': 0,
    'ㄲ': 1,
    'ㄴ': 2,
    'ㄷ': 3,
    'ㄸ': 4,
    'ㄹ': 5,
    'ㅁ': 6,
    'ㅂ': 7,
    'ㅃ': 8,
    'ㅅ': 9,
    'ㅆ': 10,
    'ㅇ': 11,
    'ㅈ': 12,
    'ㅉ': 13,
    'ㅊ': 14,
    'ㅋ': 15,
    'ㅌ': 16,
    'ㅍ': 17,
    'ㅎ': 18,
  };

  static const _jungseongIndex = {
    'ㅏ': 0,
    'ㅐ': 1,
    'ㅑ': 2,
    'ㅒ': 3,
    'ㅓ': 4,
    'ㅔ': 5,
    'ㅕ': 6,
    'ㅖ': 7,
    'ㅗ': 8,
    'ㅘ': 9,
    'ㅙ': 10,
    'ㅚ': 11,
    'ㅛ': 12,
    'ㅜ': 13,
    'ㅝ': 14,
    'ㅞ': 15,
    'ㅟ': 16,
    'ㅠ': 17,
    'ㅡ': 18,
    'ㅢ': 19,
    'ㅣ': 20,
  };

  static const _jongseongIndex = {
    '': 0,
    'ㄱ': 1,
    'ㄲ': 2,
    'ㄳ': 3,
    'ㄴ': 4,
    'ㄵ': 5,
    'ㄶ': 6,
    'ㄷ': 7,
    'ㄹ': 8,
    'ㄺ': 9,
    'ㄻ': 10,
    'ㄼ': 11,
    'ㄽ': 12,
    'ㄾ': 13,
    'ㄿ': 14,
    'ㅀ': 15,
    'ㅁ': 16,
    'ㅂ': 17,
    'ㅄ': 18,
    'ㅅ': 19,
    'ㅆ': 20,
    'ㅇ': 21,
    'ㅈ': 22,
    'ㅊ': 23,
    'ㅋ': 24,
    'ㅌ': 25,
    'ㅍ': 26,
    'ㅎ': 27,
  };

  static const _splitVowels = {
    'ㅘ': ['ㅗ', 'ㅏ'],
    'ㅙ': ['ㅗ', 'ㅐ'],
    'ㅚ': ['ㅗ', 'ㅣ'],
    'ㅝ': ['ㅜ', 'ㅓ'],
    'ㅞ': ['ㅜ', 'ㅔ'],
    'ㅟ': ['ㅜ', 'ㅣ'],
    'ㅢ': ['ㅡ', 'ㅣ'],
  };

  int? _cho;
  int? _jung;
  int? _jong;
  String? _rawVowel;

  void reset() {
    _cho = null;
    _jung = null;
    _jong = null;
    _rawVowel = null;
  }

  _TextEdit input(String jamo) {
    if (_isVowel(jamo)) {
      return _inputVowel(jamo);
    }

    if (_isConsonant(jamo)) {
      return _inputConsonant(jamo);
    }

    reset();
    return _TextEdit(jamo, 0);
  }

  _TextEdit? backspace() {
    if (_jong != null && _jong! > 0) {
      final jongJamo = _jongseong[_jong!];
      final split = _splitFinals[jongJamo];
      if (split != null) {
        _jong = _jongseongIndex[split.first];
      } else {
        _jong = null;
      }
      return _TextEdit(_composeCurrent(), 1);
    }

    if (_jung != null) {
      final jungJamo = _jungseong[_jung!];
      final split = _splitVowel(jungJamo);
      if (split != null) {
        _jung = _jungseongIndex[split.first];
        return _TextEdit(_composeCurrent(), 1);
      }

      final choJamo = _choseong[_cho!];
      _jung = null;
      return _TextEdit(choJamo, 1);
    }

    if (_cho != null || _rawVowel != null) {
      reset();
      return const _TextEdit('', 1);
    }

    return null;
  }

  _TextEdit _inputConsonant(String consonant) {
    _rawVowel = null;
    final choIndex = _choseongIndex[consonant];

    if (choIndex == null || _cho == null || _jung == null) {
      _cho = choIndex;
      _jung = null;
      _jong = null;
      return _TextEdit(consonant, 0);
    }

    if (_jong == null) {
      final jongIndex = _jongseongIndex[consonant] ?? 0;
      if (jongIndex > 0) {
        _jong = jongIndex;
        return _TextEdit(_composeCurrent(), 1);
      }
    } else {
      final combined = _combinedFinals[_jongseong[_jong!] + consonant];
      if (combined != null) {
        _jong = _jongseongIndex[combined];
        return _TextEdit(_composeCurrent(), 1);
      }
    }

    _cho = choIndex;
    _jung = null;
    _jong = null;
    return _TextEdit(consonant, 0);
  }

  _TextEdit _inputVowel(String vowel) {
    if (_rawVowel != null) {
      final combined = _combinedVowels[_rawVowel! + vowel];
      if (combined != null) {
        _rawVowel = combined;
        return _TextEdit(combined, 1);
      }

      _rawVowel = vowel;
      return _TextEdit(vowel, 0);
    }

    if (_cho == null) {
      _rawVowel = vowel;
      return _TextEdit(vowel, 0);
    }

    if (_jung == null) {
      _jung = _jungseongIndex[vowel];
      return _TextEdit(_composeCurrent(), 1);
    }

    if (_jong != null && _jong! > 0) {
      final jongJamo = _jongseong[_jong!];
      final split = _splitFinals[jongJamo];
      final remainingFinal = split?.first;
      final movingInitial = split?.last ?? jongJamo;

      _jong = remainingFinal == null ? null : _jongseongIndex[remainingFinal];
      final previousSyllable = _composeCurrent();

      _cho = _choseongIndex[movingInitial];
      _jung = _jungseongIndex[vowel];
      _jong = null;
      return _TextEdit(previousSyllable + _composeCurrent(), 1);
    }

    final combined = _combinedVowels[_jungseong[_jung!] + vowel];
    if (combined != null) {
      _jung = _jungseongIndex[combined];
      return _TextEdit(_composeCurrent(), 1);
    }

    reset();
    _rawVowel = vowel;
    return _TextEdit(vowel, 0);
  }

  bool _isConsonant(String value) => _choseongIndex.containsKey(value);

  bool _isVowel(String value) => _jungseongIndex.containsKey(value);

  List<String>? _splitVowel(String value) => _splitVowels[value];

  String _composeCurrent() {
    if (_cho == null || _jung == null) {
      return _cho == null ? '' : _choseong[_cho!];
    }

    final codeUnit = 0xAC00 + ((_cho! * 21 + _jung!) * 28) + (_jong ?? 0);
    return String.fromCharCode(codeUnit);
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.onTap,
    this.accent = const Color(0xFFF4F4F4),
    this.foreground = const Color(0xFF171A20),
  });

  final String label;
  final VoidCallback onTap;
  final Color accent;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: const Color(0xFFF4F4F4),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      label: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF393C41),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

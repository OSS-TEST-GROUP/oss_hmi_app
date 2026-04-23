import 'package:flutter/material.dart';

import '../theme/launcher_tokens.dart';
import 'hangul_composer.dart';
import 'text_input_bridge.dart';

/// Input layers offered by the Tesla-reskin virtual keyboard.
enum KeyboardLayer { letters, numbers, symbols, hangul }

/// Dock-style on-screen keyboard for touch IVI use.
///
/// Layers: QWERTY letters (with single-shot shift), numbers + common
/// punctuation, and a symbols page. Keys operate on whichever
/// [EditableText] currently holds focus via [TextInputBridge]. The
/// widget is visually styled to match the launcher's Tesla tokens:
/// white keys, 1px #D0D1D2 borders, 4px radius, no shadows.
class VirtualKeyboard extends StatefulWidget {
  const VirtualKeyboard({
    super.key,
    required this.onDismiss,
  });

  /// Height the widget reserves on-screen. Kept in sync with
  /// [KeyboardHost] so the content above can be padded correctly.
  static const double height = 280.0;

  /// Fires when the user taps the close key — the host widget should
  /// hide the keyboard in response.
  final VoidCallback onDismiss;

  @override
  State<VirtualKeyboard> createState() => _VirtualKeyboardState();
}

class _VirtualKeyboardState extends State<VirtualKeyboard> {
  KeyboardLayer _layer = KeyboardLayer.letters;
  // True while a single shift is armed; consumed on the next character.
  bool _shift = false;

  // Hangul composition state — owned by the keyboard because composition
  // spans multiple key presses and must be flushed on layer/focus change.
  final HangulComposer _composer = HangulComposer();
  // Length (UTF-16 code units) of the in-progress syllable currently on
  // screen. Hangul syllables are single BMP characters so this stays
  // 0 or 1; the field exists for clarity.
  int _composingOnScreen = 0;

  void _onChar(String ch) {
    // Any non-hangul input during composition flushes the pending
    // syllable first — otherwise it would be stuck on screen while the
    // user types ASCII next to it.
    _commitHangul();
    final out = _shift && _layer == KeyboardLayer.letters
        ? ch.toUpperCase()
        : ch;
    TextInputBridge.insert(out);
    if (_shift) setState(() => _shift = false);
  }

  void _onJamo(String baseJamo) {
    final jamo = _shiftedJamo(baseJamo, _shift);
    final result = _composer.feed(jamo);
    // Remove the previous in-progress syllable, then write committed +
    // new composing. Backspace + insert is simpler than splicing the
    // controller value by hand and keeps the cursor at the end.
    for (var i = 0; i < _composingOnScreen; i++) {
      TextInputBridge.backspace();
    }
    if (result.committed.isNotEmpty) {
      TextInputBridge.insert(result.committed);
    }
    if (result.composing.isNotEmpty) {
      TextInputBridge.insert(result.composing);
    }
    _composingOnScreen = result.composing.length;
    if (_shift) setState(() => _shift = false);
  }

  /// Backspace while in the Hangul layer — peel one jamo at a time when
  /// composing, otherwise delete one character in the text field.
  void _onHangulBackspace() {
    if (!_composer.isComposing) {
      TextInputBridge.backspace();
      return;
    }
    final result = _composer.backspace();
    for (var i = 0; i < _composingOnScreen; i++) {
      TextInputBridge.backspace();
    }
    if (result.committed.isNotEmpty) {
      TextInputBridge.insert(result.committed);
    }
    if (result.composing.isNotEmpty) {
      TextInputBridge.insert(result.composing);
    }
    _composingOnScreen = result.composing.length;
  }

  /// Finalise the current syllable without changing the visible text —
  /// the composing glyph already sits in the buffer as-is.
  void _commitHangul() {
    if (_composer.isComposing) _composer.commit();
    _composingOnScreen = 0;
  }

  void _onHangulSpace() {
    _commitHangul();
    TextInputBridge.insert(' ');
  }

  void _onHangulSubmit() {
    _commitHangul();
    TextInputBridge.submit();
  }

  void _setLayer(KeyboardLayer layer) {
    // Leaving the Hangul layer without committing would strand a partial
    // syllable whose state the next layer can't progress.
    if (_layer == KeyboardLayer.hangul && layer != KeyboardLayer.hangul) {
      _commitHangul();
    }
    setState(() {
      _layer = layer;
      _shift = false;
    });
  }

  /// Map a 두벌식 base jamo to its shift variant. Most rows have no
  /// shifted form — only consonants with a double form (ㅃ, ㅉ, ㄸ, ㄲ,
  /// ㅆ) and the two vowels ㅐ / ㅔ have shifts.
  static String _shiftedJamo(String base, bool shift) {
    if (!shift) return base;
    const map = {
      'ㅂ': 'ㅃ',
      'ㅈ': 'ㅉ',
      'ㄷ': 'ㄸ',
      'ㄱ': 'ㄲ',
      'ㅅ': 'ㅆ',
      'ㅐ': 'ㅒ',
      'ㅔ': 'ㅖ',
    };
    return map[base] ?? base;
  }

  @override
  Widget build(BuildContext context) {
    // TextFieldTapRegion marks this subtree as part of the focused
    // EditableText's "not outside" group. Without it, every key tap
    // counts as a tap outside the TextField on desktop, which immediately
    // unfocuses the editor — so TextInputBridge.insert() finds no focused
    // editor and KeyboardHost debounces the keyboard away.
    return TextFieldTapRegion(
      child: Container(
        key: const Key('virtual_keyboard'),
        height: VirtualKeyboard.height,
        decoration: const BoxDecoration(
          color: LauncherTokens.bg2,
          border: Border(top: BorderSide(color: LauncherTokens.b1)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Expanded(child: _buildRows()),
          ],
        ),
      ),
    );
  }

  Widget _buildRows() {
    switch (_layer) {
      case KeyboardLayer.letters:
        return _LettersLayer(
          shift: _shift,
          onChar: _onChar,
          onShift: () => setState(() => _shift = !_shift),
          onBackspace: TextInputBridge.backspace,
          onSubmit: TextInputBridge.submit,
          onSwitchNumbers: () => _setLayer(KeyboardLayer.numbers),
          onSwitchHangul: () => _setLayer(KeyboardLayer.hangul),
          onClose: widget.onDismiss,
        );
      case KeyboardLayer.numbers:
        return _NumbersLayer(
          onChar: _onChar,
          onBackspace: TextInputBridge.backspace,
          onSubmit: TextInputBridge.submit,
          onSwitchLetters: () => _setLayer(KeyboardLayer.letters),
          onSwitchSymbols: () => _setLayer(KeyboardLayer.symbols),
          onClose: widget.onDismiss,
        );
      case KeyboardLayer.symbols:
        return _SymbolsLayer(
          onChar: _onChar,
          onBackspace: TextInputBridge.backspace,
          onSubmit: TextInputBridge.submit,
          onSwitchLetters: () => _setLayer(KeyboardLayer.letters),
          onSwitchNumbers: () => _setLayer(KeyboardLayer.numbers),
          onClose: widget.onDismiss,
        );
      case KeyboardLayer.hangul:
        return _HangulLayer(
          shift: _shift,
          onJamo: _onJamo,
          onShift: () => setState(() => _shift = !_shift),
          onBackspace: _onHangulBackspace,
          onSpace: _onHangulSpace,
          onSubmit: _onHangulSubmit,
          onSwitchEnglish: () => _setLayer(KeyboardLayer.letters),
          onSwitchNumbers: () => _setLayer(KeyboardLayer.numbers),
          onClose: widget.onDismiss,
        );
    }
  }
}

/// ─── Layers ──────────────────────────────────────────────────────────

class _LettersLayer extends StatelessWidget {
  const _LettersLayer({
    required this.shift,
    required this.onChar,
    required this.onShift,
    required this.onBackspace,
    required this.onSubmit,
    required this.onSwitchNumbers,
    required this.onSwitchHangul,
    required this.onClose,
  });

  final bool shift;
  final ValueChanged<String> onChar;
  final VoidCallback onShift;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchNumbers;
  final VoidCallback onSwitchHangul;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    String render(String c) => shift ? c.toUpperCase() : c;
    return Column(
      children: [
        Expanded(child: _KeyRow.chars(
          chars: 'qwertyuiop',
          render: render,
          onChar: onChar,
        )),
        Expanded(child: _KeyRow.chars(
          chars: 'asdfghjkl',
          render: render,
          onChar: onChar,
          padding: 18,
        )),
        Expanded(child: Row(
          children: [
            _SpecialKey(
              label: shift ? '⇧' : '⇧',
              highlighted: shift,
              flex: 2,
              onTap: onShift,
            ),
            ..._letters('zxcvbnm').map(
              (c) => Expanded(child: _CharKey(
                label: render(c),
                onTap: () => onChar(c),
              )),
            ),
            _SpecialKey(
              label: '⌫',
              flex: 2,
              onTap: onBackspace,
            ),
          ],
        )),
        Expanded(child: Row(
          children: [
            _SpecialKey(label: '123', flex: 2, onTap: onSwitchNumbers),
            _SpecialKey(label: '한', flex: 2, onTap: onSwitchHangul),
            _SpecialKey(
              label: 'space',
              flex: 5,
              onTap: () => onChar(' '),
            ),
            _CharKey(label: '.', onTap: () => onChar('.')),
            _SpecialKey(label: '↵', flex: 2, onTap: onSubmit, primary: true),
            _SpecialKey(label: '✕', flex: 1, onTap: onClose),
          ],
        )),
      ],
    );
  }

  static List<String> _letters(String s) =>
      [for (final c in s.split('')) c];
}

class _NumbersLayer extends StatelessWidget {
  const _NumbersLayer({
    required this.onChar,
    required this.onBackspace,
    required this.onSubmit,
    required this.onSwitchLetters,
    required this.onSwitchSymbols,
    required this.onClose,
  });

  final ValueChanged<String> onChar;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchLetters;
  final VoidCallback onSwitchSymbols;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _KeyRow.chars(
          chars: '1234567890',
          onChar: onChar,
        )),
        Expanded(child: _KeyRow.chars(
          chars: "-/:;()\$&@\"",
          onChar: onChar,
        )),
        Expanded(child: Row(
          children: [
            _SpecialKey(label: '#+=', flex: 2, onTap: onSwitchSymbols),
            ...".,?!'".split('').map(
                  (c) => Expanded(child: _CharKey(
                        label: c,
                        onTap: () => onChar(c),
                      )),
                ),
            _SpecialKey(label: '⌫', flex: 2, onTap: onBackspace),
          ],
        )),
        Expanded(child: Row(
          children: [
            _SpecialKey(label: 'ABC', flex: 2, onTap: onSwitchLetters),
            _SpecialKey(
              label: 'space',
              flex: 5,
              onTap: () => onChar(' '),
            ),
            _SpecialKey(label: '↵', flex: 2, onTap: onSubmit, primary: true),
            _SpecialKey(label: '✕', flex: 1, onTap: onClose),
          ],
        )),
      ],
    );
  }
}

class _SymbolsLayer extends StatelessWidget {
  const _SymbolsLayer({
    required this.onChar,
    required this.onBackspace,
    required this.onSubmit,
    required this.onSwitchLetters,
    required this.onSwitchNumbers,
    required this.onClose,
  });

  final ValueChanged<String> onChar;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchLetters;
  final VoidCallback onSwitchNumbers;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _KeyRow.chars(
          chars: '[]{}#%^*+=',
          onChar: onChar,
        )),
        Expanded(child: _KeyRow.chars(
          chars: '_\\|~<>€£¥·',
          onChar: onChar,
        )),
        Expanded(child: Row(
          children: [
            _SpecialKey(label: '123', flex: 2, onTap: onSwitchNumbers),
            ...".,?!'".split('').map(
                  (c) => Expanded(child: _CharKey(
                        label: c,
                        onTap: () => onChar(c),
                      )),
                ),
            _SpecialKey(label: '⌫', flex: 2, onTap: onBackspace),
          ],
        )),
        Expanded(child: Row(
          children: [
            _SpecialKey(label: 'ABC', flex: 2, onTap: onSwitchLetters),
            _SpecialKey(
              label: 'space',
              flex: 5,
              onTap: () => onChar(' '),
            ),
            _SpecialKey(label: '↵', flex: 2, onTap: onSubmit, primary: true),
            _SpecialKey(label: '✕', flex: 1, onTap: onClose),
          ],
        )),
      ],
    );
  }
}

/// ─── Keys ────────────────────────────────────────────────────────────

class _KeyRow extends StatelessWidget {
  const _KeyRow._({
    required this.children,
    this.padding = 0,
  });

  factory _KeyRow.chars({
    required String chars,
    required ValueChanged<String> onChar,
    String Function(String)? render,
    double padding = 0,
  }) {
    final r = render ?? (s) => s;
    return _KeyRow._(
      padding: padding,
      children: chars
          .split('')
          .map((c) => Expanded(
                child: _CharKey(
                  label: r(c),
                  onTap: () => onChar(c),
                ),
              ))
          .toList(),
    );
  }

  final List<Widget> children;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(children: children),
    );
  }
}

class _CharKey extends StatefulWidget {
  const _CharKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_CharKey> createState() => _CharKeyState();
}

class _CharKeyState extends State<_CharKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: _pressed ? LauncherTokens.bg3 : LauncherTokens.bg0,
            border: Border.all(color: LauncherTokens.b2),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: LauncherTokens.t1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecialKey extends StatefulWidget {
  const _SpecialKey({
    required this.label,
    required this.onTap,
    this.flex = 1,
    this.primary = false,
    this.highlighted = false,
  });

  final String label;
  final VoidCallback onTap;
  final int flex;
  final bool primary;
  final bool highlighted;

  @override
  State<_SpecialKey> createState() => _SpecialKeyState();
}

class _SpecialKeyState extends State<_SpecialKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.primary
        ? LauncherTokens.bg0
        : (widget.highlighted ? LauncherTokens.accent : LauncherTokens.t1);
    final bg = widget.primary
        ? (_pressed
            ? LauncherTokens.accentHover
            : LauncherTokens.accent)
        : (_pressed ? LauncherTokens.bg3 : LauncherTokens.bg2);
    final border = widget.primary ? LauncherTokens.accent : LauncherTokens.b2;

    return Expanded(
      flex: widget.flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── Hangul layer ────────────────────────────────────────────────────
/// Standard 두벌식 layout. Each key emits its *base* jamo; the shift
/// variant (ㅃ/ㅉ/ㄸ/ㄲ/ㅆ and ㅒ/ㅖ) is resolved in the keyboard's
/// [_VirtualKeyboardState._shiftedJamo]. Consonant rows show their shift
/// form as a secondary glyph when Shift is armed.
class _HangulLayer extends StatelessWidget {
  const _HangulLayer({
    required this.shift,
    required this.onJamo,
    required this.onShift,
    required this.onBackspace,
    required this.onSpace,
    required this.onSubmit,
    required this.onSwitchEnglish,
    required this.onSwitchNumbers,
    required this.onClose,
  });

  final bool shift;
  final ValueChanged<String> onJamo;
  final VoidCallback onShift;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchEnglish;
  final VoidCallback onSwitchNumbers;
  final VoidCallback onClose;

  static const List<List<String>> _rows = [
    ['ㅂ', 'ㅈ', 'ㄷ', 'ㄱ', 'ㅅ', 'ㅛ', 'ㅕ', 'ㅑ', 'ㅐ', 'ㅔ'],
    ['ㅁ', 'ㄴ', 'ㅇ', 'ㄹ', 'ㅎ', 'ㅗ', 'ㅓ', 'ㅏ', 'ㅣ'],
    ['ㅋ', 'ㅌ', 'ㅊ', 'ㅍ', 'ㅠ', 'ㅜ', 'ㅡ'],
  ];

  static const Map<String, String> _shiftedLabel = {
    'ㅂ': 'ㅃ',
    'ㅈ': 'ㅉ',
    'ㄷ': 'ㄸ',
    'ㄱ': 'ㄲ',
    'ㅅ': 'ㅆ',
    'ㅐ': 'ㅒ',
    'ㅔ': 'ㅖ',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _row(_rows[0])),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _row(_rows[1]),
          ),
        ),
        Expanded(child: Row(
          children: [
            _SpecialKey(
              label: 'shift',
              highlighted: shift,
              flex: 2,
              onTap: onShift,
            ),
            ..._rows[2].map(
              (j) => Expanded(child: _CharKey(
                label: _renderLabel(j),
                onTap: () => onJamo(j),
              )),
            ),
            _SpecialKey(label: '⌫', flex: 2, onTap: onBackspace),
          ],
        )),
        Expanded(child: Row(
          children: [
            _SpecialKey(label: '123', flex: 2, onTap: onSwitchNumbers),
            _SpecialKey(
              label: 'ABC',
              flex: 2,
              onTap: onSwitchEnglish,
            ),
            _SpecialKey(label: 'space', flex: 5, onTap: onSpace),
            _SpecialKey(label: '↵', flex: 2, onTap: onSubmit, primary: true),
            _SpecialKey(label: '✕', flex: 1, onTap: onClose),
          ],
        )),
      ],
    );
  }

  Widget _row(List<String> jamos) => Row(
        children: [
          for (final j in jamos)
            Expanded(
              child: _CharKey(
                label: _renderLabel(j),
                onTap: () => onJamo(j),
              ),
            ),
        ],
      );

  String _renderLabel(String base) =>
      shift ? (_shiftedLabel[base] ?? base) : base;
}

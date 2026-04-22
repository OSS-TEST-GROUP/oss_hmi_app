import 'dart:async';

import 'package:flutter/widgets.dart';

import 'text_input_bridge.dart';
import 'virtual_keyboard.dart';

/// Root widget that turns any descendant [TextField] into a trigger for
/// the launcher's touch keyboard.
///
/// Install as the [WidgetsApp.builder] so a single instance shadows the
/// whole widget tree (shell + every embedded plugin). The host listens
/// to [FocusManager] for focus changes: when an [EditableText] gains
/// focus the keyboard slides up, and when no editor is focused it
/// slides back down. Taps on the keyboard are routed through
/// [TextInputBridge] so keys operate on the currently focused editor
/// regardless of which widget tree owns it.
///
/// Content above the keyboard is padded by [VirtualKeyboard.height]
/// while visible so nothing important is occluded.
class KeyboardHost extends StatefulWidget {
  const KeyboardHost({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardHost> createState() => _KeyboardHostState();
}

class _KeyboardHostState extends State<KeyboardHost> {
  bool _visible = false;
  // Debounces focus changes so rapid focus traversals between text fields
  // don't make the keyboard flicker away and back.
  Timer? _hideDebounce;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    _hideDebounce?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    final nowEditing = TextInputBridge.hasFocusedEditor;
    if (nowEditing) {
      _hideDebounce?.cancel();
      if (!_visible) setState(() => _visible = true);
      return;
    }
    // Focus may briefly drop mid-traversal; wait one frame before hiding
    // so we don't dismiss the keyboard when the user taps a key.
    _hideDebounce?.cancel();
    _hideDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (!TextInputBridge.hasFocusedEditor && _visible) {
        setState(() => _visible = false);
      }
    });
  }

  void _dismiss() {
    TextInputBridge.unfocus();
    if (_visible) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: _visible ? VirtualKeyboard.height : 0,
          ),
          child: widget.child,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: _visible ? 0 : -VirtualKeyboard.height,
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: VirtualKeyboard(onDismiss: _dismiss),
          ),
        ),
      ],
    );
  }
}

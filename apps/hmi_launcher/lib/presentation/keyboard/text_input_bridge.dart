import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Helpers that read from and write to whichever [EditableText] currently
/// holds primary focus.
///
/// The launcher provides a system-wide virtual keyboard: its keys operate
/// on the active [TextField] regardless of which widget tree owns it
/// (launcher shell, plugin panel, dialog, ...). We find the focused
/// editor by walking up from [FocusManager.primaryFocus.context] to the
/// nearest [EditableTextState] — that state exposes the underlying
/// [TextEditingController].
class TextInputBridge {
  TextInputBridge._();

  /// The [EditableTextState] whose [FocusNode] currently has primary focus,
  /// or null when no text field is focused.
  static EditableTextState? focusedEditor() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return null;
    return ctx.findAncestorStateOfType<EditableTextState>();
  }

  /// Whether a text field is currently focused — the signal used by the
  /// keyboard host to decide whether to slide the keyboard in.
  static bool get hasFocusedEditor => focusedEditor() != null;

  /// Insert [text] at the current selection of the focused editor.
  /// Silently does nothing when no editor is focused.
  static void insert(String text) {
    final editor = focusedEditor();
    if (editor == null) return;
    final ctrl = editor.widget.controller;
    final value = ctrl.value;
    final sel = value.selection;
    final start = sel.isValid ? sel.start : value.text.length;
    final end = sel.isValid ? sel.end : value.text.length;
    final next = value.text.replaceRange(start, end, text);
    ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  /// Delete the character to the left of the caret, or the current
  /// selection if non-empty.
  static void backspace() {
    final editor = focusedEditor();
    if (editor == null) return;
    final ctrl = editor.widget.controller;
    final value = ctrl.value;
    final sel = value.selection;
    if (!sel.isValid) return;
    if (sel.isCollapsed) {
      if (sel.start <= 0) return;
      final next =
          value.text.substring(0, sel.start - 1) + value.text.substring(sel.end);
      ctrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start - 1),
      );
    } else {
      final next = value.text.replaceRange(sel.start, sel.end, '');
      ctrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start),
      );
    }
  }

  /// Fire the focused editor's submit action — forwards to the widget's
  /// `onSubmitted` via [EditableTextState.performAction].
  static void submit() {
    final editor = focusedEditor();
    if (editor == null) return;
    editor.performAction(TextInputAction.done);
  }

  /// Drop focus so the keyboard host can dismiss the keyboard.
  static void unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

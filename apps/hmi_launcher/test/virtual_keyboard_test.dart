import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/presentation/keyboard/keyboard_host.dart';
import 'package:hmi_launcher/presentation/keyboard/virtual_keyboard.dart';

/// Pumps a MaterialApp whose only content is a single TextField, wrapped
/// in KeyboardHost via `builder` just like main.dart does in production.
Future<TextEditingController> _pumpHost(
  WidgetTester tester, {
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => KeyboardHost(child: child!),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: TextField(
            key: const Key('target_field'),
            controller: controller,
          ),
        ),
      ),
    ),
  ));
  return controller;
}

void main() {
  group('VirtualKeyboard', () {
    testWidgets('mounts at the root and is reachable by type',
        (tester) async {
      await _pumpHost(tester);
      expect(find.byType(VirtualKeyboard), findsOneWidget);
    });

    testWidgets('tapping a letter key inserts into the focused field',
        (tester) async {
      final controller = await _pumpHost(tester);

      await tester.tap(find.byKey(const Key('target_field')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('h'));
      await tester.pump();
      await tester.tap(find.text('i'));
      await tester.pump();

      expect(controller.text, 'hi');
    });

    testWidgets('shift key capitalizes the next character only',
        (tester) async {
      final controller = await _pumpHost(tester);
      await tester.tap(find.byKey(const Key('target_field')));
      await tester.pumpAndSettle();

      // Arm shift — letter labels now render in uppercase. Tap "A" for
      // the shifted glyph, then confirm the next tap falls back to "b".
      await tester.tap(find.text('Shift'));
      await tester.pump();
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('b'));
      await tester.pump();

      expect(controller.text, 'Ab');
    });

    testWidgets('backspace removes the character to the left of the caret',
        (tester) async {
      final controller = await _pumpHost(tester, initial: 'abc');
      await tester.tap(find.byKey(const Key('target_field')));
      await tester.pumpAndSettle();

      // Caret is at end after focus; backspace removes "c".
      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(controller.text, 'ab');
    });

    testWidgets('123 switches to the numbers layer, ABC returns',
        (tester) async {
      final controller = await _pumpHost(tester);
      await tester.tap(find.byKey(const Key('target_field')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('123'));
      await tester.pump();

      // Numbers layer shows digits.
      await tester.tap(find.text('7'));
      await tester.pump();
      expect(controller.text, '7');

      // Back to letters.
      await tester.tap(find.text('ABC'));
      await tester.pump();
      await tester.tap(find.text('a'));
      await tester.pump();
      expect(controller.text, '7a');
    });

    testWidgets('한 toggle switches to the Hangul layer and composes "한"',
        (tester) async {
      final controller = await _pumpHost(tester);
      await tester.tap(find.byKey(const Key('target_field')));
      await tester.pumpAndSettle();

      // Enter Hangul mode.
      await tester.tap(find.text('한'));
      await tester.pump();

      // Type ㅎ ㅏ ㄴ  → "한"
      await tester.tap(find.text('ㅎ'));
      await tester.pump();
      await tester.tap(find.text('ㅏ'));
      await tester.pump();
      await tester.tap(find.text('ㄴ'));
      await tester.pump();

      expect(controller.text, '한');
    });

    testWidgets('Hangul layer composes "한글"',
        (tester) async {
      final controller = await _pumpHost(tester);
      await tester.tap(find.byKey(const Key('target_field')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('한'));
      await tester.pump();

      for (final j in ['ㅎ', 'ㅏ', 'ㄴ', 'ㄱ', 'ㅡ', 'ㄹ']) {
        await tester.tap(find.text(j));
        await tester.pump();
      }

      expect(controller.text, '한글');
    });

    testWidgets('ABC toggle from Hangul commits the pending syllable',
        (tester) async {
      final controller = await _pumpHost(tester);
      await tester.tap(find.byKey(const Key('target_field')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('한'));
      await tester.pump();

      // Partial syllable 하 (ㅎ + ㅏ).
      await tester.tap(find.text('ㅎ'));
      await tester.pump();
      await tester.tap(find.text('ㅏ'));
      await tester.pump();
      expect(controller.text, '하');

      // Switch back to English — the 하 should remain as-is.
      await tester.tap(find.text('ABC'));
      await tester.pump();
      await tester.tap(find.text('a'));
      await tester.pump();
      expect(controller.text, '하a');
    });
  });
}

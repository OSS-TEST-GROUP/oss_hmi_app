import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oss_launcher_bot/widgets/virtual_keyboard.dart';

void main() {
  testWidgets('virtual keyboard composes Korean syllables', (tester) async {
    var text = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VirtualKeyboard(
            onTextInput: (value, {replaceBackCount = 0}) {
              final start = (text.length - replaceBackCount)
                  .clamp(0, text.length)
                  .toInt();
              text = text.replaceRange(start, text.length, value);
            },
            onBackspace: () {
              if (text.isNotEmpty) {
                text = text.substring(0, text.length - 1);
              }
            },
            onSpace: () => text += ' ',
            onHide: () {},
            onSubmit: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('ㅎ'));
    await tester.tap(find.text('ㅏ'));
    await tester.tap(find.text('ㄴ'));

    expect(text, '한');
  });

  testWidgets('virtual keyboard enters symbols', (tester) async {
    var text = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VirtualKeyboard(
            onTextInput: (value, {replaceBackCount = 0}) {
              final start = (text.length - replaceBackCount)
                  .clamp(0, text.length)
                  .toInt();
              text = text.replaceRange(start, text.length, value);
            },
            onBackspace: () {
              if (text.isNotEmpty) {
                text = text.substring(0, text.length - 1);
              }
            },
            onSpace: () => text += ' ',
            onHide: () {},
            onSubmit: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('#+='));
    await tester.pump();
    await tester.tap(find.text('1'));
    await tester.tap(find.text('SHIFT'));
    await tester.pump();
    await tester.tap(find.text('@'));

    expect(text, '1@');
  });
}

// QA(docs/qa): TextInputBridge — 시스템 가상키보드가 포커스된 TextField 를 조작.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/presentation/keyboard/text_input_bridge.dart';

Future<TextEditingController> _pumpFocusedField(
  WidgetTester tester, {
  String initial = '',
  ValueChanged<String>? onSubmitted,
}) async {
  final ctrl = TextEditingController(text: initial);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: TextField(controller: ctrl, onSubmitted: onSubmitted),
    ),
  ));
  await tester.tap(find.byType(TextField));
  await tester.pump();
  return ctrl;
}

void main() {
  testWidgets('포커스 없으면 focusedEditor=null, insert/backspace no-op', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    expect(TextInputBridge.focusedEditor(), isNull);
    expect(TextInputBridge.hasFocusedEditor, isFalse);
    // no-op (예외 없이 통과)
    TextInputBridge.insert('x');
    TextInputBridge.backspace();
    TextInputBridge.submit();
    TextInputBridge.unfocus();
  });

  testWidgets('insert 는 캐럿 위치에 텍스트 삽입', (tester) async {
    final ctrl = await _pumpFocusedField(tester);
    expect(TextInputBridge.hasFocusedEditor, isTrue);
    TextInputBridge.insert('AB');
    await tester.pump();
    expect(ctrl.text, 'AB');
    TextInputBridge.insert('C');
    await tester.pump();
    expect(ctrl.text, 'ABC');
  });

  testWidgets('backspace(collapsed) 는 캐럿 왼쪽 한 글자 삭제', (tester) async {
    final ctrl = await _pumpFocusedField(tester);
    TextInputBridge.insert('ABC');
    await tester.pump();
    TextInputBridge.backspace();
    await tester.pump();
    expect(ctrl.text, 'AB');
  });

  testWidgets('backspace(selection) 는 선택 영역 삭제', (tester) async {
    final ctrl = await _pumpFocusedField(tester, initial: 'HELLO');
    // 앞 3글자 선택
    ctrl.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pump();
    TextInputBridge.backspace();
    await tester.pump();
    expect(ctrl.text, 'LO');
  });

  testWidgets('backspace: 캐럿이 맨 앞이면 no-op', (tester) async {
    final ctrl = await _pumpFocusedField(tester, initial: 'X');
    ctrl.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    TextInputBridge.backspace();
    await tester.pump();
    expect(ctrl.text, 'X');
  });

  testWidgets('submit 은 onSubmitted 를 발화', (tester) async {
    String? submitted;
    await _pumpFocusedField(tester, initial: 'go', onSubmitted: (v) => submitted = v);
    TextInputBridge.submit();
    await tester.pump();
    expect(submitted, 'go');
  });

  testWidgets('unfocus 후 focusedEditor=null', (tester) async {
    await _pumpFocusedField(tester, initial: 'z');
    expect(TextInputBridge.hasFocusedEditor, isTrue);
    TextInputBridge.unfocus();
    await tester.pump();
    expect(TextInputBridge.hasFocusedEditor, isFalse);
  });
}

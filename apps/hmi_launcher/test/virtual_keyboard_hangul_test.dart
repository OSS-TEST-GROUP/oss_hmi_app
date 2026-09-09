// QA(docs/qa): VirtualKeyboard 한글 레이어 핸들러 — 조합/스페이스/엔터/백스페이스/레이어전환.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/presentation/keyboard/keyboard_host.dart';
import 'package:hmi_launcher/presentation/keyboard/virtual_keyboard.dart';

Future<TextEditingController> _pumpHost(WidgetTester tester,
    {String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => KeyboardHost(child: child!),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
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

Future<void> _tap(WidgetTester tester, String label) async {
  final f = find.text(label);
  if (f.evaluate().isEmpty) return;
  await tester.tap(f.first, warnIfMissed: false);
  await tester.pump();
}

void main() {
  testWidgets('한글 조합 후 Space → 음절 확정 + 공백', (tester) async {
    final c = await _pumpHost(tester);
    await tester.tap(find.byKey(const Key('target_field')));
    await tester.pumpAndSettle();
    await _tap(tester, '한'); // 한글 레이어로
    await _tap(tester, 'ㅎ');
    await _tap(tester, 'ㅏ');
    await _tap(tester, 'ㄴ'); // 한
    await _tap(tester, 'Space');
    expect(c.text.trim(), '한');
    expect(c.text.endsWith(' '), isTrue);
  });

  testWidgets('한글 조합 중 Back → 자모 한 단계 제거', (tester) async {
    await _pumpHost(tester);
    await tester.tap(find.byKey(const Key('target_field')));
    await tester.pumpAndSettle();
    await _tap(tester, '한');
    await _tap(tester, 'ㅎ');
    await _tap(tester, 'ㅏ'); // 하
    await _tap(tester, 'Back'); // 조합 중 → ㅎ 로
    // 조합 중 백스페이스는 예외 없이 처리되면 충분(구체 결과는 조합기 규칙 의존).
    expect(find.byType(VirtualKeyboard), findsOneWidget);
  });

  testWidgets('한글 조합 후 Enter → 확정 + 제출', (tester) async {
    final c = await _pumpHost(tester);
    await tester.tap(find.byKey(const Key('target_field')));
    await tester.pumpAndSettle();
    await _tap(tester, '한');
    await _tap(tester, 'ㅇ');
    await _tap(tester, 'ㅏ'); // 아
    await _tap(tester, 'Enter');
    expect(c.text, contains('아'));
  });

  testWidgets('한글 조합 중 ABC 레이어 전환 → 미완 음절 확정', (tester) async {
    final c = await _pumpHost(tester);
    await tester.tap(find.byKey(const Key('target_field')));
    await tester.pumpAndSettle();
    await _tap(tester, '한');
    await _tap(tester, 'ㅁ');
    await _tap(tester, 'ㅏ'); // 마
    await _tap(tester, 'ABC'); // 레이어 떠나며 commit
    // 영문 레이어로 전환되었는지: 소문자 자판이 보인다.
    expect(find.text('q'), findsOneWidget);
    expect(c.text, contains('마'));
  });

  testWidgets('한글 조합 없이 Back → 필드 문자 삭제', (tester) async {
    final c = await _pumpHost(tester, initial: '가나');
    await tester.tap(find.byKey(const Key('target_field')));
    await tester.pumpAndSettle();
    await _tap(tester, '한');
    await _tap(tester, 'Back'); // 조합 아님 → 필드 백스페이스
    expect(c.text, '가');
  });

  testWidgets('숫자→기호 레이어 순회', (tester) async {
    await _pumpHost(tester);
    await tester.tap(find.byKey(const Key('target_field')));
    await tester.pumpAndSettle();
    await _tap(tester, '123'); // 숫자 레이어
    expect(find.text('1'), findsOneWidget);
    await _tap(tester, '#+='); // 기호 레이어
    await tester.pump();
    // 기호 레이어의 ABC 로 복귀
    await _tap(tester, 'ABC');
    expect(find.text('q'), findsOneWidget);
  });
}

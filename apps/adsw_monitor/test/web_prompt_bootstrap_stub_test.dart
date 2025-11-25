import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 조건부 export 라우터를 쓰면, VM 환경에서는 stub 버전이 선택됨
import 'package:adsw_monitor/view/web_prompt_bootstrap.dart';

void main() {
  testWidgets(
    'stub shows child immediately and does not trigger onConfigured',
    (WidgetTester tester) async {
      var configured = false;

      await tester.pumpWidget(
        MaterialApp(
          home: WebPromptBootstrap(
            onConfigured: (uri) async {
              configured = true;
            },
            child: const Text('STUB_CHILD'),
          ),
        ),
      );

      // child가 바로 보이는지
      expect(find.text('STUB_CHILD'), findsOneWidget);
      // onConfigured는 자동으로 호출되지 않아야 함
      expect(configured, isFalse);
    },
  );
}

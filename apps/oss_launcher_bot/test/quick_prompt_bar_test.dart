// Widget tests for QuickPromptBar — the row of one-tap launcher commands +
// the metrics button. Pure stateless widget (no chatbot service), so it runs
// headless.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oss_launcher_bot/models/chat_message.dart';
import 'package:oss_launcher_bot/widgets/quick_prompt_bar.dart';

const _prompts = [
  QuickPrompt(label: '내비 실행', command: '내비게이션 앱 실행해줘', icon: Icons.navigation),
  QuickPrompt(label: '뮤직 실행', command: '뮤직 앱 실행해줘', icon: Icons.music_note),
];

Widget _host({
  required ValueChanged<QuickPrompt> onPromptTap,
  required VoidCallback onMetricsTap,
}) =>
    MaterialApp(
      home: Scaffold(
        body: QuickPromptBar(
          compact: true,
          prompts: _prompts,
          onPromptTap: onPromptTap,
          onMetricsTap: onMetricsTap,
        ),
      ),
    );

void main() {
  testWidgets('renders a button per prompt label', (tester) async {
    await tester.pumpWidget(_host(onPromptTap: (_) {}, onMetricsTap: () {}));
    expect(find.text('내비 실행'), findsOneWidget);
    expect(find.text('뮤직 실행'), findsOneWidget);
  });

  testWidgets('tapping a prompt fires onPromptTap with that prompt', (tester) async {
    QuickPrompt? tapped;
    await tester.pumpWidget(
      _host(onPromptTap: (p) => tapped = p, onMetricsTap: () {}),
    );

    await tester.tap(find.text('뮤직 실행'));
    await tester.pump();

    expect(tapped, isNotNull);
    expect(tapped!.command, '뮤직 앱 실행해줘');
  });
}

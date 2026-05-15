import 'package:flutter_test/flutter_test.dart';

import 'package:oss_launcher_bot/app.dart';

void main() {
  testWidgets('launcher bot dashboard renders key surfaces', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Launcher AI Copilot'), findsOneWidget);
    expect(find.text('대화'), findsOneWidget);
    expect(find.text('내비 실행'), findsOneWidget);
    expect(find.text('내비게이션 앱 실행해줘'), findsOneWidget);
  });
}

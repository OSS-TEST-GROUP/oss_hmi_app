// oss_launcher_bot — end-to-end UI flow.
//
// Pure-UI app (no rosbridge): drives the launcher dashboard through the
// integration_test harness. Tapping a quick prompt fills the composer with
// that prompt's command (no LLM round-trip), which is what we assert here so
// the test stays deterministic without the Gemma model loaded.
//
// Run (needs a device/display):
//   flutter test integration_test/app_flow_test.dart -d linux

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oss_launcher_bot/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard renders and a quick prompt fills the composer',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Key surfaces render.
    expect(find.text('Launcher AI Copilot'), findsOneWidget);
    expect(find.text('내비 실행'), findsOneWidget);

    // Tap the navigation quick prompt → composer is populated with its
    // command string (a TextField now holds the command text).
    await tester.tap(find.text('내비 실행'));
    await tester.pumpAndSettle();

    expect(find.text('내비게이션 앱 실행해줘'), findsWidgets);
  });
}

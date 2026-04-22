// Helpers for the F012-F015 Actor-tab integration tests.
//
// Each Actor scenario follows the same pattern:
//   1. pump app.main()
//   2. wait until the header `text_conn_status` reads "connected"
//   3. tap `tab_actor` to bring the Actor cards on screen
//   4. enter text into the per-card app_name field, optionally fill an
//      app_settings JSON, tap the per-card Send button
//   5. wait up to 5 s for `text_actor_*_response` to render
//      `id: <n>   ret_code: ...`
//   6. assert ret_code OK + body fields
//
// dart-define overrides for the runner (also honoured by the smoke test):
//   --dart-define=ROSBRIDGE_WS_URL=ws://host:9090
//   --dart-define=HEALTH_TIMEOUT_SEC=30
//   --dart-define=ACTOR_TEST_APP=demo_app    (default)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String defaultActorTestApp = String.fromEnvironment(
  'ACTOR_TEST_APP',
  defaultValue: 'demo_app',
);

const int healthTimeoutSec = int.fromEnvironment(
  'HEALTH_TIMEOUT_SEC',
  defaultValue: 30,
);

/// 5 s + small slack — must outlive the Actor card's own UI timeout
/// (`actor_page.dart::_uiTimeout`) so a slow heartbeat container still
/// fits inside the assertion window.
const Duration actorResponseWindow = Duration(seconds: 6);

/// Wait until the header `text_conn_status` widget mounts with the
/// label "connected". Polls every 250 ms up to [healthTimeoutSec].
Future<void> waitForRosConnected(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1) * healthTimeoutSec);
  while (DateTime.now().isBefore(deadline)) {
    final finder = find.byKey(const Key('text_conn_status'));
    if (finder.evaluate().isNotEmpty) {
      final w = tester.widget<Text>(finder);
      if (w.data == 'connected') return;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  throw TimeoutException(
    'header text_conn_status never reached "connected" within '
    '${healthTimeoutSec}s',
  );
}

/// Switch the TabBar to the Actor tab and pump one frame.
Future<void> openActorTab(WidgetTester tester) async {
  final finder = find.byKey(const Key('tab_actor'));
  expect(finder, findsOneWidget, reason: 'tab_actor must be mounted');
  await tester.tap(finder);
  await tester.pumpAndSettle(const Duration(milliseconds: 250));
}

/// Drive a single Actor card end-to-end:
///   1. enter [appName] into [appNameKey]
///   2. (optional) enter [valueText] into [valueKey] for SetSettings
///   3. tap [sendKey]
///   4. poll [responseKey] until its text contains "ret_code:" or window expires
///
/// Returns the final response text. Caller asserts on its content.
Future<String> sendActorCard(
  WidgetTester tester, {
  required String appName,
  required Key appNameKey,
  required Key sendKey,
  required Key responseKey,
  Key? valueKey,
  String? valueText,
}) async {
  await tester.enterText(find.byKey(appNameKey), appName);
  await tester.pump();

  if (valueKey != null) {
    await tester.enterText(find.byKey(valueKey), valueText ?? '');
    await tester.pump();
  }

  await tester.tap(find.byKey(sendKey));
  await tester.pump();   // setState → 'Sending...'

  // Poll the response widget; the Actor card uses an internal 5 s Timer
  // for its own timeout, so we give the same budget plus a little slack.
  final deadline = DateTime.now().add(actorResponseWindow);
  while (DateTime.now().isBefore(deadline)) {
    final w = tester.widget<Text>(find.byKey(responseKey));
    final t = w.data ?? '';
    if (t.contains('ret_code:')) return t;
    await tester.pump(const Duration(milliseconds: 200));
  }
  return tester.widget<Text>(find.byKey(responseKey)).data ?? '';
}

/// Convenience: pump the test viewport tall so all four Actor cards are
/// hit-testable without scroll (mirrors actor_page_test.dart's helper).
void enlargeViewportForActorCards(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class TimeoutException implements Exception {
  TimeoutException(this.message);
  final String message;
  @override
  String toString() => 'TimeoutException: $message';
}

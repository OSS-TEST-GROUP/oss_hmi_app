// F014 — GetAppUpdateState 왕복 검증.
//
// Drives the Actor tab's GetAppUpdateState card and asserts a non-empty
// app_state_info comes back inside the 5 s window.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ota_monitor/main.dart' as app;

import '_helpers/actor_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'F014 — GetAppUpdateState round-trip via Actor tab',
    (tester) async {
      enlargeViewportForActorCards(tester);

      app.main(<String>[]);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await waitForRosConnected(tester);
      await openActorTab(tester);

      final body = await sendActorCard(
        tester,
        appName: defaultActorTestApp,
        appNameKey: const Key('field_actor_get_state_app_name'),
        sendKey: const Key('btn_actor_get_state'),
        responseKey: const Key('text_actor_get_state_response'),
      );

      expect(body, contains('id:'));
      expect(body, isNot(contains('timeout')));
      expect(body, contains('ret_code: OK'));
      expect(body, contains('app_state_info:'));

      // ac4: app_state_info should not be empty. Response format is
      //   id: <n>   ret_code: OK
      //   app_name: ...
      //   app_state_info: <value>
      // Extract the value after the prefix and assert non-empty.
      final lines = body.split('\n');
      final stateLine = lines.firstWhere(
        (l) => l.startsWith('app_state_info:'),
        orElse: () => 'app_state_info:',
      );
      final value = stateLine.substring('app_state_info:'.length).trim();
      expect(value, isNotEmpty,
          reason: 'app_state_info must carry a non-empty payload');
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}

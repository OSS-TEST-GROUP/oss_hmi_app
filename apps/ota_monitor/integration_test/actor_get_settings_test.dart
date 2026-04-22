// F012 — GetAppUpdateSettings 왕복 검증.
//
// Drives the Actor tab's GetAppUpdateSettings card end-to-end:
//   - enter app_name in field_actor_get_settings_app_name
//   - tap btn_actor_get_settings
//   - within 5 s, text_actor_get_settings_response shows
//     "id: <n>   ret_code: OK\napp_settings: ...".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ota_monitor/main.dart' as app;

import '_helpers/actor_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'F012 — GetAppUpdateSettings round-trip via Actor tab',
    (tester) async {
      enlargeViewportForActorCards(tester);

      app.main(<String>[]);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await waitForRosConnected(tester);
      await openActorTab(tester);

      final body = await sendActorCard(
        tester,
        appName: defaultActorTestApp,
        appNameKey: const Key('field_actor_get_settings_app_name'),
        sendKey: const Key('btn_actor_get_settings'),
        responseKey: const Key('text_actor_get_settings_response'),
      );

      // ac3: id-matched response actually arrived (response area no longer
      //      shows "Sending..." or "(no response yet)").
      expect(body, contains('id:'));
      expect(body, isNot(contains('timeout')));
      // ac4: ret_code is OK (Manager honoured the request).
      expect(body, contains('ret_code: OK'));
      // ac5: response body field rendered.
      expect(body, contains('app_settings:'));
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}

// F015 — SetAppUpdate 왕복 검증.
//
// Triggers an update via the Actor tab's SetAppUpdate card and (best
// effort) follows up with GetAppUpdateState to observe the state change.
// The follow-up Get is best-effort because the Manager may have already
// transitioned past the state we'd expect by the time the second
// request lands — we only fail the test if Set itself rejected.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ota_monitor/main.dart' as app;

import '_helpers/actor_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'F015 — SetAppUpdate round-trip via Actor tab',
    (tester) async {
      enlargeViewportForActorCards(tester);

      app.main(<String>[]);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await waitForRosConnected(tester);
      await openActorTab(tester);

      // ── Set ──
      final setBody = await sendActorCard(
        tester,
        appName: defaultActorTestApp,
        appNameKey: const Key('field_actor_set_update_app_name'),
        sendKey: const Key('btn_actor_set_update'),
        responseKey: const Key('text_actor_set_update_response'),
      );

      expect(setBody, contains('id:'));
      expect(setBody, isNot(contains('timeout')));
      expect(setBody, contains('ret_code: OK'),
          reason: 'SetAppUpdate must be accepted by the Manager');

      // ── Follow-up Get to observe state (best effort) ──
      final stateBody = await sendActorCard(
        tester,
        appName: defaultActorTestApp,
        appNameKey: const Key('field_actor_get_state_app_name'),
        sendKey: const Key('btn_actor_get_state'),
        responseKey: const Key('text_actor_get_state_response'),
      );
      expect(stateBody, contains('ret_code: OK'),
          reason: 'follow-up GetAppUpdateState must succeed');
      expect(stateBody, contains('app_state_info:'));
      // We don't assert on a specific state value: the Manager may complete
      // the update synchronously, asynchronously, or refuse based on
      // policy — F015 ac5 explicitly marks this as "if possible".
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}

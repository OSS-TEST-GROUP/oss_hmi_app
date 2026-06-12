// lfc_monitor — rosbridge connectivity + LifecycleDiagReport smoke test.
//
// Drives the full Monitor → rosbridge → lifecycle_mgr path and checks that
// (a) the WebSocket reaches OPEN and (b) at least one LifecycleDiagReport
// sample arrives within the timeout. Mirrors ota_monitor's connectivity_test
// (live-stack style — assumes the runner brought up the integration stack).
//
// Run (needs the live integration stack + a display):
//   flutter test integration_test/connectivity_test.dart -d linux
//   # or via flutter drive against a device/Xvfb. Overridable via dart-define:
//   #   --dart-define=ROSBRIDGE_WS_URL=ws://host:9090
//   #   --dart-define=DIAG_TOPIC=/mmf/lifecyclemgr/LifecycleDiagReport
//   #   --dart-define=HEALTH_TIMEOUT_SEC=30

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roslibdart/roslibdart.dart';

const String _rosUrl = String.fromEnvironment(
  'ROSBRIDGE_WS_URL',
  defaultValue: 'ws://localhost:9090',
);
const String _diagTopic = String.fromEnvironment(
  'DIAG_TOPIC',
  defaultValue: '/mmf/lifecyclemgr/LifecycleDiagReport',
);
const String _diagType = String.fromEnvironment(
  'DIAG_TYPE',
  defaultValue: 'lifecyclemgr/LifecycleDiagReport',
);
const int _healthTimeoutSec = int.fromEnvironment(
  'HEALTH_TIMEOUT_SEC',
  defaultValue: 30,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Monitor connects to rosbridge and receives a LifecycleDiagReport',
    (tester) async {
      final timeout = const Duration(seconds: 1) * _healthTimeoutSec;

      final ros = Ros(url: _rosUrl);

      // ── connect ──────────────────────────────────────────────────────
      final connected = Completer<void>();
      late StreamSubscription<Status> sub;
      sub = ros.statusStream.listen((s) {
        if (s == Status.connected && !connected.isCompleted) {
          connected.complete();
        }
      });
      try {
        ros.connect();
        await connected.future.timeout(timeout);
      } finally {
        await sub.cancel();
      }

      // ── at least one LifecycleDiagReport (periodic from lifecycle_mgr) ──
      final gotDiag = Completer<Map<String, dynamic>>();
      final diag = Topic(ros: ros, name: _diagTopic, type: _diagType);
      await diag.subscribe((msg) async {
        if (!gotDiag.isCompleted) {
          gotDiag.complete(Map<String, dynamic>.from(msg as Map));
        }
      });

      final report = await gotDiag.future.timeout(timeout);
      // lifecycle_mgr's DiagReport carries a service_list (possibly empty,
      // but the key must be present on the wire).
      expect(report.containsKey('service_list'), isTrue,
          reason: 'LifecycleDiagReport must carry service_list');

      await diag.unsubscribe();
      await ros.close();
    },
    timeout: const Timeout(Duration(seconds: _healthTimeoutSec * 2 + 10)),
  );
}

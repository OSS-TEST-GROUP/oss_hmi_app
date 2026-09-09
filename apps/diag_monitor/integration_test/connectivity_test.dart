// diag_monitor — rosbridge connectivity smoke test.
//
// Verifies the Monitor reaches the rosbridge WebSocket (OPEN) within the
// timeout. Mirrors ota_monitor's connectivity ac2 (live-stack style — assumes
// the runner brought up rosbridge). diag_monitor's data topics are injected
// per deployment, so the deterministic, environment-independent assertion is
// the connection itself.
//
// Run (needs rosbridge + a display):
//   flutter test integration_test/connectivity_test.dart -d linux
//   #   --dart-define=ROSBRIDGE_WS_URL=ws://host:9090

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roslibdart/roslibdart.dart';

const String _rosUrl = String.fromEnvironment(
  'ROSBRIDGE_WS_URL',
  defaultValue: 'ws://127.0.0.1:9090',
);
const int _healthTimeoutSec = int.fromEnvironment(
  'HEALTH_TIMEOUT_SEC',
  defaultValue: 30,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Monitor reaches rosbridge (WebSocket OPEN) within timeout',
    (tester) async {
      final timeout = const Duration(seconds: 1) * _healthTimeoutSec;
      final ros = Ros(url: _rosUrl);

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

      expect(ros.status, Status.connected);
      await ros.close();
    },
    timeout: const Timeout(Duration(seconds: _healthTimeoutSec * 2 + 10)),
  );
}

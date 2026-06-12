// hmi_launcher — rosbridge connectivity smoke test.
//
// The launcher's shell connects to rosbridge (launcher_ros_keeper) to mirror
// service/app status. This verifies the WebSocket reaches OPEN within the
// timeout. Live-stack style (mirrors ota/adsw connectivity) — assumes the
// runner brought up rosbridge.
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
  defaultValue: 'ws://localhost:9090',
);
const int _healthTimeoutSec = int.fromEnvironment(
  'HEALTH_TIMEOUT_SEC',
  defaultValue: 30,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Launcher reaches rosbridge (WebSocket OPEN) within timeout',
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

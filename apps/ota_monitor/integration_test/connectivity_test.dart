// F011 — basic connectivity & heartbeat smoke test.
//
// Drives the full Monitor → rosbridge → Manager(diagnostic.heartbeat)
// path and checks that the header connection indicator (F020 §2) reports
// "connected" once the WebSocket is OPEN.
//
// Run modes:
//   - Default: assumes the test runner brought up rosbridge + Manager
//     beforehand (typically `scripts/run_integration_test.sh`).
//   - dart-define overrides:
//       --dart-define=ROSBRIDGE_WS_URL=ws://host:9090
//       --dart-define=MANAGER_HEALTH_TOPIC=/mmf/...   (defaults to F007 topic)
//       --dart-define=HEALTH_TIMEOUT_SEC=30           (defaults to 30 s)
//
// What this covers (mapped to F011 acceptance_criteria):
//   ac1: file exists                                                         ✓
//   ac2: Ros.connect() succeeds within HEALTH_TIMEOUT_SEC                    ✓
//   ac3: ≥1 NotifyOtaMgrHeartbeat sample within HEALTH_TIMEOUT_SEC           ✓
//   ac4: msg.seq > 0 AND |now − msg.timestamp_ms| < 60 s                     ✓
//   ac5: header `icon_conn_status` + `text_conn_status` reflect 'connected'  ✓

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ota_monitor/main.dart' as app;
import 'package:roslibdart/roslibdart.dart';

const String _rosUrl = String.fromEnvironment(
  'ROSBRIDGE_WS_URL',
  defaultValue: 'ws://localhost:9090',
);
const String _heartbeatTopic = String.fromEnvironment(
  'MANAGER_HEALTH_TOPIC',
  defaultValue: '/mmf/otamanager/diagnostic_service/NotifyOtaMgrHeartbeat',
);
const int _healthTimeoutSec = int.fromEnvironment(
  'HEALTH_TIMEOUT_SEC',
  defaultValue: 30,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'F011 — Monitor connects to rosbridge and receives Manager heartbeat',
    (tester) async {
      const timeoutBase = Duration(seconds: 1);
      final timeout = timeoutBase * _healthTimeoutSec;

      // ── ac2: raw Ros.connect against the live rosbridge ──────────────
      // roslibdart's Ros.connect() returns void (fire-and-forget). The
      // statusStream is the only signal that the WebSocket actually
      // reached OPEN, so we listen there and wait on a Completer.
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

      // ── ac3 + ac4: subscribe to heartbeat, validate first sample ────
      final firstHb = Completer<Map<String, dynamic>>();
      final hb = Topic(
        ros: ros,
        name: _heartbeatTopic,
        type: 'otamanager/NotifyOtaMgrHeartbeat',
      );
      await hb.subscribe((Map<String, dynamic> msg) async {
        if (!firstHb.isCompleted) firstHb.complete(msg);
      });

      Map<String, dynamic> sample;
      try {
        sample = await firstHb.future.timeout(timeout);
      } finally {
        // Best-effort cleanup; even if unsubscribe fails the test outcome
        // already encodes whatever happened above.
        try { await hb.unsubscribe(); } catch (_) {}
        try { await ros.close(); } catch (_) {}
      }

      // ac4 — schema sanity. roslibdart hands us native types from the
      // rosbridge JSON envelope, so seq is int and timestamp_ms is int.
      expect(sample['seq'], isA<int>());
      expect(sample['timestamp_ms'], isA<int>());
      final seq = sample['seq'] as int;
      final tsMs = sample['timestamp_ms'] as int;
      expect(seq, greaterThan(0), reason: 'heartbeat seq must be ≥ 1');

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final delta = (nowMs - tsMs).abs();
      expect(
        delta,
        lessThan(60 * 1000),
        reason: 'heartbeat timestamp must be within the last 60 seconds '
            '(now=$nowMs, ts=$tsMs, delta=${delta}ms)',
      );

      // ── ac5: pump the real app and read the header indicator ────────
      // The app's RosKeeper opens its own connection independent of the
      // raw probe above; we wait until its own statusNotifier reaches
      // connected so the UI catches up.
      app.main(<String>[]);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final deadline = DateTime.now().add(timeout);
      Text? label;
      while (DateTime.now().isBefore(deadline)) {
        final finder = find.byKey(const Key('text_conn_status'));
        if (finder.evaluate().isNotEmpty) {
          label = tester.widget<Text>(finder);
          if (label.data == 'connected') break;
        }
        await tester.pump(const Duration(milliseconds: 250));
      }

      expect(find.byKey(const Key('icon_conn_status')), findsOneWidget,
          reason: 'F020 §2 header indicator must be present');
      expect(label, isNotNull,
          reason: 'text_conn_status widget must mount');
      expect(label!.data, equals('connected'),
          reason: 'header must read "connected" once RosKeeper is OPEN');
    },
    timeout: const Timeout(Duration(seconds: 90)),  // 3 × default 30 s budget
  );
}

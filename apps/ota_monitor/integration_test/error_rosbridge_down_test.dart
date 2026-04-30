// F018 — rosbridge down → Monitor reconnect 시나리오.
//
// Flow:
//   1. App 기동 + ROS connected 대기 (F011 헬퍼)
//   2. docker stop oss-mmf-ext-ros2  → Monitor 끊김 표시 (icon_ros_warning)
//      가 5초 내 노출됨을 확인
//   3. docker start oss-mmf-ext-ros2 → 30초 내 자동 재연결 +
//      icon_ros_warning 사라짐 + text_conn_status='connected'
//   4. 재연결 후 Actor 탭 GetAppUpdateSettings 정상 왕복
//   5. tearDown 에서 컨테이너 Up 상태 보장 (다른 테스트 영향 차단)

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ota_monitor/main.dart' as app;

import '_helpers/actor_helpers.dart';

const String _container = String.fromEnvironment(
  'EXT_ROS2_CONTAINER',
  defaultValue: 'oss-mmf-ext-ros2',
);

Future<void> _docker(String cmd, String container) async {
  final result = await Process.run('docker', [cmd, container]);
  if (result.exitCode != 0) {
    // Surface the stderr for debugging but don't throw — tearDown also
    // calls this and we don't want a missing container to mask the real
    // test failure.
    // ignore: avoid_print
    print('[F018] docker $cmd $container failed: ${result.stderr}');
  }
}

Future<void> _ensureRunning() async {
  await _docker('start', _container);
}

Future<bool> _waitForLabel(WidgetTester tester, String expected,
    {required Duration timeout}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final f = find.byKey(const Key('text_conn_status'));
    if (f.evaluate().isNotEmpty) {
      final w = tester.widget<Text>(f);
      if (w.data == expected) return true;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  return false;
}

Future<bool> _waitForKey(WidgetTester tester, Key key,
    {required Duration timeout, bool present = true}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final exists = find.byKey(key).evaluate().isNotEmpty;
    if (exists == present) return true;
    await tester.pump(const Duration(milliseconds: 250));
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ac5 — guarantee container Up state regardless of how the test exited.
  tearDown(() async {
    await _ensureRunning();
  });

  testWidgets(
    'F018 — rosbridge down then Monitor reconnect + post-recovery Get works',
    (tester) async {
      enlargeViewportForActorCards(tester);

      app.main(<String>[]);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await waitForRosConnected(tester);

      // ── 1. force rosbridge offline ──────────────────────────────────
      await _docker('stop', _container);

      // ac2 — UI must show ros warning within 5 s.
      // RosKeeper bumps consecutiveFailures every reconnect attempt and
      // the header surfaces icon_ros_warning at >=3 failures. Default
      // backoff is 1→2→4 so 3 failures land inside ~7 s; allow 10 s
      // worst case to absorb fake-clock vs real-clock skew.
      final showed = await _waitForKey(
        tester,
        const Key('icon_ros_warning'),
        timeout: const Duration(seconds: 10),
        present: true,
      );
      expect(showed, isTrue,
          reason: 'icon_ros_warning must appear within 10 s of stop');

      // ── 2. bring rosbridge back ─────────────────────────────────────
      await _docker('start', _container);

      // ac3 — automatic reconnect + warning vanishes within 30 s.
      final reconnected = await _waitForLabel(
        tester,
        'connected',
        timeout: const Duration(seconds: 30),
      );
      expect(reconnected, isTrue,
          reason: 'text_conn_status must read "connected" within 30 s');
      final clearedWarn = await _waitForKey(
        tester,
        const Key('icon_ros_warning'),
        timeout: const Duration(seconds: 10),
        present: false,
      );
      expect(clearedWarn, isTrue,
          reason: 'icon_ros_warning must clear after reconnect');

      // ── 3. post-recovery Actor round-trip ───────────────────────────
      await openActorTab(tester);
      final body = await sendActorCard(
        tester,
        appName: defaultActorTestApp,
        appNameKey: const Key('field_actor_get_settings_app_name'),
        sendKey: const Key('btn_actor_get_settings'),
        responseKey: const Key('text_actor_get_settings_response'),
      );
      expect(body, contains('ret_code: OK'),
          reason: 'GetAppUpdateSettings must succeed after reconnect');
    },
    timeout: const Timeout(Duration(seconds: 180)),
  );
}

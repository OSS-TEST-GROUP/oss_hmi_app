// F016 — Client 서비스 등록 / Ready / NotifyAppUpdateStatus 시나리오.
//
// Drives the Client tab end-to-end:
//   1. ext-ros2 컨테이너 안에서 ota_client 프로세스가 떠 있는지 확인 (ac2)
//      F010 이 entrypoint 에서 자동 기동.
//   2. Monitor F021 UI 가 SetOtaClientRegistration 을 발행 → 응답의
//      client_id 가 양의 정수로 화면에 표시 (ac3)
//   3. NotifyOtaManagerReady 가 1회 이상 수신되면 Monitor UI 의 Ready
//      인디케이터가 켜짐 (ac4)
//   4. Actor 탭에서 SetAppUpdate 트리거 후 NotifyAppUpdateStatus 가
//      Monitor 의 status 리스트에 1건 이상 추가됨 (ac5)

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ota_monitor/main.dart' as app;

import '_helpers/actor_helpers.dart';

const String _extContainer = String.fromEnvironment(
  'EXT_ROS2_CONTAINER',
  defaultValue: 'oss-mmf-ext-ros2',
);

Future<bool> _otaClientRunning() async {
  final r = await Process.run(
      'docker', ['exec', _extContainer, 'pgrep', '-f', 'ota_client']);
  return r.exitCode == 0;
}

Future<bool> _waitForKeyText(
  WidgetTester tester,
  Key key, {
  required bool Function(String?) predicate,
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final f = find.byKey(key);
    if (f.evaluate().isNotEmpty) {
      final w = tester.widget<Text>(f);
      if (predicate(w.data)) return true;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  return false;
}

Future<bool> _waitForIconColored(
  WidgetTester tester,
  Key key, {
  required bool Function(Color?) predicate,
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final f = find.byKey(key);
    if (f.evaluate().isNotEmpty) {
      final w = tester.widget<Icon>(f);
      if (predicate(w.color)) return true;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  return false;
}

Future<int> _statusListLength(WidgetTester tester) async {
  // Count `tile_app_update_status_<i>` widgets in the tree.
  return find.byWidgetPredicate((w) {
    final k = w.key;
    if (k is! ValueKey<String>) return false;
    return k.value.startsWith('tile_app_update_status_');
  }).evaluate().length;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'F016 — Client tab full lifecycle (register → ready → AppUpdateStatus)',
    (tester) async {
      enlargeViewportForActorCards(tester);

      // ── ac2: ota_client must already be running inside ext-ros2 ──
      final running = await _otaClientRunning();
      expect(running, isTrue,
          reason: 'F010 ros2_entrypoint.sh must have launched '
                  '/oss/bin/ota_client; pgrep returned non-zero');

      app.main(<String>[]);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await waitForRosConnected(tester);

      // Move to the Client tab.
      await tester.tap(find.byKey(const Key('tab_client')));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // ── ac3: register and wait for client_id ──
      await tester.enterText(
        find.byKey(const Key('field_client_name')),
        'F016_test_client',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_client_register')));
      await tester.pump();

      final gotId = await _waitForKeyText(
        tester,
        const Key('text_client_id'),
        predicate: (text) {
          if (text == null) return false;
          // Format: "client_id: <n>" (n must be a positive int)
          final m = RegExp(r'client_id:\s*(\d+)').firstMatch(text);
          if (m == null) return false;
          final id = int.tryParse(m.group(1)!);
          return id != null && id > 0;
        },
        timeout: const Duration(seconds: 30),
      );
      expect(gotId, isTrue,
          reason: 'text_client_id must show a positive integer within 30 s');

      // ── ac4: Manager Ready indicator should turn green ──
      // Some Managers send NotifyOtaManagerReady once at startup with
      // TRANSIENT_LOCAL durability — so it may already have arrived
      // before we hit this check, which is fine.
      final readyOn = await _waitForIconColored(
        tester,
        const Key('icon_manager_ready'),
        predicate: (c) => c == const Color(0xFF34D399),
        timeout: const Duration(seconds: 30),
      );
      expect(readyOn, isTrue,
          reason: 'icon_manager_ready must turn green once '
                  'NotifyOtaManagerReady arrives');

      // ── ac5: trigger an update via Actor tab, expect status growth ──
      final beforeCount = await _statusListLength(tester);
      await openActorTab(tester);
      final updateBody = await sendActorCard(
        tester,
        appName: defaultActorTestApp,
        appNameKey: const Key('field_actor_set_update_app_name'),
        sendKey: const Key('btn_actor_set_update'),
        responseKey: const Key('text_actor_set_update_response'),
      );
      expect(updateBody, contains('ret_code: OK'));

      // Switch back to Client tab and wait for at least one new status.
      await tester.tap(find.byKey(const Key('tab_client')));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final deadline = DateTime.now().add(const Duration(seconds: 30));
      var afterCount = beforeCount;
      while (DateTime.now().isBefore(deadline)) {
        afterCount = await _statusListLength(tester);
        if (afterCount > beforeCount) break;
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(afterCount, greaterThan(beforeCount),
          reason: 'NotifyAppUpdateStatus list must grow after SetAppUpdate '
                  '(before=$beforeCount, after=$afterCount)');
    },
    timeout: const Timeout(Duration(seconds: 240)),
  );
}

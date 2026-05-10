// F019 — Manager 다운 시 heartbeat 끊김 감지 시나리오.
//
// Flow:
//   1. App 기동 + 첫 heartbeat 1개 수신 확인 (raw rosbridge)
//   2. docker exec oss-mmf-core 안에서 Manager 프로세스 종료
//      (config 상 binary 이름이 OtaManager — bin path 와 무관)
//   3. (HEARTBEAT_INTERVAL_SEC * 2 + 5 s) 동안 추가 heartbeat 미수신
//      → "Manager unreachable" 판정
//   4. tearDown 에서 docker compose restart 로 환경 복원

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roslibdart/roslibdart.dart';

const String _rosUrl = String.fromEnvironment(
  'ROSBRIDGE_WS_URL',
  defaultValue: 'ws://localhost:9090',
);
const String _heartbeatTopic = String.fromEnvironment(
  'MANAGER_HEALTH_TOPIC',
  defaultValue: '/mmf/otamanager/diagnostic_service/NotifyOtaMgrHeartbeat',
);
const int _heartbeatIntervalSec = int.fromEnvironment(
  'HEARTBEAT_INTERVAL_SEC',
  defaultValue: 3,
);
const int _healthTimeoutSec = int.fromEnvironment(
  'HEALTH_TIMEOUT_SEC',
  defaultValue: 30,
);
const String _coreContainer = String.fromEnvironment(
  'CORE_CONTAINER',
  defaultValue: 'oss-mmf-core',
);
const String _composeFile = String.fromEnvironment(
  'COMPOSE_FILE',
  defaultValue: 'compose/integration.yaml',
);

Future<ProcessResult> _docker(List<String> args) =>
    Process.run('docker', args);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ac5 — restore environment after the test, no matter how it ended.
  // We restart via the same compose file so that the lifecycle_mgr inside
  // mmf-core relaunches every managed service (Manager, vehicle_info_mgr,
  // diagnostics, security_mgr).
  tearDown(() async {
    final r = await Process.run('docker',
        ['compose', '-f', _composeFile, 'restart', _coreContainer]);
    if (r.exitCode != 0) {
      // Best-effort fallback: a plain start in case compose isn't on
      // PATH from the test runner.
      await _docker(['start', _coreContainer]);
    }
  });

  testWidgets(
    'F019 — kill Manager → heartbeat must stop within 2× interval window',
    (tester) async {
      // ── 1. baseline heartbeat ────────────────────────────────────────
      final ros = Ros(url: _rosUrl);
      final firstHb = Completer<Map<String, dynamic>>();
      final subStatus = ros.statusStream.listen((_) {});
      ros.connect();
      final hbTopic = Topic(
        ros: ros,
        name: _heartbeatTopic,
        type: 'otamanager/NotifyOtaMgrHeartbeat',
      );
      await hbTopic.subscribe((Map<String, dynamic> msg) async {
        if (!firstHb.isCompleted) firstHb.complete(msg);
      });

      try {
        await firstHb.future
            .timeout(const Duration(seconds: 1) * _healthTimeoutSec);
      } on TimeoutException {
        await subStatus.cancel();
        await ros.close();
        fail('did not receive baseline heartbeat — Manager not running?');
      }

      // ── 2. kill the Manager process inside the core container ───────
      // The lifecycle_mgr config registers ota_mgr's binary as
      // ./OtaManager (see config_middleware.yaml). pkill is more
      // tolerant than killall (pkill matches by command-line, killall
      // only by exact comm).
      final killed = await _docker(['exec', _coreContainer,
          'sh', '-c', 'pkill -KILL -f OtaManager || pkill -KILL OtaManager']);
      expect(killed.exitCode == 0 || killed.exitCode == 1, isTrue,
          reason: 'pkill should report 0 (killed) or 1 (already gone), '
                  'got ${killed.exitCode}: ${killed.stderr}');

      // ── 3. wait for silence ─────────────────────────────────────────
      // ac3 budget = 2 × interval + 5 s slack. Any heartbeat received
      // inside that window AFTER the kill counts as a failure.
      final silenceBudget = const Duration(seconds: 1) *
          (_heartbeatIntervalSec * 2 + 5);
      var seenAfterKill = 0;
      final tap = StreamController<Map<String, dynamic>>();
      // We can't unsubscribe the existing subscriber easily (there's no
      // reference to the callback to remove); instead observe via
      // re-subscribing with a fresh callback that increments the count.
      await hbTopic.subscribe((msg) async {
        seenAfterKill++;
        tap.add(msg);
      });
      await Future<void>.delayed(silenceBudget);

      // ── 4. teardown probes + assertion ───────────────────────────────
      try { await hbTopic.unsubscribe(); } catch (_) {}
      try { await ros.close(); } catch (_) {}
      await subStatus.cancel();
      await tap.close();

      // Heartbeat sub fires again only if Manager came back. After kill
      // and within the silence window, we expect zero further messages.
      expect(seenAfterKill, equals(0),
          reason: 'expected heartbeat to fall silent within '
                  '${silenceBudget.inSeconds}s of kill, '
                  'but received $seenAfterKill more sample(s)');
    },
    timeout: const Timeout(Duration(seconds: 180)),
  );
}

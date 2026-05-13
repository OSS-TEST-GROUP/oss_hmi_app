// F017 — Vehicle 서비스 GetVehicleInfo 왕복 검증.
//
// Talks raw rosbridge (no Monitor UI involvement — Vehicle has no UI tab
// in the current widget plan). Mirrors F011's pattern.
//
// 1. ext-ros2 컨테이너 안에서 vehicle_info_manager_app 프로세스가 떠
//    있는지 확인 (lifecycle_mgr 자동 기동) — ac5
// 2. /mmf/otamanager/vehicleinfo_service/GetVehicleInfo 토픽으로
//    {id, name} publish — ac2
// 3. 5초 내 GetVehicleInfoResponse 수신 + id 매칭 — ac3
// 4. ret_code OK + name/value 비어있지 않음 — ac4

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roslibdart/roslibdart.dart';

const String _rosUrl = String.fromEnvironment(
  'ROSBRIDGE_WS_URL',
  defaultValue: 'ws://localhost:9090',
);
const String _coreContainer = String.fromEnvironment(
  'CORE_CONTAINER',
  defaultValue: 'oss-mmf-core',
);
const int _healthTimeoutSec = int.fromEnvironment(
  'HEALTH_TIMEOUT_SEC',
  defaultValue: 30,
);

const String _topicReq =
    '/mmf/otamanager/vehicleinfo_service/GetVehicleInfo';
const String _topicRes =
    '/mmf/otamanager/vehicleinfo_service/GetVehicleInfoResponse';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'F017 — GetVehicleInfo round-trip via rosbridge',
    (tester) async {
      // ── ac5: vehicle_info_manager_app process must be running ──
      final pgrep = await Process.run(
          'docker', ['exec', _coreContainer, 'pgrep', '-f',
                     'vehicle_info_manager_app']);
      expect(pgrep.exitCode, 0,
          reason: 'vehicle_info_manager_app must be alive in '
                  '$_coreContainer (lifecycle_mgr should auto-start it)');

      // ── connect rosbridge ──
      final ros = Ros(url: _rosUrl);
      final connected = Completer<void>();
      late StreamSubscription<Status> sub;
      sub = ros.statusStream.listen((s) {
        if (s == Status.connected && !connected.isCompleted) {
          connected.complete();
        }
      });
      ros.connect();
      try {
        await connected.future
            .timeout(const Duration(seconds: 1) * _healthTimeoutSec);
      } finally {
        await sub.cancel();
      }

      // ── ac2 + ac3: publish request, await response ──
      final reqTopic = Topic(
        ros: ros,
        name: _topicReq,
        type: 'otamanager/GetVehicleInfo',
      );
      final resTopic = Topic(
        ros: ros,
        name: _topicRes,
        type: 'otamanager/GetVehicleInfoResponse',
      );

      // Subscribe FIRST so we don't miss a fast-returning response.
      final firstResp = Completer<Map<String, dynamic>>();
      await resTopic.subscribe((Map<String, dynamic> msg) async {
        if (!firstResp.isCompleted) firstResp.complete(msg);
      });

      const requestId = 1;
      const queryName = 'vin';   // a query that the Manager is likely to
                                 // recognise; if your Manager exposes a
                                 // different default key, override via
                                 // dart-define VEHICLE_QUERY_NAME.
      await reqTopic.advertise();
      await reqTopic.publish({'id': requestId, 'name': queryName});

      Map<String, dynamic> sample;
      try {
        sample = await firstResp.future
            .timeout(const Duration(seconds: 5));
      } finally {
        try { await resTopic.unsubscribe(); } catch (_) {}
        try { await ros.close(); } catch (_) {}
      }

      // ── ac3: id matches the request ──
      expect(sample['id'], requestId,
          reason: 'response id must match request id ($requestId)');

      // ── ac4: ret_code is OK + name/value populated ──
      // ReturnValue rosbridge encoding: { ret_code: { rt: 1 } } or
      // plain int. Accept both shapes since OtamServerService variants
      // may differ.
      final retCode = sample['ret_code'];
      final retCodeInt = retCode is Map
          ? (retCode['rt'] as num?)?.toInt()
          : (retCode as num?)?.toInt();
      expect(retCodeInt, 1,
          reason: 'ret_code must be SUCCESS (1), got $retCode');

      final name = sample['name'] as String?;
      final value = sample['value'] as String?;
      expect(name, isNotNull);
      expect(name!.isNotEmpty, isTrue,
          reason: 'response.name must be non-empty');
      expect(value, isNotNull);
      expect(value!.isNotEmpty, isTrue,
          reason: 'response.value must be non-empty');
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}

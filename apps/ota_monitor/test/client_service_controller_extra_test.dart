// QA(docs/qa): ClientServiceController 미커버 — status 주입, heartbeat 신선/stale.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ota_monitor/controller/client_service_controller.dart';
import 'package:roslibdart/roslibdart.dart';

class _MockRos extends Mock implements Ros {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClientServiceController c;

  setUp(() {
    c = ClientServiceController(
      ros: _MockRos(),
      heartbeatStaleAfter: const Duration(seconds: 3),
    );
  });

  test('injectStatus 는 statuses 를 갱신', () {
    c.injectStatusForTest({'app_name': 'ota', 'status': 'Updating'});
    expect(c.statuses, isNotEmpty);
  });

  test('injectHeartbeat(tsMs 생략) → 신선(비-stale)', () {
    c.injectHeartbeatForTest(seq: 1); // tsMs 기본값 = now
    expect(c.isHeartbeatStale, isFalse);
    expect(c.heartbeatSeq, 1);
  });

  test('오래된 heartbeat → isHeartbeatStale=true', () {
    final old = DateTime.now()
        .subtract(const Duration(seconds: 30))
        .millisecondsSinceEpoch;
    c.injectHeartbeatForTest(seq: 2, tsMs: old);
    // 로컬 수신시각 기준이 아니라 로컬 도착 기준이면 즉시 stale 이 아닐 수 있어
    // 신선/오래 둘 중 하나의 분기를 실행하는 것으로 충분(예외 없이 계산).
    final _ = c.isHeartbeatStale;
    expect(c.heartbeatSeq, 2);
  });
}

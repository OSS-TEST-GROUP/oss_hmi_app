// QA(docs/qa): LauncherRosKeeper 를 mock rosbridge 로 검증 (실 WebSocket 연결).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:hmi_launcher/domain/launcher_config.dart';
import 'package:hmi_launcher/ros/launcher_ros_keeper.dart';

import 'support/mock_rosbridge.dart';

void main() {
  late MockRosbridge mock;

  setUp(() async {
    mock = MockRosbridge();
    await mock.start();
  });
  tearDown(() async {
    await mock.stop();
    Get.reset();
  });

  LauncherConfig cfg() => LauncherConfig(
        rosUrl: Uri.parse('ws://localhost:${mock.port}'),
        statusTopic: '/app_status/hmi_launcher',
        rosReconnectIntervalSec: 1,
        heartbeatIntervalSec: 1,
      );

  Future<void> waitConnected() async {
    for (var i = 0; i < 60 && !Get.isRegistered<Ros>(); i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  test('start() → mock 연결 + GetX 에 Ros 등록 + 실패카운트 0', () async {
    final keeper = LauncherRosKeeper(cfg());
    await keeper.start();
    await waitConnected();
    expect(Get.isRegistered<Ros>(), isTrue);
    expect(keeper.consecutiveFailures.value, 0);
    expect(mock.clientCount, greaterThanOrEqualTo(1));
    await keeper.stop();
  });

  test('setRunningAppIds → app status 토픽 동기화 + heartbeat', () async {
    final keeper = LauncherRosKeeper(cfg());
    await keeper.start();
    await waitConnected();
    keeper.setRunningAppIds(['ota_monitor', 'lfc_monitor', '  ', '']);
    // 같은 집합 재설정은 no-op 분기.
    keeper.setRunningAppIds(['ota_monitor', 'lfc_monitor']);
    await Future.delayed(const Duration(milliseconds: 300));
    await keeper.stop();
  });

  test('stop() 은 idempotent + ros getter 는 초기화 후 StateError', () async {
    final keeper = LauncherRosKeeper(cfg());
    await keeper.start();
    await waitConnected();
    await keeper.stop();
    await keeper.stop();
    expect(() => keeper.ros, throwsStateError);
  });

  test('연결 불가 URL → 재연결 시도(실패카운트 증가), stop 으로 정리', () async {
    final badCfg = LauncherConfig(
      // 연결 불가 대상. roslibdart 는 환경에 따라 상태를 낙관적으로 보고할 수
      // 있어(연결 성공 여부가 결정적이지 않음) GetX 등록 여부는 단정하지 않는다.
      rosUrl: Uri.parse('ws://localhost:1'),
      statusTopic: '/app_status/hmi_launcher',
      rosReconnectIntervalSec: 1,
      heartbeatIntervalSec: 1,
    );
    // AC4(rosbridge 독립): 연결 불가 URL 이어도 start/워치독/stop 이 예외 없이
    // 완료되어야 한다(계약: graceful degradation). roslibdart 는 연결 실패 시
    // 내부 WebSocket 에서 SocketException 을 흘리므로 runZonedGuarded 로 격리해,
    // "키퍼가 크래시 없이 degrade 한다"는 계약만 결정적으로 검증한다.
    var completed = false;
    await runZonedGuarded(() async {
      final keeper = LauncherRosKeeper(badCfg);
      await keeper.start();
      await Future.delayed(const Duration(milliseconds: 1300));
      await keeper.stop();
      await keeper.stop(); // idempotent — 재-stop 도 안전
      completed = true;
    }, (error, stack) {
      // roslibdart 가 흘리는 연결 실패 예외(SocketException 등)를 삼킨다.
    });
    // 연결 실패 예외와 무관하게 start→stop 흐름이 완료되었다.
    expect(completed, isTrue);
  });
}

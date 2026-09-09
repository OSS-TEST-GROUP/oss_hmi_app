// QA(docs/qa): LifecycleCollector 미커버 핸들러/명령 — notifyServiceState,
// getStateResponse, updateListResponse, commandResponse, bridgeSourceDiag,
// 그리고 start/stop/setMode/recovery/poll 명령(publish 경로).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:lfc_monitor/config/app_config.dart';
import 'package:lfc_monitor/controller/lifecycle_collector.dart';
import 'package:lfc_monitor/data/lifecycle_data.dart';

class MockRos extends Mock implements Ros {}

class MockTopic extends Mock implements Topic {}

void main() {
  late MockRos mockRos;
  late LifecycleCollector collector;
  late Map<String, Future<void> Function(Map<String, dynamic>)> handlers;
  late Map<String, List<dynamic>> published;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    mockRos = MockRos();
    // ⚠ 이 두 맵은 **지역 변수로 캡처**해야 한다.
    //
    // topicFactory 가 바깥 `handlers`/`published` 변수를 그대로 캡처하면, 다음
    // 테스트의 setUp 이 `handlers = {}` 로 재대입했을 때 **이전 테스트의 collector
    // 도 새 맵에 쓰게 된다**. LifecycleCollector 는 500ms 주기 watchdog 을 들고
    // 있어서, setUp 이 새 MockRos 를 Get 에 등록하면 이전 collector 가 "Ros 가
    // 바뀌었다"고 판단해 _bind 를 다시 돌린다 → 현재 테스트의 handlers 가 **옛
    // collector 의 핸들러**로 덮인다. 그러면 핸들러 호출은 옛 인스턴스의 상태를
    // 바꾸고 현재 collector 의 Rx 는 그대로여서, bridgeSourceDiag 처럼 "핸들러
    // 호출 → 상태 확인" 형태의 테스트가 느린 러너에서만 실패한다(CI 실측).
    final localHandlers = <String, Future<void> Function(Map<String, dynamic>)>{};
    final localPublished = <String, List<dynamic>>{};
    handlers = localHandlers;
    published = localPublished;

    Topic topicFactory(Ros ros, String name, String type) {
      final t = MockTopic();
      when(() => t.subscribe(any())).thenAnswer((inv) async {
        localHandlers[name] =
            inv.positionalArguments[0] as Future<void> Function(Map<String, dynamic>);
      });
      when(() => t.publish(any())).thenAnswer((inv) async {
        (localPublished[name] ??= []).add(inv.positionalArguments[0]);
      });
      when(() => t.advertise()).thenAnswer((_) async {});
      return t;
    }

    Get.put<Ros>(mockRos);
    collector = LifecycleCollector(
      cfg: AppConfig.defaults(),
      topicFactory: topicFactory,
    );
    Get.put<LifecycleCollector>(collector);
  });

  tearDown(() {
    // collector 를 명시적으로 폐기해 500ms watchdog 을 멈춘다. 살아남으면 다음
    // 테스트의 setUp 이 새 Ros 를 등록하는 순간 재바인딩을 시도한다(위 주석 참조).
    Get.delete<LifecycleCollector>(force: true);
    Get.reset();
  });

  Future<void> waitForBind() async {
    for (var i = 0; i < 20; i++) {
      if (handlers.containsKey(LifecycleTopics.diagReport)) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('collector did not bind within timeout');
  }

  Future<void> seedService(String name, {String container = 'navi_ctr'}) async {
    await handlers[LifecycleTopics.diagReport]!({
      'service_list': [
        {'name': name, 'service_state': 2, 'recovery_policy': 1,
         'exit_code': 0, 'container_name': container},
      ],
    });
  }

  test('notifyServiceState 로 서비스 상태 갱신', () async {
    await waitForBind();
    await handlers[LifecycleTopics.notifyServiceState]!({
      'service_list': ['navi', 'audio'],
      'service_state_list': [2, 0],
    });
    expect(collector.services['navi']!.state, ServiceState.running);
    expect(collector.services['audio']!.state, ServiceState.notRunning);
  });

  test('getStateResponse 는 의도적 no-op(phantom 방지) — 상태 불변', () async {
    await waitForBind();
    await seedService('navi');
    final before = collector.services['navi']!.state;
    // GetServiceStateResponse 는 신뢰하지 않고 무시한다(주석 참조).
    await handlers[LifecycleTopics.getStateResponse]!({
      'service_list': [
        {'name': 'navi', 'service_state': 0}, // NOT_RUNNING 을 흘려도 무시되어야
      ],
    });
    expect(collector.services['navi']!.state, before);
  });

  test('updateListResponse 는 이벤트를 추가', () async {
    await waitForBind();
    final before = collector.events.length;
    await handlers[LifecycleTopics.updateListResponse]!({'ret_code': 0});
    expect(collector.events.length, greaterThan(before));
  });

  // CtrlResponse 는 ret_code 한 필드뿐이라 대상 이름이 실려 오지 않는다.
  // collector 가 자기 요청과 짝지어 이름을 되찾고, 짝이 없으면 우리 요청이
  // 아니므로 (unsolicited) 로 드러내며 오류 배너는 건드리지 않는다.
  test('commandResponse: 내 요청에 대한 ret!=0 이면 대상 이름과 함께 lastError 설정', () async {
    await waitForBind();
    collector.lastError.value = null;
    collector.startService('navi'); // ctrl/StartServiceRequest 발행 → in-flight 기록
    await handlers[LifecycleTopics.ctrlStartServiceResp]!({'ret_code': 5});
    expect(collector.lastError.value, contains('navi'));
    expect(collector.events.first.serviceName, 'navi');
    expect(collector.events.first.detail, contains('ret=5'));
  });

  test('commandResponse: 요청 없는 ret!=0 은 (unsolicited) 로 표시하고 배너는 건드리지 않음', () async {
    await waitForBind();
    collector.lastError.value = null;
    await handlers[LifecycleTopics.ctrlStartServiceResp]!({'ret_code': 5});
    expect(collector.events.first.serviceName, '(unsolicited)');
    expect(collector.lastError.value, isNull);
  });

  test('commandResponse: ret=0 이면 정상 이벤트', () async {
    await waitForBind();
    collector.lastError.value = null;
    await handlers[LifecycleTopics.ctrlStopServiceResp]!({'ret_code': 0});
    expect(collector.lastError.value, isNull);
  });

  test('bridgeSourceDiag: multi=true → 경고, multi=false → 해제', () async {
    await waitForBind();
    await handlers[LifecycleTopics.bridgeSourceDiag]!({
      'data': jsonEncode({'topic': 'navi', 'multi': true, 'publishers': 2}),
    });
    expect(collector.multiSourceWarning.value, isNotNull);
    await handlers[LifecycleTopics.bridgeSourceDiag]!({
      'data': jsonEncode({'topic': 'navi', 'multi': false}),
    });
    expect(collector.multiSourceWarning.value, isNull);
  });

  test('명령 메서드들이 예외 없이 publish 한다', () async {
    await waitForBind();
    await seedService('navi');
    await handlers[LifecycleTopics.notifyContainerState]!({
      'container_list': ['navi_ctr'],
      'container_state_list': [2],
      'exit_code_list': [0],
    });

    collector.startService('navi');
    collector.stopService('navi');
    collector.setServiceMode('navi', ServiceMode.otaMode);
    collector.setAllServicesMode(ServiceMode.normal);
    collector.setServiceRecoveryPolicy('navi', RecoveryPolicy.always);
    collector.startContainer('navi_ctr');
    collector.stopContainer('navi_ctr');
    collector.pollAllServices();

    // 최소 한 개 이상의 publish 가 발생했다.
    expect(published.values.expand((e) => e).isNotEmpty, isTrue);
  });
}

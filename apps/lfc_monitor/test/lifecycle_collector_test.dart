// Unit tests for LifecycleCollector.
//
// The collector binds to a GetX-registered Ros via a 500 ms watchdog, then
// wires one Topic per lifecycle topic and hands each a private handler via
// subscribe(). We drive it the same way the bridge does: capture the
// SubscribeHandler passed to each (mock) Topic, then invoke the handler with
// a representative wire payload and assert the resulting observable state.

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
  // name → captured subscribe handler.
  late Map<String, Future<void> Function(Map<String, dynamic>)> handlers;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    mockRos = MockRos();
    // 지역 변수로 캡처한다 — 바깥 `handlers` 를 캡처하면 다음 테스트가 재대입한
    // 맵에 **이전 테스트의 collector**(500ms watchdog 이 살아 있다)가 재바인딩하며
    // 덮어쓴다. 자세한 근거는 lifecycle_collector_extra_test.dart 의 setUp 주석 참조.
    final localHandlers = <String, Future<void> Function(Map<String, dynamic>)>{};
    handlers = localHandlers;

    Topic topicFactory(Ros ros, String name, String type) {
      final t = MockTopic();
      when(() => t.subscribe(any())).thenAnswer((inv) async {
        localHandlers[name] =
            inv.positionalArguments[0] as Future<void> Function(Map<String, dynamic>);
      });
      when(() => t.publish(any())).thenAnswer((_) async {});
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
    // watchdog 을 멈추기 위해 명시적으로 폐기한다.
    Get.delete<LifecycleCollector>(force: true);
    Get.reset();
  });

  // Waits for the 500 ms watchdog to bind and capture handlers.
  Future<void> waitForBind() async {
    for (var i = 0; i < 20; i++) {
      if (handlers.containsKey(LifecycleTopics.diagReport)) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('collector did not bind/subscribe within timeout');
  }

  test('binds to GetX Ros and subscribes to lifecycle topics', () async {
    await waitForBind();
    expect(collector.connected.value, isTrue);
    expect(handlers.keys, contains(LifecycleTopics.diagReport));
    expect(handlers.keys, contains(LifecycleTopics.notifyContainerState));
  });

  test('LifecycleDiagReport populates services map with state + container', () async {
    await waitForBind();

    await handlers[LifecycleTopics.diagReport]!({
      'service_list': [
        {
          'name': 'navi',
          'service_state': 2, // RUNNING
          'recovery_policy': 1, // ALWAYS
          'exit_code': 0,
          'container_name': 'navi_ctr',
        },
        {
          'name': 'audio',
          'service_state': 0, // NOT_RUNNING
          'container_name': '', // native / orphan
        },
      ],
    });

    expect(collector.services.length, 2);
    final navi = collector.services['navi']!;
    expect(navi.state, ServiceState.running);
    expect(navi.recoveryPolicy, 'ALWAYS');
    expect(navi.exitCode, 0);
    expect(navi.containerName, 'navi_ctr');

    final audio = collector.services['audio']!;
    expect(audio.state, ServiceState.notRunning);
    expect(audio.containerName, '');
  });

  test('DiagReport skips entries with empty name', () async {
    await waitForBind();
    await handlers[LifecycleTopics.diagReport]!({
      'service_list': [
        {'name': '', 'service_state': 2},
        {'service_state': 2}, // no name
      ],
    });
    expect(collector.services, isEmpty);
  });

  test('NotifyContainerState populates containers map with state', () async {
    await waitForBind();

    await handlers[LifecycleTopics.notifyContainerState]!({
      'container_list': ['navi_ctr', 'hmi_launcher'],
      'container_state_list': [2, 1], // RUNNING, STOPPED
      'exit_code_list': [0, 137],
    });

    expect(collector.containers.length, 2);
    expect(collector.containers['navi_ctr']!.state, ContainerState.running);
    expect(collector.containers['hmi_launcher']!.state, ContainerState.stopped);
    expect(collector.containers['hmi_launcher']!.exitCode, 137);
  });

  test('NotifyContainerState pushes an event on state change only', () async {
    await waitForBind();

    // First arrival establishes the container (unknown → running = a change).
    await handlers[LifecycleTopics.notifyContainerState]!({
      'container_list': ['navi_ctr'],
      'container_state_list': [2],
    });
    final afterFirst = collector.events.length;
    expect(afterFirst, greaterThanOrEqualTo(1));

    // Same state again → no new event.
    await handlers[LifecycleTopics.notifyContainerState]!({
      'container_list': ['navi_ctr'],
      'container_state_list': [2],
    });
    expect(collector.events.length, afterFirst);

    // State change → new event.
    await handlers[LifecycleTopics.notifyContainerState]!({
      'container_list': ['navi_ctr'],
      'container_state_list': [1],
    });
    expect(collector.events.length, greaterThan(afterFirst));
  });
}

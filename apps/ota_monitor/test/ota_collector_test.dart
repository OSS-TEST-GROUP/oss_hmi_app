import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ota_monitor/controller/ota_collector.dart';
import 'package:ota_monitor/data/ota_data.dart';
import 'package:roslibdart/roslibdart.dart';

class MockRos extends Mock implements Ros {}

class MockTopic extends Mock implements Topic {}

void main() {
  late MockRos mockRos;
  late OtaCollector collector;
  late List<MockTopic> respTopics; // 5 response topics
  late List<MockTopic> reqTopics;  // 4 request topics

  setUp(() {
    Get.reset();

    mockRos = MockRos();
    Get.put<Ros>(mockRos);

    respTopics = List.generate(5, (_) => MockTopic());
    reqTopics  = List.generate(4, (_) => MockTopic());

    for (final t in [...respTopics, ...reqTopics]) {
      when(() => t.subscribe(any())).thenAnswer((_) async {});
      when(() => t.advertise()).thenAnswer((_) async {});
      when(() => t.publish(any())).thenAnswer((_) async {});
    }

    int respIdx = 0;
    int reqIdx  = 0;

    Topic topicFactory(Ros ros, String name, String type) {
      if (otaResponseTopics.contains(name)) return respTopics[respIdx++];
      return reqTopics[reqIdx++];
    }

    collector = OtaCollector(topicFactory: topicFactory);
  });

  tearDown(() => Get.reset());

  Future<void> initTopics() async {
    await collector.startTopics(mockRos);
    await Future<void>.delayed(Duration.zero);
  }

  // ── Initial state ────────────────────────────────────────────────────────

  group('initial state', () {
    test('topicData / appList / updateHistory are empty at creation', () {
      expect(collector.topicData, isEmpty);
      expect(collector.appList, isEmpty);
      expect(collector.updateHistory, isEmpty);
    });
  });

  // ── startTopics ──────────────────────────────────────────────────────────

  group('startTopics', () {
    test('subscribes 5 response topics and advertises 4 request topics',
        () async {
      await initTopics();

      for (final t in respTopics) {
        verify(() => t.subscribe(any())).called(1);
      }
      for (final t in reqTopics) {
        verify(() => t.advertise()).called(1);
      }
    });
  });

  // ── onSettingsResponse ───────────────────────────────────────────────────

  group('onSettingsResponse', () {
    test('updates topicData and appList', () {
      collector.onSettingsResponse(<String, dynamic>{
        'app_name': 'MyApp',
        'app_settings': '{"auto":true}',
        'ret_code': 1,
      });

      expect(collector.topicData['MyApp_settings'], '{"auto":true}');
      expect(collector.topicData['MyApp_settings_ret'], ReturnValue.success);
      final app = collector.appList.firstWhere((a) => a['name'] == 'MyApp');
      expect(app['settings'], '{"auto":true}');
    });

    test('ignores message with null app_name', () {
      collector.onSettingsResponse(
          <String, dynamic>{'app_name': null, 'ret_code': 1});
      expect(collector.appList, isEmpty);
    });
  });

  // ── onSetSettingsResponse ────────────────────────────────────────────────

  group('onSetSettingsResponse', () {
    test('records success', () {
      collector.onSetSettingsResponse(<String, dynamic>{'ret_code': 1});
      expect(
          collector.topicData['last_set_settings_result'], ReturnValue.success);
    });

    test('records fail', () {
      collector.onSetSettingsResponse(<String, dynamic>{'ret_code': 2});
      expect(
          collector.topicData['last_set_settings_result'], ReturnValue.fail);
    });

    test('records unknown when ret_code is null', () {
      collector.onSetSettingsResponse(<String, dynamic>{'ret_code': null});
      expect(
          collector.topicData['last_set_settings_result'], ReturnValue.unknown);
    });
  });

  // ── onStateResponse ──────────────────────────────────────────────────────

  group('onStateResponse', () {
    test('updates topicData and appList', () {
      collector.onStateResponse(<String, dynamic>{
        'app_name': 'AppA',
        'app_state_info': 'idle',
        'ret_code': 1,
      });

      expect(collector.topicData['AppA_state'], 'idle');
      expect(collector.topicData['AppA_state_ret'], ReturnValue.success);
      final app = collector.appList.firstWhere((a) => a['name'] == 'AppA');
      expect(app['state'], 'idle');
    });
  });

  // ── onUpdateResponse ─────────────────────────────────────────────────────

  group('onUpdateResponse', () {
    test('updates topicData and adds history entry', () {
      collector.onUpdateResponse(
          <String, dynamic>{'app_name': 'AppB', 'ret_code': 2});

      expect(collector.topicData['AppB_update_result'], ReturnValue.fail);
      expect(collector.updateHistory, isNotEmpty);
      expect(collector.updateHistory.first['app_name'], 'AppB');
      expect(collector.updateHistory.first['message'], 'Update requested');
      expect(collector.updateHistory.first['ret_code'], 2);
    });
  });

  // ── onNotifyStatus ───────────────────────────────────────────────────────

  group('onNotifyStatus', () {
    test('updates topicData, appList status, and history', () {
      collector.onNotifyStatus(
          <String, dynamic>{'app_name': 'AppC', 'status': 'downloading'});

      expect(collector.topicData['AppC_status'], 'downloading');
      final app = collector.appList.firstWhere((a) => a['name'] == 'AppC');
      expect(app['status'], 'downloading');
      expect(collector.updateHistory.first['message'], 'Status: downloading');
    });

    test('ignores when app_name or status is null', () {
      collector.onNotifyStatus(
          <String, dynamic>{'app_name': null, 'status': null});
      expect(collector.appList, isEmpty);
      expect(collector.updateHistory, isEmpty);
    });
  });

  // ── updateHistory capped at 20 ───────────────────────────────────────────

  group('updateHistory', () {
    test('is capped at 20 entries', () {
      for (int i = 0; i < 25; i++) {
        collector.onUpdateResponse(
            <String, dynamic>{'app_name': 'App$i', 'ret_code': 0});
      }
      expect(collector.updateHistory.length, 20);
    });
  });

  // ── publish helpers ──────────────────────────────────────────────────────

  group('publish after startTopics', () {
    test('requestAppSettings publishes id + app_name on reqTopics[0]',
        () async {
      await initTopics();
      collector.requestAppSettings('TestApp');

      verify(() => reqTopics[0].publish(any(
            that: predicate<Map<String, dynamic>>(
                (m) => m['app_name'] == 'TestApp' && m.containsKey('id')),
          ))).called(1);
    });

    test('setAppSettings publishes id + app_name + app_settings on reqTopics[1]',
        () async {
      await initTopics();
      collector.setAppSettings('TestApp', '{"interval":5}');

      verify(() => reqTopics[1].publish(any(
            that: predicate<Map<String, dynamic>>((m) =>
                m['app_name'] == 'TestApp' &&
                m['app_settings'] == '{"interval":5}' &&
                m.containsKey('id')),
          ))).called(1);
    });

    test('requestAppState publishes id + app_name on reqTopics[2]', () async {
      await initTopics();
      collector.requestAppState('TestApp');

      verify(() => reqTopics[2].publish(any(
            that: predicate<Map<String, dynamic>>(
                (m) => m['app_name'] == 'TestApp' && m.containsKey('id')),
          ))).called(1);
    });

    test('requestUpdate publishes id + app_name on reqTopics[3]', () async {
      await initTopics();
      collector.requestUpdate('TestApp');

      verify(() => reqTopics[3].publish(any(
            that: predicate<Map<String, dynamic>>(
                (m) => m['app_name'] == 'TestApp' && m.containsKey('id')),
          ))).called(1);
    });
  });

  // ── ReturnValue enum ─────────────────────────────────────────────────────

  group('ReturnValue.fromInt', () {
    test('1 → success', () => expect(ReturnValue.fromInt(1), ReturnValue.success));
    test('2 → fail',    () => expect(ReturnValue.fromInt(2), ReturnValue.fail));
    test('null → unknown', () => expect(ReturnValue.fromInt(null), ReturnValue.unknown));
    test('0 → unknown',    () => expect(ReturnValue.fromInt(0), ReturnValue.unknown));
    test('99 → unknown',   () => expect(ReturnValue.fromInt(99), ReturnValue.unknown));
  });
}

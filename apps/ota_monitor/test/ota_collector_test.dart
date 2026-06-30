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
  late List<MockTopic> respTopics; // 5 + GetAppListResponse + DeleteClientResponse = 7
  late List<MockTopic> reqTopics;  // 4 + GetAppList + DeleteClient        = 6

  setUp(() {
    Get.reset();

    mockRos = MockRos();
    Get.put<Ros>(mockRos);

    // Mock slots cover everything OtaCollector subscribes / advertises:
    //   - 5 otaResponseTopics
    //   - GetAppListResponse (resp dedicated)
    //   - DeleteOtaClientRegistrationResponse (resp dedicated)
    //   - 4 otaRequestTopics
    //   - GetAppList request (dedicated)
    //   - DeleteOtaClientRegistration request (dedicated)
    respTopics = List.generate(7, (_) => MockTopic());
    reqTopics  = List.generate(6, (_) => MockTopic());

    for (final t in [...respTopics, ...reqTopics]) {
      when(() => t.subscribe(any())).thenAnswer((_) async {});
      when(() => t.advertise()).thenAnswer((_) async {});
      when(() => t.publish(any())).thenAnswer((_) async {});
    }

    int respIdx = 0;
    int reqIdx  = 0;

    Topic topicFactory(Ros ros, String name, String type) {
      // Dedicated response subscriptions outside the otaResponseTopics
      // array — route explicitly so each gets its own mock.
      if (name == otaGetAppListResTopic) return respTopics[respIdx++];
      if (name == otaDeleteClientResTopic) return respTopics[respIdx++];
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
    test('topicData and appList are empty at creation', () {
      expect(collector.topicData, isEmpty);
      expect(collector.appList, isEmpty);
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
    test('updates topicData', () {
      collector.onUpdateResponse(
          <String, dynamic>{'app_name': 'AppB', 'ret_code': 2});

      expect(collector.topicData['AppB_update_result'], ReturnValue.fail);
    });
  });

  // ── onNotifyStatus (status-only — no history) ────────────────────────────

  group('onNotifyStatus', () {
    test('updates topicData and appList status', () {
      collector.onNotifyStatus(
          <String, dynamic>{'app_name': 'AppC', 'status': 'downloading'});

      expect(collector.topicData['AppC_status'], 'downloading');
      final app = collector.appList.firstWhere((a) => a['name'] == 'AppC');
      expect(app['status'], 'downloading');
    });

    test('ignores when app_name or status is null', () {
      collector.onNotifyStatus(
          <String, dynamic>{'app_name': null, 'status': null});
      expect(collector.appList, isEmpty);
    });
  });

  // ── publish helpers ──────────────────────────────────────────────────────

  group('F023 — GetAppList', () {
    test('onGetAppListResponse replaces appList and sets source=manager',
        () async {
      await initTopics();

      // Seed appList with one local entry to prove it gets replaced.
      collector.appList.add({
        'name': 'local_only',
        'settings': '',
        'state': '',
        'status': 'Unknown',
      });
      expect(collector.appListSource.value, 'local');
      expect(collector.appListGeneration.value, 0);

      collector.onGetAppListResponse({
        'app_names': ['from_manager_a', 'from_manager_b'],
        'owner_client_ids': [1, 2],
        'ret_code': 1,
      });

      expect(collector.appListSource.value, 'manager');
      expect(collector.appListGeneration.value, 1);
      expect(collector.appList.map((e) => e['name']).toList(),
          ['from_manager_a', 'from_manager_b']);
      expect(collector.appOwnerClientIds['from_manager_a'], 1);
      expect(collector.appOwnerClientIds['from_manager_b'], 2);
    });

    test('preserves cached settings/state for apps that survive the swap',
        () async {
      await initTopics();
      collector.appList.add({
        'name': 'shared',
        'settings': '{"v":"1"}',
        'state': 'idle',
        'status': 'Synced',
      });

      collector.onGetAppListResponse({
        'app_names': ['shared'],
        'owner_client_ids': [42],
        'ret_code': 1,
      });

      expect(collector.appList.length, 1);
      final entry = collector.appList[0];
      expect(entry['name'], 'shared');
      expect(entry['settings'], '{"v":"1"}');   // cached survived
      expect(entry['state'], 'idle');
      expect(entry['status'], 'Synced');
    });

    test('requestAppList publishes id and increments per call', () async {
      await initTopics();
      final id1 = collector.requestAppList();
      final id2 = collector.requestAppList();
      expect(id2, id1 + 1);
      // reqTopics[4] is the GetAppList request slot (factory order).
      verify(() => reqTopics[4].publish(any(
            that: predicate<Map<String, dynamic>>(
                (m) => m['id'] is int && (m['id'] as int) > 0),
          ))).called(2);
    });
  });

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

  // ── F007: error stream surfaces publish failures ────────────────────────

  group('error stream (F007)', () {
    test('_publish emits error when topic is not ready', () async {
      // Build a collector that never calls startTopics, so publishers stay null.
      Get.reset();
      Get.put<Ros>(mockRos);
      final solo = OtaCollector(
        topicFactory: (ros, name, type) => MockTopic(),
      );

      final events = <String>[];
      final sub = solo.errors.listen(events.add);
      solo.requestAppSettings('AppX');
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first, contains('연결되지 않음'));

      await sub.cancel();
    });

    test('_publish does not emit when the topic is ready', () async {
      await initTopics();
      final events = <String>[];
      final sub = collector.errors.listen(events.add);
      collector.requestAppSettings('AppX');
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
      await sub.cancel();
    });
  });

  // ── F004: initial apps auto-load ───────────────────────────────────────

  group('initialApps', () {
    test('seeds appList with Unknown status at construction', () {
      Get.reset();
      Get.put<Ros>(mockRos);
      final c = OtaCollector(
        topicFactory: (ros, name, type) => MockTopic(),
        initialApps: const ['AppA', 'AppB'],
      );
      expect(c.appList.length, 2);
      expect(c.appList[0]['name'], 'AppA');
      expect(c.appList[0]['status'], 'Unknown');
      expect(c.appList[1]['name'], 'AppB');
    });

    test('issues settings + state requests for each app after startTopics',
        () async {
      Get.reset();
      Get.put<Ros>(mockRos);
      // Extra slots for GetAppList + DeleteOtaClientRegistration mocks
      // (response + request channels each).
      final respTopics2 = List.generate(7, (_) => MockTopic());
      final reqTopics2 = List.generate(6, (_) => MockTopic());
      for (final t in [...respTopics2, ...reqTopics2]) {
        when(() => t.subscribe(any())).thenAnswer((_) async {});
        when(() => t.advertise()).thenAnswer((_) async {});
        when(() => t.publish(any())).thenAnswer((_) async {});
      }
      int ri = 0, qi = 0;
      final c = OtaCollector(
        topicFactory: (ros, name, type) {
          if (name == otaGetAppListResTopic) return respTopics2[ri++];
          if (name == otaDeleteClientResTopic) return respTopics2[ri++];
          if (otaResponseTopics.contains(name)) return respTopics2[ri++];
          return reqTopics2[qi++];
        },
        initialApps: const ['NavigationApp', 'MapUpdater'],
      );
      await c.startTopics(mockRos);
      await Future<void>.delayed(Duration.zero);

      // settings requests — reqTopics[0]
      verify(() => reqTopics2[0].publish(any(
            that: predicate<Map<String, dynamic>>(
                (m) => m['app_name'] == 'NavigationApp'),
          ))).called(1);
      verify(() => reqTopics2[0].publish(any(
            that: predicate<Map<String, dynamic>>(
                (m) => m['app_name'] == 'MapUpdater'),
          ))).called(1);

      // state requests — reqTopics[2]
      verify(() => reqTopics2[2].publish(any(
            that: predicate<Map<String, dynamic>>(
                (m) => m['app_name'] == 'NavigationApp'),
          ))).called(1);
      verify(() => reqTopics2[2].publish(any(
            that: predicate<Map<String, dynamic>>(
                (m) => m['app_name'] == 'MapUpdater'),
          ))).called(1);

      // 2 apps × (settings + state) = 4 pending requests recorded
      expect(c.pendingRequestCount, 4);
    });

    test('empty initialApps results in no appList entries or pending requests',
        () async {
      Get.reset();
      Get.put<Ros>(mockRos);
      // F023 — extra slots for GetAppList + DeleteClient response/request mocks.
      // _start opens 7 response-side (5 ota + GetAppList + DeleteClient) and
      // 6 request-side (4 ota + GetAppList + DeleteClient) channels; the slots
      // and routing must cover all of them or the factory index overruns.
      final respTopics2 = List.generate(7, (_) => MockTopic());
      final reqTopics2 = List.generate(6, (_) => MockTopic());
      for (final t in [...respTopics2, ...reqTopics2]) {
        when(() => t.subscribe(any())).thenAnswer((_) async {});
        when(() => t.advertise()).thenAnswer((_) async {});
        when(() => t.publish(any())).thenAnswer((_) async {});
      }
      int ri = 0, qi = 0;
      final c = OtaCollector(
        topicFactory: (ros, name, type) {
          if (name == otaGetAppListResTopic) return respTopics2[ri++];
          if (name == otaDeleteClientResTopic) return respTopics2[ri++];
          if (otaResponseTopics.contains(name)) return respTopics2[ri++];
          return reqTopics2[qi++];
        },
      );
      await c.startTopics(mockRos);

      expect(c.appList, isEmpty);
      expect(c.pendingRequestCount, 0);
    });
  });

  // ── F003: requestId tracking & matching ─────────────────────────────────

  group('requestId tracking', () {
    test('requestAppSettings adds a pending request', () async {
      await initTopics();
      collector.requestAppSettings('AppA');
      expect(collector.pendingRequestCount, 1);

      final first = collector.pendingRequests.values.first;
      expect(first.appName, 'AppA');
      expect(first.kind, OtaRequestKind.getSettings);
    });

    test('each publish allocates a unique id and stores its kind', () async {
      await initTopics();
      collector.requestAppSettings('AppA');
      collector.requestAppState('AppA');
      collector.requestUpdate('AppA');
      collector.setAppSettings('AppA', '{}');

      expect(collector.pendingRequestCount, 4);
      final kinds = collector.pendingRequests.values.map((p) => p.kind).toSet();
      expect(kinds, {
        OtaRequestKind.getSettings,
        OtaRequestKind.getState,
        OtaRequestKind.setUpdate,
        OtaRequestKind.setSettings,
      });
      final ids = collector.pendingRequests.keys.toList();
      expect(ids.toSet().length, ids.length); // all unique
    });

    test('3 concurrent requests match 3 responses by id and clear pending',
        () async {
      await initTopics();
      collector.requestAppSettings('AppA');
      collector.requestAppSettings('AppB');
      collector.requestAppSettings('AppC');
      expect(collector.pendingRequestCount, 3);

      final ids = collector.pendingRequests.keys.toList()..sort();
      // Deliver responses in reversed order to prove id matching (not order).
      collector.onSettingsResponse({
        'id': ids[2],
        'app_name': 'AppC',
        'app_settings': 'c',
        'ret_code': 1,
      });
      collector.onSettingsResponse({
        'id': ids[0],
        'app_name': 'AppA',
        'app_settings': 'a',
        'ret_code': 1,
      });
      collector.onSettingsResponse({
        'id': ids[1],
        'app_name': 'AppB',
        'app_settings': 'b',
        'ret_code': 1,
      });

      expect(collector.pendingRequestCount, 0);
      expect(collector.topicData['AppA_settings'], 'a');
      expect(collector.topicData['AppB_settings'], 'b');
      expect(collector.topicData['AppC_settings'], 'c');
    });

    test('orphan response (unknown id) is still applied but does not crash',
        () async {
      await initTopics();
      collector.onSettingsResponse({
        'id': 99999,
        'app_name': 'Ghost',
        'app_settings': 'x',
        'ret_code': 1,
      });
      expect(collector.topicData['Ghost_settings'], 'x');
      expect(collector.pendingRequestCount, 0);
    });

    test('mismatched kind does not remove pending entry', () async {
      await initTopics();
      collector.requestAppSettings('AppA'); // kind = getSettings
      final id = collector.pendingRequests.keys.first;

      // Arrive as a stateResponse with the same id — should NOT match.
      collector.onStateResponse({
        'id': id,
        'app_name': 'AppA',
        'app_state_info': 's',
        'ret_code': 1,
      });
      expect(collector.pendingRequestCount, 1,
          reason: 'pending getSettings entry must remain');
    });

    test('onSetSettingsResponse falls back to pending appName when msg omits it',
        () async {
      await initTopics();
      collector.setAppSettings('AppA', '{}');
      final id = collector.pendingRequests.keys.first;

      // Response omits app_name — pending lookup should provide it.
      collector.onSetSettingsResponse({
        'id': id,
        'ret_code': 1,
      });
      expect(collector.pendingRequestCount, 0);
      expect(collector.topicData['AppA_set_settings_result'],
          ReturnValue.success);
      expect(collector.topicData['last_set_settings_result'],
          ReturnValue.success);
    });

    test('sweepExpiredRequests removes entries older than requestTimeout',
        () async {
      Get.reset();
      Get.put<Ros>(mockRos);

      // Fully-stubbed topic mocks routed by the factory. A bare MockTopic()
      // leaves subscribe()/advertise() unstubbed, so they return null where
      // _start awaits a Future<void> — newer Dart rejects this as
      // "type 'Null' is not a subtype of type 'Future<void>'". Cover all
      // _start channels (5 response + GetAppList/DeleteClient resp = 7,
      // 4 request + GetAppList/DeleteClient req = 6).
      final mockRespTopics = List.generate(7, (_) => MockTopic());
      final mockReqTopics = List.generate(6, (_) => MockTopic());
      for (final t in [...mockRespTopics, ...mockReqTopics]) {
        when(() => t.subscribe(any())).thenAnswer((_) async {});
        when(() => t.advertise()).thenAnswer((_) async {});
        when(() => t.publish(any())).thenAnswer((_) async {});
      }
      int ri = 0, qi = 0;
      final shortCollector = OtaCollector(
        topicFactory: (ros, name, type) {
          if (name == otaGetAppListResTopic) return mockRespTopics[ri++];
          if (name == otaDeleteClientResTopic) return mockRespTopics[ri++];
          if (otaResponseTopics.contains(name)) return mockRespTopics[ri++];
          return mockReqTopics[qi++];
        },
        requestTimeout: const Duration(milliseconds: 50),
        timeoutSweepInterval: const Duration(hours: 1), // manual sweep
      );

      await shortCollector.startTopics(mockRos);
      shortCollector.requestAppSettings('StaleApp');
      expect(shortCollector.pendingRequestCount, 1);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      final removed = shortCollector.sweepExpiredRequests();
      expect(removed, 1);
      expect(shortCollector.pendingRequestCount, 0);
    });
  });
}

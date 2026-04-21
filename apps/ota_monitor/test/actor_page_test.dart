import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ota_monitor/controller/ota_collector.dart';
import 'package:ota_monitor/data/ota_data.dart';
import 'package:ota_monitor/view/actor_page.dart';
import 'package:roslibdart/roslibdart.dart';

class _MockRos extends Mock implements Ros {}

class _MockTopic extends Mock implements Topic {}

/// F009 widget tests for the Actor-service raw UI.
///
/// Covers:
///   - All 16 F020 widget keys are mounted (card/field/btn/text × 4 cards).
///   - Send publishes on the matching request topic with the assigned id.
///   - A successful response (ret_code=1) renders "ret_code: OK" and
///     resolves the in-flight state.
///   - A response with ret_code=2 renders "ret_code: ERROR".
///   - The 5-second UI timer surfaces a ⚠ timeout when no response arrives.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRos ros;
  late OtaCollector collector;
  late List<_MockTopic> respTopics;
  late List<_MockTopic> reqTopics;
  late Map<String, Function(Map<String, dynamic>)> subscriptions;

  setUp(() async {
    Get.reset();

    ros = _MockRos();
    Get.put<Ros>(ros);

    respTopics = List.generate(5, (_) => _MockTopic());
    reqTopics = List.generate(4, (_) => _MockTopic());
    subscriptions = {};

    // Map factory order (see OtaCollector._start) to the response-topic name
    // so tests can inject messages via subscriptions[topicName].
    const respTopicByIndex = otaResponseTopics;
    int respIdx = 0;
    int reqIdx = 0;

    for (var i = 0; i < respTopics.length; i++) {
      final name = respTopicByIndex[i];
      when(() => respTopics[i].subscribe(any())).thenAnswer((inv) async {
        subscriptions[name] =
            inv.positionalArguments[0] as Function(Map<String, dynamic>);
      });
    }
    for (final t in reqTopics) {
      when(() => t.advertise()).thenAnswer((_) async {});
      when(() => t.publish(any())).thenAnswer((_) async {});
    }

    Topic topicFactory(Ros _, String name, String type) {
      if (otaResponseTopics.contains(name)) return respTopics[respIdx++];
      return reqTopics[reqIdx++];
    }

    collector = OtaCollector(
      topicFactory: topicFactory,
      autoStartTimers: false,
    );
    await collector.startTopics(ros);
    await Future<void>.delayed(Duration.zero);

    registerFallbackValue(<String, dynamic>{});
  });

  tearDown(() => Get.reset());

  Widget makeApp() => MaterialApp(home: Scaffold(
        body: ActorPage(collector: collector),
      ));

  // The four Actor cards stacked vertically exceed the default 800×600
  // viewport; tap on the lower cards would be treated as offscreen. Enlarge
  // the view so every card is hit-testable without a scroll.
  void enlargeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('F009 widget keys', () {
    testWidgets('all 16 Actor tab keys are mounted', (tester) async {
      enlargeView(tester);
      await tester.pumpWidget(makeApp());
      await tester.pumpAndSettle();

      const keys = [
        // GetAppUpdateSettings
        'card_actor_get_settings',
        'field_actor_get_settings_app_name',
        'btn_actor_get_settings',
        'text_actor_get_settings_response',
        // SetAppUpdateSettings
        'card_actor_set_settings',
        'field_actor_set_settings_app_name',
        'field_actor_set_settings_value',
        'btn_actor_set_settings',
        'text_actor_set_settings_response',
        // GetAppUpdateState
        'card_actor_get_state',
        'field_actor_get_state_app_name',
        'btn_actor_get_state',
        'text_actor_get_state_response',
        // SetAppUpdate
        'card_actor_set_update',
        'field_actor_set_update_app_name',
        'btn_actor_set_update',
        'text_actor_set_update_response',
      ];
      for (final k in keys) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: 'missing key $k');
      }
    });

    testWidgets('Send is disabled until app_name is entered', (tester) async {
      enlargeView(tester);
      await tester.pumpWidget(makeApp());
      await tester.pumpAndSettle();

      final btn = tester.widget<ElevatedButton>(
        find.byKey(const Key('btn_actor_get_settings')),
      );
      expect(btn.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('field_actor_get_settings_app_name')),
        'demo_app',
      );
      await tester.pumpAndSettle();
      final btn2 = tester.widget<ElevatedButton>(
        find.byKey(const Key('btn_actor_get_settings')),
      );
      expect(btn2.onPressed, isNotNull);
    });
  });

  group('F009 send & response', () {
    // NOTE: flutter_test uses a fake async zone — pumpAndSettle advances
    // pending Timers (including our 5s UI timeout) on the fake clock.
    // These tests therefore use pump() for single-frame settles and
    // explicit pump(duration) only when we mean to cross the 5s boundary.

    testWidgets('GetAppUpdateSettings publishes with id and renders OK',
        (tester) async {
      enlargeView(tester);
      await tester.pumpWidget(makeApp());
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('field_actor_get_settings_app_name')),
        'demo_app',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_actor_get_settings')));
      await tester.pump();

      // Verify publish on the request topic. reqTopics[0] is the
      // GetAppUpdateSettings request topic (factory order).
      final pub = verify(() => reqTopics[0].publish(captureAny()));
      pub.called(1);
      final captured = pub.captured.single as Map<String, dynamic>;
      expect(captured['app_name'], 'demo_app');
      expect(captured['id'], isA<int>());
      final id = captured['id'] as int;

      // Simulate the rosbridge-delivered response before the 5s timer.
      subscriptions[otaResponseTopics[0]]!({
        'id': id,
        'app_name': 'demo_app',
        'app_settings': '{"v":"1.2.3"}',
        'ret_code': 1,
      });
      await tester.pump();                              // microtask → stream
      await tester.pump();                              // stream listener setState

      final resp = tester.widget<Text>(
        find.byKey(const Key('text_actor_get_settings_response')),
      );
      expect(resp.data, contains('ret_code: OK'));
      expect(resp.data, contains('app_settings: {"v":"1.2.3"}'));
      expect(resp.data, contains('id: $id'));
    });

    testWidgets('ret_code=2 renders ERROR in the response area',
        (tester) async {
      enlargeView(tester);
      await tester.pumpWidget(makeApp());
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('field_actor_get_state_app_name')),
        'failing_app',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_actor_get_state')));
      await tester.pump();

      // GetAppUpdateState is the 3rd request topic (index 2).
      final pub = verify(() => reqTopics[2].publish(captureAny()));
      pub.called(1);
      final id = (pub.captured.single as Map<String, dynamic>)['id'] as int;

      subscriptions[otaResponseTopics[2]]!({
        'id': id,
        'app_name': 'failing_app',
        'app_state_info': '',
        'ret_code': 2,
      });
      await tester.pump();
      await tester.pump();

      final resp = tester.widget<Text>(
        find.byKey(const Key('text_actor_get_state_response')),
      );
      expect(resp.data, contains('ret_code: ERROR'));
    });

    testWidgets('5s UI timeout renders ⚠ when no response arrives',
        (tester) async {
      enlargeView(tester);
      await tester.pumpWidget(makeApp());
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('field_actor_set_update_app_name')),
        'silent_app',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_actor_set_update')));
      await tester.pump();

      // Pre-timeout: response area shows "Sending..."
      final mid = tester.widget<Text>(
        find.byKey(const Key('text_actor_set_update_response')),
      );
      expect(mid.data, contains('Sending'));

      // Advance past the 5s UI timeout (fake clock).
      await tester.pump(const Duration(seconds: 6));

      final after = tester.widget<Text>(
        find.byKey(const Key('text_actor_set_update_response')),
      );
      expect(after.data, contains('timeout'));
      expect(after.data, contains('5s'));
    });
  });

  group('F009 OtaCollector responses stream', () {
    test('emits OtaResponseEvent after onSettingsResponse', () async {
      final events = <OtaResponseEvent>[];
      final sub = collector.responses.listen(events.add);

      collector.onSettingsResponse({
        'id': 42,
        'app_name': 'x',
        'app_settings': 'raw',
        'ret_code': 1,
      });
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.kind, OtaRequestKind.getSettings);
      expect(events.single.id, 42);
      expect(events.single.appName, 'x');
      expect(events.single.retCode, 1);
      expect(events.single.body['app_settings'], 'raw');

      await sub.cancel();
    });

    test('emits for all four response kinds', () async {
      final events = <OtaResponseEvent>[];
      final sub = collector.responses.listen(events.add);

      collector.onSettingsResponse({'id': 1, 'ret_code': 1});
      collector.onSetSettingsResponse({'id': 2, 'ret_code': 1});
      collector.onStateResponse({'id': 3, 'ret_code': 1});
      collector.onUpdateResponse({'id': 4, 'ret_code': 1});
      await Future<void>.delayed(Duration.zero);

      expect(events.map((e) => e.kind).toList(), [
        OtaRequestKind.getSettings,
        OtaRequestKind.setSettings,
        OtaRequestKind.getState,
        OtaRequestKind.setUpdate,
      ]);

      await sub.cancel();
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ota_monitor/controller/client_service_controller.dart';
import 'package:roslibdart/roslibdart.dart';

class _MockRos extends Mock implements Ros {}

class _MockTopic extends Mock implements Topic {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(<String, dynamic>{});

  group('ClientServiceController', () {
    late _MockRos ros;
    late ClientServiceController c;

    setUp(() {
      ros = _MockRos();
      // The controller doesn't touch the Ros directly until setup() — we
      // skip setup() in these tests and exercise behaviour via the
      // injectXxxForTest helpers. That keeps the tests independent of
      // roslibdart's WebSocket plumbing.
      c = ClientServiceController(ros: ros);
    });

    test('initial state has null clientId, manager not ready, no statuses',
        () {
      expect(c.clientId, isNull);
      expect(c.managerReady, isFalse);
      expect(c.statuses, isEmpty);
    });

    test('registration response sets clientId and notifies', () {
      var notifyCount = 0;
      c.addListener(() => notifyCount++);

      c.injectRegistrationResponseForTest(42);

      expect(c.clientId, 42);
      expect(notifyCount, 1);
    });

    test('manager ready notifies once and stays true', () {
      var notifyCount = 0;
      c.addListener(() => notifyCount++);

      c.injectManagerReadyForTest();
      c.injectManagerReadyForTest();   // second time — no double notify

      expect(c.managerReady, isTrue);
      expect(notifyCount, 1, reason: 'second ready should be a no-op');
    });

    test('status injects newest-first, capped at history limit', () {
      final small = ClientServiceController(ros: ros, historyLimit: 3);
      for (var i = 0; i < 5; i++) {
        small.injectStatusForTest({
          'client_id': i,
          'app_name': 'app_$i',
          'status': 'phase_$i',
        });
      }
      expect(small.statuses, hasLength(3));
      // newest first → ids should be 4, 3, 2
      expect(small.statuses[0]['client_id'], 4);
      expect(small.statuses[1]['client_id'], 3);
      expect(small.statuses[2]['client_id'], 2);
    });

    test('register() before setup() is a safe no-op (no throw)', () async {
      await expectLater(
        c.register('foo', ['app1']),
        completes,
      );
    });

    group('setup() wiring', () {
      late _MockTopic regTopic;
      late _MockTopic regResTopic;
      late _MockTopic readyTopic;
      late _MockTopic statusTopic;
      late ClientServiceController controller;

      setUp(() {
        regTopic    = _MockTopic();
        regResTopic = _MockTopic();
        readyTopic  = _MockTopic();
        statusTopic = _MockTopic();
        for (final t in [regTopic, regResTopic, readyTopic, statusTopic]) {
          when(() => t.subscribe(any())).thenAnswer((_) async {});
          when(() => t.advertise()).thenAnswer((_) async {});
          when(() => t.publish(any())).thenAnswer((_) async {});
        }
        controller = ClientServiceController(
          ros: ros,
          topicFactory: (r, name, type) {
            switch (name) {
              case ClientServiceController.topicRegistration:
                return regTopic;
              case ClientServiceController.topicRegistrationResponse:
                return regResTopic;
              case ClientServiceController.topicManagerReady:
                return readyTopic;
              case ClientServiceController.topicAppUpdateStatus:
                return statusTopic;
              default:
                throw StateError('unexpected topic: $name');
            }
          },
        );
      });

      test('subscribes the three notify-style topics and advertises the request',
          () async {
        await controller.setup();
        verify(() => regResTopic.subscribe(any())).called(1);
        verify(() => readyTopic.subscribe(any())).called(1);
        verify(() => statusTopic.subscribe(any())).called(1);
        verify(() => regTopic.advertise()).called(1);
      });

      test('register() publishes the expected payload', () async {
        await controller.setup();
        await controller.register('demo', ['a', 'b', 'c']);
        final captured = verify(() => regTopic.publish(captureAny())).captured;
        expect(captured, hasLength(1));
        final msg = captured.single as Map<String, dynamic>;
        expect(msg['client_name'], 'demo');
        expect(msg['app_list'], ['a', 'b', 'c']);
      });

      test('setup() is idempotent', () async {
        await controller.setup();
        await controller.setup();
        verify(() => regResTopic.subscribe(any())).called(1);   // not 2
      });
    });
  });
}

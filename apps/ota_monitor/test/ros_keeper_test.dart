import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ota_monitor/config/app_config.dart';
import 'package:ota_monitor/ros/ros_keeper.dart';
import 'package:roslibdart/roslibdart.dart';

class MockRos extends Mock implements Ros {}

void main() {
  group('RosKeeper', () {
    late AppConfig cfg;
    late MockRos mockRos;
    late List<Duration> createdTimerDurations;

    Timer fakeTimerFactory(Duration duration, void Function(Timer) cb) {
      createdTimerDurations.add(duration);
      final t = Timer(const Duration(milliseconds: 1), () {});
      cb(t);
      return t;
    }

    setUp(() {
      cfg = AppConfig(
        rosUrl: Uri.parse('ws://dummy-ros:9090'),
        statusTopic: '/app_status/test_ota',
      );
      mockRos = MockRos();
      createdTimerDurations = [];

      when(() => mockRos.statusStream)
          .thenAnswer((_) => const Stream<Status>.empty());
      when(() => mockRos.status).thenReturn(Status.none);
    });

    test('ros getter throws StateError before start', () {
      final keeper = RosKeeper(
        cfg,
        rosFactory: (_) => mockRos,
        timerFactory: fakeTimerFactory,
      );

      expect(() => keeper.ros, throwsA(isA<StateError>()));
    });

    test('start() creates ros instance and starts reconnect loop', () async {
      final keeper = RosKeeper(
        cfg,
        rosFactory: (_) => mockRos,
        timerFactory: fakeTimerFactory,
      );

      await keeper.start();

      expect(keeper.ros, same(mockRos));
      // _kickReconnect() calls connect() synchronously before first await
      verify(() => mockRos.connect()).called(1);
      // timerFactory was called once with 1-second duration
      expect(createdTimerDurations, contains(const Duration(seconds: 1)));
    });

    test('stop() calls ros.close and clears ros', () async {
      when(() => mockRos.close()).thenAnswer((_) async {});

      final keeper = RosKeeper(
        cfg,
        rosFactory: (_) => mockRos,
        timerFactory: fakeTimerFactory,
      );

      await keeper.start();
      await keeper.stop();

      verify(() => mockRos.close()).called(1);
      expect(() => keeper.ros, throwsA(isA<StateError>()));
    });

    test('calling start() twice closes the first ros instance', () async {
      final mockRos1 = MockRos();
      final mockRos2 = MockRos();
      when(() => mockRos1.statusStream)
          .thenAnswer((_) => const Stream<Status>.empty());
      when(() => mockRos2.statusStream)
          .thenAnswer((_) => const Stream<Status>.empty());
      when(() => mockRos1.status).thenReturn(Status.none);
      when(() => mockRos2.status).thenReturn(Status.none);
      when(() => mockRos1.close()).thenAnswer((_) async {});
      when(() => mockRos2.close()).thenAnswer((_) async {});

      int count = 0;
      final keeper = RosKeeper(
        cfg,
        rosFactory: (_) => ++count == 1 ? mockRos1 : mockRos2,
        timerFactory: fakeTimerFactory,
      );

      await keeper.start(); // uses mockRos1
      await keeper.start(); // stop() -> mockRos1.close(), then uses mockRos2

      verify(() => mockRos1.close()).called(1);
      verifyNever(() => mockRos2.close());
      expect(keeper.ros, same(mockRos2));
    });

    // ── F010: exponential backoff sequence (pure function) ───────────────

    group('nextBackoff', () {
      test('doubles up to maxBackoff and caps at 8s', () {
        expect(RosKeeper.nextBackoff(const Duration(seconds: 1)),
            const Duration(seconds: 2));
        expect(RosKeeper.nextBackoff(const Duration(seconds: 2)),
            const Duration(seconds: 4));
        expect(RosKeeper.nextBackoff(const Duration(seconds: 4)),
            const Duration(seconds: 8));
        expect(RosKeeper.nextBackoff(const Duration(seconds: 8)),
            const Duration(seconds: 8));
      });

      test('stays at maxBackoff when current already exceeds it', () {
        expect(RosKeeper.nextBackoff(const Duration(seconds: 30)),
            RosKeeper.maxBackoff);
      });

      test('initial constants match the documented values', () {
        expect(RosKeeper.initialBackoff, const Duration(seconds: 1));
        expect(RosKeeper.maxBackoff, const Duration(seconds: 8));
      });
    });

    // ── F010: GetX instance replacement on status.connected ──────────────

    group('onConnected GetX wiring', () {
      late StreamController<Status> statusCtrl;

      // A timer factory that does NOT auto-fire the heartbeat callback,
      // so the test doesn't exercise Topic.publish on a skeleton mock Ros.
      Timer inertTimerFactory(Duration d, void Function(Timer) cb) =>
          Timer(const Duration(days: 1), () {});

      setUp(() => Get.reset());
      tearDown(() => Get.reset());

      MockRos readyMock() {
        final r = MockRos();
        statusCtrl = StreamController<Status>.broadcast();
        when(() => r.statusStream).thenAnswer((_) => statusCtrl.stream);
        // status starts at none; the stream emission drives the transition.
        when(() => r.status).thenReturn(Status.none);
        when(() => r.close()).thenAnswer((_) async {});
        return r;
      }

      test('Get.put<Ros> is populated when statusStream emits connected',
          () async {
        final r = readyMock();
        final keeper = RosKeeper(
          cfg,
          rosFactory: (_) => r,
          timerFactory: inertTimerFactory,
        );
        await keeper.start();
        // Flip status and fire the stream.
        when(() => r.status).thenReturn(Status.connected);
        statusCtrl.add(Status.connected);
        await Future<void>.delayed(Duration.zero);

        expect(Get.isRegistered<Ros>(), isTrue);
        expect(Get.find<Ros>(), same(r));
        await statusCtrl.close();
        await keeper.stop();
      });

      test('Get.replace<Ros> is used when an instance was already registered',
          () async {
        final older = MockRos();
        when(() => older.statusStream)
            .thenAnswer((_) => const Stream<Status>.empty());
        when(() => older.status).thenReturn(Status.none);
        when(() => older.close()).thenAnswer((_) async {});
        Get.put<Ros>(older, permanent: true);

        final r = readyMock();
        final keeper = RosKeeper(
          cfg,
          rosFactory: (_) => r,
          timerFactory: inertTimerFactory,
        );
        await keeper.start();
        when(() => r.status).thenReturn(Status.connected);
        statusCtrl.add(Status.connected);
        await Future<void>.delayed(Duration.zero);

        expect(Get.find<Ros>(), same(r),
            reason: 'onConnected must swap the GetX instance');
        await statusCtrl.close();
        await keeper.stop();
      });
    });

    // ── F010: AppConfig-driven interval wiring (F005 integration) ────────

    test('heartbeat timer duration comes from cfg.heartbeatIntervalSec',
        () async {
      cfg = AppConfig(
        rosUrl: Uri.parse('ws://dummy:9090'),
        statusTopic: '/app_status/test_ota',
        heartbeatIntervalSec: 7,
      );
      final keeper = RosKeeper(
        cfg,
        rosFactory: (_) => mockRos,
        timerFactory: fakeTimerFactory,
      );
      await keeper.start();
      expect(createdTimerDurations, contains(const Duration(seconds: 7)));
    });
  });
}

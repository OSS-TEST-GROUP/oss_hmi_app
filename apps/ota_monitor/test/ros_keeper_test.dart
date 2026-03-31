import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
          .thenAnswer((_) => Stream<Status>.empty());
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
          .thenAnswer((_) => Stream<Status>.empty());
      when(() => mockRos2.statusStream)
          .thenAnswer((_) => Stream<Status>.empty());
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
  });
}

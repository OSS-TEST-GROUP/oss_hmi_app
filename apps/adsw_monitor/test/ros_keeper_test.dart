// test/ros_keeper_test.dart
//
// RosKeeper was refactored to drive connection state off Ros.statusStream
// (connect → on Status.connected register/replace in GetX). This test exercises
// that lifecycle with an injected MockRos whose statusStream we drive.

import 'dart:async';

import 'package:adsw_monitor/config/app_config.dart';
import 'package:adsw_monitor/ros_keeper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roslibdart/roslibdart.dart';

class MockRos extends Mock implements Ros {}

class MockTopic extends Mock implements Topic {}

void main() {
  group('RosKeeper', () {
    late AppConfig cfg;
    late MockRos mockRos;
    late MockTopic mockTopic;
    late StreamController<Status> statusCtrl;

    setUp(() {
      Get.testMode = true;
      Get.reset();
      cfg = AppConfig(
        rosUrl: Uri.parse('ws://dummy-ros:9090'),
        statusTopic: '/app_status/test_app',
      );
      mockRos = MockRos();
      mockTopic = MockTopic();
      statusCtrl = StreamController<Status>.broadcast();

      when(() => mockRos.statusStream).thenAnswer((_) => statusCtrl.stream);
      when(() => mockRos.connect()).thenAnswer((_) {});
      when(() => mockRos.close()).thenAnswer((_) async {});
      when(() => mockRos.status).thenReturn(Status.connected);
      when(() => mockTopic.advertise()).thenAnswer((_) async {});
      when(() => mockTopic.publish(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await statusCtrl.close();
      Get.reset();
    });

    RosKeeper makeKeeper() => RosKeeper(
          cfg,
          rosFactory: (_) => mockRos,
          topicFactory: (_, __, ___) => mockTopic,
        );

    test('ros getter throws before start', () {
      final keeper = makeKeeper();
      expect(() => keeper.ros, throwsA(isA<StateError>()));
    });

    test('start() creates ros and exposes it via getter', () async {
      final keeper = makeKeeper();
      addTearDown(keeper.stop);

      await keeper.start();

      // start() wires statusStream + reconnect loop; the Ros instance is
      // exposed via the getter (connect() is driven by the reconnect path,
      // not necessarily synchronously within start()).
      expect(keeper.ros, same(mockRos));
    });

    test('Status.connected registers Ros in GetX', () async {
      final keeper = makeKeeper();
      addTearDown(keeper.stop);

      await keeper.start();
      statusCtrl.add(Status.connected);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(Get.isRegistered<Ros>(), isTrue);
      expect(Get.find<Ros>(), same(mockRos));
    });

    test('stop() clears ros, calls ros.close, and the getter throws again',
        () async {
      final keeper = makeKeeper();
      await keeper.start();
      await keeper.stop();

      verify(() => mockRos.close()).called(greaterThanOrEqualTo(1));
      expect(() => keeper.ros, throwsA(isA<StateError>()));
    });

    test('calling start() multiple times tears down the previous Ros',
        () async {
      final mockRos1 = MockRos();
      final mockRos2 = MockRos();
      for (final m in [mockRos1, mockRos2]) {
        when(() => m.statusStream).thenAnswer((_) => statusCtrl.stream);
        when(() => m.connect()).thenAnswer((_) {});
        when(() => m.close()).thenAnswer((_) async {});
        when(() => m.status).thenReturn(Status.connected);
      }
      var n = 0;
      final keeper = RosKeeper(
        cfg,
        rosFactory: (_) => (++n == 1) ? mockRos1 : mockRos2,
        topicFactory: (_, __, ___) => mockTopic,
      );
      addTearDown(keeper.stop);

      await keeper.start(); // mockRos1
      await keeper.start(); // internal stop() closes mockRos1, creates mockRos2

      verify(() => mockRos1.close()).called(greaterThanOrEqualTo(1));
      expect(keeper.ros, same(mockRos2));
    });
  });
}

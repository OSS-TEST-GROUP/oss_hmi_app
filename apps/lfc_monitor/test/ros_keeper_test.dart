// Unit tests for lfc_monitor's RosKeeper.
//
// Exercises the connect → register-in-GetX → advertise lifecycle without a
// live rosbridge by injecting a MockRos (whose statusStream we drive) and a
// MockTopic.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:lfc_monitor/config/app_config.dart';
import 'package:lfc_monitor/ros_keeper.dart';

class MockRos extends Mock implements Ros {}

class MockTopic extends Mock implements Topic {}

void main() {
  late AppConfig cfg;
  late MockRos mockRos;
  late MockTopic mockTopic;
  late StreamController<Status> statusCtrl;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    cfg = AppConfig.defaults();
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

  test('ros getter throws before start()', () {
    final keeper = makeKeeper();
    expect(() => keeper.ros, throwsA(isA<StateError>()));
  });

  test('start() creates ros, connects and exposes it via getter', () async {
    final keeper = makeKeeper();
    addTearDown(keeper.stop);

    await keeper.start();

    expect(keeper.ros, same(mockRos));
    verify(() => mockRos.connect()).called(1);
  });

  test('Status.connected registers Ros in GetX and advertises status topic',
      () async {
    final keeper = makeKeeper();
    addTearDown(keeper.stop);

    await keeper.start();
    statusCtrl.add(Status.connected);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(Get.isRegistered<Ros>(), isTrue);
    expect(Get.find<Ros>(), same(mockRos));
    verify(() => mockTopic.advertise()).called(1);
  });

  test('stop() closes ros and the getter throws again', () async {
    final keeper = makeKeeper();
    await keeper.start();
    await keeper.stop();

    verify(() => mockRos.close()).called(1);
    expect(() => keeper.ros, throwsA(isA<StateError>()));
  });

  test('start() twice tears down the previous Ros', () async {
    final keeper = makeKeeper();
    addTearDown(keeper.stop);

    await keeper.start();
    await keeper.start(); // internal stop() closes the first instance

    verify(() => mockRos.close()).called(greaterThanOrEqualTo(1));
  });
}

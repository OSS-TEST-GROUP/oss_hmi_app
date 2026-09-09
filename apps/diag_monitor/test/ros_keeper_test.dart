// test/ros_keeper_test.dart

import 'dart:async';

import 'package:diag_monitor/config/app_config.dart';
import 'package:diag_monitor/ros_keeper.dart';
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
      when(() => mockRos.requestPublisher(any())).thenAnswer((_) => 'pub-id');
      when(() => mockRos.requestAdvertiser(any())).thenAnswer((_) => 'adv-id');
      when(() => mockTopic.advertise()).thenAnswer((_) async {});
      when(() => mockTopic.publish(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await statusCtrl.close();
      Get.reset();
    });

    RosKeeper makeKeeper({
      RosFactory? rosFactory,
      TopicFactory? topicFactory,
      TimerFactory? timerFactory,
    }) =>
        RosKeeper(
          cfg,
          rosFactory: rosFactory ?? (_) => mockRos,
          topicFactory: topicFactory ?? (_, __, ___) => mockTopic,
          timerFactory: timerFactory,
        );

    test('ros getter throws before start', () {
      final keeper = makeKeeper();
      expect(() => keeper.ros, throwsA(isA<StateError>()));
    });

    test('start() creates ros and exposes it via getter', () async {
      final keeper = makeKeeper();
      addTearDown(keeper.stop);

      await keeper.start();
      expect(keeper.ros, same(mockRos));
    });

    test('Status.connected registers Ros in GetX', () async {
      final keeper = makeKeeper();
      addTearDown(keeper.stop);

      await keeper.start();
      statusCtrl.add(Status.connected);
      await Future<void>.delayed(Duration.zero);

      expect(Get.find<Ros>(), same(mockRos));
    });

    test('stop() clears ros, calls ros.close, and the getter throws again', () async {
      final keeper = makeKeeper();

      await keeper.start();
      expect(keeper.ros, same(mockRos));

      await keeper.stop();
      verify(() => mockRos.close()).called(greaterThanOrEqualTo(1));
      expect(() => keeper.ros, throwsA(isA<StateError>()));
    });

    test('calling start() multiple times tears down the previous Ros', () async {
      final keeper = makeKeeper();
      addTearDown(keeper.stop);

      await keeper.start();
      await keeper.start();

      verify(() => mockRos.close()).called(greaterThanOrEqualTo(1));
    });

    test('Status stream error and done callbacks handle gracefully', () async {
      final keeper = makeKeeper();
      addTearDown(keeper.stop);

      await keeper.start();
      statusCtrl.addError(Exception('test error'));
      await statusCtrl.close();
      await Future<void>.delayed(Duration.zero);
      expect(keeper.ros, same(mockRos));
    });

    test('periodic timer publishes status when connected', () async {
      void Function(Timer)? timerCallback;
      final keeper = makeKeeper(
        timerFactory: (duration, onTick) {
          final t = Timer(Duration.zero, () {});
          timerCallback = onTick;
          return t;
        },
      );
      addTearDown(keeper.stop);

      await keeper.start();
      expect(timerCallback, isNotNull);
      timerCallback!(Timer(Duration.zero, () {}));
      await pumpEventQueue();
      verify(() => mockTopic.publish(any())).called(greaterThanOrEqualTo(1));
    });

    test('reconnect loop handles disconnect, close failure and recreate', () async {
      final disconnectedRos = MockRos();
      final reconnectedRos = MockRos();
      final disCtrl = StreamController<Status>.broadcast();
      final reconCtrl = StreamController<Status>.broadcast();

      when(() => disconnectedRos.statusStream).thenAnswer((_) => disCtrl.stream);
      when(() => disconnectedRos.connect()).thenThrow(Exception('connect failed'));
      when(() => disconnectedRos.close()).thenThrow(Exception('close failed'));
      when(() => disconnectedRos.status).thenReturn(Status.closed);
      when(() => disconnectedRos.requestAdvertiser(any())).thenAnswer((_) => 'adv-1');
      when(() => disconnectedRos.requestPublisher(any())).thenAnswer((_) => 'pub-1');

      when(() => reconnectedRos.statusStream).thenAnswer((_) => reconCtrl.stream);
      when(() => reconnectedRos.connect()).thenAnswer((_) {});
      when(() => reconnectedRos.close()).thenAnswer((_) async {});
      when(() => reconnectedRos.status).thenReturn(Status.connected);
      when(() => reconnectedRos.requestAdvertiser(any())).thenAnswer((_) => 'adv-2');
      when(() => reconnectedRos.requestPublisher(any())).thenAnswer((_) => 'pub-2');

      var factoryCount = 0;
      final keeper = makeKeeper(
        rosFactory: (_) => factoryCount++ == 0 ? disconnectedRos : reconnectedRos,
      );

      await keeper.start();
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await keeper.stop();

      await disCtrl.close();
      await reconCtrl.close();
      expect(factoryCount, greaterThanOrEqualTo(2));
    });

    test('reconnectPoll triggers kick when ros is not stable connected', () async {
      void Function(Timer)? pollCallback;
      final pollMockRos = MockRos();
      when(() => pollMockRos.statusStream).thenAnswer((_) => Stream.value(Status.connected));
      when(() => pollMockRos.connect()).thenAnswer((_) {});
      when(() => pollMockRos.close()).thenAnswer((_) async {});
      when(() => pollMockRos.status).thenReturn(Status.connected);
      when(() => pollMockRos.requestAdvertiser(any())).thenAnswer((_) => 'adv-3');
      when(() => pollMockRos.requestPublisher(any())).thenAnswer((_) => 'pub-3');

      final keeper = RosKeeper(
        cfg,
        rosFactory: (_) => pollMockRos,
        topicFactory: (_, __, ___) => mockTopic,
        timerFactory: (dur, cb) {
          if (dur == const Duration(seconds: 2)) {
            pollCallback = cb;
          }
          return Timer(Duration.zero, () {});
        },
      );
      addTearDown(keeper.stop);

      await keeper.start();
      expect(keeper.ros, isNotNull);
      expect(pollCallback, isNotNull);

      // Trigger poll callback with connected status
      pollCallback!(Timer(Duration.zero, () {}));
      await pumpEventQueue();

      // Trigger poll callback with closed status to cover _kickReconnect branch
      when(() => pollMockRos.status).thenReturn(Status.closed);
      pollCallback!(Timer(Duration.zero, () {}));
      await pumpEventQueue();
    });

    test('reconnect loop handles safe close success', () async {
      final rosOk = MockRos();
      final statusCtrl = StreamController<Status>.broadcast();
      when(() => rosOk.statusStream).thenAnswer((_) => statusCtrl.stream);
      when(() => rosOk.connect()).thenAnswer((_) {});
      when(() => rosOk.close()).thenAnswer((_) async {});
      when(() => rosOk.status).thenReturn(Status.closed);
      when(() => rosOk.requestAdvertiser(any())).thenAnswer((_) => 'adv-ok');
      when(() => rosOk.requestPublisher(any())).thenAnswer((_) => 'pub-ok');

      final keeper = makeKeeper(rosFactory: (_) => rosOk);
      await keeper.start();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await keeper.stop();
      await statusCtrl.close();
    });

    test('_onConnected uses Get.replace when Ros is already registered', () async {
      Get.put<Ros>(MockRos(), permanent: true);
      final connectedRos = MockRos();
      when(() => connectedRos.statusStream).thenAnswer((_) => Stream.value(Status.connected));
      when(() => connectedRos.connect()).thenAnswer((_) {});
      when(() => connectedRos.close()).thenAnswer((_) async {});
      when(() => connectedRos.status).thenReturn(Status.connected);
      when(() => connectedRos.requestAdvertiser(any())).thenAnswer((_) => 'adv-conn');
      when(() => connectedRos.requestPublisher(any())).thenAnswer((_) => 'pub-conn');

      final keeper = makeKeeper(rosFactory: (_) => connectedRos);
      await keeper.start();
      expect(Get.find<Ros>(), same(connectedRos));
      await keeper.stop();
    });
  });
}

// test/ros_keeper_test.dart
import 'dart:async';

import 'package:adsw_monitor/config/app_config.dart';
import 'package:adsw_monitor/ros_keeper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roslibdart/roslibdart.dart';

class MockRos extends Mock implements Ros {}
class MockTopic extends Mock implements Topic {}

void main() {
  group('RosKeeper', () {
    late AppConfig cfg;
    late MockRos mockRos;
    late MockTopic mockTopic;
    late List<Duration> createdTimerDurations;

    // 타이머 팩토리: 진짜 1초 기다리지 말고,
    // Timer를 하나 만들고 *콜백을 즉시 한 번 호출*해서
    // 타이머 콜백 내부 코드까지 커버리지를 올려준다.
    Timer fakeTimerFactory(Duration duration, void Function(Timer) cb) {
      createdTimerDurations.add(duration);
      final t = Timer(const Duration(milliseconds: 1), () {}); // 더미 타이머
      cb(t); // 바로 한 번 실행해서 publish 경로 태우기
      return t;
    }

    setUp(() {
      cfg = AppConfig(
        rosUrl: Uri.parse('ws://dummy-ros:9090'),
        statusTopic: '/app_status/test_app',
      );
      mockRos = MockRos();
      mockTopic = MockTopic();
      createdTimerDurations = [];
    });

    test('ros getter throws before start', () {
      final keeper = RosKeeper(
        cfg,
        rosFactory: (_) => mockRos,
        topicFactory: (_, __, ___) => mockTopic,
        timerFactory: fakeTimerFactory,
      );

      expect(
        () => keeper.ros,
        throwsA(isA<StateError>()),
      );
    });

    test('start() creates ros, connects, creates topic, and schedules timer',
        () async {
      // publish는 Future<void>를 반환하므로 async {} 로 스텁
      when(() => mockTopic.publish(any())).thenAnswer((_) async {});

      final keeper = RosKeeper(
        cfg,
        rosFactory: (_) => mockRos,
        topicFactory: (ros, name, type) {
          // 생성 시 전달되는 파라미터도 한 번 검증
          expect(ros, same(mockRos));
          expect(name, cfg.statusTopic);
          expect(type, 'std_msgs/String');
          return mockTopic;
        },
        timerFactory: fakeTimerFactory,
      );

      await keeper.start();

      // ros getter가 동일 mockRos를 반환하는지
      expect(keeper.ros, same(mockRos));

      // connect는 한 번 호출되어야 함
      verify(() => mockRos.connect()).called(1);

      // fakeTimerFactory에서 콜백을 바로 실행했으므로
      // 최소 한 번은 publish({'data': 'running'})가 불려야 함
      verify(() => mockTopic.publish({'data': 'running'})).called(
        greaterThanOrEqualTo(1),
      );

      // 타이머 duration도 우리가 준 1초인 것을 확인
      expect(createdTimerDurations, [const Duration(seconds: 1)]);
    });

    test('stop() cancels timer, clears ros and calls ros.close', () async {
      when(() => mockTopic.publish(any())).thenAnswer((_) async {});
      when(() => mockRos.close()).thenAnswer((_) async {});

      final keeper = RosKeeper(
        cfg,
        rosFactory: (_) => mockRos,
        topicFactory: (_, __, ___) => mockTopic,
        timerFactory: fakeTimerFactory,
      );

      await keeper.start();
      await keeper.stop();

      // stop()은 ros.close()를 한 번 호출해야 함
      verify(() => mockRos.close()).called(1);

      // _ros가 null로 초기화되었기 때문에 ros getter는 다시 StateError를 던져야 함
      expect(
        () => keeper.ros,
        throwsA(isA<StateError>()),
      );
    });

    test('calling start() multiple times always cleans previous state',
        () async {
      final mockRos1 = MockRos();
      final mockRos2 = MockRos();
      when(() => mockTopic.publish(any())).thenAnswer((_) async {});
      when(() => mockRos1.close()).thenAnswer((_) async {});
      when(() => mockRos2.close()).thenAnswer((_) async {});

      int rosCreateCount = 0;

      final keeper = RosKeeper(
        cfg,
        rosFactory: (_) {
          rosCreateCount++;
          // 첫 번째 start에서는 mockRos1, 두 번째 start에서는 mockRos2 반환
          return rosCreateCount == 1 ? mockRos1 : mockRos2;
        },
        topicFactory: (_, __, ___) => mockTopic,
        timerFactory: fakeTimerFactory,
      );

      await keeper.start();  // mockRos1 사용
      await keeper.start();  // 내부에서 stop() -> mockRos1.close() 호출 후 mockRos2 생성

      // 이전 ROS 인스턴스는 stop()에서 close()가 호출되어야 함
      verify(() => mockRos1.close()).called(1);
      // 두 번째 인스턴스는 아직 stop()을 안 불렀으니 close() 되면 안 됨
      verifyNever(() => mockRos2.close());

      // 현재 ros getter는 두 번째 인스턴스를 반환해야 한다
      expect(keeper.ros, same(mockRos2));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:adsw_monitor/controller/adsw_collector.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get/get.dart';

class MockRos extends Mock implements Ros {}
class MockTopic extends Mock implements Topic {}

void main() {
  late MockRos mockRos;
  late MockTopic mockTopic;
  late AdswCollector collector;

  late Topic Function(Ros, String, String) mockTopicFactory;

  setUp(() {
  mockRos = MockRos();
  mockTopic = MockTopic();

  // GetX에 mockRos 등록
  Get.put<Ros>(mockRos);

  // mockTopicFactory 정의
  mockTopicFactory = (ros, name, type) => mockTopic;

  // mockTopic의 subscribe 동작 정의
  when(() => mockTopic.subscribe(any())).thenAnswer((_) async {});

  collector = AdswCollector(topicFactory: mockTopicFactory);
});


  group('AdswCollector subscribeTopic', () {
    test('calls topic.subscribe for each topic', () {
      // Arrange
      when(() => mockTopic.subscribe(any())).thenAnswer((_) async {});

      final topics = ['/t1', '/t2'];
      final types = ['type1', 'type2'];
      final handlers = [
        (Map<String, dynamic> msg) async {},
        (Map<String, dynamic> msg) async {},
      ];

      // Act
      collector.subscribeTopic(topics, types, handlers);

      // Assert
      verify(() => mockTopic.subscribe(any())).called(2);
    });
  });

  group('AdswCollector data handlers', () {
    test('handleVehicleStatus updates topicData', () async {
      final msg = {
        'gear': {'status': 'D'},
        'steering_tire_angle': 1.2,
        'turn_indicators': 'left',
        'hazard_lights': 'off',
      };

      await collector.handleVehicleStatus(msg);

      expect(collector.topicData['Gear'], 'D');
      expect(collector.topicData['Steering tire angle'], 1.2);
      expect(collector.topicData['Turn indicator'], 'left');
      expect(collector.topicData['Hazard light'], 'off');
    });

    test('handleLaneDeparture updates lane departure status', () async {
      final msg = {
        'status': [
          {
            'name': 'lane_departure_checker: lane_departure',
            'message': 'Lane crossed',
            'values': [
              {'key': 'is_out_of_lane', 'value': 'true'}
            ]
          }
        ]
      };

      await collector.handleLaneDeparture(msg);

      expect(collector.topicData['Lane departure'], 'Lane crossed');
      expect(collector.isLaneDeparture.value, 'true');
    });
  });
}

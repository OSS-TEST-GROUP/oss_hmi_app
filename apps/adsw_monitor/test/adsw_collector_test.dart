import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:mockito/annotations.dart';

import 'package:adsw_monitor/controller/adsw_collector.dart';

@GenerateNiceMocks([
  MockSpec<Topic>(),
])
import 'adsw_collector_test.mocks.dart';

void main() {
  late AdswCollector collector;
  late MockTopic mockTopic;

  setUp(() {
    mockTopic = MockTopic();

    collector = AdswCollector(
      topicFactory: (ros, name, type) => mockTopic,
    );
  });

  test('connect should initialize ros and handlerList', () {
    final result = collector.connect('ws://localhost:9090');

    expect(result, isTrue);
    expect(collector.ros.url, equals('ws://localhost:9090'));
    expect(collector.handlerList.length, greaterThan(5));
  });

  test('subscribeTopic should subscribe to all topics with correct handlers', () async {
    collector.connect('ws://localhost:9090');

    final topics = ['/topic1', '/topic2'];
    final types = ['std_msgs/String', 'std_msgs/String'];
    final handler = (Map<String, dynamic> msg) async {};
    final handlers = [handler, handler];

    when(mockTopic.subscribe(any)).thenAnswer((_) async {});

    collector.subscribeTopic(topics, types, handlers);

    //verify(mockTopic.subscribe(any)).called(2);

    final capturedHandlers = verify(mockTopic.subscribe(captureAny)).captured;
    expect(capturedHandlers.length, 2);
    expect(capturedHandlers.first, isA<Function>());
  });

  test('handleBattery should update topicData with battery status', () async {
    final msg = {'voltage': 12.3, 'current': 1.2};
    await collector.handleBattery(msg);

    expect(collector.topicData['Battery status'], equals(msg));
  });

  test('handleLaneDeparture should update topicData and isLaneDeparture', () async {
    final msg = {
      'status': [
        {
          'name': 'lane_departure_checker: lane_departure',
          'message': 'out_of_lane',
          'values': [
            {'key': 'is_out_of_lane', 'value': 'true'}
          ]
        }
      ]
    };

    await collector.handleLaneDeparture(msg);

    expect(collector.topicData['Lane departure'], equals('out_of_lane'));
    expect(collector.isLaneDeparture.value, equals('true'));
  });
}
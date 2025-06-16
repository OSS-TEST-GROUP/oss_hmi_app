import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:mockito/annotations.dart';

import 'package:adsw_monitor/controller/mw_collector.dart';

@GenerateNiceMocks([
  MockSpec<Topic>(),
])
import 'mw_collector_test.mocks.dart';

void main() {
  late MwCollector collector;
  late MockTopic mockTopic;

  setUp(() {
    mockTopic = MockTopic();

    collector = MwCollector(
      topicFactory: (ros, name, type) => mockTopic,
    );
  });

  test('connect should initialize ros and handlerList', () {
    final result = collector.connect('ws://test');

    expect(result, isTrue);
    expect(collector.ros.url, equals('ws://test'));
    expect(collector.handlerList.length, greaterThan(0));
  });

  test('subscribeTopic should subscribe to all topics with correct handlers', () async {
    collector.connect('ws://test');

    final topics = ['/topic1', '/topic2'];
    final types = ['std_msgs/String', 'std_msgs/String'];
    final handler = (Map<String, dynamic> msg) async {};
    final handlers = [handler, handler];

    when(mockTopic.subscribe(any)).thenAnswer((_) async {});

    collector.subscribeTopic(topics, types, handlers);

    final capturedHandlers = verify(mockTopic.subscribe(captureAny)).captured;
    
    expect(capturedHandlers.length, 2);
    expect(capturedHandlers.first, isA<Function>());
  });

  test('handleLifecycle should update topicData correctly', () async {
    await collector.handleLifecycle({'status': 'success'});
    expect(collector.topicData['Lifecycle status'], {'status': 'success'});
  });
}
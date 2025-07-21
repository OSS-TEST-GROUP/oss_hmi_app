import 'package:flutter_test/flutter_test.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:adsw_monitor/controller/mw_collector.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get/get.dart';

class MockRos extends Mock implements Ros {}
class MockTopic extends Mock implements Topic {}

void main() {
  late MockRos mockRos;
  late MockTopic mockTopic;
  late MwCollector collector;
  late Topic Function(Ros, String, String) mockTopicFactory;

  setUp(() {
    mockRos = MockRos();
    mockTopic = MockTopic();

    // GetX에 mockRos 주입
    Get.put<Ros>(mockRos);

    // Topic Factory 정의
    mockTopicFactory = (ros, name, type) => mockTopic;

    // topic.subscribe() mock 처리
    when(() => mockTopic.subscribe(any())).thenAnswer((_) async {});

    // collector 초기화
    collector = MwCollector(topicFactory: mockTopicFactory);
  });

  group('MwCollector subscribeTopic', () {
    test('calls topic.subscribe for each topic', () {
      final topics = ['/mw1', '/mw2'];
      final types = ['type1', 'type2'];
      final handlers = [
        (Map<String, dynamic> msg) async {},
        (Map<String, dynamic> msg) async {},
      ];

      collector.subscribeTopic(topics, types, handlers);

      verify(() => mockTopic.subscribe(any())).called(2);
    });
  });

  group('MwCollector data handlers', () {
    test('handleLifecycle updates topicData', () async {
      final msg = {'state': 'active'};

      await collector.handleLifecycle(msg);

      expect(collector.topicData['Lifecycle status'], msg);
    });

    test('handleOta updates topicData', () async {
      final msg = {'version': '1.0.0'};

      await collector.handleOta(msg);

      expect(collector.topicData['Ota status'], msg);
    });

    test('handleSecurity updates topicData', () async {
      final msg = {'status': 'secure'};

      await collector.handleSecurity(msg);

      expect(collector.topicData['Security status'], msg);
    });
  });
}

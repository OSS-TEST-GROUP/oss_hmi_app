import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:adsw_monitor/controller/mw_collector.dart';

class MockRos extends Mock implements Ros {}

class MockTopic extends Mock implements Topic {}

void main() {
  late MwCollector collector;
  late MockRos mockRos;

  setUp(() {
    mockRos = MockRos();
    collector = MwCollector();
    collector.ros = mockRos; // 직접 주입
  });

  test('connect should initialize Ros and return true', () {
    final result = collector.connect('ws://test');

    expect(result, true);
    expect(collector.handlerList.length, greaterThan(0));
  });

  test('handleLifecycle should update topicData correctly', () async {
    await collector.handleLifecycle({'status': 'success'});
    expect(collector.topicData['Lifecycle status'], {'status': 'success'});
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:adsw_monitor/controller/adsw_collector.dart';

class MockRos extends Mock implements Ros {}

class MockTopic extends Mock implements Topic {}

void main() {
  late AdswCollector collector;
  late MockRos mockRos;

  setUp(() {
    mockRos = MockRos();
    collector = AdswCollector();
    collector.ros = mockRos; // 직접 주입
  });

  test('connect should initialize Ros and return true', () {
    final result = collector.connect('ws://test');

    expect(result, true);
    expect(collector.handlerList.length, greaterThan(0));
  });

  test('handleGear should update topicData correctly', () async {
    await collector.handleVehicleStatus({'gear': {'status':'D'}});
    expect(collector.topicData['Gear'], 'D');
  });

  test('handleLaneDeparture should update topicData and isLaneDeparture', () async {
    final msg = {
      'status': [
        {
          'name': 'lane_departure_checker: lane_departure',
          'message': 'Departed lane',
          'values': [
            {'key': 'is_out_of_lane', 'value': 'true'}
          ]
        }
      ]
    };

    await collector.handleLaneDeparture(msg);

    expect(collector.topicData['Lane departure'], 'Departed lane');
    expect(collector.isLaneDeparture.value, 'true');
  });
}
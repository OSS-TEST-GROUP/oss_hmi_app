// import 'package:flutter_test/flutter_test.dart';
// import 'package:roslibdart/roslibdart.dart';
// import 'package:adsw_monitor/controller/adsw_collector.dart';
// import 'package:mocktail/mocktail.dart';
// import 'package:get/get.dart';

// class MockRos extends Mock implements Ros {}
// class MockTopic extends Mock implements Topic {}

// void main() {
//   late MockRos mockRos;
//   late MockTopic mockTopic;
//   late AdswCollector collector;

//   late Topic Function(Ros, String, String) mockTopicFactory;

//   setUp(() {
//   mockRos = MockRos();
//   mockTopic = MockTopic();

//   // GetX에 mockRos 등록
//   Get.put<Ros>(mockRos);

//   // mockTopicFactory 정의
//   mockTopicFactory = (ros, name, type) => mockTopic;

//   // mockTopic의 subscribe 동작 정의
//   when(() => mockTopic.subscribe(any())).thenAnswer((_) async {});

//   collector = AdswCollector(topicFactory: mockTopicFactory);
// });


//   group('AdswCollector subscribeTopic', () {
//     test('calls topic.subscribe for each topic', () {
//       // Arrange
//       when(() => mockTopic.subscribe(any())).thenAnswer((_) async {});

//       final topics = ['/t1', '/t2'];
//       final types = ['type1', 'type2'];
//       final handlers = [
//         (Map<String, dynamic> msg) async {},
//         (Map<String, dynamic> msg) async {},
//       ];

//       // Act
//       collector.subscribeTopic(topics, types, handlers);

//       // Assert
//       verify(() => mockTopic.subscribe(any())).called(2);
//     });
//   });

//   group('AdswCollector data handlers', () {
//     test('handleVehicleStatus updates topicData', () async {
//       final msg = {
//         'gear': {'status': 'D'},
//         'steering_tire_angle': 1.2,
//         'turn_indicators': 'left',
//         'hazard_lights': 'off',
//       };

//       await collector.handleVehicleStatus(msg);

//       expect(collector.topicData['Gear'], 'D');
//       expect(collector.topicData['Steering tire angle'], 1.2);
//       expect(collector.topicData['Turn indicator'], 'left');
//       expect(collector.topicData['Hazard light'], 'off');
//     });

//     test('handleLaneDeparture updates lane departure status', () async {
//       final msg = {
//         'status': [
//           {
//             'name': 'lane_departure_checker: lane_departure',
//             'message': 'Lane crossed',
//             'values': [
//               {'key': 'is_out_of_lane', 'value': 'true'}
//             ]
//           }
//         ]
//       };

//       await collector.handleLaneDeparture(msg);

//       expect(collector.topicData['Lane departure'], 'Lane crossed');
//       expect(collector.isLaneDeparture.value, 'true');
//     });
//   });
// }

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
    // GetX 초기화
    Get.reset();

    mockRos = MockRos();
    mockTopic = MockTopic();

    // GetX에 mockRos 등록
    Get.put<Ros>(mockRos);

    // topicFactory는 항상 동일한 mockTopic을 반환하도록 설정
    mockTopicFactory = (ros, name, type) => mockTopic;

    // subscribe 호출 시 에러가 나지 않도록 스텁
    when(() => mockTopic.subscribe(any())).thenAnswer((_) async {});

    collector = AdswCollector(topicFactory: mockTopicFactory);
  });

  tearDown(() {
    // GetX 정리
    Get.reset();
  });

  group('AdswCollector subscribeTopic', () {
    test('subscribeTopic calls subscribe for each topic', () {
      // Arrange
      final topics = ['/t1', '/t2'];
      final types = ['type1', 'type2'];
      final handlers = <SubscribeHandler>[
        (Map<String, dynamic> msg) async {}, // 더미 핸들러 1
        (Map<String, dynamic> msg) async {}, // 더미 핸들러 2
      ];

      // Act
      collector.subscribeTopic(topics, types, handlers);

      // Assert
      // 동일한 mockTopic이 두 번 subscribe 호출되어야 함
      verify(() => mockTopic.subscribe(any())).called(2);
    });
  });

  group('AdswCollector handleVehicleStatus', () {
    test('handleVehicleStatus maps raw numeric values into display strings', () async {
      // Arrange
      final msg = <String, dynamic>{
        'gear': {'status': 2},            // 2 -> 'D'
        'turn_indicators': {'status': 3}, // 3 -> 'RIGHT'
        'hazard_lights': {'status': 2},   // 2 -> 'ON'
        'steering_tire_angle': 1.2345,    // 소수점 2자리로 포맷
      };

      // Act
      await collector.handleVehicleStatus(msg);

      // Assert
      // 기어 / 방향지시등 / 비상등 문자열 매핑 확인
      expect(collector.topicData['Gear'], 'D');
      expect(collector.topicData['Turn indicator'], 'RIGHT');
      expect(collector.topicData['Hazard light'], 'ON');

      // steering_tire_angle은 _f2 포맷(소수점 2자리)으로 저장됨
      expect(collector.topicData['Steering tire angle'], '1.23');
    });

    test('handleVehicleStatus falls back to "-" for unknown values', () async {
      // Arrange: status가 없거나 알 수 없는 값인 경우
      final msg = <String, dynamic>{
        'gear': {'status': 99},
        'turn_indicators': null,
        'hazard_lights': {},
        'steering_tire_angle': null,
      };

      // Act
      await collector.handleVehicleStatus(msg);

      // Assert
      expect(collector.topicData['Gear'], '-');
      expect(collector.topicData['Turn indicator'], '-');
      expect(collector.topicData['Hazard light'], '-');
      expect(collector.topicData['Steering tire angle'], '-');
    });
  });

  group('AdswCollector handleCurrentVelocity', () {
    test('handleCurrentVelocity stores km/h string with 2 decimal places', () async {
      // Arrange: 10 m/s = 36.00 km/h
      final msg = <String, dynamic>{
        'longitudinal_velocity': 10.0,
      };

      // Act
      await collector.handleCurrentVelocity(msg);

      // Assert
      expect(collector.topicData['Current velocity'], '36.00');
    });

    test('handleCurrentVelocity stores "-" when velocity is null', () async {
      // Arrange
      final msg = <String, dynamic>{
        'longitudinal_velocity': null,
      };

      // Act
      await collector.handleCurrentVelocity(msg);

      // Assert
      expect(collector.topicData['Current velocity'], '-');
    });
  });

  group('AdswCollector handleLaneDeparture', () {
    test('handleLaneDeparture updates lane departure status and flag', () async {
      // Arrange
      final msg = <String, dynamic>{
        'status': [
          {
            'name': 'lane_departure_checker: lane_departure',
            'message': 'Lane crossed',
            'values': [
              {'key': 'is_out_of_lane', 'value': 'true'},
            ],
          },
        ],
      };

      // Act
      await collector.handleLaneDeparture(msg);

      // Assert
      expect(collector.topicData['Lane departure'], 'Lane crossed');
      expect(collector.isLaneDeparture.value, 'true');
    });

    test('handleLaneDeparture uses default "false" when value is missing', () async {
      // Arrange: is_out_of_lane가 없는 경우
      final msg = <String, dynamic>{
        'status': [
          {
            'name': 'lane_departure_checker: lane_departure',
            'message': 'No lane departure',
            'values': <Map<String, dynamic>>[],
          },
        ],
      };

      // Act
      await collector.handleLaneDeparture(msg);

      // Assert
      expect(collector.topicData['Lane departure'], 'No lane departure');
      expect(collector.isLaneDeparture.value, 'false');
    });
  });

  group('AdswCollector handlePlanningPath', () {
    test('handlePlanningPath sets all values to null when points list is empty', () async {
      // Arrange
      final msg = <String, dynamic>{
        'points': <Map<String, dynamic>>[],
      };

      // Act
      await collector.handlePlanningPath(msg);

      // Assert
      expect(collector.topicData['Planning path index'], isNull);
      expect(collector.topicData['Planning path x'], isNull);
      expect(collector.topicData['Planning path y'], isNull);
      expect(collector.topicData['Planning path z'], isNull);
    });

    test('handlePlanningPath uses final point when is_final is true', () async {
      // Arrange
      final msg = <String, dynamic>{
        'points': [
          {
            'is_final': false,
            'pose': {
              'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
            },
          },
          {
            'is_final': true,
            'pose': {
              'position': {'x': 1.0, 'y': 2.0, 'z': 3.0},
            },
          },
        ],
      };

      // Act
      await collector.handlePlanningPath(msg);

      // Assert
      expect(collector.topicData['Planning path index'], 1);
      expect(collector.topicData['Planning path x'], 1.0);
      expect(collector.topicData['Planning path y'], 2.0);
      expect(collector.topicData['Planning path z'], 3.0);
    });

    test('handlePlanningPath falls back to last point when no final flag is present', () async {
      // Arrange
      final msg = <String, dynamic>{
        'points': [
          {
            'pose': {
              'position': {'x': 10.0, 'y': 20.0, 'z': 30.0},
            },
          },
          {
            'pose': {
              'position': {'x': 11.0, 'y': 22.0, 'z': 33.0},
            },
          },
        ],
      };

      // Act
      await collector.handlePlanningPath(msg);

      // Assert
      expect(collector.topicData['Planning path index'], 1);
      expect(collector.topicData['Planning path x'], 11.0);
      expect(collector.topicData['Planning path y'], 22.0);
      expect(collector.topicData['Planning path z'], 33.0);
    });
  });

  group('AdswCollector handleLocalizationData', () {
    test('handleLocalizationData formats position and twist vectors', () async {
      // Arrange
      final msg = <String, dynamic>{
        'pose': {
          'pose': {
            'position': {
              'x': 1.234,
              'y': -2.345,
              'z': 3.456,
            },
          },
        },
        'twist': {
          'twist': {
            'linear': {
              'x': 0.1,
              'y': 0.2,
              'z': 0.3,
            },
            'angular': {
              'x': -0.4,
              'y': -0.5,
              'z': -0.6,
            },
          },
        },
      };

      // Act
      await collector.handleLocalizationData(msg);

      // Assert: pose 값은 소수점 2자리
      expect(collector.topicData['Localization pose x'], '1.23');
      expect(collector.topicData['Localization pose y'], '-2.35');
      expect(collector.topicData['Localization pose z'], '3.46');

      // 벡터는 x/y/z 모두 포맷된 문자열
      expect(
        collector.topicData['Localization twist linear'],
        'x:0.10, y:0.20, z:0.30',
      );
      expect(
        collector.topicData['Localization twist angular'],
        'x:-0.40, y:-0.50, z:-0.60',
      );
    });

    test('handleLocalizationData uses "-" when data is missing', () async {
      // Arrange: pose / twist 정보가 비어있는 경우
      final msg = <String, dynamic>{
        'pose': {},
        'twist': {},
      };

      // Act
      await collector.handleLocalizationData(msg);

      // Assert
      expect(collector.topicData['Localization pose x'], '-');
      expect(collector.topicData['Localization pose y'], '-');
      expect(collector.topicData['Localization pose z'], '-');
      expect(collector.topicData['Localization twist linear'], '-');
      expect(collector.topicData['Localization twist angular'], '-');
    });
  });

  group('AdswCollector handleMapData', () {
    test('handleMapData copies map height and width', () async {
      // Arrange
      final msg = <String, dynamic>{
        'height': 123,
        'width': 456,
      };

      // Act
      await collector.handleMapData(msg);

      // Assert
      expect(collector.topicData['pcd height'], 123);
      expect(collector.topicData['pcd width'], 456);
    });
  });

  group('AdswCollector handleBattery / handleSensorCount / handleSensorData', () {
    test('handleBattery stores energy_level as Battery status', () async {
      // Arrange
      final msg = <String, dynamic>{
        'energy_level': 88,
      };

      // Act
      await collector.handleBattery(msg);

      // Assert
      expect(collector.topicData['Battery status'], 88);
    });

    test('handleSensorCount stores data as Number of sensor', () async {
      // Arrange
      final msg = <String, dynamic>{
        'data': 5,
      };

      // Act
      await collector.handleSensorCount(msg);

      // Assert
      expect(collector.topicData['Number of sensor'], 5);
    });

    test('handleSensorData stores orientation_covariance', () async {
      // Arrange
      final msg = <String, dynamic>{
        'orientation_covariance': [1, 2, 3],
      };

      // Act
      await collector.handleSensorData(msg);

      // Assert
      expect(
        collector.topicData['Imu Data - orientation_covariance'],
        [1, 2, 3],
      );
    });
  });

  group('AdswCollector handleObjectRecognition', () {
    test('handleObjectRecognition sets "-" and 0 count when objects list is empty', () async {
      // Arrange
      final msg = <String, dynamic>{
        'objects': <dynamic>[],
      };

      // Act
      await collector.handleObjectRecognition(msg);

      // Assert
      expect(collector.topicData['Object recognition'], '-');
      expect(collector.topicData['Object recognition count'], 0);
    });

    test('handleObjectRecognition maps labels and probabilities correctly', () async {
      // Arrange
      final msg = <String, dynamic>{
        'objects': [
          {
            'classification': [
              {'label': 1, 'probability': 0.8}, // CAR (0.80)
              {'label': 2, 'probability': 0.5},
            ],
          },
          {
            'classification': [
              {'label': 7, 'probability': 0.9}, // PEDESTRIAN (0.90)
            ],
          },
        ],
      };

      // Act
      await collector.handleObjectRecognition(msg);

      // Assert
      final text = collector.topicData['Object recognition'] as String;
      final count = collector.topicData['Object recognition count'] as int;

      expect(count, 2);
      expect(
        text.split('\n'),
        ['CAR (0.80)', 'PEDESTRIAN (0.90)'],
      );
    });
  });
}

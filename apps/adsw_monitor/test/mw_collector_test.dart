// import 'package:flutter_test/flutter_test.dart';
// import 'package:roslibdart/roslibdart.dart';
// import 'package:adsw_monitor/controller/mw_collector.dart';
// import 'package:mocktail/mocktail.dart';
// import 'package:get/get.dart';

// class MockRos extends Mock implements Ros {}
// class MockTopic extends Mock implements Topic {}

// void main() {
//   late MockRos mockRos;
//   late MockTopic mockTopic;
//   late MwCollector collector;
//   late Topic Function(Ros, String, String) mockTopicFactory;

//   setUp(() {
//     mockRos = MockRos();
//     mockTopic = MockTopic();

//     // GetX에 mockRos 주입
//     Get.put<Ros>(mockRos);

//     // Topic Factory 정의
//     mockTopicFactory = (ros, name, type) => mockTopic;

//     // topic.subscribe() mock 처리
//     when(() => mockTopic.subscribe(any())).thenAnswer((_) async {});

//     // collector 초기화
//     collector = MwCollector(topicFactory: mockTopicFactory);
//   });

//   group('MwCollector subscribeTopic', () {
//     test('calls topic.subscribe for each topic', () {
//       final topics = ['/mw1', '/mw2'];
//       final types = ['type1', 'type2'];
//       final handlers = [
//         (Map<String, dynamic> msg) async {},
//         (Map<String, dynamic> msg) async {},
//       ];

//       collector.subscribeTopic(topics, types, handlers);

//       verify(() => mockTopic.subscribe(any())).called(2);
//     });
//   });

//   group('MwCollector data handlers', () {
//     test('handleLifecycle updates topicData', () async {
//       final msg = {'state': 'active'};

//       await collector.handleLifecycle(msg);

//       expect(collector.topicData['Lifecycle status'], msg);
//     });

//     test('handleOta updates topicData', () async {
//       final msg = {'version': '1.0.0'};

//       await collector.handleOta(msg);

//       expect(collector.topicData['Ota status'], msg);
//     });

//     test('handleSecurity updates topicData', () async {
//       final msg = {'status': 'secure'};

//       await collector.handleSecurity(msg);

//       expect(collector.topicData['Security status'], msg);
//     });
//   });
// }

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:adsw_monitor/controller/mw_collector.dart';

class MockRos extends Mock implements Ros {}

class MockTopic extends Mock implements Topic {}

void main() {
  late MockRos mockRos;

  late MockTopic infoReqTopic;
  late MockTopic infoListReqTopic;
  late MockTopic infoRespTopic;
  late MockTopic infoListRespTopic;

  late MwCollector collector;

  // subscribe에 전달되는 핸들러를 잡아두기 위한 변수
  dynamic infoListHandler; // Future<void> Function(Map<String, dynamic>)
  dynamic infoRespHandler; // Future<void> Function(Map<String, dynamic>)

  setUp(() {
    // GetX 초기화
    Get.reset();

    mockRos = MockRos();

    infoReqTopic = MockTopic();
    infoListReqTopic = MockTopic();
    infoRespTopic = MockTopic();
    infoListRespTopic = MockTopic();

    // GetX에 Ros 주입
    Get.put<Ros>(mockRos);

    // advertise / unadvertise / publish / subscribe / unsubscribe 전부 스텁
    when(() => infoReqTopic.advertise())
        .thenAnswer((_) => Future<void>.value());
    when(() => infoListReqTopic.advertise())
        .thenAnswer((_) => Future<void>.value());

    when(() => infoReqTopic.unadvertise())
        .thenAnswer((_) => Future<void>.value());
    when(() => infoListReqTopic.unadvertise())
        .thenAnswer((_) => Future<void>.value());

    when(() => infoReqTopic.publish(any()))
        .thenAnswer((_) => Future<void>.value());
    when(() => infoListReqTopic.publish(any()))
        .thenAnswer((_) => Future<void>.value());

    when(() => infoRespTopic.subscribe(any())).thenAnswer((invocation) async {
      // Info Response 핸들러 캡처
      infoRespHandler = invocation.positionalArguments[0];
    });
    when(() => infoListRespTopic.subscribe(any()))
        .thenAnswer((invocation) async {
      // Info List Response 핸들러 캡처
      infoListHandler = invocation.positionalArguments[0];
    });

    when(() => infoRespTopic.unsubscribe())
        .thenAnswer((_) => Future<void>.value());
    when(() => infoListRespTopic.unsubscribe())
        .thenAnswer((_) => Future<void>.value());

    // topicFactory: 토픽 이름에 따라 각각 다른 MockTopic 반환
    Topic topicFactory(Ros ros, String name, String type) {
      switch (name) {
        case '/mmf/diagnosticmgr/DiagnosticInfoRequest':
          return infoReqTopic;
        case '/mmf/diagnosticmgr/DiagnosticInfoListRequest':
          return infoListReqTopic;
        case '/mmf/diagnosticmgr/DiagnosticInfoResponse':
          return infoRespTopic;
        case '/mmf/diagnosticmgr/DiagnosticInfoListResponse':
          return infoListRespTopic;
        default:
          return MockTopic();
      }
    }

    collector = MwCollector(topicFactory: topicFactory);
  });

  tearDown(() {
    Get.reset();
  });

  group('MwCollector lifecycle', () {
    test('onInit prepares topics, subscribes, advertises, and kicks initial list request',
        () async {
      // Act
      collector.onInit();

      // 비동기 내부(_start, advertise, publish)가 돌 시간을 한 틱 줌
      await Future<void>.delayed(Duration.zero);

      // Assert
      // 리스트/상세 Request 퍼블리셔 advertise 여부
      verify(() => infoListReqTopic.advertise()).called(1);
      verify(() => infoReqTopic.advertise()).called(1);

      // Response 서브스크립션 여부
      verify(() => infoListRespTopic.subscribe(any())).called(1);
      verify(() => infoRespTopic.subscribe(any())).called(1);

      // 최초 InfoList 요청이 최소 1회는 발사되어야 함
      verify(() => infoListReqTopic.publish(any())).called(greaterThan(0));
    });

    test('onClose unsubscribes and unadvertises topics', () async {
      // Arrange
      collector.onInit();
      await Future<void>.delayed(Duration.zero);

      // Act
      collector.onClose();

      // Assert
      // 구독 해제
      verify(() => infoListRespTopic.unsubscribe()).called(1);
      verify(() => infoRespTopic.unsubscribe()).called(1);
      // advertise 해제
      verify(() => infoListReqTopic.unadvertise()).called(1);
      verify(() => infoReqTopic.unadvertise()).called(1);
    });
  });

  group('MwCollector info list handling', () {
    test('onInfoListResponse builds code/name mapping and initializes topicData',
        () async {
      // Arrange
      collector.onInit();
      await Future<void>.delayed(Duration.zero);

      // 리스트 응답 핸들러가 제대로 캡처되었는지 확인
      expect(infoListHandler, isNotNull);

      final msg = <String, dynamic>{
        'diag_codes': [1, '2', -1], // 1, 2만 유효 코드
        'diag_names': ['DiagA', 'DiagB', 'DiagC'],
      };

      // Act
      await infoListHandler(msg);

      // Assert
      // diagNames에 유효한 이름만 들어왔는지 확인
      expect(collector.diagNames, ['DiagA', 'DiagB']);

      // topicData에는 최소한 기본 값 '-'로 초기화되어야 함
      expect(collector.topicData['DiagA'], isNotNull);
      expect(collector.topicData['DiagB'], isNotNull);
      expect(collector.topicData['DiagA'], '-');
      expect(collector.topicData['DiagB'], '-');

      // 각 코드에 대한 상세 요청이 퍼블리시 되었는지 확인
      verify(() => infoReqTopic.publish({
            'diag_code': 1,
            'diag_name': 'DiagA',
          })).called(1);
      verify(() => infoReqTopic.publish({
            'diag_code': 2,
            'diag_name': 'DiagB',
          })).called(1);
    });
  });

  group('MwCollector info response handling', () {
    test('onInfoResponse uses code mapping and populates structured info',
        () async {
      // Arrange
      collector.onInit();
      await Future<void>.delayed(Duration.zero);
      expect(infoListHandler, isNotNull);
      expect(infoRespHandler, isNotNull);

      // 1) 먼저 리스트 응답으로 code -> name 매핑
      final listMsg = <String, dynamic>{
        'diag_codes': [10],
        'diag_names': ['EngineStatus'],
      };
      await infoListHandler(listMsg);

      // 2) 해당 코드에 대한 상세 응답
      final respMsg = <String, dynamic>{
        'diag_code': 10,
        'ret_code': 1, // PASS
        'status': 2, // FATAL
        'message': 'Overheated',
      };

      // Act
      await infoRespHandler(respMsg);

      // Assert
      final info =
          collector.topicData['EngineStatus'] as Map<String, dynamic>?;

      expect(info, isNotNull);
      expect(info!['name'], 'EngineStatus');
      expect(info['code'], 10);
      // ret_code / ret_text 매핑 확인
      expect(info['ret_code'], 1);
      expect(info['ret_text'], 'PASS');
      // status / status_text 매핑 확인
      expect(info['status'], 2);
      expect(info['status_text'], 'FATAL');
      expect(info['message'], 'Overheated');
    });

    test('onInfoResponse falls back to diag_name when code is unknown and reads nested enums',
        () async {
      // Arrange
      collector.onInit();
      await Future<void>.delayed(Duration.zero);
      expect(infoRespHandler, isNotNull);

      // 리스트 응답 없이 바로 상세 응답이 들어오는 상황 가정
      final respMsg = <String, dynamic>{
        'diag_code': 999, // 매핑에 없는 코드
        'diag_name': 'UnknownDiag',
        'ret_code': {
          'ret_code': 2, // FAIL
        },
        'status': {
          'diag_status': 3, // WARNING
        },
        'message': 'Something odd',
      };

      // Act
      await infoRespHandler(respMsg);

      // Assert
      final info =
          collector.topicData['UnknownDiag'] as Map<String, dynamic>?;

      expect(info, isNotNull);
      expect(info!['name'], 'UnknownDiag');
      expect(info['code'], 999);
      expect(info['ret_code'], 2);
      expect(info['ret_text'], 'FAIL');
      expect(info['status'], 3);
      expect(info['status_text'], 'WARNING');
      expect(info['message'], 'Something odd');
    });
  });
}

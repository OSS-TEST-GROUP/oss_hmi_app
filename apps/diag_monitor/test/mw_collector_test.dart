// import 'package:flutter_test/flutter_test.dart';
// import 'package:roslibdart/roslibdart.dart';
// import 'package:diag_monitor/controller/mw_collector.dart';
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


import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:diag_monitor/controller/mw_collector.dart';

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
  dynamic notificationHandler; // Future<void> Function(Map<String, dynamic>)

  setUp(() {
    // GetX 초기화
    Get.reset();

    mockRos = MockRos();

    // 테스트 간 핸들러 캡처 누수 방지(이전 테스트의 bind 핸들러를 재사용하지 않도록).
    infoListHandler = null;
    infoRespHandler = null;
    notificationHandler = null;

    infoReqTopic = MockTopic();
    infoListReqTopic = MockTopic();
    infoRespTopic = MockTopic();
    infoListRespTopic = MockTopic();
    // 소스가 DiagnosticNotification 도 구독함 → 별도 mock + 스텁 필요.
    final infoNotificationTopic = MockTopic();
    when(() => infoNotificationTopic.subscribe(any()))
        .thenAnswer((invocation) async {
      notificationHandler = invocation.positionalArguments[0];
    });
    when(() => infoNotificationTopic.unsubscribe())
        .thenAnswer((_) => Future<void>.value());

    // GetX에 Ros 주입
    Get.put<Ros>(mockRos);
    // 소스가 ros.status (connected) 를 게이트로 사용 → 스텁.
    when(() => mockRos.status).thenReturn(Status.connected);

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
        case '/mmf/diagnosticmgr/DiagnosticNotification':
          return infoNotificationTopic;
        default:
          return MockTopic();
      }
    }

    collector = MwCollector(topicFactory: topicFactory);
  });

  tearDown(() {
    // collector 는 Get.put 으로 등록하지 않았으므로 watchdog 타이머를 직접 정리.
    collector.onClose();
    Get.reset();
  });

  // onInit() 은 500ms 주기 watchdog 으로 ROS 에 바인딩한다(동기 X). 바인딩이
  // 끝나면 infoListResp 구독 핸들러가 캡처되므로 그 시점까지 폴링한다.
  Future<void> waitForBind() async {
    for (var i = 0; i < 40; i++) {
      if (infoListHandler != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('MwCollector did not bind/subscribe within timeout');
  }

  group('MwCollector lifecycle', () {
    test('onInit binds (advertise+subscribe) and refreshOnce sends the list request',
        () async {
      // Act — watchdog 바인딩 대기
      collector.onInit();
      await waitForBind();

      // Assert — 바인딩 시 Request 퍼블리셔 advertise + Response 구독
      verify(() => infoListReqTopic.advertise()).called(1);
      verify(() => infoReqTopic.advertise()).called(1);
      verify(() => infoListRespTopic.subscribe(any())).called(1);
      verify(() => infoRespTopic.subscribe(any())).called(1);

      // 현 설계: 초기 리스트 요청은 refreshOnce() 가 트리거(자동 X).
      await collector.refreshOnce();
      verify(() => infoListReqTopic.publish(any())).called(greaterThan(0));
    });

    test('onClose unsubscribes and unadvertises topics', () async {
      // Arrange
      collector.onInit();
      await waitForBind();

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
    test('onInfoListResponse maps code/name into diagnostics and requests detail',
        () async {
      // Arrange
      collector.onInit();
      await waitForBind();

      // 리스트 응답 핸들러가 제대로 캡처되었는지 확인
      expect(infoListHandler, isNotNull);

      final msg = <String, dynamic>{
        'diag_codes': [1, '2'],
        'diag_names': ['DiagA', 'DiagB'],
      };

      // Act
      await infoListHandler(msg);

      // Assert — 현 API: diagnostics(List<Map>) 에 name/code 매핑이 들어옴
      // (구버전 diagNames/topicData 게터는 제거됨).
      final byName = {
        for (final e in collector.diagnostics) e['name'] as String: e,
      };
      expect(byName.containsKey('DiagA'), isTrue);
      expect(byName.containsKey('DiagB'), isTrue);
      expect(byName['DiagA']!['code'], 1);
      expect(byName['DiagB']!['code'], 2); // '2' → 2 정규화

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
      await waitForBind();
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

      // Assert — 현 API: 상세 응답은 diagnostics 의 해당 code 엔트리를 갱신
      // (구버전 topicData 맵 제거됨).
      final info = collector.diagnostics.firstWhere(
        (e) => e['code'] == 10,
        orElse: () => <String, dynamic>{},
      );
      expect(info, isNotEmpty);
      expect(info['name'], 'EngineStatus');
      expect(info['code'], 10);
      // ret_code / ret_text 매핑 확인
      expect(info['ret_code'], 1);
      expect(info['ret_text'], 'PASS');
      // status / status_text 매핑 확인
      expect(info['status'], 2);
      expect(info['status_text'], 'FATAL');
      expect(info['message'], 'Overheated');
    });

    test('onInfoResponse ignores a detail whose code is not in the list (graceful no-op)',
        () async {
      // 현 _onInfoResponse 는 diagnostics 에 없는 code 면 early-return 한다
      // (구버전의 diag_name fallback 신규 생성 동작은 제거됨).
      // Arrange
      collector.onInit();
      await waitForBind();
      expect(infoRespHandler, isNotNull);

      // 리스트 응답으로 코드 10만 등록.
      await infoListHandler(<String, dynamic>{
        'diag_codes': [10],
        'diag_names': ['EngineStatus'],
      });
      final before = collector.diagnostics.length;

      // 매핑에 없는 코드(999)에 대한 상세 응답.
      await infoRespHandler(<String, dynamic>{
        'diag_code': 999,
        'diag_name': 'UnknownDiag',
        'ret_code': {'ret_code': 2},
        'status': {'diag_status': 3},
        'message': 'Something odd',
      });

      // Assert — 새 엔트리 생성 안 됨, 기존 목록 불변.
      expect(collector.diagnostics.length, before);
      expect(
        collector.diagnostics.any((e) => e['name'] == 'UnknownDiag'),
        isFalse,
      );
    });

    test('onInfoListResponse handles empty list and null gracefully', () async {
      collector.onInit();
      await waitForBind();

      // Empty response
      await infoListHandler(<String, dynamic>{
        'diag_codes': <dynamic>[],
        'diag_names': <dynamic>[],
      });
      expect(collector.diagnostics, isEmpty);

      // Malformed response
      await infoListHandler(<String, dynamic>{});
      expect(collector.diagnostics, isEmpty);
    });

    test('onInfoResponse parses nested map ret_code and status, and fallback ret_text', () async {
      collector.onInit();
      await waitForBind();

      await infoListHandler(<String, dynamic>{
        'diag_codes': [20, 21],
        'diag_names': ['SensorA', 'SensorB'],
      });

      // Nested map ret_code & status
      await infoRespHandler(<String, dynamic>{
        'diag_code': 20,
        'ret_code': {'ret_code': 2},
        'status': {'diag_status': 1},
        'message': 'OK',
      });

      final item20 = collector.diagnostics.firstWhere((e) => e['code'] == 20);
      expect(item20['ret_code'], 2);
      expect(item20['ret_text'], 'FAIL');
      expect(item20['status'], 1);
      expect(item20['status_text'], 'PASS');

      // Unknown ret_code and status
      await infoRespHandler(<String, dynamic>{
        'diag_code': 21,
        'ret_code': 99,
        'status': 99,
        'message': 'Unknown',
      });

      final item21 = collector.diagnostics.firstWhere((e) => e['code'] == 21);
      expect(item21['ret_code'], 99);
      expect(item21['ret_text'], '99');
      expect(item21['status'], 99);
      expect(item21['status_text'], '99');
    });

    test('onNotification parses item, logs, and triggers security alert', () async {
      collector.onInit();
      await waitForBind();

      // Send normal notification
      await notificationHandler(<String, dynamic>{
        'diag_code': 100,
        'diag_name': 'BrakeSensor',
        'status': 1,
        'message': 'Brake normal',
        'source_message_name': 'sensor_node',
        'raw_data': 'raw123',
      });

      expect(collector.notificationLogs.length, 1);
      expect(collector.notificationLogs.first.label, 'BrakeSensor (100)');
      expect(collector.securityData.value, isNull);

      // Send security notification
      await notificationHandler(<String, dynamic>{
        'diag_code': 101,
        'diag_name': 'SecurityManager',
        'status': 'FATAL',
        'message': 'Intrusion detected',
        'source_message_name': 'sec_node',
        'raw_data': 'sec_raw',
      });

      expect(collector.notificationLogs.length, 2);
      expect(collector.securityData.value, isNotNull);
      expect(collector.securityData.value, contains('Intrusion detected'));

      // Test different status string types and security keywords
      await notificationHandler(<String, dynamic>{
        'diag_code': 102,
        'diag_name': 'Normal Sensor',
        'status': 'WARNING',
        'message': 'Warning from SecMgr',
        'source_message_name': 'node',
      });
      expect(collector.notificationLogs.first.status, 3);
      expect(collector.notificationLogs.first.statusText, 'WARNING');

      await notificationHandler(<String, dynamic>{
        'diag_code': 103,
        'diag_name': 'Security Manager',
        'status': {'value': 'PASS'},
        'message': 'OK',
      });
      expect(collector.notificationLogs.first.status, 1);
      expect(collector.notificationLogs.first.statusText, 'PASS');

      await notificationHandler(<String, dynamic>{
        'diag_code': 104,
        'diag_name': 'Unknown status format',
        'status': {'value': 2},
        'message': 'custom raw',
        'raw_data': 'security_mgr log',
      });
      expect(collector.notificationLogs.first.status, 2);
      expect(collector.notificationLogs.first.statusText, 'FATAL');

      // Test format security alert with empty/null sub fields
      await notificationHandler(<String, dynamic>{
        'diag_code': 105,
        'diag_name': 'secmgr',
        'status': 2,
        'message': '',
        'source_message_name': '',
        'raw_data': '',
      });
      expect(collector.securityData.value, contains('secmgr (105)'));
    });

    test('refreshOnce handles advertise failure and exception gracefully', () async {
      when(() => infoReqTopic.advertise()).thenThrow(Exception('advertise error'));
      await collector.refreshOnce();
      expect(collector.lastError.value, isNotEmpty);
    });
  });
}

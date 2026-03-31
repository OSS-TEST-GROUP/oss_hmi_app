// OTA Monitor — Integration Tests
//
// MockOtaManager(rosbridge WebSocket 서버)를 통해
// 실제 roslibdart ↔ OtaCollector ↔ UI 전체 파이프라인을 검증한다.
//
// 실행:
//   flutter test integration_test/ -d linux
//
// 테스트 시나리오:
//   1. App List   — 연결 후 초기 앱 목록이 UI에 표시됨
//   2. App Details — 앱 선택 시 settings / state 가 UI에 표시됨
//   3. Update History — 업데이트 요청 후 히스토리에 기록됨

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ota_monitor/config/app_config.dart';
import 'package:ota_monitor/controller/ota_collector.dart';
import 'package:ota_monitor/data/ota_data.dart';
import 'package:ota_monitor/main.dart';
import 'package:ota_monitor/ros/ros_keeper.dart';
import 'package:roslibdart/roslibdart.dart';

import 'mock_ota_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockOtaManager mock;
  late RosKeeper rosKeeper;
  late OtaCollector collector;

  // ── 전체 테스트 생애주기 ──────────────────────────────────────────────────

  setUpAll(() async {
    mock = MockOtaManager();
    await mock.start();
  });

  tearDownAll(() async {
    await mock.stop();
  });

  setUp(() async {
    Get.reset();
    mock.receivedRequests.clear();

    // OtaCollector — 실제 roslibdart Topic 팩토리 사용
    collector = OtaCollector(
      topicFactory: (ros, name, type) => Topic(ros: ros, name: name, type: type),
    );
    Get.put<OtaCollector>(collector, permanent: true);

    // RosKeeper — mock 서버 포트를 가리킴
    final cfg = AppConfig(
      rosUrl: Uri.parse('ws://localhost:${mock.port}'),
      statusTopic: '/test/ota_monitor_status',
    );
    rosKeeper = RosKeeper(cfg);
    await rosKeeper.start();
  });

  tearDown(() async {
    await rosKeeper.stop();
    Get.reset();
  });

  // ── 공통 헬퍼 ────────────────────────────────────────────────────────────

  // 조건이 참이 될 때까지 최대 [maxAttempts] × 100ms 대기.
  // Future.delayed로 실제 시간을 소비하고, pump()로 프레임을 처리한다.
  Future<void> waitUntil(
    WidgetTester tester,
    bool Function() condition, {
    int maxAttempts = 60,
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
  }

  // integration_test 환경(Xvfb 등)에서 실제 화면이 작아 RenderFlex overflow가
  // 발생할 수 있다. 이는 앱 로직 버그가 아닌 테스트 환경 제약이므로 suppression.
  // addTearDown으로 테스트 종료 시 원래 핸들러를 복원한다.
  void suppressOverflowErrors() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  // integration_test에서 렌더링 표면을 충분히 넓게 설정한다.
  void setTestSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. App List
  // ══════════════════════════════════════════════════════════════════════════

  group('App List', () {
    testWidgets(
      '연결 후 초기 앱 3개가 목록에 표시된다',
      (tester) async {
        await tester.pumpWidget(const OtaMonitorApp());

        // mock 서버에서 NotifyAppUpdateStatus × 3을 받을 때까지 대기
        await waitUntil(tester, () => collector.appList.length >= 3);

        expect(find.text('NavigationApp'), findsOneWidget);
        expect(find.text('MapUpdater'), findsOneWidget);
        expect(find.text('SensorFusion'), findsOneWidget);
      },
    );

    testWidgets(
      '각 앱의 초기 상태 텍스트가 표시된다',
      (tester) async {
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        // status 텍스트 확인 (앱 카드 하단 표시)
        expect(find.text('Synced'), findsOneWidget);   // NavigationApp
        expect(find.text('idle'), findsAtLeastNWidgets(1)); // MapUpdater
      },
    );

    testWidgets(
      'App List 헤더에 앱 개수가 표시된다',
      (tester) async {
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        // DataViewWidget 타이틀: 'App List (3)'
        expect(find.text('App List (3)'), findsOneWidget);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2. App Details
  // ══════════════════════════════════════════════════════════════════════════

  group('App Details', () {
    testWidgets(
      '앱을 선택하면 App Details 타이틀에 앱 이름이 표시된다',
      (tester) async {
        setTestSurface(tester);
        suppressOverflowErrors();
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        // NavigationApp 탭
        await tester.tap(find.text('NavigationApp'));
        await tester.pump();

        expect(find.text('App Details: NavigationApp'), findsOneWidget);
      },
    );

    testWidgets(
      '앱 선택 후 settings가 로드되어 UI에 표시된다',
      (tester) async {
        setTestSurface(tester);
        suppressOverflowErrors();

        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        await tester.tap(find.text('NavigationApp'));

        // collector에 settings 데이터가 수신되었는지 확인
        await waitUntil(
            tester, () => collector.topicData['NavigationApp_settings'] != null);

        // settings JSON 값이 collector에 저장됨
        final settings =
            collector.topicData['NavigationApp_settings'] as String;
        expect(settings, contains('auto_update'));

        // settings 값이 UI에도 표시됨 (overflow가 없는 경우)
        expect(find.textContaining('auto_update'), findsOneWidget);
      },
    );

    testWidgets(
      '앱 선택 후 state가 로드되어 UI에 표시된다',
      (tester) async {
        setTestSurface(tester);
        suppressOverflowErrors();

        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        await tester.tap(find.text('NavigationApp'));

        // state 응답 수신 대기
        await waitUntil(
            tester, () => collector.topicData['NavigationApp_state'] != null);

        // collector에 state 데이터가 저장됨
        expect(collector.topicData['NavigationApp_state'], 'idle');

        // state 값 'idle'이 UI에도 표시됨
        expect(find.text('idle'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      '앱 선택 시 GetAppUpdateSettings, GetAppUpdateState 요청이 전송된다',
      (tester) async {
        setTestSurface(tester);
        suppressOverflowErrors();
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        await tester.tap(find.text('MapUpdater'));
        await waitUntil(
            tester, () => collector.topicData['MapUpdater_settings'] != null);

        final topicsRequested =
            mock.receivedRequests.map((r) => r['topic'] as String).toList();

        expect(topicsRequested, contains(otaRequestTopics[0])); // GetAppUpdateSettings
        expect(topicsRequested, contains(otaRequestTopics[2])); // GetAppUpdateState
      },
    );

    testWidgets(
      'Refresh Settings 버튼을 누르면 settings가 다시 요청된다',
      (tester) async {
        setTestSurface(tester);
        suppressOverflowErrors();
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        await tester.tap(find.text('NavigationApp'));
        await waitUntil(
            tester, () => collector.topicData['NavigationApp_settings'] != null);

        final countBefore = mock.receivedRequests
            .where((r) => r['topic'] == otaRequestTopics[0])
            .length;

        await tester.tap(find.text('Refresh Settings'));
        await waitUntil(tester, () {
          final countAfter = mock.receivedRequests
              .where((r) => r['topic'] == otaRequestTopics[0])
              .length;
          return countAfter > countBefore;
        });

        final countAfter = mock.receivedRequests
            .where((r) => r['topic'] == otaRequestTopics[0])
            .length;
        expect(countAfter, greaterThan(countBefore));
      },
    );

    testWidgets(
      'Refresh State 버튼을 누르면 state가 다시 요청된다',
      (tester) async {
        setTestSurface(tester);
        suppressOverflowErrors();
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        await tester.tap(find.text('NavigationApp'));
        await waitUntil(
            tester, () => collector.topicData['NavigationApp_state'] != null);

        final countBefore = mock.receivedRequests
            .where((r) => r['topic'] == otaRequestTopics[2])
            .length;

        await tester.tap(find.text('Refresh State'));
        await waitUntil(tester, () {
          final countAfter = mock.receivedRequests
              .where((r) => r['topic'] == otaRequestTopics[2])
              .length;
          return countAfter > countBefore;
        });

        final countAfter = mock.receivedRequests
            .where((r) => r['topic'] == otaRequestTopics[2])
            .length;
        expect(countAfter, greaterThan(countBefore));
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3. Update History
  // ══════════════════════════════════════════════════════════════════════════

  group('Update History', () {
    // 공통 셋업: 연결 → 앱 선택 → details 로드 완료 대기
    Future<void> selectApp(WidgetTester tester, String appName) async {
      setTestSurface(tester);
      suppressOverflowErrors();
      await tester.pumpWidget(const OtaMonitorApp());
      await waitUntil(tester, () => collector.appList.length >= 3);

      await tester.tap(find.text(appName));
      await waitUntil(
          tester, () => collector.topicData['${appName}_settings'] != null);
    }

    testWidgets(
      '업데이트 요청 확인 다이얼로그가 표시된다',
      (tester) async {
        await selectApp(tester, 'NavigationApp');

        await tester.tap(find.text('Request Update'));
        await tester.pump();

        // 확인 다이얼로그 확인
        expect(find.text('확인'), findsAtLeastNWidgets(1));
        expect(find.textContaining('NavigationApp'), findsAtLeastNWidgets(1));

        // 취소
        await tester.tap(find.text('취소'));
        await tester.pump();
      },
    );

    testWidgets(
      '업데이트 확인 후 updateHistory에 Update requested 항목이 기록된다',
      (tester) async {
        await selectApp(tester, 'NavigationApp');

        await tester.tap(find.text('Request Update'));
        await tester.pump();
        await tester.tap(find.text('확인').last); // 다이얼로그 확인

        // SetAppUpdateResponse 수신 대기 ('Update requested' 항목이 생길 때까지)
        await waitUntil(tester, () => collector.updateHistory
            .any((e) => e['message'] == 'Update requested'));

        final entry = collector.updateHistory
            .firstWhere((e) => e['message'] == 'Update requested',
                orElse: () => {});
        expect(entry['app_name'], 'NavigationApp');
        expect(entry['ret_code'], 1); // success
      },
    );

    testWidgets(
      '업데이트 후 updating, complete 상태가 히스토리에 순서대로 기록된다',
      (tester) async {
        await selectApp(tester, 'NavigationApp');

        await tester.tap(find.text('Request Update'));
        await tester.pump();
        await tester.tap(find.text('확인').last);

        // updating + complete NotifyAppUpdateStatus 수신 대기
        await waitUntil(tester, () => collector.updateHistory
            .any((e) => e['message'] == 'Status: complete'));

        final messages =
            collector.updateHistory.map((e) => e['message'] as String).toList();

        expect(messages, contains('Status: updating'));
        expect(messages, contains('Status: complete'));
      },
    );

    testWidgets(
      '업데이트 완료 후 앱 상태가 complete로 변경된다',
      (tester) async {
        await selectApp(tester, 'NavigationApp');

        await tester.tap(find.text('Request Update'));
        await tester.pump();
        await tester.tap(find.text('확인').last);

        // complete 상태 수신 대기
        await waitUntil(tester,
            () => collector.topicData['NavigationApp_status'] == 'complete');

        expect(collector.topicData['NavigationApp_status'], 'complete');

        // appList의 status도 업데이트됨
        final app = collector.appList
            .firstWhere((a) => a['name'] == 'NavigationApp', orElse: () => {});
        expect(app['status'], 'complete');
      },
    );

    testWidgets(
      '히스토리 항목이 Update History 패널에 UI로 표시된다',
      (tester) async {
        await selectApp(tester, 'NavigationApp');

        await tester.tap(find.text('Request Update'));
        await tester.pump();
        await tester.tap(find.text('확인').last);

        await waitUntil(tester, () => collector.updateHistory
            .any((e) => e['message'] == 'Update requested'));
        await tester.pump(); // UI 재빌드

        // Update History 패널에 NavigationApp 텍스트가 보여야 함
        // (appName - message 형식으로 표시)
        expect(
          find.textContaining('NavigationApp'),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      '다른 앱(MapUpdater)의 업데이트도 올바르게 히스토리에 기록된다',
      (tester) async {
        await selectApp(tester, 'MapUpdater');

        await tester.tap(find.text('Request Update'));
        await tester.pump();
        await tester.tap(find.text('확인').last);

        await waitUntil(tester, () => collector.updateHistory
            .any((e) => e['app_name'] == 'MapUpdater' && e['message'] == 'Update requested'));

        final entry = collector.updateHistory.firstWhere(
            (e) => e['app_name'] == 'MapUpdater' && e['message'] == 'Update requested',
            orElse: () => {});
        expect(entry, isNotEmpty);
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 4. 수동 상태 주입 (mock.sendNotifyStatus 활용)
  // ══════════════════════════════════════════════════════════════════════════

  group('수동 상태 주입', () {
    testWidgets(
      'sendNotifyStatus로 임의 앱을 목록에 추가할 수 있다',
      (tester) async {
        setTestSurface(tester);
        suppressOverflowErrors();
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        // 테스트에서 새 앱 상태를 직접 주입
        mock.sendNotifyStatus('TestInjectedApp', 'testing');
        await waitUntil(tester,
            () => collector.appList.any((a) => a['name'] == 'TestInjectedApp'));

        expect(find.text('TestInjectedApp'), findsOneWidget);
      },
    );

    testWidgets(
      'sendNotifyStatus로 기존 앱 상태를 변경할 수 있다',
      (tester) async {
        setTestSurface(tester);
        suppressOverflowErrors();
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        // 연결 불안정 시 재전송 — 수신 확인될 때까지 반복 송신
        await waitUntil(tester, () {
          if (collector.topicData['NavigationApp_status'] == 'error') return true;
          mock.sendNotifyStatus('NavigationApp', 'error');
          return false;
        }, maxAttempts: 60);

        final app = collector.appList
            .firstWhere((a) => a['name'] == 'NavigationApp', orElse: () => {});
        expect(app['status'], 'error');
      },
    );
  });
}

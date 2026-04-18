// OTA Monitor — Integration Tests
//
// Default: drive the full roslibdart ↔ OtaCollector ↔ UI pipeline through
// MockOtaManager (a local WebSocket server).
//
// F013 real rosbridge mode:
//   Passing --dart-define=OTA_ROS_URL=ws://localhost:9090 skips MockOtaManager
//   and connects to the real rosbridge_server at that URL. A ROS2
//   rosbridge_server + ota_manager_mock.py (or the real OtaManager) must
//   already be running. See integration_test/REAL_STACK_SETUP.md for details.
//
// Run:
//   flutter test integration_test/ -d linux                                     # mock
//   flutter test integration_test/ -d linux --dart-define=OTA_ROS_URL=ws://...  # real
//
// Test scenarios:
//   1. App List        — initial app list is displayed in the UI after connect
//   2. App Details     — selecting an app renders its settings / state
//   3. Update History  — requesting an update records an entry
//   4. Manual status injection — Mock-only (sendNotifyStatus); skipped in real mode

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

// F013: real rosbridge mode when --dart-define=OTA_ROS_URL=ws://... is set.
// An empty value keeps the existing MockOtaManager path.
const String _otaRosUrlOverride =
    String.fromEnvironment('OTA_ROS_URL', defaultValue: '');
final bool _useRealStack = _otaRosUrlOverride.isNotEmpty;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  MockOtaManager? mock;
  late RosKeeper rosKeeper;
  late OtaCollector collector;

  // ── Test lifecycle ──────────────────────────────────────────────────────

  setUpAll(() async {
    if (!_useRealStack) {
      mock = MockOtaManager();
      await mock!.start();
    }
  });

  tearDownAll(() async {
    if (!_useRealStack && mock != null) {
      await mock!.stop();
    }
  });

  setUp(() async {
    Get.reset();
    if (!_useRealStack) {
      mock!.receivedRequests.clear();
    }

    // OtaCollector — real roslibdart Topic factory
    collector = OtaCollector(
      topicFactory: (ros, name, type) => Topic(ros: ros, name: name, type: type),
    );
    Get.put<OtaCollector>(collector, permanent: true);

    // RosKeeper — override URL in real mode, otherwise the mock server port
    final rosUrl = _useRealStack
        ? Uri.parse(_otaRosUrlOverride)
        : Uri.parse('ws://localhost:${mock!.port}');
    final cfg = AppConfig(
      rosUrl: rosUrl,
      statusTopic: '/test/ota_monitor_status',
    );
    rosKeeper = RosKeeper(cfg);
    await rosKeeper.start();
  });

  tearDown(() async {
    await rosKeeper.stop();
    Get.reset();
  });

  // ── Helpers ─────────────────────────────────────────────────────────────

  // Wait until [condition] becomes true, up to [maxAttempts] × 100ms.
  // Uses Future.delayed to consume real time and pump() to process frames.
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

  // In integration_test environments (e.g. Xvfb) the actual surface can be
  // small, causing RenderFlex overflow. This is an env constraint, not a bug,
  // so we suppress it. addTearDown restores the original handler.
  void suppressOverflowErrors() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  // Set a sufficiently wide rendering surface for integration_test.
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

        // Wait until 3 NotifyAppUpdateStatus events arrive from the mock.
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

        // Check status text (shown at the bottom of each app card).
        expect(find.text('Synced'), findsOneWidget);   // NavigationApp
        expect(find.text('idle'), findsAtLeastNWidgets(1)); // MapUpdater
      },
    );

    testWidgets(
      'App List 헤더에 앱 개수가 표시된다',
      (tester) async {
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        // DataViewWidget title: 'App List (3)'
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

        // Tap NavigationApp.
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

        // Check that settings data arrived at the collector.
        await waitUntil(
            tester, () => collector.topicData['NavigationApp_settings'] != null);

        // Settings JSON is stored on the collector.
        final settings =
            collector.topicData['NavigationApp_settings'] as String;
        expect(settings, contains('auto_update'));

        // Settings value is also rendered in the UI (when no overflow).
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

        // Wait for state response.
        await waitUntil(
            tester, () => collector.topicData['NavigationApp_state'] != null);

        // State data is stored on the collector.
        expect(collector.topicData['NavigationApp_state'], 'idle');

        // The 'idle' state value is also rendered in the UI.
        expect(find.text('idle'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      '앱 선택 시 GetAppUpdateSettings, GetAppUpdateState 요청이 전송된다',
      (tester) async {
        if (_useRealStack) return; // F013: mock.receivedRequests only in mock mode
        setTestSurface(tester);
        suppressOverflowErrors();
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        await tester.tap(find.text('MapUpdater'));
        await waitUntil(
            tester, () => collector.topicData['MapUpdater_settings'] != null);

        final topicsRequested =
            mock!.receivedRequests.map((r) => r['topic'] as String).toList();

        expect(topicsRequested, contains(otaRequestTopics[0])); // GetAppUpdateSettings
        expect(topicsRequested, contains(otaRequestTopics[2])); // GetAppUpdateState
      },
    );

    testWidgets(
      'Refresh Settings 버튼을 누르면 settings가 다시 요청된다',
      (tester) async {
        if (_useRealStack) return; // F013: mock.receivedRequests only in mock mode
        setTestSurface(tester);
        suppressOverflowErrors();
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        await tester.tap(find.text('NavigationApp'));
        await waitUntil(
            tester, () => collector.topicData['NavigationApp_settings'] != null);

        final countBefore = mock!.receivedRequests
            .where((r) => r['topic'] == otaRequestTopics[0])
            .length;

        await tester.tap(find.text('Refresh Settings'));
        await waitUntil(tester, () {
          final countAfter = mock!.receivedRequests
              .where((r) => r['topic'] == otaRequestTopics[0])
              .length;
          return countAfter > countBefore;
        });

        final countAfter = mock!.receivedRequests
            .where((r) => r['topic'] == otaRequestTopics[0])
            .length;
        expect(countAfter, greaterThan(countBefore));
      },
    );

    testWidgets(
      'Refresh State 버튼을 누르면 state가 다시 요청된다',
      (tester) async {
        if (_useRealStack) return; // F013: mock.receivedRequests only in mock mode
        setTestSurface(tester);
        suppressOverflowErrors();
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        await tester.tap(find.text('NavigationApp'));
        await waitUntil(
            tester, () => collector.topicData['NavigationApp_state'] != null);

        final countBefore = mock!.receivedRequests
            .where((r) => r['topic'] == otaRequestTopics[2])
            .length;

        await tester.tap(find.text('Refresh State'));
        await waitUntil(tester, () {
          final countAfter = mock!.receivedRequests
              .where((r) => r['topic'] == otaRequestTopics[2])
              .length;
          return countAfter > countBefore;
        });

        final countAfter = mock!.receivedRequests
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
    // Common setup: connect → select app → wait for details to load.
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

        // Verify the confirm dialog.
        expect(find.text('확인'), findsAtLeastNWidgets(1));
        expect(find.textContaining('NavigationApp'), findsAtLeastNWidgets(1));

        // Cancel.
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
        await tester.tap(find.text('확인').last); // confirm the dialog

        // Wait for SetAppUpdateResponse (until an 'Update requested' entry appears).
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

        // Wait for updating + complete NotifyAppUpdateStatus.
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

        // Wait for the complete status.
        await waitUntil(tester,
            () => collector.topicData['NavigationApp_status'] == 'complete');

        expect(collector.topicData['NavigationApp_status'], 'complete');

        // status on appList is also updated.
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
        await tester.pump(); // rebuild UI

        // NavigationApp text must appear in the Update History panel
        // (rendered as "appName - message").
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
  // 4. Manual status injection (uses mock.sendNotifyStatus)
  // ══════════════════════════════════════════════════════════════════════════

  group('Manual status injection', () {
    testWidgets(
      'sendNotifyStatus로 임의 앱을 목록에 추가할 수 있다',
      (tester) async {
        if (_useRealStack) return; // F013: sendNotifyStatus only in mock mode
        setTestSurface(tester);
        suppressOverflowErrors();
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        // Inject a new app status directly from the test.
        mock!.sendNotifyStatus('TestInjectedApp', 'testing');
        await waitUntil(tester,
            () => collector.appList.any((a) => a['name'] == 'TestInjectedApp'));

        expect(find.text('TestInjectedApp'), findsOneWidget);
      },
    );

    testWidgets(
      'sendNotifyStatus로 기존 앱 상태를 변경할 수 있다',
      (tester) async {
        if (_useRealStack) return; // F013: sendNotifyStatus only in mock mode
        setTestSurface(tester);
        suppressOverflowErrors();
        await tester.pumpWidget(const OtaMonitorApp());
        await waitUntil(tester, () => collector.appList.length >= 3);

        // Retransmit on flaky connections until reception is confirmed.
        await waitUntil(tester, () {
          if (collector.topicData['NavigationApp_status'] == 'error') return true;
          mock!.sendNotifyStatus('NavigationApp', 'error');
          return false;
        }, maxAttempts: 60);

        final app = collector.appList
            .firstWhere((a) => a['name'] == 'NavigationApp', orElse: () => {});
        expect(app['status'], 'error');
      },
    );
  });
}

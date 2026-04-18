// F011: Chrome (web) integration tests for ota_monitor.
//
// 실행법:
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/ota_web_test.dart \
//     -d chrome
//
// 상세 가이드: integration_test/INTEGRATION_TEST_GUIDE.md 의 "Web 실행" 섹션.
//
// 이 테스트는 MockOtaManager(dart:io HttpServer) 를 사용하지 않는다. 브라우저
// 런타임에는 dart:io가 없기 때문이다. 대신 OtaCollector에 seed 데이터를 주입해
// UI 렌더링·상호작용을 검증한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ota_monitor/controller/ota_collector.dart';
import 'package:ota_monitor/view/ota_view_page.dart';
import 'package:roslibdart/roslibdart.dart';

class _MockRos extends Mock implements Ros {}
class _MockTopic extends Mock implements Topic {}

Future<OtaCollector> _seedCollector(List<Map<String, dynamic>> apps) async {
  Get.reset();
  Get.put<Ros>(_MockRos());
  final topics = List.generate(9, (_) {
    final t = _MockTopic();
    when(() => t.subscribe(any())).thenAnswer((_) async {});
    when(() => t.advertise()).thenAnswer((_) async {});
    when(() => t.publish(any())).thenAnswer((_) async {});
    return t;
  });
  int i = 0;
  final c = OtaCollector(
    topicFactory: (ros, name, type) => topics[i++ % topics.length],
    autoStartTimers: false,
  );
  Get.put<OtaCollector>(c);
  for (final a in apps) {
    c.appList.add(a);
    final name = a['name'] as String;
    c.topicData['${name}_settings'] = a['settings'] ?? '';
    c.topicData['${name}_state'] = a['state'] ?? '';
    c.topicData['${name}_status'] = a['status'] ?? 'Unknown';
  }
  return c;
}

void _suppressOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('RenderFlex overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web: app list renders and shows seeded entries',
      (tester) async {
    _suppressOverflow();
    await _seedCollector([
      {
        'name': 'NavigationApp',
        'settings': '{"interval":5}',
        'state': 'idle',
        'status': 'Ready',
      },
      {
        'name': 'MapUpdater',
        'settings': '',
        'state': '',
        'status': 'Unknown',
      },
    ]);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: OtaViewPage()),
    ));
    await tester.pump();

    expect(find.text('NavigationApp'), findsOneWidget);
    expect(find.text('MapUpdater'), findsOneWidget);
    expect(find.textContaining('App List (2)'), findsOneWidget);

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      Get.reset();
    });
  });

  testWidgets('web: opening "테스트 앱 추가" dialog works in browser',
      (tester) async {
    _suppressOverflow();
    await _seedCollector(const []);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: OtaViewPage()),
    ));
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, '테스트 앱 추가'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      Get.reset();
    });
  });
}

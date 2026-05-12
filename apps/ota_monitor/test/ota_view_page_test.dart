import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ota_monitor/controller/ota_collector.dart';
import 'package:ota_monitor/view/ota_view_page.dart';
import 'package:roslibdart/roslibdart.dart';

class _MockRos extends Mock implements Ros {}
class _MockTopic extends Mock implements Topic {}

/// Suppress RenderFlex overflow noise since widget tests run at a nominal
/// viewport size smaller than the production 3-panel layout. Real layout
/// correctness is covered by integration tests with a full display.
void _suppressOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('RenderFlex overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

/// Widget tests for the refactored OtaViewPage. The right panel is now
/// 4 inline ActorCards (was App Details + Update History before).
Future<OtaCollector> _putCollector({
  List<Map<String, dynamic>> seedApps = const [],
}) async {
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
  final collector = OtaCollector(
    topicFactory: (ros, name, type) => topics[i++ % topics.length],
    autoStartTimers: false,
  );
  Get.put<OtaCollector>(collector);

  for (final a in seedApps) {
    collector.appList.add(a);
    final name = a['name'] as String;
    collector.topicData['${name}_settings'] = a['settings'] ?? '';
    collector.topicData['${name}_state'] = a['state'] ?? '';
    collector.topicData['${name}_status'] = a['status'] ?? 'Unknown';
  }

  addTearDown(() async {
    Get.delete<OtaCollector>(force: true);
    Get.reset();
  });
  return collector;
}

Future<void> _pumpView(WidgetTester tester, {int truncateLength = 100}) async {
  _suppressOverflow();
  tester.view.physicalSize = const Size(1800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: OtaViewPage(truncateLength: truncateLength),
    ),
  ));
  await tester.pump(); // let Obx settle

  // Ensure the widget tree is torn down and controllers disposed BEFORE the
  // test framework checks for pending timers.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void main() {
  tearDown(() => Get.reset());

  testWidgets('renders the app list with seeded entries', (tester) async {
    await _putCollector(seedApps: [
      {'name': 'NavigationApp', 'settings': '', 'state': '', 'status': 'Ready'},
      {'name': 'MapUpdater', 'settings': '', 'state': '', 'status': 'Unknown'},
    ]);
    await _pumpView(tester);

    expect(find.text('NavigationApp'), findsOneWidget);
    expect(find.text('MapUpdater'), findsOneWidget);
    expect(find.textContaining('App List (2)'), findsOneWidget);
  });

  testWidgets('right panel exposes the four Actor cards by key',
      (tester) async {
    await _putCollector();
    await _pumpView(tester);

    expect(find.byKey(const Key('card_actor_get_settings')), findsOneWidget);
    expect(find.byKey(const Key('card_actor_set_settings')), findsOneWidget);
    expect(find.byKey(const Key('card_actor_get_state')), findsOneWidget);
    expect(find.byKey(const Key('card_actor_set_update')), findsOneWidget);
  });

  testWidgets('removed UI (테스트 앱 추가, App Details, Update History) is gone',
      (tester) async {
    await _putCollector(seedApps: [
      {'name': 'NavigationApp', 'settings': '', 'state': '', 'status': 'Ready'},
    ]);
    await _pumpView(tester);

    expect(find.text('테스트 앱 추가'), findsNothing);
    expect(find.text('App Details'), findsNothing);
    expect(find.text('Update History'), findsNothing);
  });
}

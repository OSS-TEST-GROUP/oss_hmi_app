import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:adsw_monitor/controller/mw_collector.dart';
import 'package:adsw_monitor/view/mw_view_page.dart';

void main() {
  late MwCollector mockCollector;

  setUp(() {
    mockCollector = MwCollector();
    Get.put<MwCollector>(mockCollector);
  });

  // testWidgets('should display security problem dialog', (WidgetTester tester) async {
  //   
  // });

  testWidgets('should show expansionTile title', (WidgetTester tester) async {

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: MwViewPage()),
      ),
    );

    await tester.pump();

    // 큰 카테고리명들이 다 보여야 함
    expect(find.text('Lifecycle status'), findsOneWidget);
    expect(find.text('Ota status'), findsOneWidget);
    expect(find.text('Security status'), findsOneWidget);
  });
}
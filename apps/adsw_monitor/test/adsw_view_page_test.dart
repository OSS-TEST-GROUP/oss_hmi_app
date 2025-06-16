import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:adsw_monitor/controller/adsw_collector.dart';
import 'package:adsw_monitor/view/adsw_view_page.dart';
import 'package:roslibdart/roslibdart.dart';

void main() {
  late AdswCollector mockCollector;

  setUp(() {
    mockCollector = AdswCollector(
      topicFactory: (ros, name, type) => Topic(ros: ros, name: name, type: type),
    );
    Get.put<AdswCollector>(mockCollector);
  });

  testWidgets('should display Lane Departure dialog when isLaneDeparture is true', (WidgetTester tester) async {
    // 초기 상태 설정
    mockCollector.topicData['Lane departure'] = '차선 이탈 경고!';
    mockCollector.isLaneDeparture.value = 'true';

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: AdswViewPage()), 
      ),
    );

    await tester.pump(); // Obx 반영
    await tester.pump(); // Dialog 표시 반영

    // alert dialog 텍스트가 보여야 함
    expect(find.text('Lane departure'), findsOneWidget);
    expect(find.text('차선 이탈 경고!'), findsOneWidget);

    // alert dialog 버튼이 잘 보여야 함
    expect(find.text('close'), findsOneWidget);
    expect(find.text('ok'), findsOneWidget);

    // alert dialog 닫기
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    // alert dialog 사라져야 함
    expect(find.text('Lane departure'), findsNothing);
  });

  testWidgets('should show expansionTile title', (WidgetTester tester) async {

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: AdswViewPage()),
      ),
    );

    await tester.pump();

    // 큰 카테고리명들이 다 보여야 함
    expect(find.text('Vehicle'), findsOneWidget);
    expect(find.text('Sensor'), findsOneWidget);
    expect(find.text('Perception'), findsOneWidget);
    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('Localization'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Control'), findsOneWidget);
  });
}
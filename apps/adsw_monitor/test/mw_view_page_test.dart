import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:adsw_monitor/view/mw_view_page.dart';
import 'package:adsw_monitor/controller/mw_collector.dart';
import 'package:roslibdart/roslibdart.dart';

void main() {
  late MwCollector mockCollector;

  setUp(() {
    mockCollector = MwCollector(
      topicFactory: (ros, name, type) => Topic(ros: ros, name: name, type: type),
    );
    mockCollector.topicData['Ota status'] = 'Running';
    Get.put<MwCollector>(mockCollector);
  });

  testWidgets('MwViewPage displays all three DataViewWidgets and toggles sections',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: MwViewPage()),
      ),
    );

    // 각 카테고리명들이 다 보여야 함
    expect(find.text('Lifecycle Status'), findsOneWidget);
    expect(find.text('OTA Status'), findsOneWidget);
    expect(find.text('Security Status'), findsOneWidget);

    // 초기 상태에서는 하위 항목들이 보이지 않아야 함
    expect(find.text('perception_node'), findsNothing);
    expect(find.text('System Version'), findsNothing);
    expect(find.text('Security Level'), findsNothing);

    // Lifecycle Status 클릭
    await tester.tap(find.text('Lifecycle Status'));
    await tester.pumpAndSettle();

    // 클릭하면 하위 항목들이 보여야 함
    expect(find.text('perception_node'), findsOneWidget);
    expect(find.text('localization_node'), findsOneWidget);
    expect(find.text('sensor_fusion'), findsOneWidget);
  });
}

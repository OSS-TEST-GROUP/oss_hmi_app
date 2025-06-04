import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adsw_monitor/widget/data_view_widget.dart';
import 'package:adsw_monitor/model/key_value_item.dart';

void main() {

  testWidgets('DataViewWidget expands to show key-value items', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: DataViewWidget(
            title: 'Info',
            items: [
              KeyValueItem(keyLabel: 'Gear', value: 'D'),
              KeyValueItem(keyLabel: 'Velocity', value: '45 km/h'),
            ],
          ),
        ),
      ),
    );

    // expansion tile 펼치기 전에는 tile의 title만 보여야 함
    expect(find.text('Info'), findsOneWidget);
    expect(find.text('Gear'), findsNothing);
    expect(find.text('Velocity'), findsNothing);

    // expansion tile 펼치기
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    
    // 펼친 후에는 상세 데이터가 보여야 함
    expect(find.text('Gear'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('Velocity'), findsOneWidget);
    expect(find.text('45 km/h'), findsOneWidget);
  });

}
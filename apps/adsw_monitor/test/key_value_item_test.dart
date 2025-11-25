import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adsw_monitor/widget/key_value_item.dart';

void main() {
  group('KeyValueItem Widget Tests', () {
    testWidgets('renders label and value correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyValueItem(
              label: 'Gear',
              value: 'D',
            ),
          ),
        ),
      );

      expect(find.text('Gear'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      // expect(find.byIcon(Icons.check_circle), findsOneWidget); // Default: StatusType.good
    });

    testWidgets('renders subtitle correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyValueItem(
              label: 'Gear', 
              value: 'D',
              subtitle: 'hello test',),
          ),
        ),
      );

      expect(find.text('Gear'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('hello test'), findsOneWidget);
    });
  });
}

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
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // Default: StatusType.good
    });

    testWidgets('renders warning status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyValueItem(
              label: 'Battery',
              value: 'Low',
              status: StatusType.warning,
            ),
          ),
        ),
      );

      expect(find.text('Battery'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('renders error status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyValueItem(
              label: 'Sensor',
              value: 'Fail',
              status: StatusType.error,
            ),
          ),
        ),
      );

      expect(find.text('Sensor'), findsOneWidget);
      expect(find.text('Fail'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });
  });
}

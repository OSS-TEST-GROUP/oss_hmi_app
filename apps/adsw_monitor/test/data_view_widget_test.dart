import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adsw_monitor/widget/data_view_widget.dart';
import 'package:adsw_monitor/widget/key_value_item.dart';

void main() {
  group('DataViewWidget Tests', () {
    testWidgets('renders title, icon, and status', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DataViewWidget(
              title: 'Vehicle',
              icon: Icons.directions_car,
              iconColor: Colors.blue,
              status: StatusType.good,
              isExpanded: false,
              onTap: () {},
              children: const [],
            ),
          ),
        ),
      );

      expect(find.text('Vehicle'), findsOneWidget);
      expect(find.byIcon(Icons.directions_car), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // StatusType.good
    });

    testWidgets('expands and shows children when isExpanded is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DataViewWidget(
              title: 'Sensor',
              icon: Icons.sensors,
              iconColor: Colors.green,
              status: StatusType.warning,
              isExpanded: true,
              onTap: () {},
              children: const [
                Text('Sensor A'),
                Text('Sensor B'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Sensor A'), findsOneWidget);
      expect(find.text('Sensor B'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DataViewWidget(
              title: 'Planning',
              icon: Icons.route,
              iconColor: Colors.purple,
              status: StatusType.error,
              isExpanded: false,
              onTap: () {
                tapped = true;
              },
              children: const [],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Planning'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('does not render children when not expanded', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DataViewWidget(
              title: 'Localization',
              icon: Icons.gps_fixed,
              iconColor: Colors.orange,
              status: StatusType.error,
              isExpanded: false,
              onTap: () {},
              children: const [
                Text('Pose'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Pose'), findsNothing);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });
  });
}

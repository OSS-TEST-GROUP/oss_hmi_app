import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_data_app/widgets/data_card.dart';
import 'package:vehicle_data_app/widgets/info_card.dart';

void main() {
  group('VehicleDataApp Widgets Tests', () {
    testWidgets('DataCard renders label and value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DataCard(label: 'Engine Speed', value: '3000 RPM'),
          ),
        ),
      );

      expect(find.text('Engine Speed'), findsOneWidget);
      expect(find.text('3000 RPM'), findsOneWidget);
    });

    testWidgets('InfoCard renders title and item pairs', (tester) async {
      final items = [
        {'label': 'MODEL ID', 'value': 'KONA'},
        {'label': 'SPEED', 'value': '60 km/h'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfoCard(
              title: 'Vehicle Status',
              items: items,
              leadingIcon: Icons.directions_car,
            ),
          ),
        ),
      );

      expect(find.text('VEHICLE STATUS'), findsOneWidget);
      expect(find.text('MODEL ID'), findsOneWidget);
      expect(find.text('KONA'), findsOneWidget);
      expect(find.text('SPEED'), findsOneWidget);
      expect(find.text('60 km/h'), findsOneWidget);
      expect(find.byIcon(Icons.directions_car), findsOneWidget);
    });
  });
}

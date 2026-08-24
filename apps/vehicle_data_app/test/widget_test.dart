import 'package:flutter_test/flutter_test.dart';

import 'package:vehicle_data_app/main.dart';

void main() {
  testWidgets('VehicleDataApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VehicleDataApp());
    expect(find.byType(VehicleDataApp), findsOneWidget);
  });
}

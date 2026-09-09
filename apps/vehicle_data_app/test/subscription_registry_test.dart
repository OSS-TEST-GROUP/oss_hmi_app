import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_data_app/grpc/subscription_registry.dart';

void main() {
  group('SubscriptionRegistry Tests', () {
    test('add, cancel, remove, and recount cycle', () {
      final reg = SubscriptionRegistry();

      expect(reg.activeCount.value, 0);

      reg.add('sub-001', client: 'client-A', pathPattern: 'Vehicle.Speed');
      expect(reg.activeCount.value, 1);
      expect(reg.isActive('sub-001'), isTrue);
      expect(reg.clientLabel('sub-001'), 'client-A');
      expect(reg.pathPatternOf('sub-001'), 'Vehicle.Speed');

      reg.add('sub-002', client: 'client-B', pathPattern: 'Vehicle.Powertrain.*');
      expect(reg.activeCount.value, 2);

      final snapshot = reg.debugSnapshot();
      expect(snapshot.length, 2);
      expect(snapshot.first, contains('ACTIVE'));

      reg.cancel('sub-001');
      expect(reg.activeCount.value, 1);
      expect(reg.isActive('sub-001'), isFalse);

      reg.remove('sub-001');
      reg.remove('sub-002');
      expect(reg.activeCount.value, 0);
    });
  });
}

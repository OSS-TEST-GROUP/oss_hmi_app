import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_data_app/services/sim_bus.dart';

void main() {
  group('SimulatorBus Tests', () {
    test('instance returns singleton', () {
      final a = SimulatorBus.instance;
      final b = SimulatorBus.instance;
      expect(identical(a, b), isTrue);
    });

    test('pushData converts map to DataPackages and emits to stream', () async {
      final bus = SimulatorBus.instance;
      final completer = Completer<void>();

      final sub = bus.stream.listen((pack) {
        expect(pack.data.isNotEmpty, isTrue);
        final speedPkg = pack.data.firstWhere((d) => d.path == 'Vehicle.Speed');
        expect(speedPkg.dp.first.value, '120');
        completer.complete();
      });

      bus.pushData({'Vehicle.Speed': 120, 'VehicleModelID': 'test-model'});

      await completer.future.timeout(const Duration(seconds: 2));
      expect(bus.lastPack, isNotNull);
      await sub.cancel();
    });
  });
}

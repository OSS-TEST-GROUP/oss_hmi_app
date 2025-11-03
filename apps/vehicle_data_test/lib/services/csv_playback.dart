import 'dart:async';
import 'package:vehicle_data_test/services/csv_loader.dart';
import 'package:vehicle_data_test/services/data_cache.dart';
import 'package:vehicle_data_test/services/sim_bus.dart';
import 'package:vehicle_data_test/services/vss_mapper.dart';

class CsvPlayback {
  CsvPlayback(this.table, {this.useSiUnits = false});

  final CsvTable table;
  final bool useSiUnits;

  Timer? _timer;
  int _i = 0;

  bool get isRunning => _timer != null;
  int get currentIndex => _i;
  int get totalRows => table.rows.length;

  void start({Duration interval = const Duration(seconds: 1)}) {
    if (_timer != null || table.rows.isEmpty) return;

    final mapper = VssMapper(
      useSiUnits: useSiUnits, 
      defaultVehicleModelId: 'vm-001', 
      defaultUserId: 'user-ye');

    _timer = Timer.periodic(interval, (t) {
      if (_i >= table.rows.length) {
        stop(); // 끝나면 멈춤
        return;
      }

      //final row = table.rows[_i++];
      final vss = mapper.rowToVssFull(table, _i++);

      if (vss.isNotEmpty) {
        DataCache.instance.update(vss);
        SimulatorBus.instance.pushData(vss);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    _i = 0;
  }
}

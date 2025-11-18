import 'dart:async';
import 'package:vehicle_data_test/src/generated/VISSv3.0.pb.dart';

class SimulatorBus {
  SimulatorBus._();
  static final SimulatorBus instance = SimulatorBus._();

  final _controller = StreamController<DataPackages>.broadcast();
  Stream<DataPackages> get stream => _controller.stream;

  DataPackages? lastPack;

  void pushData(Map<String, dynamic> data) {
    lastPack = _mapToDataPackages(data);
    _controller.add(_mapToDataPackages(data));
  }

  void close() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  DataPackages _mapToDataPackages(Map<String, dynamic> data) {
    final dp = DataPackages();
    final ts = DateTime.now().toUtc().toIso8601String();
    data.forEach((path, value) {
      if (value == null) return;
      final pkg = DataPackages_DataPackage()..path = path;
      final point = DataPackages_DataPackage_DataPoint()
        ..value = value.toString()
        ..ts = ts;
      pkg.dp.add(point);
      dp.data.add(pkg);
    });
    return dp;
  }
}
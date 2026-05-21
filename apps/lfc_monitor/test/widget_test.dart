// Smoke tests for lfc_monitor.
//
// The full app expects a live rosbridge_server connection, so instead of
// booting LfcMonitorApp we just exercise the data model + config defaults to
// guard against accidental schema/enum breaks.

import 'package:flutter_test/flutter_test.dart';

import 'package:lfc_monitor/config/app_config.dart';
import 'package:lfc_monitor/data/lifecycle_data.dart';

void main() {
  test('AppConfig.defaults yields expected rosUrl + poll', () {
    final cfg = AppConfig.defaults();
    expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9090');
    expect(cfg.statusTopic, '/app_status/lfc_monitor');
    expect(cfg.pollIntervalSec, 5);
  });

  test('ServiceState.fromInt maps IDL declaration order', () {
    expect(ServiceState.fromInt(0), ServiceState.notRunning);
    expect(ServiceState.fromInt(1), ServiceState.initializing);
    expect(ServiceState.fromInt(2), ServiceState.running);
    expect(ServiceState.fromInt(3), ServiceState.runningNoResponse);
    expect(ServiceState.fromInt(4), ServiceState.terminating);
    expect(ServiceState.fromInt(99), ServiceState.unknown);
    expect(ServiceState.fromInt(null), ServiceState.unknown);
  });

  test('ServiceMode round-trips via int', () {
    expect(ServiceMode.normal.value, 0);
    expect(ServiceMode.otaMode.value, 1);
    expect(ServiceMode.fromInt(0), ServiceMode.normal);
    expect(ServiceMode.fromInt(1), ServiceMode.otaMode);
    expect(ServiceMode.fromInt(null), ServiceMode.normal);
  });
}

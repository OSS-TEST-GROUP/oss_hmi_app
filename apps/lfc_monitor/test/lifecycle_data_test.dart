// Unit tests for lfc_monitor's IDL ↔ wire enums.
//
// These enums are hand-mirrored from idl/dds/lifecycle/LifecycleCommon.idl
// (declaration-order-stamped integers). A mismatch with the IDL would
// silently mis-label live samples, so these tests pin every int↔enum↔label
// mapping as a regression guard.

import 'package:flutter_test/flutter_test.dart';
import 'package:lfc_monitor/data/lifecycle_data.dart';

void main() {
  group('ServiceState', () {
    test('fromInt maps IDL declaration order', () {
      expect(ServiceState.fromInt(0), ServiceState.notRunning);
      expect(ServiceState.fromInt(1), ServiceState.initializing);
      expect(ServiceState.fromInt(2), ServiceState.running);
      expect(ServiceState.fromInt(3), ServiceState.runningNoResponse);
      expect(ServiceState.fromInt(4), ServiceState.terminating);
    });

    test('fromInt falls back to unknown for null / out-of-range', () {
      expect(ServiceState.fromInt(null), ServiceState.unknown);
      expect(ServiceState.fromInt(99), ServiceState.unknown);
      expect(ServiceState.fromInt(-1), ServiceState.unknown);
    });

    test('labels match the IDL string form', () {
      expect(ServiceState.notRunning.label, 'NOT_RUNNING');
      expect(ServiceState.initializing.label, 'INITIALIZING');
      expect(ServiceState.running.label, 'RUNNING');
      expect(ServiceState.runningNoResponse.label, 'RUNNING_NO_RESPONSE');
      expect(ServiceState.terminating.label, 'TERMINATING');
      expect(ServiceState.unknown.label, 'UNKNOWN');
    });
  });

  group('ServiceMode', () {
    test('fromInt + value round-trip', () {
      expect(ServiceMode.fromInt(0), ServiceMode.normal);
      expect(ServiceMode.fromInt(1), ServiceMode.otaMode);
      expect(ServiceMode.fromInt(null), ServiceMode.normal);
      expect(ServiceMode.normal.value, 0);
      expect(ServiceMode.otaMode.value, 1);
      expect(ServiceMode.normal.label, 'NORMAL');
      expect(ServiceMode.otaMode.label, 'OTA_MODE');
    });
  });

  group('ContainerState', () {
    test('fromInt maps IDL declaration order', () {
      expect(ContainerState.fromInt(1), ContainerState.stopped);
      expect(ContainerState.fromInt(2), ContainerState.running);
      expect(ContainerState.fromInt(3), ContainerState.paused);
    });

    test('fromInt falls back to unknownState for 0 / null / out-of-range', () {
      expect(ContainerState.fromInt(0), ContainerState.unknownState);
      expect(ContainerState.fromInt(null), ContainerState.unknownState);
      expect(ContainerState.fromInt(7), ContainerState.unknownState);
    });

    test('labels', () {
      expect(ContainerState.stopped.label, 'STOPPED');
      expect(ContainerState.running.label, 'RUNNING');
      expect(ContainerState.paused.label, 'PAUSED');
      expect(ContainerState.unknownState.label, 'UNKNOWN');
    });
  });

  group('RecoveryPolicy', () {
    test('fromInt maps IDL declaration order', () {
      expect(RecoveryPolicy.fromInt(0), RecoveryPolicy.defaultPolicy);
      expect(RecoveryPolicy.fromInt(1), RecoveryPolicy.always);
      expect(RecoveryPolicy.fromInt(2), RecoveryPolicy.onFailure);
      expect(RecoveryPolicy.fromInt(3), RecoveryPolicy.onSuccess);
      expect(RecoveryPolicy.fromInt(4), RecoveryPolicy.onNotResponding);
      expect(RecoveryPolicy.fromInt(5), RecoveryPolicy.manual);
      expect(RecoveryPolicy.fromInt(null), RecoveryPolicy.defaultPolicy);
    });

    test('value is the inverse of fromInt', () {
      for (final p in RecoveryPolicy.values) {
        expect(RecoveryPolicy.fromInt(p.value), p);
      }
    });

    test('fromLabel round-trips every label', () {
      for (final p in RecoveryPolicy.values) {
        expect(RecoveryPolicy.fromLabel(p.label), p);
      }
      // Unknown label → defaultPolicy.
      expect(RecoveryPolicy.fromLabel('NOPE'), RecoveryPolicy.defaultPolicy);
      expect(RecoveryPolicy.fromLabel(null), RecoveryPolicy.defaultPolicy);
    });
  });

  group('OsType', () {
    test('value mapping', () {
      expect(OsType.ros2.value, 0);
      expect(OsType.agl.value, 1);
      expect(OsType.autosar.value, 2);
    });
  });
}

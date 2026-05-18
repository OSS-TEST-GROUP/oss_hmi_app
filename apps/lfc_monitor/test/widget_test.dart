// Smoke tests for lfc_monitor.
//
// The full app expects a live rosbridge_server connection, so instead of
// booting LfcMonitorApp we just exercise the data model + config defaults to
// guard against accidental schema/enum breaks.

import 'package:flutter_test/flutter_test.dart';

import 'package:lfc_monitor/config/app_config.dart';
import 'package:lfc_monitor/controller/settings_controller.dart';
import 'package:lfc_monitor/data/lifecycle_data.dart';

void main() {
  test('AppConfig.defaults yields expected rosUrl + poll', () {
    final cfg = AppConfig.defaults();
    expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9090');
    expect(cfg.statusTopic, '/app_status/lfc_monitor');
    expect(cfg.pollIntervalSec, 5);
    expect(cfg.theme, 'light');
  });

  test('AppConfig.copyWith only swaps named fields', () {
    final base = AppConfig.defaults();
    final next = base.copyWith(theme: 'dark', rosUrl: Uri.parse('ws://10.0.0.1:9090'));
    expect(next.theme, 'dark');
    expect(next.rosUrl.toString(), 'ws://10.0.0.1:9090');
    expect(next.statusTopic, base.statusTopic);
    expect(next.pollIntervalSec, base.pollIntervalSec);
    expect(next.knownServices, same(base.knownServices));
  });

  test('AppConfig.fromJson honors theme key', () {
    final j = AppConfig.fromJson(<String, dynamic>{'theme': 'dark'});
    expect(j.theme, 'dark');
    // Missing theme → defaults to light (the post-F014 default).
    final j2 = AppConfig.fromJson(const <String, dynamic>{});
    expect(j2.theme, 'light');
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

  test('ContainerState.fromInt maps IDL declaration order', () {
    expect(ContainerState.fromInt(0), ContainerState.unknownState);
    expect(ContainerState.fromInt(1), ContainerState.stopped);
    expect(ContainerState.fromInt(2), ContainerState.running);
    expect(ContainerState.fromInt(3), ContainerState.paused);
    expect(ContainerState.fromInt(99), ContainerState.unknownState);
    expect(ContainerState.fromInt(null), ContainerState.unknownState);
  });

  test('ContainerType.fromInt maps IDL declaration order', () {
    expect(ContainerType.fromInt(0), ContainerType.unknownType);
    expect(ContainerType.fromInt(1), ContainerType.docker);
    expect(ContainerType.fromInt(2), ContainerType.dockerCompose);
    expect(ContainerType.fromInt(3), ContainerType.k3s);
    expect(ContainerType.fromInt(99), ContainerType.unknownType);
  });

  test('LifecycleTopics carry the F013 ctrl/* + container surface', () {
    // Pin the wire topic strings — these must stay byte-identical with
    // lifecycle_mgr's MessageType::GetTopicStr() and the dds_bridge
    // entries in service/extension/ros2/ext_comm/dds_bridge/main.cc.
    expect(LifecycleTopics.notifyContainerState,
        '/mmf/lifecyclemgr/NotifyContainerState');
    expect(LifecycleTopics.ctrlStartServiceReq,
        '/mmf/lifecyclemgr/ctrl/StartService');
    expect(LifecycleTopics.ctrlStartServiceResp,
        '/mmf/lifecyclemgr/ctrl/StartServiceResponse');
    expect(LifecycleTopics.ctrlSetServiceModeReq,
        '/mmf/lifecyclemgr/ctrl/SetServiceMode');
    expect(LifecycleTopics.ctrlStartContainerReq,
        '/mmf/lifecyclemgr/ctrl/StartContainer');
    expect(LifecycleTopics.ctrlStopContainerResp,
        '/mmf/lifecyclemgr/ctrl/StopContainerResponse');
  });

  test('LifecycleTypes carry the F013 ROS msg names', () {
    expect(LifecycleTypes.notifyContainerState, 'lifecyclemgr/NotifyContainerState');
    // All five ctrl/* responses share CtrlResponse on the wire.
    expect(LifecycleTypes.ctrlResponse, 'lifecyclemgr/CtrlResponse');
    expect(LifecycleTypes.ctrlStartContainerReq,
        'lifecyclemgr/CtrlStartContainerRequest');
  });

  test('SettingsController.isValidUrl accepts ws/wss only', () {
    expect(SettingsController.isValidUrl('ws://127.0.0.1:9090'), isTrue);
    expect(SettingsController.isValidUrl('wss://host.example/ros'), isTrue);
    expect(SettingsController.isValidUrl('ws://host'), isTrue);
    // Negative cases.
    expect(SettingsController.isValidUrl(''), isFalse);
    expect(SettingsController.isValidUrl('http://host:9090'), isFalse);
    expect(SettingsController.isValidUrl('//host:9090'), isFalse);
    expect(SettingsController.isValidUrl('ws:/host'), isFalse);
    // Oversized URL.
    expect(SettingsController.isValidUrl('ws://${'x' * 2100}'), isFalse);
  });
}

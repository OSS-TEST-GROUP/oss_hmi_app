import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:get/get.dart';

import '../domain/launcher_config.dart';

typedef RosFactory = Ros Function(String url);

/// L009: Unified ROS connection keeper for the launcher.
///
/// Simplified from ota_monitor's RosKeeper. Registers a single Ros instance
/// via GetX that all embedded plugin collectors share.
///
/// Creates and maintains a single `Ros` instance registered via GetX,
/// which embedded plugin collectors (OtaCollector, AdswCollector, etc.)
/// can access via `Get.find<Ros>()`.
class LauncherRosKeeper {
  LauncherRosKeeper(
    this.cfg, {
    RosFactory? rosFactory,
  }) : _rosFactory = rosFactory ?? ((url) => Ros(url: url));

  final LauncherConfig cfg;
  final RosFactory _rosFactory;

  Ros? _ros;
  Topic? _statusTopic;
  Timer? _reconnectPoll;
  Timer? _heartbeatTimer;
  StreamSubscription<Status>? _statusSub;

  bool _stopping = false;
  bool _reconnecting = false;

  Ros get ros => _ros ?? (throw StateError('ROS not initialized'));

  /// Number of consecutive reconnect failures.
  final ValueNotifier<int> consecutiveFailures = ValueNotifier<int>(0);

  Future<void> start() async {
    await stop();
    _stopping = false;

    _ros = _rosFactory(cfg.rosUrl.toString());

    _statusTopic = Topic(
      ros: _ros!,
      name: cfg.statusTopic,
      type: 'std_msgs/String',
      reconnectOnClose: true,
    );

    _statusSub = _ros!.statusStream.listen(
      (s) async {
        debugPrint('[LauncherROS] status=$s');
        if (s == Status.connected) {
          await _onConnected();
        }
      },
      onError: (e, st) =>
          debugPrint('[LauncherROS] statusStream error: $e'),
      onDone: () => debugPrint('[LauncherROS] statusStream done'),
    );

    // Watchdog poll
    _reconnectPoll?.cancel();
    _reconnectPoll = Timer.periodic(
        Duration(seconds: cfg.rosReconnectIntervalSec), (_) async {
      final r = _ros;
      if (_stopping || r == null) return;
      if (_reconnecting) return;
      if (await _isStableConnected(r)) return;
      _kickReconnect();
    });

    // Heartbeat timer
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
        Duration(seconds: cfg.heartbeatIntervalSec), (_) async {
      final r = _ros;
      if (r == null || r.status != Status.connected) return;
      try {
        _statusTopic?.publish({'data': 'running'});
      } catch (e) {
        debugPrint('[LauncherROS] heartbeat publish error: $e');
      }
    });

    _kickReconnect();
  }

  Future<void> stop() async {
    _stopping = true;
    _reconnectPoll?.cancel();
    _reconnectPoll = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _statusSub?.cancel();
    _statusSub = null;
    _ros?.close();
    _ros = null;
    _statusTopic = null;
  }

  Future<bool> _isStableConnected(Ros r) async {
    return r.status == Status.connected;
  }

  void _kickReconnect() {
    if (_reconnecting) return;
    _reconnecting = true;

    final r = _ros;
    if (r == null) {
      _reconnecting = false;
      return;
    }

    if (r.status == Status.connected) {
      consecutiveFailures.value = 0;
      _reconnecting = false;
      return;
    }

    consecutiveFailures.value++;
    debugPrint('[LauncherROS] reconnect attempt ${consecutiveFailures.value}');

    r.connect();
    _reconnecting = false;
  }

  Future<void> _onConnected() async {
    consecutiveFailures.value = 0;

    // Register or replace the global Ros instance in GetX
    if (Get.isRegistered<Ros>()) {
      Get.replace<Ros>(_ros!);
      debugPrint('[LauncherROS] Ros replaced in GetX');
    } else {
      Get.put<Ros>(_ros!);
      debugPrint('[LauncherROS] Ros registered in GetX');
    }
  }
}

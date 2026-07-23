import 'dart:async';

import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'config/app_config.dart';

typedef RosFactory = Ros Function(String url);
typedef TopicFactory = Topic Function(Ros ros, String name, String type);

/// Minimal Ros connection manager — mirrors lfc_monitor's RosKeeper shape so
/// the embedded launcher can swap in its own GetX-registered Ros without
/// touching this class.
///
/// Lifecycle:
///   start() → Ros connect → on Status.connected register/replace in GetX
///                          → publish a tiny status heartbeat every 1s.
///   stop()  → cancel timers / streams, close Ros.
class RosKeeper {
  RosKeeper(
    this.cfg, {
    RosFactory? rosFactory,
    TopicFactory? topicFactory,
  })  : _rosFactory = rosFactory ?? ((url) => Ros(url: url)),
        _topicFactory =
            topicFactory ?? ((r, n, t) => Topic(ros: r, name: n, type: t));

  final AppConfig cfg;
  final RosFactory _rosFactory;
  final TopicFactory _topicFactory;

  Ros? _ros;
  Topic? _statusTopic;
  StreamSubscription<Status>? _statusSub;
  Timer? _heartbeat;
  bool _stopping = false;
  bool _registered = false;

  Ros get ros => _ros ?? (throw StateError('ROS not initialized'));

  Future<void> start() async {
    await stop();
    _stopping = false;

    _ros = _rosFactory(cfg.rosUrl.toString());

    _statusTopic = _topicFactory(
      _ros!,
      cfg.statusTopic,
      'std_msgs/String',
    );

    _statusSub = _ros!.statusStream.listen(
      (s) async {
        // ignore: avoid_print
        print('[ROS] status=$s');
        if (s == Status.connected) {
          await _onConnected();
        } else {
          _registered = false;
        }
      },
      onError: (e, _) {
        // ignore: avoid_print
        print('[ROS] statusStream error: $e');
      },
    );

    // Best-effort connect; roslibdart's Ros.connect() is implicit on first use.
    try {
      _ros!.connect();
    } catch (_) {}

    _heartbeat = Timer.periodic(const Duration(seconds: 1), (_) async {
      final r = _ros;
      if (r == null || r.status != Status.connected) return;
      await _onConnected();
      try {
        _statusTopic?.publish({'data': 'running'});
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    _stopping = true;
    _heartbeat?.cancel();
    _heartbeat = null;
    await _statusSub?.cancel();
    _statusSub = null;
    try {
      await _ros?.close();
    } catch (_) {}
    _ros = null;
    _statusTopic = null;
    _registered = false;
  }

  Future<void> _onConnected() async {
    if (_stopping) return;
    final r = _ros;
    if (r == null || r.status != Status.connected) return;
    if (_registered) return;

    try {
      if (!Get.isRegistered<Ros>()) {
        Get.put<Ros>(r, permanent: true);
      } else {
        Get.replace<Ros>(r);
      }
    } catch (_) {}

    try {
      await _statusTopic?.advertise();
    } catch (_) {}

    _registered = true;
  }
}

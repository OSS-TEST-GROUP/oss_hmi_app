import 'dart:async';
import 'package:roslibdart/roslibdart.dart';
import '../config/app_config.dart';

class RosKeeper {
  RosKeeper(this.cfg);

  final AppConfig cfg;
  Ros? _ros;
  Topic? _statusTopic;
  Timer? _timer;

  Ros get ros => _ros ?? (throw StateError('ROS not initialized'));

  Future<void> start() async {
    await stop(); // 안전 정리

    _ros = Ros(url: cfg.rosUrl.toString());
    _ros!.connect();

    _statusTopic = Topic(
      ros: _ros!,
      name: cfg.statusTopic,
      type: 'std_msgs/String',
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      try {
        _statusTopic?.publish({'data': 'running'});
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _statusTopic = null;

    try {
      await _ros?.close();
    } catch (_) {}
    _ros = null;
  }
}

import 'dart:async';
import 'package:roslibdart/roslibdart.dart';
import '../config/app_config.dart';

typedef RosFactory = Ros Function(String url);
typedef TopicFactory = Topic Function(Ros ros, String name, String type);
typedef TimerFactory = Timer Function(
    Duration duration, void Function(Timer) onTick);

class RosKeeper {
  RosKeeper(
    this.cfg, {
    RosFactory? rosFactory,
    TopicFactory? topicFactory,
    TimerFactory? timerFactory,
  })  : _rosFactory = rosFactory ?? ((url) => Ros(url: url)),
        _topicFactory = topicFactory ??
            ((ros, name, type) => Topic(ros: ros, name: name, type: type)),
        _timerFactory = timerFactory ??
            ((duration, onTick) => Timer.periodic(duration, onTick));

  final AppConfig cfg;
  final RosFactory _rosFactory;
  final TopicFactory _topicFactory;
  final TimerFactory _timerFactory;

  Ros? _ros;
  Topic? _statusTopic;
  Timer? _timer;

  Ros get ros => _ros ?? (throw StateError('ROS not initialized'));

  Future<void> start() async {
    // 안전 정리
    await stop();

    _ros = _rosFactory(cfg.rosUrl.toString());
    _ros!.connect();

    _statusTopic = _topicFactory(
      _ros!,
      cfg.statusTopic,
      'std_msgs/String',
    );

    _timer = _timerFactory(const Duration(seconds: 1), (_) {
      try {
        _statusTopic?.publish({'data': 'running'});
      } catch (_) {
        // ignore
      }
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _statusTopic = null;

    try {
      final result = _ros?.close();
      if (result is Future) {
        await result;
      }
    } catch (_) {}

    _ros = null;
  }
}

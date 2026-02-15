import 'dart:async';
import 'package:roslibdart/roslibdart.dart';
import '../config/app_config.dart';
import 'package:get/get.dart';

typedef RosFactory = Ros Function(String url);
typedef TopicFactory = Topic Function(Ros ros, String name, String type);
typedef TimerFactory = Timer Function(Duration duration, void Function(Timer) onTick);

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

  bool _stopping = false;

  Ros get ros => _ros ?? (throw StateError('ROS not initialized'));
  Timer? _reconnectPoll;
  StreamSubscription<Status>? _statusSub;
  bool _reconnecting = false;
  
  bool _restored = false;

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
        print('[ROS] status=$s');

        if (s == Status.connected) {
          await _onConnected();
        } else {
          _restored = false;
        }
      },
      // (s) => print('[ROS] status=$s'),
      onError: (e, st) => print('[ROS] statusStream error: $e'),
      onDone: () => print('[ROS] statusStream done'),
    );

    _reconnectPoll?.cancel();
    _reconnectPoll = Timer.periodic(const Duration(seconds: 2), (_) async {
      final r = _ros;
      if (_stopping || r == null) return;
      //if (r.status == Status.connected) return;
      if (_reconnecting) return;
      if (await _isStableConnected(r)) return;
      _kickReconnect();
    });

    _kickReconnect();

    _timer = _timerFactory(const Duration(seconds: 1), (_) async {
      final r = _ros;
      if (r == null) return;
      if (r.status != Status.connected) return;
      await _onConnected();
      try { _statusTopic?.publish({'data': 'running'}); } catch (_) {}
    });
  }

  Future<void> _onConnected() async {
    if (_stopping) return;
    final r = _ros;
    if (r == null) return;
    if (r.status != Status.connected) return;
    if (_restored) return;

    try {
      if (!Get.isRegistered<Ros>()) {
        Get.put<Ros>(r, permanent: true);
      } else {
        Get.replace<Ros>(r);
      }
    } catch (_) {

    }

    try {
      await _statusTopic?.advertise();
    } catch (_) {}

    _restored = true;
    print('[ROS] onConnected: restored topics & DI updated');
  }

  Future<bool> _safeCloseWithResult(Ros r) async {
    try {
      await r.close().timeout(const Duration(seconds: 2));
      return true;
    } catch (e) {
      print('[RECON] close timeout/failed: $e');
      return false;
    }
  }

  void _recreateRos() {
    print('[RECON] recreate Ros');

    _statusSub?.cancel();
    _statusSub = null;

    _ros = _rosFactory(cfg.rosUrl.toString());

    _statusTopic = Topic(
      ros: _ros!,
      name: cfg.statusTopic,
      type: 'std_msgs/String',
      reconnectOnClose: true,
    );

    _statusSub = _ros!.statusStream.listen(
      (s) async {
        print('[ROS] status=$s');
        if (s == Status.connected) {
          await _onConnected();
        } else {
          _restored = false;
        }
      },
      //(s) => print('[ROS] status=$s'),
      onError: (e, st) => print('[ROS] statusStream error: $e'),
      onDone: () => print('[ROS] statusStream done'),
    );
  }

  void _kickReconnect() {
    print('[RECON] kick called. stopping=$_stopping reconnecting=$_reconnecting status=${_ros?.status}');
    if (_stopping || _reconnecting) return;

    final r0 = _ros;
    if (r0 == null) return;

    _reconnecting = true;

    unawaited(() async {
      try {
        print('[RECON] loop start');

        var delay = const Duration(seconds: 1);
        const maxDelay = Duration(seconds: 8);

        while (!_stopping) {
          final r = _ros;
          if (r == null) return;

          if (r.status == Status.connected) {
            await _onConnected();
            return;
          }

          try {
            print('[RECON] connect try. status=${r.status}');
            r.connect();
          } catch (e) {
            print('[RECON] connect threw: $e');
          }

          await Future<void>.delayed(const Duration(seconds: 1));
          if (_ros?.status == Status.connected) {
            await _onConnected();
            return;
          }

          print('[RECON] E: before close');
          final ok = await _safeCloseWithResult(r);
          print('[RECON] F: after close ok=$ok');

          if (!ok) {
            _recreateRos();
          }

          await Future<void>.delayed(delay);
          delay = delay * 2;
          if (delay > maxDelay) delay = maxDelay;
        }
      } finally {
        _reconnecting = false;
        print('[RECON] loop end');
      }
    }());
  }


  Future<bool> _isStableConnected(Ros r) async {
    if (r.status != Status.connected) return false;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return r.status == Status.connected;
  }

  Future<void> stop() async {
    _stopping = true;

    _reconnectPoll?.cancel();
    _reconnectPoll = null;

    _timer?.cancel();
    _timer = null;

    await _statusSub?.cancel();
    _statusSub = null;

    final r = _ros;
    if (r != null) {
      await _safeCloseWithResult(r);
    }

    _statusTopic = null;
    _ros = null;
    _reconnecting = false;
    _restored = false;
  }

}

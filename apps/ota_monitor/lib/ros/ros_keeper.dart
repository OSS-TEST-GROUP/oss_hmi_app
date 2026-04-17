import 'dart:async';
import 'package:roslibdart/roslibdart.dart';
import '../config/app_config.dart';
import 'package:get/get.dart';

typedef RosFactory = Ros Function(String url);
typedef TimerFactory = Timer Function(Duration duration, void Function(Timer) onTick);

class RosKeeper {
  RosKeeper(
    this.cfg, {
    RosFactory? rosFactory,
    TimerFactory? timerFactory,
  })  : _rosFactory = rosFactory ?? ((url) => Ros(url: url)),
        _timerFactory = timerFactory ??
            ((duration, onTick) => Timer.periodic(duration, onTick));

  final AppConfig cfg;
  final RosFactory _rosFactory;
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
      onError: (e, st) => print('[ROS] statusStream error: $e'),
      onDone: () => print('[ROS] statusStream done'),
    );

    _reconnectPoll?.cancel();
    _reconnectPoll = Timer.periodic(
        Duration(seconds: cfg.rosReconnectIntervalSec), (_) async {
      final r = _ros;
      if (_stopping || r == null) return;
      if (_reconnecting) return;
      if (await _isStableConnected(r)) return;
      _kickReconnect();
    });

    _kickReconnect();

    _timer = _timerFactory(
        Duration(seconds: cfg.heartbeatIntervalSec), (_) async {
      final r = _ros;
      if (r == null) return;
      if (r.status != Status.connected) return;
      await _onConnected();
      try {
        _statusTopic?.publish({'data': 'running'});
      } catch (_) {}
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
    } catch (_) {}

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
      onError: (e, st) => print('[ROS] statusStream error: $e'),
      onDone: () => print('[ROS] statusStream done'),
    );
  }

  void _kickReconnect() {
    if (_stopping || _reconnecting) return;

    final r0 = _ros;
    if (r0 == null) return;

    _reconnecting = true;

    unawaited(() async {
      try {
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
            r.connect();
          } catch (e) {
            print('[RECON] connect threw: $e');
          }

          await Future<void>.delayed(const Duration(seconds: 1));
          if (_ros?.status == Status.connected) {
            await _onConnected();
            return;
          }

          final ok = await _safeCloseWithResult(r);
          if (!ok) {
            _recreateRos();
          }

          await Future<void>.delayed(delay);
          delay = delay * 2;
          if (delay > maxDelay) delay = maxDelay;
        }
      } finally {
        _reconnecting = false;
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

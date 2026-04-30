import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:roslibdart/roslibdart.dart';
import '../config/app_config.dart';
import '../logging/app_log.dart';
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

  /// F010: exponential backoff sequence used by [_kickReconnect].
  ///
  /// Doubles the delay up to [maxBackoff], then stays there. Exposed as a
  /// pure function so the 1s → 2s → 4s → 8s progression can be unit tested
  /// without simulating wall-clock time.
  static const Duration initialBackoff = Duration(seconds: 1);
  static const Duration maxBackoff = Duration(seconds: 8);

  static Duration nextBackoff(Duration current) {
    final next = current * 2;
    return next > maxBackoff ? maxBackoff : next;
  }

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

  // F007: number of consecutive reconnect iterations that did not yield a
  // connected state. Exposed as a listenable notifier so the UI can show
  // a warning badge after repeated failures.
  final ValueNotifier<int> consecutiveFailures = ValueNotifier<int>(0);

  // F011 (oss-agent3): live ROS connection status mirrored from
  // statusStream. The header connection indicator (icon_conn_status /
  // text_conn_status, F020 §2) listens to this so smoke tests can read
  // the UI side after `await waitForRosbridge()`.
  final ValueNotifier<Status> statusNotifier =
      ValueNotifier<Status>(Status.none);

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
        appLog('[ROS] status=$s');
        statusNotifier.value = s;   // F011 — mirror to UI listener
        if (s == Status.connected) {
          await _onConnected();
        } else {
          _restored = false;
        }
      },
      onError: (e, st) => appLog('[ROS] statusStream error: $e', level: 'warn'),
      onDone: () => appLog('[ROS] statusStream done'),
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
    // F007: fresh connection resets the failure streak.
    consecutiveFailures.value = 0;
    appLog('[ROS] onConnected: restored topics & DI updated');
  }

  Future<bool> _safeCloseWithResult(Ros r) async {
    try {
      await r.close().timeout(const Duration(seconds: 2));
      return true;
    } catch (e) {
      appLog('[RECON] close timeout/failed: $e', level: 'warn');
      return false;
    }
  }

  void _recreateRos() {
    appLog('[RECON] recreate Ros');

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
        appLog('[ROS] status=$s');
        statusNotifier.value = s;   // F011 — mirror to UI listener
        if (s == Status.connected) {
          await _onConnected();
        } else {
          _restored = false;
        }
      },
      onError: (e, st) => appLog('[ROS] statusStream error: $e', level: 'warn'),
      onDone: () => appLog('[ROS] statusStream done'),
    );
  }

  void _kickReconnect() {
    if (_stopping || _reconnecting) return;

    final r0 = _ros;
    if (r0 == null) return;

    _reconnecting = true;

    unawaited(() async {
      try {
        var delay = initialBackoff;

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
            appLog('[RECON] connect threw: $e', level: 'warn');
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

          // F007: one more iteration without a connection.
          consecutiveFailures.value = consecutiveFailures.value + 1;

          await Future<void>.delayed(delay);
          delay = nextBackoff(delay);
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

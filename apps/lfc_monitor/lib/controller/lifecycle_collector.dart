import 'dart:async';

import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import '../config/app_config.dart';
import '../data/lifecycle_data.dart';

typedef TopicFactory = Topic Function(Ros ros, String name, String type);

/// Wires the lfc_monitor UI to lifecycle_mgr via rosbridge.
///
/// Subscribes to:
///   - NotifyServiceState              (real-time state transitions; crash events)
///   - GetServiceStateResponse         (poll cycle; full snapshot)
///   - UpdateServiceListResponse       (registry confirms)
///   - StartServiceResponse / StopServiceResponse / SetServiceModeResponse (control acks)
///   - LifecycleDiagReport             (periodic richer status)
///
/// Publishes:
///   - GetServiceStateRequest          (poll triggered by [pollIntervalSec])
///   - StartServiceRequest / StopServiceRequest / SetServiceModeRequest (user actions)
///
/// State is exposed as Rx maps/lists so the view can rebuild via Obx().
class LifecycleCollector extends GetxController {
  LifecycleCollector({
    required this.cfg,
    required this.topicFactory,
  });

  final AppConfig cfg;
  final TopicFactory topicFactory;

  // ─── Public observable state ────────────────────────────────────────────
  /// service_name → ServiceInfo (state, recovery, exit_code).
  final RxMap<String, ServiceInfo> services = <String, ServiceInfo>{}.obs;

  /// Newest-first ring of recent lifecycle events.
  final RxList<LifecycleEvent> events = <LifecycleEvent>[].obs;

  /// Echo of the last command's return code (per command kind).
  final RxnString lastError = RxnString();
  final RxBool connected = false.obs;

  static const int _eventCapacity = 100;

  // ─── Internal subscriptions / publishers ────────────────────────────────
  Topic? _notifyStateSub;
  Topic? _getStateRespSub;
  Topic? _updateListRespSub;
  Topic? _startRespSub;
  Topic? _stopRespSub;
  Topic? _setModeRespSub;
  Topic? _diagReportSub;

  Topic? _getStateReqPub;
  Topic? _startReqPub;
  Topic? _stopReqPub;
  Topic? _setModeReqPub;

  Timer? _rosWatchdog;
  Timer? _pollTimer;
  Ros? _boundRos;

  @override
  void onInit() {
    super.onInit();
    _rosWatchdog = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!Get.isRegistered<Ros>()) return;
      final r = Get.find<Ros>();
      if (identical(r, _boundRos) && _boundRos != null) return;
      _bind(r);
    });

    // Seed services from config so UI isn't blank pre-handshake.
    for (final n in cfg.knownServices) {
      services.putIfAbsent(n, () => ServiceInfo(name: n));
    }
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _rosWatchdog?.cancel();
    super.onClose();
  }

  Future<void> _bind(Ros r) async {
    _boundRos = r;
    connected.value = true;

    // Subscribe topics (lifecycle_mgr → us)
    _notifyStateSub   = topicFactory(r, LifecycleTopics.notifyServiceState,  LifecycleTypes.notifyServiceState);
    _getStateRespSub  = topicFactory(r, LifecycleTopics.getStateResponse,    LifecycleTypes.getStateResponse);
    _updateListRespSub= topicFactory(r, LifecycleTopics.updateListResponse,  LifecycleTypes.updateListResponse);
    _startRespSub     = topicFactory(r, LifecycleTopics.startResponse,       LifecycleTypes.startResponse);
    _stopRespSub      = topicFactory(r, LifecycleTopics.stopResponse,        LifecycleTypes.stopResponse);
    _setModeRespSub   = topicFactory(r, LifecycleTopics.setModeResponse,     LifecycleTypes.setModeResponse);
    _diagReportSub    = topicFactory(r, LifecycleTopics.diagReport,          LifecycleTypes.diagReport);

    await _notifyStateSub!.subscribe(_onNotifyServiceState);
    await _getStateRespSub!.subscribe(_onGetStateResponse);
    await _updateListRespSub!.subscribe(_onUpdateListResponse);
    await _startRespSub!.subscribe((m) async => _onCommandResponse(LifecycleEventKind.startResponse, m));
    await _stopRespSub!.subscribe((m) async => _onCommandResponse(LifecycleEventKind.stopResponse, m));
    await _setModeRespSub!.subscribe((m) async => _onCommandResponse(LifecycleEventKind.setModeResponse, m));
    await _diagReportSub!.subscribe(_onDiagReport);

    // Publish topics (us → lifecycle_mgr)
    _getStateReqPub = topicFactory(r, LifecycleTopics.getStateRequest, LifecycleTypes.getStateRequest);
    _startReqPub    = topicFactory(r, LifecycleTopics.startRequest,    LifecycleTypes.startRequest);
    _stopReqPub     = topicFactory(r, LifecycleTopics.stopRequest,     LifecycleTypes.stopRequest);
    _setModeReqPub  = topicFactory(r, LifecycleTopics.setModeRequest,  LifecycleTypes.setModeRequest);
    try { await _getStateReqPub?.advertise(); } catch (_) {}
    try { await _startReqPub?.advertise();    } catch (_) {}
    try { await _stopReqPub?.advertise();     } catch (_) {}
    try { await _setModeReqPub?.advertise();  } catch (_) {}

    // Kick off the poll timer
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: cfg.pollIntervalSec.clamp(1, 60)),
      (_) => pollAllServices(),
    );
    // One eager poll so the UI populates fast.
    pollAllServices();
  }

  // ─── Subscribers ────────────────────────────────────────────────────────
  Future<void> _onNotifyServiceState(Map<String, dynamic> msg) async {
    final list = (msg['service_list'] as List?)?.cast<dynamic>() ?? const [];
    final states = (msg['service_state_list'] as List?)?.cast<dynamic>() ?? const [];
    final n = list.length < states.length ? list.length : states.length;
    for (int i = 0; i < n; i++) {
      final name = list[i].toString();
      final newState = ServiceState.fromInt((states[i] as num?)?.toInt());
      final info = services[name] ?? ServiceInfo(name: name);
      final prevState = info.state;
      info.state = newState;
      info.lastChangedAt = DateTime.now();
      services[name] = info;
      if (prevState != newState) {
        _pushEvent(LifecycleEvent(
          timestamp: DateTime.now(),
          serviceName: name,
          from: prevState,
          to: newState,
        ));
      }
    }
    services.refresh();
  }

  Future<void> _onGetStateResponse(Map<String, dynamic> msg) async {
    // Same payload shape as NotifyServiceState for the GUI's purposes.
    await _onNotifyServiceState(msg);
  }

  Future<void> _onUpdateListResponse(Map<String, dynamic> msg) async {
    final ret = (msg['ret_code'] as num?)?.toInt() ?? -1;
    _pushEvent(LifecycleEvent(
      timestamp: DateTime.now(),
      serviceName: '(registry)',
      from: ServiceState.unknown,
      to: ServiceState.unknown,
      kind: LifecycleEventKind.updateList,
      detail: ret == 0 ? 'SUCCESS' : 'ret=$ret',
    ));
  }

  Future<void> _onCommandResponse(LifecycleEventKind kind, Map<String, dynamic> msg) async {
    final ret = (msg['ret_code'] as num?)?.toInt() ?? -1;
    _pushEvent(LifecycleEvent(
      timestamp: DateTime.now(),
      serviceName: '(${kind.name})',
      from: ServiceState.unknown,
      to: ServiceState.unknown,
      kind: kind,
      detail: ret == 0 ? 'SUCCESS' : 'FAILED (ret=$ret)',
    ));
    if (ret != 0) lastError.value = '${kind.name}: ret=$ret';
  }

  Future<void> _onDiagReport(Map<String, dynamic> msg) async {
    final list = (msg['service_list'] as List?) ?? const [];
    for (final entry in list) {
      if (entry is! Map) continue;
      final name = (entry['name'] ?? entry['service_name'] ?? '').toString();
      if (name.isEmpty) continue;
      final info = services[name] ?? ServiceInfo(name: name);
      final stateInt = (entry['state'] as num?)?.toInt();
      if (stateInt != null) info.state = ServiceState.fromInt(stateInt);
      final recovery = entry['recovery_policy'];
      if (recovery is num) info.recoveryPolicy = _recoveryLabel(recovery.toInt());
      final ec = entry['exit_code'];
      if (ec is num) info.exitCode = ec.toInt();
      services[name] = info;
    }
    services.refresh();
  }

  static String _recoveryLabel(int v) {
    // IDL declaration order:
    // R_DEFAULT, ALWAYS, ON_FAILURE, ON_SUCCESS, ON_NOT_RESPONDING, MANUAL
    const names = [
      'DEFAULT', 'ALWAYS', 'ON_FAILURE', 'ON_SUCCESS', 'ON_NOT_RESPONDING', 'MANUAL'
    ];
    return (v >= 0 && v < names.length) ? names[v] : 'UNKNOWN($v)';
  }

  void _pushEvent(LifecycleEvent e) {
    events.insert(0, e);
    if (events.length > _eventCapacity) {
      events.removeRange(_eventCapacity, events.length);
    }
  }

  // ─── Public command API ─────────────────────────────────────────────────
  /// Polls every known service. Empty `is_all_service=false` + names list, so
  /// lifecycle_mgr returns a snapshot tailored to our tracked set.
  void pollAllServices() {
    if (_getStateReqPub == null) return;
    final names = services.keys.toList(growable: false);
    if (names.isEmpty) return;
    try {
      _getStateReqPub!.publish({
        'os_type': OsType.ros2.value,
        'service_list': names,
        'is_all_service': false,
      });
    } catch (e) {
      lastError.value = 'poll failed: $e';
    }
  }

  void startService(String name) {
    _publish(_startReqPub, 'start', {
      'os_type': OsType.ros2.value,
      'service_list': [name],
      'is_group': false,
    });
  }

  void stopService(String name) {
    _publish(_stopReqPub, 'stop', {
      'os_type': OsType.ros2.value,
      'service_list': [name],
      'is_group': false,
    });
  }

  void setServiceMode(String name, ServiceMode mode) {
    _publish(_setModeReqPub, 'setMode', {
      'os_type': OsType.ros2.value,
      'service_list': [name],
      'is_group': false,
      'service_mode': mode.value,
    });
  }

  void _publish(Topic? t, String label, Map<String, dynamic> payload) {
    if (t == null) {
      lastError.value = 'ROS not connected — $label';
      return;
    }
    try {
      t.publish(payload);
    } catch (e) {
      lastError.value = '$label failed: $e';
    }
  }
}

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
///   - NotifyContainerState            (F013: container start/stop transitions)
///   - GetServiceStateResponse         (poll cycle; full snapshot)
///   - UpdateServiceListResponse       (registry confirms)
///   - LifecycleDiagReport             (periodic richer status)
///   - ctrl/{StartService,StopService,SetServiceMode,StartContainer,
///          StopContainer}Response     (F013: ctrl/* gate acks)
///
/// Publishes:
///   - GetServiceStateRequest          (poll triggered by [pollIntervalSec])
///   - ctrl/{StartService,StopService,SetServiceMode,StartContainer,
///          StopContainer}             (F013: user-initiated mutations go
///                                       through lifecycle_mgr's policy gate
///                                       rather than the actuator topics
///                                       directly)
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
  /// service_name → ServiceInfo (state, recovery, exit_code, containerName).
  final RxMap<String, ServiceInfo> services = <String, ServiceInfo>{}.obs;

  /// F013: container_name → ContainerInfo (state, exit_code, ...).
  /// Currently populated incrementally from NotifyContainerState arrivals.
  /// image/deploy_file/namespace stay blank until the inventory channel
  /// reaches us — see TODO at the subscription site.
  final RxMap<String, ContainerInfo> containers = <String, ContainerInfo>{}.obs;

  /// Newest-first ring of recent lifecycle events.
  final RxList<LifecycleEvent> events = <LifecycleEvent>[].obs;

  /// Echo of the last command's return code (per command kind).
  final RxnString lastError = RxnString();
  final RxBool connected = false.obs;

  static const int _eventCapacity = 100;

  // ─── Internal subscriptions / publishers ────────────────────────────────
  Topic? _notifyStateSub;
  Topic? _notifyContainerStateSub;
  Topic? _getStateRespSub;
  Topic? _updateListRespSub;
  Topic? _diagReportSub;
  // F013: ctrl/* response subscriptions (one per command shape).
  Topic? _ctrlStartServiceRespSub;
  Topic? _ctrlStopServiceRespSub;
  Topic? _ctrlSetServiceModeRespSub;
  Topic? _ctrlStartContainerRespSub;
  Topic? _ctrlStopContainerRespSub;

  Topic? _getStateReqPub;
  // F013: ctrl/* request publishers — replace direct Start/Stop/SetMode
  // publishers from the F012 baseline.  All mutations now route through
  // lifecycle_mgr's policy gate.
  Topic? _ctrlStartServiceReqPub;
  Topic? _ctrlStopServiceReqPub;
  Topic? _ctrlSetServiceModeReqPub;
  Topic? _ctrlStartContainerReqPub;
  Topic? _ctrlStopContainerReqPub;

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

    // ── Subscribe (lifecycle_mgr / adsw_manager → us) ─────────────────────
    _notifyStateSub          = topicFactory(r, LifecycleTopics.notifyServiceState,    LifecycleTypes.notifyServiceState);
    _notifyContainerStateSub = topicFactory(r, LifecycleTopics.notifyContainerState,  LifecycleTypes.notifyContainerState);
    _getStateRespSub         = topicFactory(r, LifecycleTopics.getStateResponse,      LifecycleTypes.getStateResponse);
    _updateListRespSub       = topicFactory(r, LifecycleTopics.updateListResponse,    LifecycleTypes.updateListResponse);
    _diagReportSub           = topicFactory(r, LifecycleTopics.diagReport,            LifecycleTypes.diagReport);

    // F013: ctrl/* response acks. All five payloads share CtrlResponse, so
    // the dart-side handler is just a `kind → label` switch.
    _ctrlStartServiceRespSub    = topicFactory(r, LifecycleTopics.ctrlStartServiceResp,    LifecycleTypes.ctrlResponse);
    _ctrlStopServiceRespSub     = topicFactory(r, LifecycleTopics.ctrlStopServiceResp,     LifecycleTypes.ctrlResponse);
    _ctrlSetServiceModeRespSub  = topicFactory(r, LifecycleTopics.ctrlSetServiceModeResp,  LifecycleTypes.ctrlResponse);
    _ctrlStartContainerRespSub  = topicFactory(r, LifecycleTopics.ctrlStartContainerResp,  LifecycleTypes.ctrlResponse);
    _ctrlStopContainerRespSub   = topicFactory(r, LifecycleTopics.ctrlStopContainerResp,   LifecycleTypes.ctrlResponse);

    await _notifyStateSub!.subscribe(_onNotifyServiceState);
    await _notifyContainerStateSub!.subscribe(_onNotifyContainerState);
    await _getStateRespSub!.subscribe(_onGetStateResponse);
    await _updateListRespSub!.subscribe(_onUpdateListResponse);
    await _diagReportSub!.subscribe(_onDiagReport);
    await _ctrlStartServiceRespSub!.subscribe(
        (m) async => _onCommandResponse(LifecycleEventKind.ctrlStartServiceResponse, m));
    await _ctrlStopServiceRespSub!.subscribe(
        (m) async => _onCommandResponse(LifecycleEventKind.ctrlStopServiceResponse, m));
    await _ctrlSetServiceModeRespSub!.subscribe(
        (m) async => _onCommandResponse(LifecycleEventKind.ctrlSetServiceModeResponse, m));
    await _ctrlStartContainerRespSub!.subscribe(
        (m) async => _onCommandResponse(LifecycleEventKind.ctrlStartContainerResponse, m));
    await _ctrlStopContainerRespSub!.subscribe(
        (m) async => _onCommandResponse(LifecycleEventKind.ctrlStopContainerResponse, m));

    // ── Publish (us → lifecycle_mgr) ──────────────────────────────────────
    _getStateReqPub          = topicFactory(r, LifecycleTopics.getStateRequest,         LifecycleTypes.getStateRequest);
    _ctrlStartServiceReqPub  = topicFactory(r, LifecycleTopics.ctrlStartServiceReq,     LifecycleTypes.ctrlStartServiceReq);
    _ctrlStopServiceReqPub   = topicFactory(r, LifecycleTopics.ctrlStopServiceReq,      LifecycleTypes.ctrlStopServiceReq);
    _ctrlSetServiceModeReqPub= topicFactory(r, LifecycleTopics.ctrlSetServiceModeReq,   LifecycleTypes.ctrlSetServiceModeReq);
    _ctrlStartContainerReqPub= topicFactory(r, LifecycleTopics.ctrlStartContainerReq,   LifecycleTypes.ctrlStartContainerReq);
    _ctrlStopContainerReqPub = topicFactory(r, LifecycleTopics.ctrlStopContainerReq,    LifecycleTypes.ctrlStopContainerReq);
    try { await _getStateReqPub?.advertise();           } catch (_) {}
    try { await _ctrlStartServiceReqPub?.advertise();   } catch (_) {}
    try { await _ctrlStopServiceReqPub?.advertise();    } catch (_) {}
    try { await _ctrlSetServiceModeReqPub?.advertise(); } catch (_) {}
    try { await _ctrlStartContainerReqPub?.advertise(); } catch (_) {}
    try { await _ctrlStopContainerReqPub?.advertise();  } catch (_) {}

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

  // F013: NotifyContainerState arrives whenever ContainerHealthMonitor sees
  // a container transition. Payload is parallel arrays
  // {container_list, container_state_list, exit_code_list}, same shape as
  // NotifyServiceState but for the container surface.
  Future<void> _onNotifyContainerState(Map<String, dynamic> msg) async {
    final list   = (msg['container_list']       as List?)?.cast<dynamic>() ?? const [];
    final states = (msg['container_state_list'] as List?)?.cast<dynamic>() ?? const [];
    final exits  = (msg['exit_code_list']       as List?)?.cast<dynamic>() ?? const [];
    final n = list.length < states.length ? list.length : states.length;
    for (int i = 0; i < n; i++) {
      final name = list[i].toString();
      final newState = ContainerState.fromInt((states[i] as num?)?.toInt());
      final info = containers[name] ?? ContainerInfo(name: name);
      final prevState = info.state;
      info.state = newState;
      info.exitCode = (i < exits.length) ? (exits[i] as num?)?.toInt() : info.exitCode;
      info.lastChangedAt = DateTime.now();
      containers[name] = info;
      if (prevState != newState) {
        _pushEvent(LifecycleEvent(
          timestamp: DateTime.now(),
          serviceName: name,           // overloaded — could split to a dedicated
                                       // `target` field; keep tight for now.
          from: ServiceState.unknown,  // container state ≠ service state; use
                                       // unknown sentinels in the legacy field.
          to: ServiceState.unknown,
          kind: LifecycleEventKind.containerStateChange,
          detail: '${prevState.label} → ${newState.label}',
        ));
      }
    }
    containers.refresh();
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

  // F013: all mutation commands route through ctrl/* so lifecycle_mgr can
  // policy-gate (e.g. reject if a service is in OTA_MODE). The actuator
  // topic shape (with os_type / is_group) is no longer used from here —
  // lifecycle_mgr's StateManager re-derives those from its registry.

  void startService(String name) {
    _publish(_ctrlStartServiceReqPub, 'ctrlStartService', {
      'service_list': [name],
    });
  }

  void stopService(String name) {
    _publish(_ctrlStopServiceReqPub, 'ctrlStopService', {
      'service_list': [name],
    });
  }

  void setServiceMode(String name, ServiceMode mode) {
    _publish(_ctrlSetServiceModeReqPub, 'ctrlSetServiceMode', {
      'service_list': [name],
      'service_mode': mode.value,
    });
  }

  // F013: container-level commands. Container is identified by name only;
  // lifecycle_mgr's StateManager looks the type up in its registry to know
  // which docker / docker-compose / k3s op to issue via adsw_manager.
  void startContainer(String name) {
    _publish(_ctrlStartContainerReqPub, 'ctrlStartContainer', {
      'container_list': [name],
    });
  }

  void stopContainer(String name) {
    _publish(_ctrlStopContainerReqPub, 'ctrlStopContainer', {
      'container_list': [name],
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

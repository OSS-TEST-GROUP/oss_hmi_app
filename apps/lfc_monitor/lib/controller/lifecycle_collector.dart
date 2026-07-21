import 'dart:async';
import 'dart:convert';

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

  /// Non-null when dds_bridge reports a bridged lifecycle topic has >1 distinct
  /// publisher — i.e. a duplicate core/adsw is on this DDS domain (the exact
  /// condition behind the autoware RUNNING↔NOT_RUNNING flapping). The view
  /// shows this as a warning banner. Cleared when the bridge reports it resolved.
  final RxnString multiSourceWarning = RxnString();
  final RxSet<String> _multiSourceTopics = <String>{}.obs;

  static const int _eventCapacity = 100;

  // ─── Internal subscriptions / publishers ────────────────────────────────
  Topic? _notifyStateSub;
  Topic? _notifyContainerStateSub;
  Topic? _getStateRespSub;
  Topic? _updateListRespSub;
  Topic? _diagReportSub;
  Topic? _bridgeSourceDiagSub;
  // F013: ctrl/* response subscriptions (one per command shape).
  Topic? _ctrlStartServiceRespSub;
  Topic? _ctrlStopServiceRespSub;
  Topic? _ctrlSetServiceModeRespSub;
  Topic? _ctrlStartContainerRespSub;
  Topic? _ctrlStopContainerRespSub;
  // F014 follow-up: recovery policy
  Topic? _ctrlSetRecoveryPolicyRespSub;

  Topic? _getStateReqPub;
  // F013: ctrl/* request publishers — replace direct Start/Stop/SetMode
  // publishers from the F012 baseline.  All mutations now route through
  // lifecycle_mgr's policy gate.
  Topic? _ctrlStartServiceReqPub;
  Topic? _ctrlStopServiceReqPub;
  Topic? _ctrlSetServiceModeReqPub;
  Topic? _ctrlStartContainerReqPub;
  Topic? _ctrlStopContainerReqPub;
  // F014 follow-up
  Topic? _ctrlSetRecoveryPolicyReqPub;

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

    // cfg.knownServices seed deliberately dropped: the UI only shows
    // services adsw_manager has registered (i.e. those carrying a
    // container_name in LifecycleDiagReport).  Pre-seeded ghost entries
    // would never match a container and clutter the panel.
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
    _bridgeSourceDiagSub     = topicFactory(r, LifecycleTopics.bridgeSourceDiag,      LifecycleTypes.stdString);

    // F013: ctrl/* response acks. All five payloads share CtrlResponse, so
    // the dart-side handler is just a `kind → label` switch.
    _ctrlStartServiceRespSub    = topicFactory(r, LifecycleTopics.ctrlStartServiceResp,    LifecycleTypes.ctrlResponse);
    _ctrlStopServiceRespSub     = topicFactory(r, LifecycleTopics.ctrlStopServiceResp,     LifecycleTypes.ctrlResponse);
    _ctrlSetServiceModeRespSub  = topicFactory(r, LifecycleTopics.ctrlSetServiceModeResp,  LifecycleTypes.ctrlResponse);
    _ctrlStartContainerRespSub  = topicFactory(r, LifecycleTopics.ctrlStartContainerResp,  LifecycleTypes.ctrlResponse);
    _ctrlStopContainerRespSub   = topicFactory(r, LifecycleTopics.ctrlStopContainerResp,   LifecycleTypes.ctrlResponse);
    _ctrlSetRecoveryPolicyRespSub = topicFactory(r, LifecycleTopics.ctrlSetRecoveryPolicyResp, LifecycleTypes.ctrlResponse);

    await _notifyStateSub!.subscribe(_onNotifyServiceState);
    await _notifyContainerStateSub!.subscribe(_onNotifyContainerState);
    await _getStateRespSub!.subscribe(_onGetStateResponse);
    await _updateListRespSub!.subscribe(_onUpdateListResponse);
    await _diagReportSub!.subscribe(_onDiagReport);
    await _bridgeSourceDiagSub!.subscribe(_onBridgeSourceDiag);
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
    await _ctrlSetRecoveryPolicyRespSub!.subscribe(
        (m) async => _onCommandResponse(LifecycleEventKind.ctrlSetRecoveryPolicyResponse, m));

    // ── Publish (us → lifecycle_mgr) ──────────────────────────────────────
    _getStateReqPub          = topicFactory(r, LifecycleTopics.getStateRequest,         LifecycleTypes.getStateRequest);
    _ctrlStartServiceReqPub  = topicFactory(r, LifecycleTopics.ctrlStartServiceReq,     LifecycleTypes.ctrlStartServiceReq);
    _ctrlStopServiceReqPub   = topicFactory(r, LifecycleTopics.ctrlStopServiceReq,      LifecycleTypes.ctrlStopServiceReq);
    _ctrlSetServiceModeReqPub= topicFactory(r, LifecycleTopics.ctrlSetServiceModeReq,   LifecycleTypes.ctrlSetServiceModeReq);
    _ctrlStartContainerReqPub= topicFactory(r, LifecycleTopics.ctrlStartContainerReq,   LifecycleTypes.ctrlStartContainerReq);
    _ctrlStopContainerReqPub = topicFactory(r, LifecycleTopics.ctrlStopContainerReq,    LifecycleTypes.ctrlStopContainerReq);
    _ctrlSetRecoveryPolicyReqPub = topicFactory(r, LifecycleTopics.ctrlSetRecoveryPolicyReq, LifecycleTypes.ctrlSetRecoveryPolicyReq);
    try { await _getStateReqPub?.advertise();             } catch (_) {}
    try { await _ctrlStartServiceReqPub?.advertise();     } catch (_) {}
    try { await _ctrlStopServiceReqPub?.advertise();      } catch (_) {}
    try { await _ctrlSetServiceModeReqPub?.advertise();   } catch (_) {}
    try { await _ctrlStartContainerReqPub?.advertise();   } catch (_) {}
    try { await _ctrlStopContainerReqPub?.advertise();    } catch (_) {}
    try { await _ctrlSetRecoveryPolicyReqPub?.advertise();} catch (_) {}

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
    // Intentionally ignored.
    //
    // GetServiceStateResponse arrives over rosbridge via dds_bridge, which
    // forwards every raw-topic sample it sees. A stray publisher writing
    // NOT_RUNNING to mmf/lifecyclemgr/GetServiceStateResponse on the same
    // DDS domain therefore reaches the UI and makes the service state
    // visibly oscillate between RUNNING and NOT_RUNNING even when
    // adsw_manager is steadily reporting RUNNING. dds_bridge's per-listener
    // trust-on-first-use guard can race-lose to that phantom and pin the
    // wrong publisher on this topic, so we don't trust this stream here.
    //
    // The two remaining sources are sufficient and authoritative:
    //   - NotifyServiceState: state-change events from adsw_manager, fast.
    //   - LifecycleDiagReport: periodic snapshot from lifecycle_mgr (which
    //     applies its own sender-GID guard before relaying state into the
    //     report), accurate.
    // Both flow through dds_bridge as well but their phantom incidence is
    // low to none in practice; if either starts oscillating, apply the
    // same fix there.
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

  /// dds_bridge multi-source diagnostic (std_msgs/String).
  /// msg = {data: '{"topic":"...","publishers":N,"multi":true|false}'}.
  /// Tracks which bridged topics currently have duplicate publishers and
  /// composes a single warning banner string (or null when all clear).
  Future<void> _onBridgeSourceDiag(Map<String, dynamic> msg) async {
    final raw = msg['data'];
    if (raw is! String || raw.isEmpty) return;
    Map<String, dynamic> d;
    try {
      d = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return; // malformed — ignore
    }
    final topic = (d['topic'] as String?) ?? 'lifecycle';
    final multi = d['multi'] == true;
    final publishers = d['publishers'];

    if (multi) {
      _multiSourceTopics.add(topic);
    } else {
      _multiSourceTopics.remove(topic);
    }

    if (_multiSourceTopics.isEmpty) {
      multiSourceWarning.value = null;
    } else {
      final n = (publishers is int) ? publishers : _multiSourceTopics.length + 1;
      multiSourceWarning.value =
          '⚠ 같은 DDS domain 에 발행자 $n개 감지 — core/adsw 가 중복 실행 중일 수 있습니다 '
          '(${_multiSourceTopics.join(", ")}). 서비스 상태가 실제와 다르게 보일 수 있음.';
    }
  }

  Future<void> _onDiagReport(Map<String, dynamic> msg) async {
    final list = (msg['service_list'] as List?) ?? const [];
    for (final entry in list) {
      if (entry is! Map) continue;
      final name = (entry['name'] ?? entry['service_name'] ?? '').toString();
      if (name.isEmpty) continue;
      final info = services[name] ?? ServiceInfo(name: name);
      // service_state matches the IDL field name; legacy `state` retained
      // as a fallback in case the bridge sends a flattened payload.
      final stateInt =
          (entry['service_state'] as num?)?.toInt() ?? (entry['state'] as num?)?.toInt();
      if (stateInt != null) info.state = ServiceState.fromInt(stateInt);
      final recovery = entry['recovery_policy'];
      if (recovery is num) info.recoveryPolicy = _recoveryLabel(recovery.toInt());
      final ec = entry['exit_code'];
      if (ec is num) info.exitCode = ec.toInt();
      // F013/F014 follow-up: ServiceStatus now carries container_name from
      // lifecycle_mgr, so the ServicesPanel filter against a selected
      // container actually has something to match against.
      final cn = entry['container_name'];
      if (cn is String) info.containerName = cn;
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
        'mw_type': MwType.ros2.value,
        'service_list': names,
        'is_all_service': false,
      });
    } catch (e) {
      lastError.value = 'poll failed: $e';
    }
  }

  // F013: all mutation commands route through ctrl/* so lifecycle_mgr can
  // policy-gate (e.g. reject if a service is in OTA_MODE). The actuator
  // topic shape (with mw_type / is_group) is no longer used from here —
  // lifecycle_mgr's StateManager re-derives those from its registry.

  void startService(String name) {
    // F014 follow-up instrumentation: log every call site so we can
    // tell whether a real button click is fired or some Flutter
    // re-render path is re-invoking us.  Stack trace cut short so the
    // operator-visible logs stay readable.
    _logCall('startService', name);

    // Client-side guard: a service can't run without its hosting container.
    // If the service is mapped to a container that is NOT running, refuse the
    // Start here (return early) and tell the operator to start the container
    // first — instead of firing ctrl/StartService + optimistically flipping to
    // INITIALIZING only for the server (adsw) to gate it. The server still
    // gates as a backstop; this is immediate UX feedback + avoids a bogus
    // optimistic state flip. Unknown container (not yet in the map) → allow,
    // so we never over-block on a stale/absent state.
    final containerName = services[name]?.containerName ?? '';
    if (containerName.isNotEmpty) {
      final ci = containers[containerName];
      if (ci != null && ci.state != ContainerState.running) {
        final msg = "'$name' 시작 불가 — 컨테이너 '$containerName' 가 실행 중이 "
            "아닙니다. 컨테이너를 먼저 Start 하세요.";
        lastError.value = msg;
        _logCall('startService.blocked',
            "$name: container '$containerName' not running (${ci.state.label})");
        _pushEvent(LifecycleEvent(
          timestamp: DateTime.now(),
          serviceName: name,
          from: ServiceState.unknown,
          to: ServiceState.unknown,
          kind: LifecycleEventKind.ctrlStartServiceResponse,
          detail: "BLOCKED — container '$containerName' not running; "
              "start the container first",
        ));
        return;
      }
    }

    // Optimistic UI update — paint INITIALIZING immediately, push an
    // Events row so the operator sees their click landed, then the real
    // NotifyServiceState / next DiagReport overwrites with the confirmed
    // state (RUNNING on success, back to NOT_RUNNING on failure). Without
    // this the badge would stay at NOT_RUNNING until the next
    // LifecycleDiagReport (~30 s) because we deliberately ignore
    // GetServiceStateResponse to dodge phantom samples and
    // NotifyServiceState's bridged delivery is currently unreliable.
    _optimisticServiceState(name, ServiceState.initializing);
    _publish(_ctrlStartServiceReqPub, 'ctrlStartService', {
      'service_list': [name],
    });
  }

  void stopService(String name) {
    _logCall('stopService', name);
    // Same optimistic flip as startService — see commentary there.
    _optimisticServiceState(name, ServiceState.notRunning);
    _publish(_ctrlStopServiceReqPub, 'ctrlStopService', {
      'service_list': [name],
    });
  }

  // Repaint the local ServiceInfo + push an Events row so the operator
  // sees the click registered. The next authoritative source
  // (NotifyServiceState if it arrives, otherwise DiagReport) corrects any
  // divergence — if the actuator rejected the change, the badge will flip
  // back and a second Events row will follow.
  void _optimisticServiceState(String name, ServiceState newState) {
    final info = services[name];
    if (info == null) return;
    final prevState = info.state;
    if (prevState == newState) return;
    info.state = newState;
    info.lastChangedAt = DateTime.now();
    services[name] = info;
    services.refresh();
    _pushEvent(LifecycleEvent(
      timestamp: DateTime.now(),
      serviceName: name,
      from: prevState,
      to: newState,
    ));
  }

  void _logCall(String label, String arg) {
    final stack = StackTrace.current.toString().split('\n');
    // Skip frames 0-1 (this helper + the caller itself); keep next 4
    // so we see the click handler (or whatever invoked it).
    final relevant = stack.skip(2).take(4).join('\n  ');
    // ignore: avoid_print
    print('[collector] $label($arg) caller:\n  $relevant');
  }

  void setServiceMode(String name, ServiceMode mode) {
    _logCall('setServiceMode', '$name:${mode.label}');
    _publish(_ctrlSetServiceModeReqPub, 'ctrlSetServiceMode', {
      'service_list': [name],
      'service_mode': mode.value,
    });
  }

  /// Apply [mode] to every currently-registered service in a single
  /// ctrl/SetServiceMode publish. Used by the Settings dialog's global
  /// NORMAL/OTA toggle so an operator can flip the whole vehicle to OTA
  /// mode without touching each service individually.
  void setAllServicesMode(ServiceMode mode) {
    _logCall('setAllServicesMode', mode.label);
    final names = services.keys.toList(growable: false);
    if (names.isEmpty) {
      lastError.value = 'no registered services to apply mode to';
      return;
    }
    _publish(_ctrlSetServiceModeReqPub, 'ctrlSetServiceMode(all)', {
      'service_list': names,
      'service_mode': mode.value,
    });
  }

  // F013: container-level commands. Container is identified by name only;
  // lifecycle_mgr's StateManager looks the type up in its registry to know
  // which docker / docker-compose / k3s op to issue via adsw_manager.
  void startContainer(String name) {
    _logCall('startContainer', name);
    _publish(_ctrlStartContainerReqPub, 'ctrlStartContainer', {
      'container_list': [name],
    });
  }

  void stopContainer(String name) {
    _logCall('stopContainer', name);
    _publish(_ctrlStopContainerReqPub, 'ctrlStopContainer', {
      'container_list': [name],
    });
  }

  /// F014 follow-up: change a single service's recovery policy.
  /// lifecycle_mgr policy-gates + forwards to adsw_manager which
  /// persists to saved-service-list.yaml.
  void setServiceRecoveryPolicy(String name, RecoveryPolicy policy) {
    _logCall('setServiceRecoveryPolicy', '$name:${policy.label}');
    // Optimistic update: paint the new policy onto the local ServiceInfo
    // immediately so the dropdown reflects the choice without waiting for
    // the ~30s LifecycleDiagReport heartbeat. If the actuator rejects the
    // change (CtrlResponse.ret_code != 0), _onCommandResponse surfaces
    // lastError and the next DiagReport overwrites this back to the
    // server-side truth.
    final info = services[name];
    if (info != null) {
      info.recoveryPolicy = policy.label;
      services[name] = info;
      services.refresh();
    }
    _publish(_ctrlSetRecoveryPolicyReqPub, 'ctrlSetRecoveryPolicy', {
      'service_list': [name],
      'recovery_policy': policy.value,
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

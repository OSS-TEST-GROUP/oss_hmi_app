import 'dart:async';

import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import '../config/app_config.dart';
import '../data/rviz2_data.dart';

typedef TopicFactory = Topic Function(Ros ros, String name, String type);

/// Wires the rviz2_monitor UI to lifecycle_mgr via rosbridge.
///
/// Subscribes to:
///   - NotifyContainerState (F013: container start/stop transitions)
///   - LifecycleDiagReport  (periodic richer status snapshot)
///   - ctrl/StartContainerResponse / ctrl/StopContainerResponse (ctrl gate acks)
///   - /rosout (rcl_interfaces/msg/Log — node log lines; filtered by node name)
///
/// Publishes:
///   - ctrl/StartContainer {container_list: [cfg.containerName]}
///   - ctrl/StopContainer  {container_list: [cfg.containerName]}
///
/// Mirrors lfc_monitor's LifecycleCollector _bind/watchdog pattern:
///   - A 500ms watchdog detects a new GetX-registered Ros and re-binds.
///   - Optimistic UI state is applied immediately; authoritative
///     NotifyContainerState / DiagReport overwrites on arrival.
class Rviz2Controller extends GetxController {
  Rviz2Controller({
    required this.cfg,
    required this.topicFactory,
  });

  final AppConfig cfg;
  final TopicFactory topicFactory;

  // ─── Public observable state ────────────────────────────────────────────

  /// rviz2 container state (state/exitCode/lastChangedAt).
  final Rx<ContainerInfo> container = ContainerInfo(name: 'rviz2').obs;

  /// True once GetX has a live Ros and _bind() has run.
  final RxBool connected = false.obs;

  /// Recent /rosout lines, newest at index 0 (ring buffer).
  final RxList<LogLine> logs = <LogLine>[].obs;

  /// Last ctrl/* error message, or null.
  final RxnString lastError = RxnString();

  static const int _logCapacity = 300;

  // ─── Internal subscriptions / publishers ────────────────────────────────
  Topic? _notifyContainerStateSub;
  Topic? _diagReportSub;
  Topic? _ctrlStartContainerRespSub;
  Topic? _ctrlStopContainerRespSub;
  Topic? _rosoutSub;

  Topic? _ctrlStartContainerReqPub;
  Topic? _ctrlStopContainerReqPub;

  Timer? _rosWatchdog;
  Ros? _boundRos;

  @override
  void onInit() {
    super.onInit();
    // Poll every 500ms for a newly registered Ros (same as lfc's watchdog).
    _rosWatchdog = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!Get.isRegistered<Ros>()) return;
      final r = Get.find<Ros>();
      if (identical(r, _boundRos) && _boundRos != null) return;
      _bind(r);
    });
  }

  @override
  void onClose() {
    _rosWatchdog?.cancel();
    super.onClose();
  }

  Future<void> _bind(Ros r) async {
    _boundRos = r;
    connected.value = true;

    // ── Subscribe ────────────────────────────────────────────────────────
    _notifyContainerStateSub = topicFactory(
      r,
      Rviz2Topics.notifyContainerState,
      Rviz2Types.notifyContainerState,
    );
    _diagReportSub = topicFactory(
      r,
      Rviz2Topics.diagReport,
      Rviz2Types.diagReport,
    );
    _ctrlStartContainerRespSub = topicFactory(
      r,
      Rviz2Topics.ctrlStartContainerResp,
      Rviz2Types.ctrlResponse,
    );
    _ctrlStopContainerRespSub = topicFactory(
      r,
      Rviz2Topics.ctrlStopContainerResp,
      Rviz2Types.ctrlResponse,
    );
    _rosoutSub = topicFactory(
      r,
      cfg.rosoutTopic,
      Rviz2Types.rosoutLog,
    );

    await _notifyContainerStateSub!.subscribe(_onNotifyContainerState);
    await _diagReportSub!.subscribe(_onDiagReport);
    await _ctrlStartContainerRespSub!.subscribe(
        (m) async => _onCtrlResponse('ctrlStartContainer', m));
    await _ctrlStopContainerRespSub!.subscribe(
        (m) async => _onCtrlResponse('ctrlStopContainer', m));
    await _rosoutSub!.subscribe(_onRosout);

    // ── Publish ──────────────────────────────────────────────────────────
    _ctrlStartContainerReqPub = topicFactory(
      r,
      Rviz2Topics.ctrlStartContainerReq,
      Rviz2Types.ctrlStartContainerReq,
    );
    _ctrlStopContainerReqPub = topicFactory(
      r,
      Rviz2Topics.ctrlStopContainerReq,
      Rviz2Types.ctrlStopContainerReq,
    );
    try {
      await _ctrlStartContainerReqPub?.advertise();
    } catch (_) {}
    try {
      await _ctrlStopContainerReqPub?.advertise();
    } catch (_) {}
  }

  // ─── Subscribers ────────────────────────────────────────────────────────

  /// NotifyContainerState arrives whenever ContainerHealthMonitor detects a
  /// container transition. Payload: parallel arrays
  /// {container_list, container_state_list, exit_code_list}.
  /// Filters to cfg.containerName only.
  Future<void> _onNotifyContainerState(Map<String, dynamic> msg) async {
    final list = (msg['container_list'] as List?)?.cast<dynamic>() ?? const [];
    final states =
        (msg['container_state_list'] as List?)?.cast<dynamic>() ?? const [];
    final exits =
        (msg['exit_code_list'] as List?)?.cast<dynamic>() ?? const [];

    final n = list.length < states.length ? list.length : states.length;
    for (int i = 0; i < n; i++) {
      final name = list[i].toString();
      if (name != cfg.containerName) continue;
      final newState =
          ContainerState.fromInt((states[i] as num?)?.toInt());
      final info = container.value;
      info.state = newState;
      info.exitCode =
          (i < exits.length) ? (exits[i] as num?)?.toInt() : info.exitCode;
      info.lastChangedAt = DateTime.now();
      container.refresh();
    }
  }

  /// LifecycleDiagReport: periodic snapshot from lifecycle_mgr. Searches the
  /// container_list field for cfg.containerName and refreshes state.
  Future<void> _onDiagReport(Map<String, dynamic> msg) async {
    // DiagReport carries container_list alongside service_list.
    // Shape: {container_list: [{name, container_state, exit_code, ...}]}.
    final list = (msg['container_list'] as List?) ?? const [];
    for (final entry in list) {
      if (entry is! Map) continue;
      final name = (entry['name'] ?? '').toString();
      if (name != cfg.containerName) continue;
      final stateInt = (entry['container_state'] as num?)?.toInt() ??
          (entry['state'] as num?)?.toInt();
      final info = container.value;
      if (stateInt != null) info.state = ContainerState.fromInt(stateInt);
      final ec = entry['exit_code'];
      if (ec is num) info.exitCode = ec.toInt();
      info.lastChangedAt = DateTime.now();
      container.refresh();
      break;
    }
  }

  /// Handles ctrl/StartContainer and ctrl/StopContainer response acks.
  Future<void> _onCtrlResponse(String label, Map<String, dynamic> msg) async {
    final ret = (msg['ret_code'] as num?)?.toInt() ?? -1;
    if (ret != 0) {
      lastError.value = '$label failed: ret=$ret';
      _appendLog(LogLine(
        level: 40, // ERROR
        name: 'rviz2_monitor',
        msg: '$label rejected by lifecycle_mgr (ret=$ret)',
        ts: DateTime.now(),
      ));
    } else {
      lastError.value = null;
    }
  }

  /// /rosout subscription — filters to log lines whose node name contains
  /// cfg.containerName so only rviz2-originating logs appear.
  ///
  /// rcl_interfaces/msg/Log wire shape:
  ///   {stamp: {sec, nanosec}, level: int, name: str, msg: str, ...}
  Future<void> _onRosout(Map<String, dynamic> msg) async {
    final name = (msg['name'] ?? '').toString();
    if (!name.contains(cfg.containerName)) return;
    final level = (msg['level'] as num?)?.toInt() ?? 20;
    final text = (msg['msg'] ?? '').toString();
    _appendLog(LogLine(
      level: level,
      name: name,
      msg: text,
      ts: DateTime.now(),
    ));
  }

  void _appendLog(LogLine line) {
    logs.insert(0, line);
    if (logs.length > _logCapacity) {
      logs.removeRange(_logCapacity, logs.length);
    }
  }

  // ─── Public command API ─────────────────────────────────────────────────

  /// Start the rviz2 container via ctrl/StartContainer.
  /// Applies an optimistic RUNNING state immediately so the badge updates
  /// before the authoritative NotifyContainerState arrives.
  void startRviz2() {
    _optimisticState(ContainerState.running);
    _publish(_ctrlStartContainerReqPub, 'ctrlStartContainer', {
      'container_list': [cfg.containerName],
    });
  }

  /// Stop the rviz2 container via ctrl/StopContainer.
  /// Applies an optimistic STOPPED state immediately.
  void stopRviz2() {
    _optimisticState(ContainerState.stopped);
    _publish(_ctrlStopContainerReqPub, 'ctrlStopContainer', {
      'container_list': [cfg.containerName],
    });
  }

  /// Paint a tentative state onto the local ContainerInfo so the UI reflects
  /// the user's action immediately. The next authoritative source
  /// (NotifyContainerState or DiagReport) will correct any divergence.
  void _optimisticState(ContainerState newState) {
    final info = container.value;
    if (info.state == newState) return;
    info.state = newState;
    info.lastChangedAt = DateTime.now();
    container.refresh();
  }

  void _publish(Topic? t, String label, Map<String, dynamic> payload) {
    if (t == null) {
      lastError.value = 'ROS not connected — $label skipped';
      return;
    }
    try {
      t.publish(payload);
    } catch (e) {
      lastError.value = '$label failed: $e';
    }
  }
}

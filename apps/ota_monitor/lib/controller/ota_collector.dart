import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:ota_monitor/data/ota_data.dart';
import 'package:ota_monitor/logging/app_log.dart';

enum OtaRequestKind {
  getSettings,
  setSettings,
  getState,
  setUpdate,
}

/// F009: response event emitted whenever an Actor-service Response arrives
/// (success or business-level error). Lets the Actor tab (and future
/// consumers) react to individual requests without polling [topicData].
///
/// `id` is the request id that was assigned by [OtaCollector] when the
/// matching publish was issued; callers use it to match their own in-flight
/// request. `body` carries the raw decoded message so consumers can read
/// fields that are specific to a particular response kind.
class OtaResponseEvent {
  OtaResponseEvent({
    required this.kind,
    required this.id,
    required this.appName,
    required this.retCode,
    required this.body,
  });

  final OtaRequestKind kind;
  final int? id;
  final String? appName;
  final int? retCode;
  final Map<String, dynamic> body;
}

class PendingRequest {
  PendingRequest({
    required this.id,
    required this.appName,
    required this.kind,
    required this.sentAt,
  });

  final int id;
  final String appName;
  final OtaRequestKind kind;
  final DateTime sentAt;
}

class OtaCollector extends GetxController {
  final Topic Function(Ros ros, String name, String type) topicFactory;

  /// Request expiration window. Requests older than this are removed from
  /// [pendingRequests] with a warning log. Exposed for testing.
  final Duration requestTimeout;

  /// Sweep interval for [pendingRequests] expiration. Exposed for testing.
  final Duration timeoutSweepInterval;

  /// App names to seed the UI with at startup (F004). Settings and state
  /// requests are issued automatically for each entry once topics are
  /// advertised.
  final List<String> initialApps;

  /// Poll interval used to detect changes to the GetX-registered Ros.
  /// Exposed primarily so widget tests can disable the ticker.
  final Duration watchdogInterval;

  /// When false, onInit() skips the watchdog and timeout sweeper timers.
  /// Widget tests flip this off to avoid 'Timer is still pending' failures.
  final bool autoStartTimers;

  OtaCollector({
    Topic Function(Ros ros, String name, String type)? topicFactory,
    this.requestTimeout = const Duration(seconds: 30),
    this.timeoutSweepInterval = const Duration(seconds: 5),
    this.watchdogInterval = const Duration(seconds: 1),
    this.initialApps = const [],
    this.autoStartTimers = true,
  }) : topicFactory = topicFactory ??
            ((ros, name, type) => Topic(ros: ros, name: name, type: type)) {
    // Seed the app list immediately so the UI has something to show while
    // responses are still in flight. The entries' status stays 'Unknown'
    // until the first GetAppUpdateStateResponse arrives.
    for (final name in initialApps) {
      _updateAppList(name);
    }
  }

  Ros get _ros => Get.find<Ros>();

  // State data
  final RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> appList = <Map<String, dynamic>>[].obs;

  // Request ID tracking
  int _nextRequestId = 1000;
  final Map<int, PendingRequest> _pendingRequests = <int, PendingRequest>{};

  /// Read-only view of in-flight requests (kept for diagnostics & tests).
  Map<int, PendingRequest> get pendingRequests =>
      Map.unmodifiable(_pendingRequests);

  int get pendingRequestCount => _pendingRequests.length;

  // Topic instances
  Topic? _settingsRespSub;
  Topic? _setSettingsRespSub;
  Topic? _stateRespSub;
  Topic? _updateRespSub;

  Topic? _settingsReqPub;
  Topic? _setSettingsReqPub;
  Topic? _stateReqPub;
  Topic? _updateReqPub;

  // F023 — GetAppList query (Manager 진실 소스 통합).
  Topic? _getAppListReqPub;
  Topic? _getAppListResSub;
  int _nextGetAppListId = 1;

  /// Source label for the App List (F023).
  /// 'local' until the first GetAppListResponse arrives, then 'manager'.
  final RxString appListSource = 'local'.obs;

  /// Per-app owner client_id from the most recent GetAppListResponse.
  /// Used by tooltips / debug overlays in the Apps tab.
  final RxMap<String, int> appOwnerClientIds = <String, int>{}.obs;

  /// Monotonic counter incremented on every successful
  /// GetAppListResponse. Lets the UI's refresh button observe whether a
  /// response arrived inside its 5 s window without itself owning
  /// subscription bookkeeping.
  final RxInt appListGeneration = 0.obs;

  bool _setup = false;
  Ros? _boundRos;
  Timer? _watchdog;
  Timer? _timeoutSweeper;

  /// F009 SHOULD #1: flips to `true` once `_start` has finished subscribing
  /// and advertising the Actor topics. The Actor tab listens to this so its
  /// Send buttons stay disabled until the rosbridge round-trip is wired —
  /// wireframe §4 "미연결 → Send disabled" requirement.
  final ValueNotifier<bool> readyNotifier = ValueNotifier<bool>(false);

  bool get isReady => readyNotifier.value;

  // F007: surface user-facing error events to the UI via a broadcast stream.
  final StreamController<String> _errorCtrl =
      StreamController<String>.broadcast();

  /// Emits short, user-facing error messages (displayed as SnackBars).
  Stream<String> get errors => _errorCtrl.stream;

  // F009: per-request response events for the Actor tab's raw UI. Each
  // event fires after [_matchAndRemove] succeeds (or is skipped for
  // unsolicited notifications), so `id` is safe to use for request-reply
  // correlation on the listener side.
  final StreamController<OtaResponseEvent> _responseCtrl =
      StreamController<OtaResponseEvent>.broadcast();

  /// Emits each Actor-service response as it arrives. Broadcast stream;
  /// late subscribers miss past events.
  Stream<OtaResponseEvent> get responses => _responseCtrl.stream;

  @override
  void onInit() {
    super.onInit();
    if (!autoStartTimers) return;
    // Poll until Ros instance is available in GetX (set by RosKeeper on connect)
    _watchdog = Timer.periodic(watchdogInterval, (_) {
      if (!Get.isRegistered<Ros>()) return;
      final r = _ros;
      if (_boundRos == r && _setup) return;
      _start(r);
    });

    // Periodic sweeper for expired pending requests.
    _timeoutSweeper = Timer.periodic(timeoutSweepInterval, (_) {
      sweepExpiredRequests();
    });
  }

  @override
  void onClose() {
    _watchdog?.cancel();
    _timeoutSweeper?.cancel();
    _errorCtrl.close();
    _responseCtrl.close();
    readyNotifier.dispose();
    super.onClose();
  }

  // Called by watchdog when Ros instance changes; exposed for testing.
  Future<void> startTopics(Ros r) => _start(r);

  Future<void> _start(Ros r) async {
    _setup = false;
    readyNotifier.value = false;
    _boundRos = r;

    try {
      // ── Subscribe: response topics ───────────────────────────────────────
      _settingsRespSub = topicFactory(
          r, otaResponseTopics[0], otaRosResponseTypes[0]);
      _setSettingsRespSub = topicFactory(
          r, otaResponseTopics[1], otaRosResponseTypes[1]);
      _stateRespSub = topicFactory(
          r, otaResponseTopics[2], otaRosResponseTypes[2]);
      _updateRespSub = topicFactory(
          r, otaResponseTopics[3], otaRosResponseTypes[3]);

      await _settingsRespSub?.subscribe((m) async => onSettingsResponse(m));
      await _setSettingsRespSub?.subscribe((m) async => onSetSettingsResponse(m));
      await _stateRespSub?.subscribe((m) async => onStateResponse(m));
      await _updateRespSub?.subscribe((m) async => onUpdateResponse(m));

      // ── Advertise: request topics ────────────────────────────────────────
      _settingsReqPub = topicFactory(
          r, otaRequestTopics[0], otaRosRequestTypes[0]);
      _setSettingsReqPub = topicFactory(
          r, otaRequestTopics[1], otaRosRequestTypes[1]);
      _stateReqPub = topicFactory(
          r, otaRequestTopics[2], otaRosRequestTypes[2]);
      _updateReqPub = topicFactory(
          r, otaRequestTopics[3], otaRosRequestTypes[3]);

      await _settingsReqPub?.advertise();
      await _setSettingsReqPub?.advertise();
      await _stateReqPub?.advertise();
      await _updateReqPub?.advertise();

      // F023 — GetAppList query channel.
      _getAppListReqPub = topicFactory(
          r, otaGetAppListReqTopic, otaGetAppListReqType);
      _getAppListResSub = topicFactory(
          r, otaGetAppListResTopic, otaGetAppListResType);
      await _getAppListReqPub?.advertise();
      await _getAppListResSub?.subscribe(
          (m) async => onGetAppListResponse(m));

      _setup = true;
      readyNotifier.value = true;
      appLog('[OTA] Topics subscribed & advertised');

      // F004: auto-request settings/state for each initialApps entry.
      for (final name in initialApps) {
        requestAppSettings(name);
        requestAppState(name);
      }
      if (initialApps.isNotEmpty) {
        appLog('[OTA] Auto-requested initial apps: $initialApps');
      }
    } catch (e) {
      appLog('[OTA] _start error: $e', level: 'error');
    }
  }

  // ── Response handlers ────────────────────────────────────────────────────

  void onSettingsResponse(Map<String, dynamic> msg) {
    appLog('[OTA] GetAppUpdateSettingsResponse: $msg');
    final matched = _matchAndRemove(msg, OtaRequestKind.getSettings);
    final appName = (msg['app_name'] as String?) ?? matched?.appName;
    final appSettings = msg['app_settings'] as String?;
    final retCode = msg['ret_code'] as int?;

    if (appName != null) {
      topicData['${appName}_settings'] = appSettings ?? '';
      topicData['${appName}_settings_ret'] = ReturnValue.fromInt(retCode);
      _updateAppList(appName, settings: appSettings);
    }
    _emitResponse(OtaRequestKind.getSettings, msg, matched?.id, appName,
        retCode);
  }

  void onSetSettingsResponse(Map<String, dynamic> msg) {
    appLog('[OTA] SetAppUpdateSettingsResponse: $msg');
    final matched = _matchAndRemove(msg, OtaRequestKind.setSettings);
    final retCode = msg['ret_code'] as int?;
    final appName = (msg['app_name'] as String?) ?? matched?.appName;
    final result = ReturnValue.fromInt(retCode);
    topicData['last_set_settings_result'] = result;
    if (appName != null) {
      topicData['${appName}_set_settings_result'] = result;
    }
    _emitResponse(OtaRequestKind.setSettings, msg, matched?.id, appName,
        retCode);
  }

  void onStateResponse(Map<String, dynamic> msg) {
    appLog('[OTA] GetAppUpdateStateResponse: $msg');
    final matched = _matchAndRemove(msg, OtaRequestKind.getState);
    final appName = (msg['app_name'] as String?) ?? matched?.appName;
    final appStateInfo = msg['app_state_info'] as String?;
    final retCode = msg['ret_code'] as int?;

    if (appName != null) {
      topicData['${appName}_state'] = appStateInfo ?? '';
      topicData['${appName}_state_ret'] = ReturnValue.fromInt(retCode);
      _updateAppList(appName, state: appStateInfo);
    }
    _emitResponse(OtaRequestKind.getState, msg, matched?.id, appName, retCode);
  }

  void onUpdateResponse(Map<String, dynamic> msg) {
    appLog('[OTA] SetAppUpdateResponse: $msg');
    final matched = _matchAndRemove(msg, OtaRequestKind.setUpdate);
    final appName = (msg['app_name'] as String?) ?? matched?.appName;
    final retCode = msg['ret_code'] as int?;

    if (appName != null) {
      topicData['${appName}_update_result'] = ReturnValue.fromInt(retCode);
    }
    _emitResponse(OtaRequestKind.setUpdate, msg, matched?.id, appName,
        retCode);
  }

  // ── F023: GetAppList query ───────────────────────────────────────────────
  //
  // Issues a GetAppList request to the Manager and lets onGetAppListResponse
  // overwrite [appList] with the authoritative snapshot. Returns the
  // request id so a caller (Apps tab refresh button, integration test)
  // can correlate the response.
  int requestAppList() {
    final id = _nextGetAppListId++;
    _publish(_getAppListReqPub, {'id': id});
    appLog('[OTA] GetAppList request id=$id');
    return id;
  }

  /// Public for unit tests; called by the rosbridge subscription in
  /// production.
  void onGetAppListResponse(Map<String, dynamic> msg) {
    final names = (msg['app_names'] as List?)
            ?.whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    final owners = (msg['owner_client_ids'] as List?)
            ?.map((v) => (v as num).toInt())
            .toList(growable: false) ??
        const <int>[];

    appLog('[OTA] GetAppListResponse apps=${names.length}');

    // F023 ac3: replace appList wholesale, but preserve any per-app
    // status/settings/state cached from prior responses (key = appName).
    final preserved = <String, Map<String, dynamic>>{};
    for (final entry in appList) {
      preserved[entry['name'] as String] = Map<String, dynamic>.from(entry);
    }
    appList.clear();
    final newOwners = <String, int>{};
    for (var i = 0; i < names.length; i++) {
      final n = names[i];
      final cached = preserved[n] ?? <String, dynamic>{
        'name': n,
        'settings': '',
        'state': '',
        'status': 'Unknown',
      };
      cached['name'] = n;
      appList.add(cached);
      if (i < owners.length) newOwners[n] = owners[i];
    }
    appOwnerClientIds.assignAll(newOwners);
    appListSource.value = 'manager';
    appListGeneration.value = appListGeneration.value + 1;
  }

  // ── Publish helpers ──────────────────────────────────────────────────────
  //
  // F009: each of these returns the assigned request id so the caller
  // (Actor tab cards, tests) can match the corresponding response event.

  int requestAppSettings(String appName) {
    final id = _registerRequest(appName, OtaRequestKind.getSettings);
    _publish(_settingsReqPub, {'id': id, 'app_name': appName});
    appLog('[OTA] Requested settings for $appName (id=$id)');
    return id;
  }

  int setAppSettings(String appName, String settingsJson) {
    final id = _registerRequest(appName, OtaRequestKind.setSettings);
    _publish(_setSettingsReqPub,
        {'id': id, 'app_name': appName, 'app_settings': settingsJson});
    appLog('[OTA] Set settings for $appName (id=$id)');
    return id;
  }

  int requestAppState(String appName) {
    final id = _registerRequest(appName, OtaRequestKind.getState);
    _publish(_stateReqPub, {'id': id, 'app_name': appName});
    appLog('[OTA] Requested state for $appName (id=$id)');
    return id;
  }

  int requestUpdate(String appName) {
    final id = _registerRequest(appName, OtaRequestKind.setUpdate);
    _publish(_updateReqPub, {'id': id, 'app_name': appName});
    appLog('[OTA] Requested update for $appName (id=$id)');
    return id;
  }

  void _publish(Topic? topic, Map<String, dynamic> fields) {
    if (topic == null) {
      appLog('[OTA] publish skipped: topic not ready', level: 'warn');
      if (!_errorCtrl.isClosed) {
        _errorCtrl.add('ROS에 연결되지 않음 — 잠시 후 다시 시도하세요');
      }
      return;
    }
    try {
      topic.publish(fields);
    } catch (e) {
      appLog('[OTA] publish error: $e', level: 'warn');
      if (!_errorCtrl.isClosed) {
        _errorCtrl.add('요청 전송 실패: $e');
      }
    }
  }

  // ── Request / response correlation ───────────────────────────────────────

  int _registerRequest(String appName, OtaRequestKind kind) {
    final id = _nextRequestId++;
    _pendingRequests[id] = PendingRequest(
      id: id,
      appName: appName,
      kind: kind,
      sentAt: DateTime.now(),
    );
    return id;
  }

  /// F009: emit an [OtaResponseEvent] on the broadcast [responses] stream.
  /// Tolerates a closed controller (guards against events arriving after
  /// onClose during widget disposal).
  void _emitResponse(
    OtaRequestKind kind,
    Map<String, dynamic> msg,
    int? matchedId,
    String? appName,
    int? retCode,
  ) {
    if (_responseCtrl.isClosed) return;
    final msgId = _extractInt(msg['id']);
    _responseCtrl.add(OtaResponseEvent(
      kind: kind,
      id: msgId ?? matchedId,
      appName: appName,
      retCode: retCode,
      body: msg,
    ));
  }

  /// Look up the pending request referenced by [msg]'s `id` field (if any)
  /// and remove it when the [expectedKind] matches. Returns the matched
  /// [PendingRequest] on success, or null otherwise.
  PendingRequest? _matchAndRemove(
      Map<String, dynamic> msg, OtaRequestKind expectedKind) {
    final id = _extractInt(msg['id']);
    if (id == null) return null;
    final pending = _pendingRequests[id];
    if (pending == null) {
      appLog('[OTA] orphan response id=$id (no pending request)', level: 'warn');
      return null;
    }
    if (pending.kind != expectedKind) {
      appLog(
          '[OTA] id=$id kind mismatch (pending=${pending.kind} response=$expectedKind)');
      return null;
    }
    _pendingRequests.remove(id);
    return pending;
  }

  static int? _extractInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Remove requests older than [requestTimeout]. Returns the number of
  /// expired entries removed. Public for tests.
  int sweepExpiredRequests() {
    if (_pendingRequests.isEmpty) return 0;
    final now = DateTime.now();
    final expired = <int>[];
    _pendingRequests.forEach((id, req) {
      if (now.difference(req.sentAt) >= requestTimeout) {
        expired.add(id);
      }
    });
    for (final id in expired) {
      final p = _pendingRequests.remove(id);
      appLog(
          '[OTA] request id=$id timed out after ${requestTimeout.inSeconds}s '
          '(app=${p?.appName}, kind=${p?.kind})');
    }
    return expired.length;
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  void _updateAppList(String appName,
      {String? settings, String? state, String? status}) {
    final idx = appList.indexWhere((a) => a['name'] == appName);
    if (idx != -1) {
      final app = Map<String, dynamic>.from(appList[idx]);
      if (settings != null) app['settings'] = settings;
      if (state != null) app['state'] = state;
      if (status != null) app['status'] = status;
      appList[idx] = app;
    } else {
      appList.add({
        'name': appName,
        'settings': settings ?? '',
        'state': state ?? '',
        'status': status ?? 'Unknown',
      });
    }
  }

}

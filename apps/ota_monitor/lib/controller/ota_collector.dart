import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:ota_monitor/data/ota_data.dart';

class OtaCollector extends GetxController {
  final Topic Function(Ros ros, String name, String type) topicFactory;

  OtaCollector({
    Topic Function(Ros ros, String name, String type)? topicFactory,
  }) : topicFactory = topicFactory ??
            ((ros, name, type) => Topic(ros: ros, name: name, type: type));

  Ros get _ros => Get.find<Ros>();

  // State data
  final RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> appList = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> updateHistory =
      <Map<String, dynamic>>[].obs;

  // Request ID counter
  int _nextRequestId = 1000;

  // Topic instances
  Topic? _settingsRespSub;
  Topic? _setSettingsRespSub;
  Topic? _stateRespSub;
  Topic? _updateRespSub;
  Topic? _notifyStatusSub;

  Topic? _settingsReqPub;
  Topic? _setSettingsReqPub;
  Topic? _stateReqPub;
  Topic? _updateReqPub;

  bool _setup = false;
  Ros? _boundRos;
  Timer? _watchdog;

  @override
  void onInit() {
    super.onInit();
    // Poll until Ros instance is available in GetX (set by RosKeeper on connect)
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!Get.isRegistered<Ros>()) return;
      final r = _ros;
      if (_boundRos == r && _setup) return;
      _start(r);
    });
  }

  @override
  void onClose() {
    _watchdog?.cancel();
    super.onClose();
  }

  // Called by watchdog when Ros instance changes; exposed for testing.
  Future<void> startTopics(Ros r) => _start(r);

  Future<void> _start(Ros r) async {
    _setup = false;
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
      _notifyStatusSub = topicFactory(
          r, otaResponseTopics[4], otaRosResponseTypes[4]);

      await _settingsRespSub?.subscribe((m) async => onSettingsResponse(m));
      await _setSettingsRespSub?.subscribe((m) async => onSetSettingsResponse(m));
      await _stateRespSub?.subscribe((m) async => onStateResponse(m));
      await _updateRespSub?.subscribe((m) async => onUpdateResponse(m));
      await _notifyStatusSub?.subscribe((m) async => onNotifyStatus(m));

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

      _setup = true;
      debugPrint('[OTA] Topics subscribed & advertised');
    } catch (e) {
      debugPrint('[OTA] _start error: $e');
    }
  }

  // ── Response handlers ────────────────────────────────────────────────────

  void onSettingsResponse(Map<String, dynamic> msg) {
    debugPrint('[OTA] GetAppUpdateSettingsResponse: $msg');
    final appName = msg['app_name'] as String?;
    final appSettings = msg['app_settings'] as String?;
    final retCode = msg['ret_code'] as int?;

    if (appName != null) {
      topicData['${appName}_settings'] = appSettings ?? '';
      topicData['${appName}_settings_ret'] = ReturnValue.fromInt(retCode);
      _updateAppList(appName, settings: appSettings);
    }
  }

  void onSetSettingsResponse(Map<String, dynamic> msg) {
    debugPrint('[OTA] SetAppUpdateSettingsResponse: $msg');
    final retCode = msg['ret_code'] as int?;
    topicData['last_set_settings_result'] = ReturnValue.fromInt(retCode);
  }

  void onStateResponse(Map<String, dynamic> msg) {
    debugPrint('[OTA] GetAppUpdateStateResponse: $msg');
    final appName = msg['app_name'] as String?;
    final appStateInfo = msg['app_state_info'] as String?;
    final retCode = msg['ret_code'] as int?;

    if (appName != null) {
      topicData['${appName}_state'] = appStateInfo ?? '';
      topicData['${appName}_state_ret'] = ReturnValue.fromInt(retCode);
      _updateAppList(appName, state: appStateInfo);
    }
  }

  void onUpdateResponse(Map<String, dynamic> msg) {
    debugPrint('[OTA] SetAppUpdateResponse: $msg');
    final appName = msg['app_name'] as String?;
    final retCode = msg['ret_code'] as int?;

    if (appName != null) {
      topicData['${appName}_update_result'] = ReturnValue.fromInt(retCode);
      _addUpdateHistory(appName, 'Update requested', retCode);
    }
  }

  void onNotifyStatus(Map<String, dynamic> msg) {
    debugPrint('[OTA] NotifyAppUpdateStatus: $msg');
    final appName = msg['app_name'] as String?;
    final status = msg['status'] as String?;

    if (appName != null && status != null) {
      topicData['${appName}_status'] = status;
      _updateAppList(appName, status: status);
      _addUpdateHistory(appName, 'Status: $status', null);
    }
  }

  // ── Publish helpers ──────────────────────────────────────────────────────

  void requestAppSettings(String appName) {
    final id = _nextRequestId++;
    _publish(_settingsReqPub, {'id': id, 'app_name': appName});
    debugPrint('[OTA] Requested settings for $appName (id=$id)');
  }

  void setAppSettings(String appName, String settingsJson) {
    final id = _nextRequestId++;
    _publish(_setSettingsReqPub,
        {'id': id, 'app_name': appName, 'app_settings': settingsJson});
    debugPrint('[OTA] Set settings for $appName (id=$id)');
  }

  void requestAppState(String appName) {
    final id = _nextRequestId++;
    _publish(_stateReqPub, {'id': id, 'app_name': appName});
    debugPrint('[OTA] Requested state for $appName (id=$id)');
  }

  void requestUpdate(String appName) {
    final id = _nextRequestId++;
    _publish(_updateReqPub, {'id': id, 'app_name': appName});
    debugPrint('[OTA] Requested update for $appName (id=$id)');
  }

  void _publish(Topic? topic, Map<String, dynamic> fields) {
    if (topic == null) {
      debugPrint('[OTA] publish skipped: topic not ready');
      return;
    }
    try {
      topic.publish(fields);
    } catch (e) {
      debugPrint('[OTA] publish error: $e');
    }
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

  void _addUpdateHistory(String appName, String message, int? retCode) {
    final timestamp = DateTime.now().toIso8601String();
    updateHistory.insert(0, {
      'timestamp': timestamp,
      'app_name': appName,
      'message': message,
      'ret_code': retCode,
    });
    if (updateHistory.length > 20) {
      updateHistory.removeRange(20, updateHistory.length);
    }
  }
}

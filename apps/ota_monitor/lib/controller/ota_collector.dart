import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:ota_monitor/data/ota_data.dart';
import 'package:ota_monitor/dds/dds_keeper.dart';

class OtaCollector extends GetxController {
  // DDS keeper injected via GetX
  DdsKeeper get _dds => Get.find<DdsKeeper>();

  // State data
  final RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> appList = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> updateHistory =
      <Map<String, dynamic>>[].obs;

  // Request ID counter
  int _nextRequestId = 1000;

  @override
  void onInit() {
    super.onInit();
    _subscribeAll();
  }

  // ============= Subscribe to response topics =============

  void _subscribeAll() {
    final subs = [
      (otaResponseTopics[0], otaDdsResponseTypes[0],
          _handleGetAppUpdateSettingsResponse),
      (otaResponseTopics[1], otaDdsResponseTypes[1],
          _handleSetAppUpdateSettingsResponse),
      (otaResponseTopics[2], otaDdsResponseTypes[2],
          _handleGetAppUpdateStateResponse),
      (otaResponseTopics[3], otaDdsResponseTypes[3],
          _handleSetAppUpdateResponse),
      (otaResponseTopics[4], otaDdsResponseTypes[4],
          _handleNotifyAppUpdateStatus),
    ];

    for (final (topic, type, handler) in subs) {
      _dds.subscribe(topic, type, (t, json) {
        try {
          handler(json);
        } catch (e) {
          debugPrint('[OTA] handler error on $t: $e');
        }
      });
    }
  }

  // ============= Response handlers =============

  void _handleGetAppUpdateSettingsResponse(String json) {
    debugPrint('[OTA] GetAppUpdateSettingsResponse: $json');
    final m = _parseJson(json);
    final appName = m['app_name'] as String?;
    final appSettings = m['app_settings'] as String?;
    final retCode = m['ret_code'] as int?;

    if (appName != null) {
      topicData['${appName}_settings'] = appSettings ?? '';
      topicData['${appName}_settings_ret'] =
          ReturnValue.fromInt(retCode);
      _updateAppList(appName, settings: appSettings);
    }
  }

  void _handleSetAppUpdateSettingsResponse(String json) {
    debugPrint('[OTA] SetAppUpdateSettingsResponse: $json');
    final m = _parseJson(json);
    final retCode = m['ret_code'] as int?;
    topicData['last_set_settings_result'] = ReturnValue.fromInt(retCode);
  }

  void _handleGetAppUpdateStateResponse(String json) {
    debugPrint('[OTA] GetAppUpdateStateResponse: $json');
    final m = _parseJson(json);
    final appName = m['app_name'] as String?;
    final appStateInfo = m['app_state_info'] as String?;
    final retCode = m['ret_code'] as int?;

    if (appName != null) {
      topicData['${appName}_state'] = appStateInfo ?? '';
      topicData['${appName}_state_ret'] = ReturnValue.fromInt(retCode);
      _updateAppList(appName, state: appStateInfo);
    }
  }

  void _handleSetAppUpdateResponse(String json) {
    debugPrint('[OTA] SetAppUpdateResponse: $json');
    final m = _parseJson(json);
    final appName = m['app_name'] as String?;
    final retCode = m['ret_code'] as int?;

    if (appName != null) {
      topicData['${appName}_update_result'] = ReturnValue.fromInt(retCode);
      _addUpdateHistory(appName, 'Update requested', retCode);
    }
  }

  void _handleNotifyAppUpdateStatus(String json) {
    debugPrint('[OTA] NotifyAppUpdateStatus: $json');
    final m = _parseJson(json);
    final appName = m['app_name'] as String?;
    final status = m['status'] as String?;

    if (appName != null && status != null) {
      topicData['${appName}_status'] = status;
      _updateAppList(appName, status: status);
      _addUpdateHistory(appName, 'Status: $status', null);
    }
  }

  // ============= Publish helpers =============

  void requestAppSettings(String appName) {
    final id = _nextRequestId++;
    _publish(
      otaRequestTopics[0],
      otaDdsRequestTypes[0],
      {'id': id, 'app_name': appName},
    );
    debugPrint('[OTA] Requested settings for $appName (id: $id)');
  }

  void setAppSettings(String appName, String settingsJson) {
    final id = _nextRequestId++;
    _publish(
      otaRequestTopics[1],
      otaDdsRequestTypes[1],
      {'id': id, 'app_name': appName, 'app_settings': settingsJson},
    );
    debugPrint('[OTA] Set settings for $appName (id: $id)');
  }

  void requestAppState(String appName) {
    final id = _nextRequestId++;
    _publish(
      otaRequestTopics[2],
      otaDdsRequestTypes[2],
      {'id': id, 'app_name': appName},
    );
    debugPrint('[OTA] Requested state for $appName (id: $id)');
  }

  void requestUpdate(String appName) {
    final id = _nextRequestId++;
    _publish(
      otaRequestTopics[3],
      otaDdsRequestTypes[3],
      {'id': id, 'app_name': appName},
    );
    debugPrint('[OTA] Requested update for $appName (id: $id)');
  }

  void _publish(String topic, String typeName, Map<String, dynamic> fields) {
    try {
      final json = jsonEncode(fields);
      final rc = _dds.publish(topic, typeName, json);
      if (rc != 0) {
        debugPrint('[OTA] publish failed ($rc): $topic');
      }
    } catch (e) {
      debugPrint('[OTA] publish error: $e');
    }
  }

  // ============= Internal helpers =============

  Map<String, dynamic> _parseJson(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

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

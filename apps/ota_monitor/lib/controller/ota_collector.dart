import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:ota_monitor/data/ota_data.dart';

typedef SubscribeHandler = Future<void> Function(Map<String, dynamic> msg);
typedef TopicFactory = Topic Function(Ros ros, String name, String type);

class OtaCollector extends GetxController {
  // ROS 인스턴스 (GetX DI로부터 주입)
  Ros get ros => Get.find<Ros>();

  // Topic Factory (테스트 주입 가능)
  final TopicFactory topicFactory;

  // 상태 데이터
  final RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> appList = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> updateHistory =
      <Map<String, dynamic>>[].obs;

  // Request ID 관리
  int _nextRequestId = 1000;

  // 구독 관리
  List<Topic> _subs = [];
  Ros? _boundRos;

  // Publisher 관리
  Topic? _getSettingsPub;
  Topic? _setSettingsPub;
  Topic? _getStatePub;
  Topic? _setUpdatePub;

  // ROS 감시 타이머
  Timer? _rosWatchdog;

  OtaCollector({
    TopicFactory? topicFactory,
  }) : topicFactory =
            topicFactory ?? ((ros, name, type) => Topic(ros: ros, name: name, type: type));

  @override
  void onInit() {
    super.onInit();

    // ROS 연결 상태 감시 (500ms 주기)
    _rosWatchdog = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final r = ros;
      final rosChanged = _boundRos == null || !identical(_boundRos, r);
      final connected = r.status == Status.connected;

      if (connected && (rosChanged || _subs.isEmpty)) {
        debugPrint('[OTA] ROS (re)connected, rebinding...');
        await _rebindAndResubscribe(r);
      }
    });
  }

  @override
  void onClose() {
    _rosWatchdog?.cancel();
    _unsubscribeAll();
    _unpublishAll();
    super.onClose();
  }

  // 구독 설정
  Future<void> _rebindAndResubscribe(Ros r) async {
    _unsubscribeAll();
    _boundRos = r;

    // Response 토픽 구독
    final handlers = [
      handleGetAppUpdateSettingsResponse,
      handleSetAppUpdateSettingsResponse,
      handleGetAppUpdateStateResponse,
      handleSetAppUpdateResponse,
      handleNotifyAppUpdateStatus,
    ];

    final n = min(otaResponseTopics.length, otaResponseTypes.length);
    for (int i = 0; i < n && i < handlers.length; i++) {
      try {
        final t = topicFactory(r, otaResponseTopics[i], otaResponseTypes[i]);
        t.subscribe(handlers[i]);
        _subs.add(t);
        debugPrint('[OTA] Subscribed to ${otaResponseTopics[i]}');
      } catch (e) {
        debugPrint('[OTA] Failed to subscribe ${otaResponseTopics[i]}: $e');
      }
    }

    // Request 토픽 발행자 생성
    try {
      _getSettingsPub = topicFactory(
        r,
        '/mmf/otamanager/otaactor_service/GetAppUpdateSettings',
        'ota_manager/GetAppUpdateSettings',
      );
      _setSettingsPub = topicFactory(
        r,
        '/mmf/otamanager/otaactor_service/SetAppUpdateSettings',
        'ota_manager/SetAppUpdateSettings',
      );
      _getStatePub = topicFactory(
        r,
        '/mmf/otamanager/otaactor_service/GetAppUpdateState',
        'ota_manager/GetAppUpdateState',
      );
      _setUpdatePub = topicFactory(
        r,
        '/mmf/otamanager/otaactor_service/SetAppUpdate',
        'ota_manager/SetAppUpdate',
      );
      debugPrint('[OTA] Publishers created');
    } catch (e) {
      debugPrint('[OTA] Failed to create publishers: $e');
    }
  }

  void _unsubscribeAll() {
    for (final t in _subs) {
      try {
        t.unsubscribe();
      } catch (_) {}
    }
    _subs.clear();
  }

  void _unpublishAll() {
    _getSettingsPub?.unadvertise();
    _setSettingsPub?.unadvertise();
    _getStatePub?.unadvertise();
    _setUpdatePub?.unadvertise();
    _getSettingsPub = null;
    _setSettingsPub = null;
    _getStatePub = null;
    _setUpdatePub = null;
  }

  // ============= Response 핸들러 =============

  Future<void> handleGetAppUpdateSettingsResponse(
      Map<String, dynamic> msg) async {
    debugPrint('[OTA] GetAppUpdateSettingsResponse: $msg');

    final id = msg['id'] as num?;
    final appName = msg['app_name'] as String?;
    final appSettings = msg['app_settings'] as String?;
    final retCode = msg['ret_code'] as num?;

    if (appName != null) {
      topicData['${appName}_settings'] = appSettings ?? '';
      topicData['${appName}_settings_ret'] = ReturnValue.fromInt(retCode?.toInt());

      // 앱 목록 업데이트
      _updateAppList(appName, settings: appSettings);
    }
  }

  Future<void> handleSetAppUpdateSettingsResponse(
      Map<String, dynamic> msg) async {
    debugPrint('[OTA] SetAppUpdateSettingsResponse: $msg');

    final id = msg['id'] as num?;
    final retCode = msg['ret_code'] as num?;

    topicData['last_set_settings_result'] = ReturnValue.fromInt(retCode?.toInt());
  }

  Future<void> handleGetAppUpdateStateResponse(Map<String, dynamic> msg) async {
    debugPrint('[OTA] GetAppUpdateStateResponse: $msg');

    final id = msg['id'] as num?;
    final appName = msg['app_name'] as String?;
    final appStateInfo = msg['app_state_info'] as String?;
    final retCode = msg['ret_code'] as num?;

    if (appName != null) {
      topicData['${appName}_state'] = appStateInfo ?? '';
      topicData['${appName}_state_ret'] = ReturnValue.fromInt(retCode?.toInt());

      // 앱 목록 업데이트
      _updateAppList(appName, state: appStateInfo);
    }
  }

  Future<void> handleSetAppUpdateResponse(Map<String, dynamic> msg) async {
    debugPrint('[OTA] SetAppUpdateResponse: $msg');

    final id = msg['id'] as num?;
    final appName = msg['app_name'] as String?;
    final retCode = msg['ret_code'] as num?;

    if (appName != null) {
      topicData['${appName}_update_result'] = ReturnValue.fromInt(retCode?.toInt());

      // 업데이트 히스토리 추가
      _addUpdateHistory(appName, 'Update requested', retCode?.toInt());
    }
  }

  Future<void> handleNotifyAppUpdateStatus(Map<String, dynamic> msg) async {
    debugPrint('[OTA] NotifyAppUpdateStatus: $msg');

    final clientId = msg['client_id'] as num?;
    final appName = msg['app_name'] as String?;
    final status = msg['status'] as String?;

    if (appName != null && status != null) {
      topicData['${appName}_status'] = status;

      // 앱 목록 업데이트
      _updateAppList(appName, status: status);

      // 히스토리 추가
      _addUpdateHistory(appName, 'Status: $status', null);
    }
  }

  // ============= 발행 메서드 =============

  void requestAppSettings(String appName) {
    final id = _nextRequestId++;
    final msg = {
      'id': id,
      'app_name': appName,
    };

    try {
      _getSettingsPub?.publish(msg);
      debugPrint('[OTA] Requested settings for $appName (id: $id)');
    } catch (e) {
      debugPrint('[OTA] Failed to request settings: $e');
    }
  }

  void setAppSettings(String appName, String settingsJson) {
    final id = _nextRequestId++;
    final msg = {
      'id': id,
      'app_name': appName,
      'app_settings': settingsJson,
    };

    try {
      _setSettingsPub?.publish(msg);
      debugPrint('[OTA] Set settings for $appName (id: $id)');
    } catch (e) {
      debugPrint('[OTA] Failed to set settings: $e');
    }
  }

  void requestAppState(String appName) {
    final id = _nextRequestId++;
    final msg = {
      'id': id,
      'app_name': appName,
    };

    try {
      _getStatePub?.publish(msg);
      debugPrint('[OTA] Requested state for $appName (id: $id)');
    } catch (e) {
      debugPrint('[OTA] Failed to request state: $e');
    }
  }

  void requestUpdate(String appName) {
    final id = _nextRequestId++;
    final msg = {
      'id': id,
      'app_name': appName,
    };

    try {
      _setUpdatePub?.publish(msg);
      debugPrint('[OTA] Requested update for $appName (id: $id)');
    } catch (e) {
      debugPrint('[OTA] Failed to request update: $e');
    }
  }

  // ============= 내부 헬퍼 메서드 =============

  void _updateAppList(String appName,
      {String? settings, String? state, String? status}) {
    // 기존 앱 찾기
    final existingIndex = appList.indexWhere((app) => app['name'] == appName);

    if (existingIndex != -1) {
      // 업데이트
      final app = Map<String, dynamic>.from(appList[existingIndex]);
      if (settings != null) app['settings'] = settings;
      if (state != null) app['state'] = state;
      if (status != null) app['status'] = status;
      appList[existingIndex] = app;
    } else {
      // 새로 추가
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

    // 최근 20개만 유지
    if (updateHistory.length > 20) {
      updateHistory.removeRange(20, updateHistory.length);
    }
  }
}

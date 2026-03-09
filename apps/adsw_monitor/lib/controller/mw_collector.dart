import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

const _statusText = {
  0: 'UNKNOWN',
  1: 'PASS',
  2: 'FATAL',
  3: 'WARNING',
};

const _retText = {
  0: 'UNKNOWN',
  1: 'PASS',
  2: 'FAIL',
};

class DiagNotificationItem {
  final int diagCode;
  final String diagName;
  final int? status;
  final String? statusText;
  final String message;
  final String sourceMessageName;
  final String rawData;
  final DateTime receivedAt;

  const DiagNotificationItem({
    required this.diagCode,
    required this.diagName,
    required this.status,
    required this.statusText,
    required this.message,
    required this.sourceMessageName,
    required this.rawData,
    required this.receivedAt,
  });

  String get label {
    final n = diagName.trim().isEmpty ? 'unknown' : diagName.trim();
    return '$n ($diagCode)';
  }
}

class MwCollector extends GetxController {
  static const _pkg = 'diagnosticmgr/msg';
  static const Duration _watchdogInterval = Duration(milliseconds: 500);

  final Topic Function(Ros ros, String name, String type) topicFactory;

  Ros get ros => Get.find<Ros>();            

  final RxList<Map<String, dynamic>> diagnostics = <Map<String, dynamic>>[].obs;
  final RxList<DiagNotificationItem> notificationLogs =
      <DiagNotificationItem>[].obs;

  final RxBool isRefreshing = false.obs;
  final RxnString lastError = RxnString();
  final RxnString securityData = RxnString();

  Topic? _infoReqPub;
  Topic? _infoListReqPub;
  Topic? _infoRespSub;
  Topic? _infoListRespSub;
  Topic? _notificationSub;

  Timer? _rosWatchdog;
  Ros? _boundRos;

  bool _advertised = false;
  bool _rebinding = false;
  bool _refreshInFlight = false;

  MwCollector({required this.topicFactory});

  @override
  void onInit() {
    super.onInit();
    _startRosWatchdog();
  }

  @override
  void onClose() {
    _stopRosWatchdog();
    _clearConnectionState(resetBoundRos: true);
    super.onClose();
  }

  Future<void> refreshOnce() async {
    if (_refreshInFlight) return;

    _refreshInFlight = true;
    isRefreshing.value = true;
    lastError.value = null;
    try {
      Ros r;
      try {
        r = ros;
      } catch (e) {
        lastError.value = 'ROS instance is not available';
        debugPrint('[MW] ROS lookup failed: $e');
        return;
      }

      if (r.status != Status.connected) {
        lastError.value = 'ROS is not connected';
        return;
      }

      final ready = await _ensureBoundAndReady(r);
      if (!ready) {
        lastError.value  = 'Failed to prepare diagnostic communication';
        return;
      }

      diagnostics.clear();
      await _sendInfoListRequest();
    } catch (e) {
      lastError.value = "Refresh failed";
      debugPrint('[MW] refreshOnce failed: $e');
    } finally {
      isRefreshing.value = false;
      _refreshInFlight = false;
    }
  }

  void _startRosWatchdog() {
    _rosWatchdog?.cancel();
    _rosWatchdog = Timer.periodic(_watchdogInterval, (_) async {
      if (_rebinding) return;

      Ros r;
      try {
        r = ros;
      } catch (_) {
        if (_boundRos != null || _hasAnyCommObject()) {
          debugPrint('[MW] ROS instance unavailable. clearing connection state');
          _clearConnectionState(resetBoundRos: true);
        }
        return;
      }

      final connected = r.status == Status.connected;
      final rosChanged = _boundRos == null || !identical(_boundRos, r);
      final notReady  = !_isCommReady();

      if (!connected) {
        if (_boundRos != null || _hasAnyCommObject() || _advertised) {
          debugPrint('[MW] ROS disconnected. tearing down comms');
          _clearConnectionState(resetBoundRos: true);
        }
        return;
      }

      if (rosChanged || notReady) {
        debugPrint(
          '[MW] watchdog trigger. connected=$connected '
          'rosChanged=$rosChanged notReady=$notReady',
        );
        await _ensureBoundAndReady(r);
      }
    });
  }

  void _stopRosWatchdog() {
    _rosWatchdog?.cancel();
    _rosWatchdog = null;
  }

  bool _hasAnyCommObject() {
    return _infoReqPub != null ||
    _infoListReqPub != null ||
    _infoRespSub != null ||
    _infoListRespSub != null ||
    _notificationSub != null;
  }

  bool _isCommReady() {
    return _boundRos != null &&
          _infoReqPub != null &&
          _infoListReqPub != null &&
          _infoRespSub != null &&
          _infoListRespSub != null &&
          _notificationSub != null &&
          _advertised;
  }

  Future<bool> _ensureBoundAndReady(Ros r) async {
    if (_rebinding) return _isCommReady();
    if (r.status != Status.connected) return false;

    _rebinding = true;
    try {
      final needRecreateTopics =
          _boundRos == null ||
          !identical(_boundRos, r) ||
          _infoReqPub == null ||
          _infoListReqPub == null ||
          _infoRespSub == null ||
          _infoListRespSub == null ||
          _notificationSub == null;

      if (needRecreateTopics) {
        _createAndSubscribeTopics(r);
      }

      final advertised = await _ensureAdvertised();
      return advertised && _isCommReady();
    } catch (e) {
      debugPrint('[MW] _ensureBoundAndReady failed: $e');
      return false;
    } finally {
      _rebinding = false;
    }
  }

  void _createAndSubscribeTopics(Ros r) {
    debugPrint(
      '[MW] createAndSubscribeTopics. rosChanged='
      '${_boundRos == null || !identical(_boundRos, r)}',
    );

    _clearConnectionState(resetBoundRos: false);
    _boundRos = r;

    _infoReqPub = topicFactory(
      r,
      '/mmf/diagnosticmgr/DiagnosticInfoRequest',
      '$_pkg/DiagnosticInfoRequest',
    );

    _infoListReqPub = topicFactory(
      r,
      '/mmf/diagnosticmgr/DiagnosticInfoListRequest',
      '$_pkg/DiagnosticInfoListRequest',
    );

    _infoRespSub = topicFactory(
      r,
      '/mmf/diagnosticmgr/DiagnosticInfoResponse',
      '$_pkg/DiagnosticInfoResponse',
    );

    _infoListRespSub = topicFactory(
      r,
      '/mmf/diagnosticmgr/DiagnosticInfoListResponse',
      '$_pkg/DiagnosticInfoListResponse',
    );

    _notificationSub = topicFactory(
      r,
      '/mmf/diagnosticmgr/DiagnosticNotification',
      '$_pkg/DiagnosticNotification',
    );

    _infoListRespSub?.subscribe(_onInfoListResponse);
    _infoRespSub?.subscribe(_onInfoResponse);
    _notificationSub?.subscribe(_onNotification);

    _advertised = false;
  }

  Future<bool> _ensureAdvertised({int maxRetry = 3}) async {
    if (_advertised) return true;
    if (ros.status != Status.connected) return false;
    if (_infoReqPub == null || _infoListReqPub == null) return false;

    for (int attempt = 1; attempt <= maxRetry; attempt++) {
      try {
        await _infoListReqPub!.advertise();
        await _infoReqPub!.advertise();
        _advertised = true;
        debugPrint('[MW] advertise done (attempt=$attempt)');
        return true;
      } catch (e) {
        debugPrint('[MW] advertise failed (attempt=$attempt): $e');
        if (attempt < maxRetry) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    }

    return false;
  }

  void _clearConnectionState({required bool resetBoundRos}) {
    try {
      _infoListRespSub?.unsubscribe();
    } catch (_) {}

    try {
      _infoRespSub?.unsubscribe();
    } catch (_) {}

    try {
      _notificationSub?.unsubscribe();
    } catch (_) {}

    try {
      _infoReqPub?.unadvertise();
    } catch (_) {}

    try {
      _infoListReqPub?.unadvertise();
    } catch (_) {}

    _infoReqPub = null;
    _infoListReqPub = null;
    _infoRespSub = null;
    _infoListRespSub = null;
    _notificationSub = null;
    _advertised = false;

    if (resetBoundRos) {
      _boundRos = null;
    }
  }

  Future<void> _sendInfoListRequest() async {
    if (ros.status != Status.connected) return;
    if (!_advertised || _infoListReqPub == null) return;

    try {
      await _infoListReqPub!.publish({});
      debugPrint('[MW] DiagnosticInfoListRequest published');
    } catch (e) {
      debugPrint('[MW] list request failed: $e');
    }
  }

  Future<void> _sendInfoRequest(int code, String name) async {
    if (ros.status != Status.connected) return;
    if (!_advertised || _infoReqPub == null) return;

    try {
      debugPrint('[MW] send request code=$code name=$name');
      await _infoReqPub!.publish({
        'diag_code': code,
        'diag_name': name,
      });
    } catch (e) {
      debugPrint('[MW] info request failed: $e');
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? -1;
  }

  List<dynamic> _asList(dynamic v) => (v is List) ? v : const [];

  int? _extractRetCode(dynamic raw) {
    if (raw is Map && raw['ret_code'] is num) {
      return (raw['ret_code'] as num).toInt();
    }
    if (raw is num) return raw.toInt();
    return null;
  }

  int? _extractDiagStatus(dynamic raw) {
    if (raw is Map && raw['diag_status'] is num) {
      return (raw['diag_status'] as num).toInt();
    }
    if (raw is num) return raw.toInt();
    return null;
  }

  int? _extractNotiStatus(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final up = raw.trim().toUpperCase();
      for (final e in _statusText.entries) {
        if (e.value == up) return e.key;
      }
      final n = int.tryParse(up);
      if (n != null) return n;
    }
    if (raw is Map) {
      final v = raw['status'] ?? raw['diag_status'] ?? raw['value'];
      if (v is num) return v.toInt();
      if (v is String) {
        final up = v.trim().toUpperCase();
        for (final e in _statusText.entries) {
          if (e.value == up) return e.key;
        }
        final n = int.tryParse(up);
        if (n != null) return n;
      }
    }
    return null;
  }

  Future<void> _onInfoListResponse(Map<String, dynamic> msg) async {
    debugPrint("onInfoListResponse(): $msg");

    final codes = _asList(msg['diag_codes']);
    final names = _asList(msg['diag_names']);

    final int n = codes.length < names.length ? codes.length : names.length;

    for (int i = 0; i < n; i++) {
      final code = _toInt(codes[i]);
      final name = '${names[i]}';

      diagnostics.add({
        'name': name,
        'code': code,
        'status': null,
        'status_text': 'UNKNOWN',
        'ret_text': null,
        'message': null,
        'source_message_name': null,
        'raw_data': null,
      });

      await _sendInfoRequest(code, name);
    }
  }

  Future<void> _onInfoResponse(Map<String, dynamic> msg) async {
    debugPrint("onInfoResponse(): $msg");
    final code = _toInt(msg['diag_code']);

    final index = diagnostics.indexWhere((e) => e['code'] == code);
    if (index < 0) return;

    final int? ret = _extractRetCode(msg['ret_code']);
    final int? stat = _extractDiagStatus(msg['status']);

    diagnostics[index] = {
      'name': diagnostics[index]['name'],
      'code': code,
      'ret_code': ret,
      'ret_text': ret != null ? (_retText[ret] ?? '$ret') : null,
      'status': stat,
      'status_text': stat != null ? (_statusText[stat] ?? '$stat') : null,
      'message': msg['message'],
      'source_message_name': msg['source_message_name'],
      'raw_data': msg['raw_data'],
    };

    diagnostics.refresh();
  }

  Future<void> _onNotification(Map<String, dynamic> msg) async {
    final int code = _toInt(msg['diag_code']);
    final String diagName = '${msg['diag_name'] ?? ''}'.trim();

    final int? stat = _extractNotiStatus(msg['status']);
    final String? statText =
        stat != null ? (_statusText[stat] ?? '$stat') : null;

    final item = DiagNotificationItem(
      diagCode: code,
      diagName: diagName,
      status: stat,
      statusText: statText,
      message: '${msg['message'] ?? ''}',
      sourceMessageName: '${msg['source_message_name'] ?? ''}',
      rawData: '${msg['raw_data'] ?? ''}',
      receivedAt: DateTime.now(),
    );

    notificationLogs.insert(0, item);
  }
}
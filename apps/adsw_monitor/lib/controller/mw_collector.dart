import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

extension _NumMin on int {
  int min(int other) => this < other ? this : other;
}

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

class MwCollector extends GetxController {
  Ros get ros => Get.find<Ros>();
  final Topic Function(Ros ros, String name, String type) topicFactory;

  final RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  final RxList<String> diagNames = <String>[].obs;

  final RxList<Map<String, dynamic>> diagLogs = <Map<String, dynamic>>[].obs;
  static const int _maxLogs = 5;

  final Map<int, String> _codeToName = {};
  final Map<int, int> _missCount = {};
  static const int _removeAfterMisses = 2;

  static const _pkg = 'diagnosticmgr/msg';
  Topic? _infoReqPub;
  Topic? _infoListReqPub;
  Topic? _infoRespSub;
  Topic? _infoListRespSub;

  final Duration _reqGap = const Duration(milliseconds: 100);
  final Duration _detailRefreshEvery = const Duration(seconds: 5);
  final Duration _listRefreshEvery = const Duration(seconds: 5);

  Timer? _listRetryTimer;
  Timer? _listPollTimer;
  Timer? _detailTimer;

  bool _advertised = false;

  Ros? _boundRos;
  Timer? _rosWatchdog;
  bool _restarting = false;

  MwCollector({required this.topicFactory});

  @override
  void onInit() {
    super.onInit();

    _rosWatchdog?.cancel();
    _rosWatchdog = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (_restarting) return;

      Ros current;
      try {
        current = ros;
      } catch (_) {
        return;
      }

      final bool rosChanged = _boundRos == null || !identical(_boundRos, current);
      final bool connected = current.status == Status.connected;

      if ((rosChanged && connected) || (connected && !_advertised)) {
        await _bindAndRestart(current);
      }
    });

    unawaited(() async {
      final r = ros;
      if (r.status == Status.connected) {
        await _bindAndRestart(r);
      }
    }());
  }

  @override
  void onClose() {
    _rosWatchdog?.cancel();
    _rosWatchdog = null;

    _tearDownComms();
    super.onClose();
  }

  Future<void> _bindAndRestart(Ros r) async {
    if (_restarting) return;
    _restarting = true;
    try {
      if (r.status != Status.connected) return;

      final needRebind = _boundRos == null || !identical(_boundRos, r);
      if (needRebind) {
        debugPrint('[MW] rebind topics to new Ros');
        _tearDownComms();
        _boundRos = r;
        _prepareTopics(r);
        _wireSubs();
      }

      await _advertiseWithRetry();

      _startTimers();

      await _sendInfoListRequest();
    } finally {
      _restarting = false;
    }
  }

  void _prepareTopics(Ros r) {
    _infoReqPub = topicFactory(
      r, '/mmf/diagnosticmgr/DiagnosticInfoRequest', '$_pkg/DiagnosticInfoRequest');
    _infoListReqPub = topicFactory(
      r, '/mmf/diagnosticmgr/DiagnosticInfoListRequest', '$_pkg/DiagnosticInfoListRequest');
    _infoRespSub = topicFactory(
      r, '/mmf/diagnosticmgr/DiagnosticInfoResponse', '$_pkg/DiagnosticInfoResponse');
    _infoListRespSub = topicFactory(
      r, '/mmf/diagnosticmgr/DiagnosticInfoListResponse', '$_pkg/DiagnosticInfoListResponse');

    _advertised = false;
  }

  void _wireSubs() {
    _infoListRespSub?.subscribe(_onInfoListResponse);
    _infoRespSub?.subscribe(_onInfoResponse);
    debugPrint('[MW] subscribed to responses');
  }

  Future<void> _advertiseWithRetry() async {
    if (_advertised) return;
    if (ros.status != Status.connected) return;

    const attempts = 3;
    for (int i = 0; i < attempts; i++) {
      try {
        await _infoListReqPub?.advertise();
        await _infoReqPub?.advertise();
        _advertised = true;
        debugPrint('[MW] advertised request topics');
        return;
      } catch (e) {
        debugPrint('[MW] advertise failed (try ${i + 1}/$attempts): $e');
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
  }

  void _startTimers() {
    _listPollTimer?.cancel();
    _listPollTimer = Timer.periodic(_listRefreshEvery, (_) async {
      await _sendInfoListRequest();
    });

  }

  void _tearDownComms() {
    _missCount.clear();
    _listRetryTimer?.cancel(); _listRetryTimer = null;
    _listPollTimer?.cancel(); _listPollTimer = null;
    _detailTimer?.cancel(); _detailTimer = null;

    try { _infoListRespSub?.unsubscribe(); } catch (_) {}
    try { _infoRespSub?.unsubscribe(); } catch (_) {}
    try { _infoReqPub?.unadvertise(); } catch (_) {}
    try { _infoListReqPub?.unadvertise(); } catch (_) {}

    _infoReqPub = null;
    _infoListReqPub = null;
    _infoRespSub = null;
    _infoListRespSub = null;

    _advertised = false;
  }

  Future<void> _sendInfoListRequest() async {
    if (ros.status != Status.connected) return;
    try {
      await _infoListReqPub?.publish({});
      debugPrint('[MW] info list request send');
    } catch (e) {
      debugPrint('[MW] info list request failed: $e');
    }
  }

  Future<void> _sendInfoRequest(int code, String name) async {
    debugPrint("info request send: $code, $name");
    try { 
      await _infoReqPub?.publish({'diag_code': code, 'diag_name': name}); 
    } catch (_) {} 
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? -1;
  }

  List<dynamic> _asList(dynamic v) => (v is List) ? v : const [];

  Future<void> _onInfoListResponse(Map<String, dynamic> msg) async {
    _listRetryTimer?.cancel();

    final codes = _asList(msg['diag_codes']);
    final names = _asList(msg['diag_names']);

    final seen = <int>{};
    bool addedAny = false;

    final int n = codes.length.min(names.length);
    for (int i = 0; i < n; i++) {
      final int code = _toInt(codes[i]);
      if (code < 0) continue;

      final String name = '${names[i]}';
      seen.add(code);
      _missCount[code] = 0;
      final existed = _codeToName.containsKey(code);

      _codeToName[code] = name;

      if (!diagNames.contains(name)) {
        diagNames.add(name);
        addedAny = true;
      }

      topicData[name] = topicData[name] ??
          {
            'name': name,
            'code': code,
            'ret_code': null,
            'ret_text': null,
            'status': null,
            'status_text': 'UNKOWN',
            'message': null,
          };

      if (!existed) {
        await _sendInfoRequest(code, name);
        await Future<void>.delayed(_reqGap);
      }
    }

    final toRemove = <int>[];
    for (final code in _codeToName.keys.toList()) {
      if (seen.contains(code)) continue;

      final nextMiss = (_missCount[code] ?? 0) + 1;
      _missCount[code] = nextMiss;

      if (nextMiss >= _removeAfterMisses) {
        toRemove.add(code);
      }
    }

    for (final code in toRemove) {
      final name = _codeToName.remove(code);
      _missCount.remove(code);

      if (name != null) {
        diagNames.remove(name);
        topicData.remove(name);
      }
    }

    if (toRemove.isNotEmpty) {
      debugPrint('removed by misses($_removeAfterMisses): $toRemove');
    }

    _detailTimer ??= Timer.periodic(_detailRefreshEvery, (_) async {
      for (final e in _codeToName.entries) {
        await _sendInfoRequest(e.key, e.value);
        await Future<void>.delayed(_reqGap);
      }
    });

    if (addedAny) {
      debugPrint('diag list updated. total=${diagNames.length}');
    }
  }

  int? _extractRetCode(dynamic raw) {
    if (raw is Map && raw['ret_code'] is num) return (raw['ret_code'] as num).toInt();
    if (raw is num) return raw.toInt();
    return null;
  }

  int? _extractDiagStatus(dynamic raw) {
    if (raw is Map && raw['diag_status'] is num) return (raw['diag_status'] as num).toInt();
    if (raw is num) return raw.toInt();
    return null;
  }

  Future<void> _onInfoResponse(Map<String, dynamic> msg) async {
    debugPrint("_onInfoResponse(): $msg");

    final code = _toInt(msg['diag_code']);
    final String name = _codeToName[code] ?? '${msg['diag_name'] ?? 'unknown'}';

    final int? ret = _extractRetCode(msg['ret_code']);
    final int? stat = _extractDiagStatus(msg['status']);

    final info = {
      'name': name,
      'code': code,
      'ret_code': ret,
      'ret_text': ret != null ? (_retText[ret] ?? '$ret') : null,
      'status': stat,
      'status_text': stat != null ? (_statusText[stat] ?? '$stat') : null,
      'message': msg['message'],
    };

    topicData[name] = info;

    diagLogs.insert(0, info);
    if (diagLogs.length > _maxLogs) {
      diagLogs.removeRange(_maxLogs, diagLogs.length);
    }
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

// 작은 유틸: min 확장 (null 안전)
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
  late final Ros ros = Get.find<Ros>();
  final Topic Function(Ros ros, String name, String type) topicFactory;

  final RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  final RxList<String> diagNames = <String>[].obs;

  final Map<int, String> _codeToName = {};

  final Map<int, int> _missCount = {};

  static const int _removeAfterMisses = 2;

  static const _pkg = 'diagnosticmgr/msg';
  late final Topic _infoReqPub;
  late final Topic _infoListReqPub;
  late final Topic _infoRespSub;
  late final Topic _infoListRespSub;

  final Duration _reqGap = const Duration(milliseconds: 100);
  final Duration _detailRefreshEvery = const Duration(seconds: 5);
  final Duration _listRefreshEvery = const Duration(seconds: 5);

  Timer? _listRetryTimer;
  Timer? _listPollTimer;
  Timer? _detailTimer;

  //bool _gotListOnce = false;
  bool _advertised = false;

  MwCollector({required this.topicFactory});

  @override
  void onInit() {
    super.onInit();
    _prepareTopics();
    _wireSubs();
    _start();
  }

  @override
  void onClose() {
    _missCount.clear();
    _listRetryTimer?.cancel();
    _listPollTimer?.cancel();
    _detailTimer?.cancel();

    try {
      _infoListRespSub.unsubscribe();
      _infoRespSub.unsubscribe();
    } catch (_) {}
    try {
      _infoReqPub.unadvertise();
      _infoListReqPub.unadvertise();
    } catch (_) {}
    super.onClose();
  }

  void _prepareTopics() {
    _infoReqPub = topicFactory(ros, '/mmf/diagnosticmgr/DiagnosticInfoRequest',
        '$_pkg/DiagnosticInfoRequest');
    _infoListReqPub = topicFactory(
        ros,
        '/mmf/diagnosticmgr/DiagnosticInfoListRequest',
        '$_pkg/DiagnosticInfoListRequest');
    _infoRespSub = topicFactory(
        ros,
        '/mmf/diagnosticmgr/DiagnosticInfoResponse',
        '$_pkg/DiagnosticInfoResponse');
    _infoListRespSub = topicFactory(
        ros,
        '/mmf/diagnosticmgr/DiagnosticInfoListResponse',
        '$_pkg/DiagnosticInfoListResponse');
  }

  void _wireSubs() {
    _infoListRespSub.subscribe(_onInfoListResponse);
    _infoRespSub.subscribe(_onInfoResponse);
  }

  Future<void> _advertiseOnce() async {
    if (_advertised) return;
    await _infoListReqPub.advertise();
    await _infoReqPub.advertise();
    _advertised = true;
  }

  Future<void> _start() async {
    await _advertiseOnce();

    _kickInfoListWithRetryUntilFirstResponse();

    _listPollTimer?.cancel();
    _listPollTimer = Timer.periodic(_listRefreshEvery, (_) async {
      await _sendInfoListRequest();
    });
  }

  // ===== 퍼블리시 =====

  Future<void> _sendInfoListRequest() async {
    try {
      await _infoListReqPub.publish({});
      debugPrint('[MwCollector] info list request send');
    } catch (e) {
      debugPrint('[MwCollector] info list request failed: $e');
    }
  }

  void _kickInfoListWithRetryUntilFirstResponse() {
    _listRetryTimer?.cancel();

    Duration delay = const Duration(seconds: 1);
    const maxDelay = Duration(seconds: 8);

    Future<void> loop() async {
      try {
        await _sendInfoListRequest();
      } catch (_) {}

      _listRetryTimer = Timer(delay, () async {
        delay = delay * 2;
        if (delay > maxDelay) delay = maxDelay;
        await loop();
      });
    }

    unawaited(loop());

  }

  Future<void> _sendInfoRequest(int code, String name) async {
    debugPrint("info request send");
    try {
      await _infoReqPub.publish({'diag_code': code, 'diag_name': name});
    } catch (_) {}
  }

  // == parsing ==
  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? -1;
  }

  List<dynamic> _asList(dynamic v) => (v is List) ? v : const []; 

  // ===== 핸들러 =====
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

      topicData[name] = topicData[name] ?? {
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

    // 이번 응답에서 안보인 애들
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
      debugPrint('[MwCollector] removed by misses($_removeAfterMisses): $toRemove');
    }

    _detailTimer ??= Timer.periodic(_detailRefreshEvery, (_) async {
      for (final e in _codeToName.entries) {
        await _sendInfoRequest(e.key, e.value);
        await Future<void>.delayed(_reqGap);
      }
    });

    if (addedAny) {
      debugPrint('[MwCollector] diag list updated. total=${diagNames.length}');
    }

  }

  int? _extractRetCode(dynamic raw) {
    if (raw is Map && raw['ret_code'] is num)
      return (raw['ret_code'] as num).toInt();
    if (raw is num) return raw.toInt();
    return null;
  }

  int? _extractDiagStatus(dynamic raw) {
    if (raw is Map && raw['diag_status'] is num)
      return (raw['diag_status'] as num).toInt();
    if (raw is num) return raw.toInt();
    return null;
  }

  Future<void> _onInfoResponse(Map<String, dynamic> msg) async {
    debugPrint("_onInfoResponse()");

    final code = _toInt(msg['diag_code']);
    // _logInfoResponse(msg);

    // final int code = msg['diag_code'] is int
    //     ? msg['diag_code'] as int
    //     : int.tryParse('${msg['diag_code']}') ?? -1;

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
  }
}

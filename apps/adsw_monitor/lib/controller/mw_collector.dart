// import 'package:roslibdart/roslibdart.dart';
// import 'package:get/get.dart';

// class MwCollector extends GetxController {
//   late Ros ros = Get.find<Ros>();
//   RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
//   List<SubscribeHandler> handlerList = [];

//   final Topic Function(Ros ros, String name, String type) topicFactory;

//   final Map<int, String> diagList = {};

//   MwCollector({required this.topicFactory}) {
//     handlerList = [handleLifecycle, handleSecurity, ];


//   }

//   void subscribeTopic(List<String> topics, List<String> types, List<SubscribeHandler> handlers){

//     for(int i=0;i<topics.length;i++) {
//       final topic = topicFactory(ros, topics[i], types[i]);
//       topic.subscribe(handlers[i]);
//     }

//   }

//   Future<void> handleLifecycle(Map<String, dynamic> msg) async {

//     topicData['Diagnostic status'] = msg['diag_name'];

//   }

//   Future<void> handleSecurity(Map<String, dynamic> msg) async {

//     topicData['Security status'] = msg;

//     // 보안 문제 검사 코드

//   }

// }

import 'dart:async';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

class MwCollector extends GetxController {
  // 의존성
  late final Ros ros = Get.find<Ros>();
  final Topic Function(Ros ros, String name, String type) topicFactory;

  // UI 바인딩: name -> status
  final RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  // 표시 순서 보존용
  final RxList<String> diagNames = <String>[].obs;

  // 내부 매핑: code -> name
  final Map<int, String> _codeToName = {};

  // 토픽들 (패키지명은 환경에 맞게 조정)
  static const _pkg = 'diagnosticmgr/msg'; // 또는 'diagnosticmgr_msgs/msg'
  late final Topic _infoReqPub;
  late final Topic _infoListReqPub;
  late final Topic _infoRespSub;
  late final Topic _infoListRespSub;

  // 재시도/주기
  final Duration _reqGap = const Duration(milliseconds: 120);
  final Duration _detailRefreshEvery = const Duration(seconds: 10);
  Timer? _listRetryTimer;
  Timer? _detailTimer;
  bool _gotListOnce = false;
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
    _listRetryTimer?.cancel();
    _detailTimer?.cancel();
    try { _infoListRespSub.unsubscribe(); _infoRespSub.unsubscribe(); } catch (_) {}
    try { _infoReqPub.unadvertise(); _infoListReqPub.unadvertise(); } catch (_) {}
    super.onClose();
  }

  void _prepareTopics() {
    _infoReqPub = topicFactory(ros, '/mmf/diagnosticmgr/DiagnosticInfoRequest',       '$_pkg/DiagnosticInfoRequest');
    _infoListReqPub = topicFactory(ros, '/mmf/diagnosticmgr/DiagnosticInfoListRequest','$_pkg/DiagnosticInfoListRequest');
    _infoRespSub = topicFactory(ros, '/mmf/diagnosticmgr/DiagnosticInfoResponse',     '$_pkg/DiagnosticInfoResponse');
    _infoListRespSub = topicFactory(ros, '/mmf/diagnosticmgr/DiagnosticInfoListResponse','$_pkg/DiagnosticInfoListResponse');
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
    _kickInfoListWithRetry(); // 외부 프로그램이 늦게 떠도 받게 지수 백오프 재시도
  }

  // ===== 퍼블리시 =====
  void _kickInfoListWithRetry() {
    _listRetryTimer?.cancel();
    Duration delay = const Duration(seconds: 1);
    const maxDelay = Duration(seconds: 8);

    Future<void> loop() async {
      if (_gotListOnce) return;
      try { await _infoListReqPub.publish({}); } catch (_) {}
      _listRetryTimer = Timer(delay, () async {
        if (_gotListOnce) return;
        delay = delay * 2; if (delay > maxDelay) delay = maxDelay;
        await loop();
      });
    }
    // 즉시 시작
    unawaited(loop());
  }

  Future<void> _sendInfoRequest(int code, String name) async {
    try { await _infoReqPub.publish({'diag_code': code, 'diag_name': name}); } catch (_) {}
  }

  // ===== 핸들러 =====
  Future<void> _onInfoListResponse(Map<String, dynamic> msg) async {
    final List codes = (msg['diag_codes'] ?? []) as List;
    final List names = (msg['diag_names'] ?? []) as List;

    _codeToName.clear();
    diagNames.clear();

    for (int i = 0; i < codes.length && i < names.length; i++) {
      final int code = codes[i] is int ? codes[i] as int : int.tryParse('${codes[i]}') ?? -1;
      final String name = '${names[i]}';
      if (code >= 0) {
        _codeToName[code] = name;
        diagNames.add(name);
        // 초기 상태값을 미리 비워둠(뷰에서 바로 렌더 가능)
        topicData[name] = topicData[name] ?? '-';
      }
    }

    if (_codeToName.isNotEmpty) {
      _gotListOnce = true;
      _listRetryTimer?.cancel();
    }

    // 상세 요청 순차 발사
    for (final e in _codeToName.entries) {
      await _sendInfoRequest(e.key, e.value);
      await Future<void>.delayed(_reqGap);
    }

    // 주기 갱신(상세만)
    _detailTimer?.cancel();
    _detailTimer = Timer.periodic(_detailRefreshEvery, (_) async {
      for (final e in _codeToName.entries) {
        await _sendInfoRequest(e.key, e.value);
        await Future<void>.delayed(_reqGap);
      }
    });
  }

  Future<void> _onInfoResponse(Map<String, dynamic> msg) async {
    final int code = msg['diag_code'] is int ? msg['diag_code'] as int : int.tryParse('${msg['diag_code']}') ?? -1;
    final String name = _codeToName[code] ?? '${msg['diag_name'] ?? 'unknown'}';

    final dynamic status = _extractStatus(msg['status']); // enum 포맷 다양성 대비
    topicData[name] = status;
  }

  dynamic _extractStatus(dynamic raw) {
    if (raw is Map && raw.containsKey('diag_status')) return raw['diag_status'];
    return raw;
  }
}

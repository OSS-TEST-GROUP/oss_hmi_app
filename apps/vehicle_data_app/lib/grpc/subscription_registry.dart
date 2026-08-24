import 'package:flutter/material.dart';

class SubscriptionRegistry {
  final Map<String, bool> _active = {};           // subId -> isActive
  final Map<String, DateTime> _createdAt = {};    // 생성시각 (옵션)
  final Map<String, String?> _client = {};        // peer/authority (옵션)
  final Map<String, String> _path = {};

  final ValueNotifier<int> activeCount = ValueNotifier<int>(0);

  void add(String subId, {String? client, required String pathPattern}) {
    _active[subId] = true;
    _createdAt[subId] = DateTime.now().toUtc();
    _client[subId] = client;
    _path[subId] = pathPattern;
    _recount();
    debugPrint('!!!!---- $subId가 추가됨!!');
  }

  void cancel(String subId) {                     // unsubscribe 시 비활성화
    if (_active.containsKey(subId)) {
      _active[subId] = false;
      _recount();
    }
    debugPrint('!!!!---- unsubscribe 들어왔나봐 비활성화로 만듦');
  }

  void remove(String subId) {                     // 스트림 종료 시 완전 제거
    _active.remove(subId);
    _createdAt.remove(subId);
    _client.remove(subId);
    _path.remove(subId);
    _recount();
    debugPrint('!!!!---- stream이 종료되어 완전 제거됨: $subId');
  }

  bool isActive(String subId) => _active[subId] == true;

  String? clientLabel(String subId) => _client[subId];
  String? pathPatternOf(String subId) => _path[subId];

  void _recount() {
    activeCount.value = _active.values.where((v) => v == true).length;
  }

  List<String> debugSnapshot() => _active.keys.map((k) {
    final st = _active[k] == true ? 'ACTIVE' : 'INACTIVE';
    return 'subId=$k [$st] client=${_client[k] ?? '-'} path=${_path[k] ?? '-'}';
  }).toList();
}
import 'package:flutter/foundation.dart';

class DataCache {
  // DataCache._();
  // static final DataCache instance = DataCache._();

  // Map<String, dynamic>? _last;
  // Map<String, dynamic>? get last => _last;

  // void update(Map<String, dynamic> data) {
  //   _last = Map<String, dynamic>.from(data); // 방어적 복사
  // }

  // bool get hasData => _last != null && _last!.isNotEmpty;
  DataCache._();
  static final instance = DataCache._();

  final ValueNotifier<Map<String, dynamic>> _notifier =
      ValueNotifier<Map<String, dynamic>>({});

  ValueListenable<Map<String, dynamic>> get listenable => _notifier;

  void update(Map<String, dynamic> data) {
    _notifier.value = Map<String, dynamic>.from(data);
  }

  Map<String, dynamic> get last => _notifier.value;
}
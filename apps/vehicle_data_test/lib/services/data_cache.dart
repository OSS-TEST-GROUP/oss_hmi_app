class DataCache {
  DataCache._();
  static final DataCache instance = DataCache._();

  Map<String, dynamic>? _last;
  Map<String, dynamic>? get last => _last;

  void update(Map<String, dynamic> data) {
    _last = Map<String, dynamic>.from(data); // 방어적 복사
  }

  bool get hasData => _last != null && _last!.isNotEmpty;
}
import 'dart:core';

class AppConfig {
  final Uri rosUrl;
  final String statusTopic;

  /// Initial application names to seed the app list at startup (F004).
  final List<String> initialApps;

  /// RosKeeper watchdog poll interval in seconds (F005).
  final int rosReconnectIntervalSec;

  /// Status heartbeat publish interval in seconds (F005).
  final int heartbeatIntervalSec;

  /// Maximum number of entries retained in the update history (F005).
  final int historySize;

  /// Character count at which settings/state strings are truncated in UI (F005).
  final int truncateLength;

  /// UI theme name. Either 'light' (Tesla-inspired, default) or 'dark'
  /// (the original OTA Monitor palette). Persisted in config.json.
  final String theme;

  AppConfig({
    required this.rosUrl,
    required this.statusTopic,
    this.initialApps = const [],
    this.rosReconnectIntervalSec = 2,
    this.heartbeatIntervalSec = 1,
    this.historySize = 20,
    this.truncateLength = 100,
    this.theme = 'light',
  });

  factory AppConfig.defaults() => AppConfig(
        rosUrl: Uri.parse('ws://localhost:9090'),
        statusTopic: '/app_status/ota_monitor',
      );

  /// F008: produce a new AppConfig with selected fields overridden.
  /// All AppConfig fields are final, so callers must build a new instance
  /// when applying runtime changes (e.g. rosbridge URL from Settings UI).
  AppConfig copyWith({
    Uri? rosUrl,
    String? statusTopic,
    List<String>? initialApps,
    int? rosReconnectIntervalSec,
    int? heartbeatIntervalSec,
    int? historySize,
    int? truncateLength,
    String? theme,
  }) =>
      AppConfig(
        rosUrl: rosUrl ?? this.rosUrl,
        statusTopic: statusTopic ?? this.statusTopic,
        initialApps: initialApps ?? this.initialApps,
        rosReconnectIntervalSec:
            rosReconnectIntervalSec ?? this.rosReconnectIntervalSec,
        heartbeatIntervalSec:
            heartbeatIntervalSec ?? this.heartbeatIntervalSec,
        historySize: historySize ?? this.historySize,
        truncateLength: truncateLength ?? this.truncateLength,
        theme: theme ?? this.theme,
      );

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        rosUrl: Uri.parse(
          (j['rosbridge']?['url'] as String?) ?? 'ws://localhost:9090',
        ),
        statusTopic:
            (j['statusTopic'] as String?) ?? '/app_status/ota_monitor',
        initialApps: _parseStringList(j['initialApps']),
        rosReconnectIntervalSec:
            _asPositiveInt(j['rosReconnectIntervalSec'], 2),
        heartbeatIntervalSec: _asPositiveInt(j['heartbeatIntervalSec'], 1),
        historySize: _asPositiveInt(j['historySize'], 20),
        truncateLength: _asPositiveInt(j['truncateLength'], 100),
        theme: _parseTheme(j['theme']),
      );

  static String _parseTheme(dynamic v) {
    if (v is String && (v == 'dark' || v == 'light')) return v;
    return 'light';
  }

  static List<String> _parseStringList(dynamic v) {
    if (v is! List) return const [];
    return v.whereType<String>().toList(growable: false);
  }

  static int _asPositiveInt(dynamic v, int fallback) {
    if (v is int && v > 0) return v;
    if (v is num && v > 0) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null && parsed > 0) return parsed;
    }
    return fallback;
  }
}

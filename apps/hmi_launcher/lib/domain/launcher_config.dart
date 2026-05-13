/// L009: Configuration for the unified launcher ROS keeper.
///
/// Simplified from ota_monitor's AppConfig. Launcher shares a single
/// Ros instance across all embedded plugins.
class LauncherConfig {
  final Uri rosUrl;
  final String statusTopic;

  /// RosKeeper watchdog poll interval in seconds.
  final int rosReconnectIntervalSec;

  /// Status heartbeat publish interval in seconds.
  final int heartbeatIntervalSec;

  final String otaTheme;
  final String adswTheme;

  LauncherConfig({
    required this.rosUrl,
    required this.statusTopic,
    this.rosReconnectIntervalSec = 2,
    this.heartbeatIntervalSec = 1,
    this.otaTheme = 'light',
    this.adswTheme = 'light',
  });

  factory LauncherConfig.defaults() => LauncherConfig(
        rosUrl: Uri.parse('ws://localhost:9090'),
        statusTopic: '/app_status/hmi_launcher',
      );

  factory LauncherConfig.fromJson(Map<String, dynamic> j) => LauncherConfig(
        rosUrl: Uri.parse(
          (j['rosbridge']?['url'] as String?) ?? 'ws://localhost:9090',
        ),
        statusTopic:
            (j['statusTopic'] as String?) ?? '/app_status/hmi_launcher',
        rosReconnectIntervalSec:
            _asPositiveInt(j['rosReconnectIntervalSec'], 2),
        heartbeatIntervalSec: _asPositiveInt(j['heartbeatIntervalSec'], 1),
        otaTheme: _asThemeName(j['otaTheme']),
        adswTheme: _asThemeName(j['adswTheme']),
      );

  static int _asPositiveInt(dynamic v, int fallback) {
    if (v is int && v > 0) return v;
    if (v is num && v > 0) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null && parsed > 0) return parsed;
    }
    return fallback;
  }

  static String _asThemeName(dynamic v) {
    return v == 'dark' ? 'dark' : 'light';
  }
}

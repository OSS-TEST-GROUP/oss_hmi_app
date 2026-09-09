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
  final String diagTheme;
  final String lfcTheme;

  LauncherConfig({
    required this.rosUrl,
    required this.statusTopic,
    this.rosReconnectIntervalSec = 2,
    this.heartbeatIntervalSec = 1,
    this.otaTheme = 'light',
    this.adswTheme = 'light',
    this.diagTheme = 'light',
    this.lfcTheme = 'light',
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
        // diag_monitor 는 adsw_monitor 에서 분리된 앱이다. 분리 이전에 저장된
        // 설정에는 diagTheme 가 없으므로 adswTheme 을 물려받아 기존 외관을
        // 유지한다(진단 화면이 adsw 탭이던 시절의 테마).
        diagTheme: _asThemeName(j['diagTheme'] ?? j['adswTheme']),
        lfcTheme: _asThemeName(j['lfcTheme']),
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

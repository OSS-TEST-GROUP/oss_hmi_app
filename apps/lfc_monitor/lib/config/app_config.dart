import 'dart:core';

/// Runtime config for lfc_monitor — loaded from a JSON file next to the
/// binary (see config_loader.dart), with sane in-tree defaults.
class AppConfig {
  AppConfig({
    required this.rosUrl,
    required this.statusTopic,
    required this.pollIntervalSec,
    required this.knownServices,
    this.theme = 'light',
  });

  /// rosbridge_server WebSocket URL — typically the ext-ros2 container on
  /// host network at 9090.
  final Uri rosUrl;

  /// `std_msgs/String` topic this app heartbeats on so the launcher can
  /// detect liveness.
  final String statusTopic;

  /// How often (seconds) lfc_monitor sends GetServiceStateRequest. The host
  /// lifecycle_mgr already polls at 10s; we duplicate at the monitor side so
  /// the UI shows fresh state even right after connecting.
  final int pollIntervalSec;

  /// Optional pre-seeded service list shown before the first
  /// UpdateServiceListResponse / GetServiceStateResponse arrives — purely
  /// cosmetic. Empty list = wait for the registry handshake to populate.
  final List<String> knownServices;

  /// F014: UI theme name — `'light'` (default) or `'dark'`. Persisted by
  /// SettingsController so the user's choice survives restarts.
  final String theme;

  factory AppConfig.defaults() => AppConfig(
        // 최후 fallback 전용. 임베디드 lfc 패널은 launcher 가 주입한 rosUrl
        // (launcher config 파일 → 없으면 launcher 기본값) 을 먼저 사용하고,
        // 주입이 없을 때만 이 localhost 기본값으로 떨어진다.
        rosUrl: Uri.parse('ws://127.0.0.1:9090'),
        statusTopic: '/app_status/lfc_monitor',
        pollIntervalSec: 5,
        knownServices: const <String>[],
        theme: 'light',
      );

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        rosUrl: Uri.parse(
          (j['rosbridge']?['url'] as String?) ?? 'ws://127.0.0.1:9090',
        ),
        statusTopic:
            (j['statusTopic'] as String?) ?? '/app_status/lfc_monitor',
        pollIntervalSec: (j['pollIntervalSec'] as num?)?.toInt() ?? 5,
        knownServices: ((j['knownServices'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        theme: (j['theme'] as String?) ?? 'light',
      );

  /// F014: settings-driven mutation — used by SettingsController when the
  /// user edits rosUrl / theme at runtime so the live RosKeeper is rebuilt
  /// against a fresh config rather than the startup-time one.
  AppConfig copyWith({
    Uri? rosUrl,
    String? statusTopic,
    int? pollIntervalSec,
    List<String>? knownServices,
    String? theme,
  }) =>
      AppConfig(
        rosUrl: rosUrl ?? this.rosUrl,
        statusTopic: statusTopic ?? this.statusTopic,
        pollIntervalSec: pollIntervalSec ?? this.pollIntervalSec,
        knownServices: knownServices ?? this.knownServices,
        theme: theme ?? this.theme,
      );
}

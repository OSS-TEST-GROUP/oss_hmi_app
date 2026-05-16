import 'dart:core';

/// Runtime config for lfc_monitor — loaded from a JSON file next to the
/// binary (see config_loader.dart), with sane in-tree defaults.
class AppConfig {
  AppConfig({
    required this.rosUrl,
    required this.statusTopic,
    required this.pollIntervalSec,
    required this.knownServices,
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

  factory AppConfig.defaults() => AppConfig(
        rosUrl: Uri.parse('ws://127.0.0.1:9090'),
        statusTopic: '/app_status/lfc_monitor',
        pollIntervalSec: 5,
        knownServices: const <String>[],
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
      );
}

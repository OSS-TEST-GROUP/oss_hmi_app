import 'dart:core';

/// Runtime config for rviz2_monitor — loaded from config/config.json next to
/// the binary (see config_loader.dart), with sane in-tree defaults.
///
/// Mirrors lfc_monitor's AppConfig shape, adding [containerName] (the adsw
/// registry key for the rviz2 container) and [rosoutTopic] (the /rosout topic
/// to subscribe to for in-container log lines).
class AppConfig {
  AppConfig({
    required this.rosUrl,
    required this.containerName,
    required this.rosoutTopic,
    required this.pollIntervalSec,
    this.statusTopic = '/app_status/rviz2_monitor',
  });

  /// rosbridge_server WebSocket URL — typically the ext-ros2 container on
  /// host network at 9090.
  final Uri rosUrl;

  /// adsw_manager registry key for the rviz2 container.
  /// ctrl/StartContainer + ctrl/StopContainer use this as container_list[0].
  final String containerName;

  /// ROS topic for /rosout log lines (rcl_interfaces/msg/Log messages).
  /// Filtered by node name containing [containerName] before appending to logs.
  final String rosoutTopic;

  /// How often (seconds) the watchdog polls — kept in parity with lfc.
  final int pollIntervalSec;

  /// std_msgs/String heartbeat topic so the launcher can detect liveness.
  final String statusTopic;

  factory AppConfig.defaults() => AppConfig(
        rosUrl: Uri.parse('ws://127.0.0.1:9090'),
        containerName: 'rviz2',
        rosoutTopic: '/rosout',
        pollIntervalSec: 5,
      );

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        rosUrl: Uri.parse(
          (j['rosbridge']?['url'] as String?) ?? 'ws://127.0.0.1:9090',
        ),
        containerName: (j['containerName'] as String?) ?? 'rviz2',
        rosoutTopic: (j['rosoutTopic'] as String?) ?? '/rosout',
        pollIntervalSec: (j['pollIntervalSec'] as num?)?.toInt() ?? 5,
        statusTopic:
            (j['statusTopic'] as String?) ?? '/app_status/rviz2_monitor',
      );

  /// Settings-driven mutation — allows rebuilding the RosKeeper after a URL
  /// change at runtime without touching the constructor.
  AppConfig copyWith({
    Uri? rosUrl,
    String? containerName,
    String? rosoutTopic,
    int? pollIntervalSec,
    String? statusTopic,
  }) =>
      AppConfig(
        rosUrl: rosUrl ?? this.rosUrl,
        containerName: containerName ?? this.containerName,
        rosoutTopic: rosoutTopic ?? this.rosoutTopic,
        pollIntervalSec: pollIntervalSec ?? this.pollIntervalSec,
        statusTopic: statusTopic ?? this.statusTopic,
      );
}

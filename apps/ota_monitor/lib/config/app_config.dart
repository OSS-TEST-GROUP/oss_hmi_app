import 'dart:core';

class AppConfig {
  final Uri rosUrl;
  final String statusTopic;

  AppConfig({
    required this.rosUrl,
    required this.statusTopic,
  });

  factory AppConfig.defaults() => AppConfig(
        rosUrl: Uri.parse('ws://localhost:9090'),
        statusTopic: '/app_status/ota_monitor',
      );

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        rosUrl: Uri.parse(
          (j['rosbridge']?['url'] as String?) ?? 'ws://localhost:9090',
        ),
        statusTopic:
            (j['statusTopic'] as String?) ?? '/app_status/ota_monitor',
      );
}

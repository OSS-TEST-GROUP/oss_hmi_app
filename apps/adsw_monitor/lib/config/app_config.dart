import 'dart:core';

class AppConfig {
  final Uri rosUrl;
  final String statusTopic;

  AppConfig({
    required this.rosUrl,
    required this.statusTopic,
  });

  factory AppConfig.defaults() => AppConfig(
        rosUrl: Uri.parse('ws://127.0.0.1:9090'),
        statusTopic: '/app_status/adsw_monitor',
      );

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        rosUrl: Uri.parse(
          (j['rosbridge']?['url'] as String?) ?? 'ws://127.0.0.1:9090',
        ),
        statusTopic:
            (j['statusTopic'] as String?) ?? '/app_status/adsw_monitor',
      );
}
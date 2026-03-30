import 'dart:core';

class AppConfig {
  final int ddsDomainId;

  AppConfig({this.ddsDomainId = 0});

  factory AppConfig.defaults() => AppConfig(ddsDomainId: 0);

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        ddsDomainId: (j['dds']?['domain_id'] as int?) ?? 0,
      );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ota_monitor/config/app_config.dart';

void main() {
  group('AppConfig defaults', () {
    test('defaults returns expected rosUrl and statusTopic', () {
      final cfg = AppConfig.defaults();

      expect(cfg.rosUrl.toString(), 'ws://localhost:9090');
      expect(cfg.statusTopic, '/app_status/ota_monitor');
    });
  });

  group('AppConfig fromJson', () {
    test('reads rosbridge.url and statusTopic when provided', () {
      final json = <String, dynamic>{
        'rosbridge': {'url': 'ws://10.0.0.1:1234'},
        'statusTopic': '/app_status/custom_app',
      };

      final cfg = AppConfig.fromJson(json);

      expect(cfg.rosUrl.toString(), 'ws://10.0.0.1:1234');
      expect(cfg.statusTopic, '/app_status/custom_app');
    });

    test('falls back to defaults when keys are missing', () {
      final cfg = AppConfig.fromJson(<String, dynamic>{});

      expect(cfg.rosUrl.toString(), 'ws://localhost:9090');
      expect(cfg.statusTopic, '/app_status/ota_monitor');
    });

    test('uses default rosUrl when rosbridge.url is null', () {
      final json = <String, dynamic>{
        'rosbridge': {'url': null},
        'statusTopic': '/app_status/only_topic',
      };

      final cfg = AppConfig.fromJson(json);

      expect(cfg.rosUrl.toString(), 'ws://localhost:9090');
      expect(cfg.statusTopic, '/app_status/only_topic');
    });

    test('uses default statusTopic when field is null', () {
      final json = <String, dynamic>{
        'rosbridge': {'url': 'ws://192.168.0.10:9090'},
        'statusTopic': null,
      };

      final cfg = AppConfig.fromJson(json);

      expect(cfg.rosUrl.toString(), 'ws://192.168.0.10:9090');
      expect(cfg.statusTopic, '/app_status/ota_monitor');
    });
  });
}

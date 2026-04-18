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

  // ── F005: configurable polling / history / truncate ─────────────────────

  group('AppConfig F005 new fields', () {
    test('defaults populate new fields with documented values', () {
      final cfg = AppConfig.defaults();
      expect(cfg.initialApps, isEmpty);
      expect(cfg.rosReconnectIntervalSec, 2);
      expect(cfg.heartbeatIntervalSec, 1);
      expect(cfg.historySize, 20);
      expect(cfg.truncateLength, 100);
    });

    test('fromJson parses all F005 fields when provided', () {
      final cfg = AppConfig.fromJson(<String, dynamic>{
        'initialApps': ['NavigationApp', 'MapUpdater'],
        'rosReconnectIntervalSec': 5,
        'heartbeatIntervalSec': 3,
        'historySize': 50,
        'truncateLength': 200,
      });
      expect(cfg.initialApps, ['NavigationApp', 'MapUpdater']);
      expect(cfg.rosReconnectIntervalSec, 5);
      expect(cfg.heartbeatIntervalSec, 3);
      expect(cfg.historySize, 50);
      expect(cfg.truncateLength, 200);
    });

    test('initialApps rejects non-string entries', () {
      final cfg = AppConfig.fromJson(<String, dynamic>{
        'initialApps': ['KeepMe', 42, null, 'AlsoKeep'],
      });
      expect(cfg.initialApps, ['KeepMe', 'AlsoKeep']);
    });

    test('initialApps defaults to empty when value is not a list', () {
      final cfg = AppConfig.fromJson(<String, dynamic>{
        'initialApps': 'not-a-list',
      });
      expect(cfg.initialApps, isEmpty);
    });

    test('zero and negative integers fall back to defaults', () {
      final cfg = AppConfig.fromJson(<String, dynamic>{
        'rosReconnectIntervalSec': 0,
        'heartbeatIntervalSec': -3,
        'historySize': 0,
        'truncateLength': -10,
      });
      expect(cfg.rosReconnectIntervalSec, 2);
      expect(cfg.heartbeatIntervalSec, 1);
      expect(cfg.historySize, 20);
      expect(cfg.truncateLength, 100);
    });

    test('string numbers are accepted when positive', () {
      final cfg = AppConfig.fromJson(<String, dynamic>{
        'historySize': '7',
        'truncateLength': '42',
      });
      expect(cfg.historySize, 7);
      expect(cfg.truncateLength, 42);
    });

    test('garbage string values fall back to defaults', () {
      final cfg = AppConfig.fromJson(<String, dynamic>{
        'historySize': 'abc',
        'truncateLength': '',
      });
      expect(cfg.historySize, 20);
      expect(cfg.truncateLength, 100);
    });

    test('missing new fields keep defaults while other fields still parse', () {
      final cfg = AppConfig.fromJson(<String, dynamic>{
        'rosbridge': {'url': 'ws://x:1'},
        'statusTopic': '/custom',
      });
      expect(cfg.rosUrl.toString(), 'ws://x:1');
      expect(cfg.statusTopic, '/custom');
      expect(cfg.initialApps, isEmpty);
      expect(cfg.historySize, 20);
    });
  });
}

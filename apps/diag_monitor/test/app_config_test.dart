import 'package:flutter_test/flutter_test.dart';
import 'package:diag_monitor/config/app_config.dart';

void main() {
  group('AppConfig defaults', () {
    test('defaults returns expected rosUrl and statusTopic', () {
      // when: 기본값 팩토리 호출
      final cfg = AppConfig.defaults();

      // then: rosUrl / statusTopic이 예상값인지 확인
      expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9090');
      expect(cfg.statusTopic, '/app_status/diag_monitor');
    });
  });

  group('AppConfig fromJson', () {
    test('fromJson reads rosbridge.url and statusTopic when provided', () {
      // given
      final json = <String, dynamic>{
        'rosbridge': {'url': 'ws://10.0.0.1:1234'},
        'statusTopic': '/app_status/custom_app',
      };

      // when
      final cfg = AppConfig.fromJson(json);

      // then
      expect(cfg.rosUrl.toString(), 'ws://10.0.0.1:1234');
      expect(cfg.statusTopic, '/app_status/custom_app');
    });

    test('fromJson falls back to defaults when keys are missing', () {
      // given: 관련 키가 전혀 없는 경우
      final json = <String, dynamic>{};

      // when
      final cfg = AppConfig.fromJson(json);

      // then: defaults와 동일해야 함
      expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9090');
      expect(cfg.statusTopic, '/app_status/diag_monitor');
    });

    test('fromJson uses default rosUrl when rosbridge.url is null', () {
      // given: rosbridge는 있지만 url이 null인 경우
      final json = <String, dynamic>{
        'rosbridge': {'url': null},
        'statusTopic': '/app_status/only_topic',
      };

      // when
      final cfg = AppConfig.fromJson(json);

      // then
      expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9090');
      expect(cfg.statusTopic, '/app_status/only_topic');
    });

    test('fromJson uses default statusTopic when field is null', () {
      // given
      final json = <String, dynamic>{
        'rosbridge': {'url': 'ws://192.168.0.10:9090'},
        'statusTopic': null,
      };

      // when
      final cfg = AppConfig.fromJson(json);

      // then
      expect(cfg.rosUrl.toString(), 'ws://192.168.0.10:9090');
      expect(cfg.statusTopic, '/app_status/diag_monitor');
    });
  });
}

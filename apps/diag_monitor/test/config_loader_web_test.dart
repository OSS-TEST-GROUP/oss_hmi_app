
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diag_monitor/config/config_loader_web.dart';

class MapAssetBundle extends CachingAssetBundle {
  MapAssetBundle(this.assets);

  // key -> asset 내용 문자열
  final Map<String, String> assets;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    // 지정된 key가 없으면 에러를 던져서 "애셋 없음" 시나리오를 만들 수 있음
    final value = assets[key];
    if (value == null) {
      throw FlutterError('Asset not found: $key');
    }
    return value;
  }

  @override
  Future<ByteData> load(String key) {
    // 테스트에서는 사용하지 않는 메소드이므로 구현하지 않고 예외만 던짐
    throw UnimplementedError('load() is not used in tests');
  }
}

class FailingAssetBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    // 항상 실패시키는 번들 (예: 파일 없음, 포맷 깨짐 등)
    throw FlutterError('loadString failed for $key');
  }

  @override
  Future<ByteData> load(String key) {
    // 마찬가지로 테스트에서 직접 호출되지 않음
    throw UnimplementedError('load() is not used in tests');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loadConfig (web)', () {
    test('returns AppConfig from JSON when asset exists and is valid', () async {
      // given: 정상 JSON을 가진 가짜 번들
      final bundle = MapAssetBundle({
        'config/config.json': '''
        {
          "rosbridge": { "url": "ws://10.1.2.3:9090" },
          "statusTopic": "/app_status/web_app"
        }
        ''',
      });

      // when: web용 loadConfig에 가짜 번들을 주입
      final cfg = await loadConfig(null, bundle);

      // then: JSON 내용이 그대로 반영되어야 함
      expect(cfg.rosUrl.toString(), 'ws://10.1.2.3:9090');
      expect(cfg.statusTopic, '/app_status/web_app');
    });

    test('falls back to defaults when asset loading fails', () async {
      // given: 항상 실패하는 번들 (애셋 없음/에러 시나리오)
      final bundle = FailingAssetBundle();

      // when
      final cfg = await loadConfig(null, bundle);

      // then: 기본값으로 fallback 되어야 함
      expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9090');
      expect(cfg.statusTopic, '/app_status/diag_monitor');
    });

    test('falls back to defaults when JSON is invalid', () async {
      // given: 깨진 JSON을 가진 가짜 번들
      final bundle = MapAssetBundle({
        'config/config.json': '{ invalid json ... }',
      });

      // when
      final cfg = await loadConfig(null, bundle);

      // then: 파싱 실패 시에도 기본값 사용
      expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9090');
      expect(cfg.statusTopic, '/app_status/diag_monitor');
    });
  });
}

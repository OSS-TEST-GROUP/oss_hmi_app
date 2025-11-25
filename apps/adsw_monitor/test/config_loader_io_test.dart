// import 'dart:io';

// import 'package:flutter_test/flutter_test.dart';
// import 'package:adsw_monitor/config/config_loader_io.dart';

// void main() {
//   group('loadConfig', () {
//     test('returns defaults when finder returns null', () async {
//       // given: 설정 파일을 찾지 못하는 finder
//       Future<File?> fakeFinder(List<String> args) async {
//         return null; // 파일 없음 시나리오
//       }

//       // when
//       final cfg = await loadConfig(const [], finder: fakeFinder);

//       // then: defaults와 동일한 값이어야 함
//       expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9090');
//       expect(cfg.statusTopic, '/app_status/adsw_monitor');
//     });

//     test('parses valid JSON and returns AppConfig from file', () async {
//       // given: 임시 디렉터리 + JSON config 파일 생성
//       final tempDir = await Directory.systemTemp.createTemp('config_test_');
//       final file = File('${tempDir.path}/config.json');

//       final jsonText = '''
//       {
//         "rosbridge": { "url": "ws://10.0.0.5:1234" },
//         "statusTopic": "/app_status/custom_app"
//       }
//       ''';

//       await file.writeAsString(jsonText);

//       Future<File?> fakeFinder(List<String> args) async {
//         // 항상 위에서 만든 파일을 반환
//         return file;
//       }

//       // when
//       final cfg = await loadConfig(const [], finder: fakeFinder);

//       // then
//       expect(cfg.rosUrl.toString(), 'ws://10.0.0.5:1234');
//       expect(cfg.statusTopic, '/app_status/custom_app');

//       // 정리
//       await tempDir.delete(recursive: true);
//     });

//     test('returns defaults when JSON parsing fails', () async {
//       // given: 잘못된 JSON을 가진 파일
//       final tempDir = await Directory.systemTemp.createTemp('config_test_bad_');
//       final file = File('${tempDir.path}/config_bad.json');

//       await file.writeAsString('{ invalid json,,, }');

//       Future<File?> fakeFinder(List<String> args) async {
//         return file;
//       }

//       // when
//       final cfg = await loadConfig(const [], finder: fakeFinder);

//       // then: 파싱 실패 시 defaults로 fallback
//       expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9090');
//       expect(cfg.statusTopic, '/app_status/adsw_monitor');

//       // 정리
//       await tempDir.delete(recursive: true);
//     });
//   });
// }
// test/config_loader_io_test.dart
import 'dart:io';

import 'package:adsw_monitor/config/app_config.dart';
import 'package:adsw_monitor/config/config_loader_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('loadConfig (io) with injected finder', () {
    test('returns defaults when finder returns null', () async {
      // given: 설정 파일을 찾지 못하는 finder
      Future<File?> fakeFinder(List<String> args) async {
        return null; // 파일 없음 시나리오
      }

      // when
      final cfg = await loadConfig(const [], finder: fakeFinder);

      // then: defaults와 동일한 값이어야 함
      expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9090');
      expect(cfg.statusTopic, '/app_status/adsw_monitor');
    });

    test('parses valid JSON and returns AppConfig from file', () async {
      // given: 임시 디렉터리 + JSON config 파일 생성
      final tempDir = await Directory.systemTemp.createTemp('config_test_ok_');
      final file = File('${tempDir.path}/config.json');

      const jsonText = '''
      {
        "rosbridge": { "url": "ws://10.0.0.5:1234" },
        "statusTopic": "/app_status/custom_app"
      }
      ''';

      await file.writeAsString(jsonText);

      Future<File?> fakeFinder(List<String> args) async {
        // 항상 위에서 만든 파일을 반환
        return file;
      }

      // when
      final cfg = await loadConfig(const [], finder: fakeFinder);

      // then
      expect(cfg.rosUrl.toString(), 'ws://10.0.0.5:1234');
      expect(cfg.statusTopic, '/app_status/custom_app');

      // 정리
      await tempDir.delete(recursive: true);
    });

    test('returns defaults when JSON parsing fails', () async {
      // given: 잘못된 JSON을 가진 파일
      final tempDir =
          await Directory.systemTemp.createTemp('config_test_bad_');
      final file = File('${tempDir.path}/config_bad.json');

      await file.writeAsString('{ invalid json,,, }');

      Future<File?> fakeFinder(List<String> args) async {
        return file;
      }

      // when
      final cfg = await loadConfig(const [], finder: fakeFinder);

      // then: 파싱 실패 시 defaults로 fallback
      expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9090');
      expect(cfg.statusTopic, '/app_status/adsw_monitor');

      // 정리
      await tempDir.delete(recursive: true);
    });
  });

  group('loadConfig (io) with real _findConfigFile', () {
    test('calls _findConfigFile and still returns a valid AppConfig', () async {
      // 이 테스트는 finder를 주입하지 않아서
      // 내부에서 실제 _findConfigFile이 호출됨.
      //
      // 환경에 따라:
      //  - /etc/adsw_monitor/config.json 같은 실제 파일을 찾을 수도 있고
      //  - 아무것도 못 찾아서 defaults로 갈 수도 있음.
      //
      // 중요한 것은:
      //  - _findConfigFile의 모든 분기(ADSW_CONFIG, XDG_CONFIG_HOME/HOME, /etc,
      //    bundle 옆, Android 경로 체크)가 한 번씩은 실행되고
      //  - 예외 없이 AppConfig 하나를 돌려준다는 것.

      final cfg = await loadConfig(const []); // finder 전달 X

      expect(cfg, isA<AppConfig>());
      // 구체적인 값은 환경마다 다를 수 있으므로 타입만 확인
      expect(cfg.rosUrl, isA<Uri>());
      expect(cfg.statusTopic, isA<String>());
    });
  });
}

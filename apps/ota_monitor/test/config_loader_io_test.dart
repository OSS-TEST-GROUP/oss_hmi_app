import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ota_monitor/config/app_config.dart';
import 'package:ota_monitor/config/config_loader_io.dart';

void main() {
  group('loadConfig with injected finder', () {
    test('returns defaults when finder returns null', () async {
      Future<File?> fakeFinder(List<String> args) async => null;

      final cfg = await loadConfig(const [], finder: fakeFinder);

      expect(cfg.rosUrl.toString(), 'ws://localhost:9090');
      expect(cfg.statusTopic, '/app_status/ota_monitor');
    });

    test('parses valid JSON and returns AppConfig from file', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('ota_config_test_ok_');
      final file = File('${tempDir.path}/config.json');
      await file.writeAsString('''
{
  "rosbridge": { "url": "ws://10.0.0.5:1234" },
  "statusTopic": "/app_status/custom_ota"
}
''');

      Future<File?> fakeFinder(List<String> args) async => file;

      final cfg = await loadConfig(const [], finder: fakeFinder);

      expect(cfg.rosUrl.toString(), 'ws://10.0.0.5:1234');
      expect(cfg.statusTopic, '/app_status/custom_ota');

      await tempDir.delete(recursive: true);
    });

    test('returns defaults when JSON parsing fails', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('ota_config_test_bad_');
      final file = File('${tempDir.path}/config_bad.json');
      await file.writeAsString('{ invalid json,,, }');

      Future<File?> fakeFinder(List<String> args) async => file;

      final cfg = await loadConfig(const [], finder: fakeFinder);

      expect(cfg.rosUrl.toString(), 'ws://localhost:9090');
      expect(cfg.statusTopic, '/app_status/ota_monitor');

      await tempDir.delete(recursive: true);
    });
  });

  group('loadConfig with real _findConfigFile', () {
    test('returns a valid AppConfig without throwing', () async {
      final cfg = await loadConfig(const []);

      expect(cfg, isA<AppConfig>());
      expect(cfg.rosUrl, isA<Uri>());
      expect(cfg.statusTopic, isA<String>());
    });
  });
}

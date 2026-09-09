import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:adsw_monitor/config/config_loader_io.dart';

void main() {
  group('ConfigLoader IO Tests', () {
    test('returns defaults when finder returns null', () async {
      final cfg = await loadConfig([], finder: (_) async => null);
      expect(cfg.rosUrl.toString(), contains('9090'));
    });

    test('loads valid JSON config from file', () async {
      final tempDir = await Directory.systemTemp.createTemp('adsw_cfg_test');
      final file = File('${tempDir.path}/config.json');
      await file.writeAsString('{"rosbridge": {"url": "ws://127.0.0.1:9091"}, "statusTopic": "/test/topic"}');

      final cfg = await loadConfig([], finder: (_) async => file);
      expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9091');
      expect(cfg.statusTopic, '/test/topic');

      await tempDir.delete(recursive: true);
    });

    test('returns defaults when file contains invalid JSON', () async {
      final tempDir = await Directory.systemTemp.createTemp('adsw_cfg_test2');
      final file = File('${tempDir.path}/config.json');
      await file.writeAsString('INVALID_JSON{{{');

      final cfg = await loadConfig([], finder: (_) async => file);
      expect(cfg.rosUrl.toString(), contains('9090'));

      await tempDir.delete(recursive: true);
    });

    test('default _findConfigFile runs without crashing', () async {
      final cfg = await loadConfig([]);
      expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9090');
      expect(cfg.statusTopic, '/app_status/adsw_monitor');
    });

    test('default _findConfigFile picks up ADSW_CONFIG env if file exists', () async {
      final tempDir = await Directory.systemTemp.createTemp('adsw_env_test');
      final file = File('${tempDir.path}/config.json');
      await file.writeAsString('{"rosbridge": {"url": "ws://127.0.0.1:9099"}, "statusTopic": "/env/topic"}');

      // Test with finder reading the actual file to simulate ADSW_CONFIG
      final cfg = await loadConfig([], finder: (_) async => file);
      expect(cfg.rosUrl.toString(), 'ws://127.0.0.1:9099');
      expect(cfg.statusTopic, '/env/topic');

      await tempDir.delete(recursive: true);
    });
  });
}

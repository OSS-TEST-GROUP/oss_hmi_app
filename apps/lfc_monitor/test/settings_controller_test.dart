// QA(docs/qa): lfc_monitor SettingsController — URL 검증/적용, 테마, 원자적 파일 기록, keeper 교체.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:lfc_monitor/config/app_config.dart';
import 'package:lfc_monitor/controller/settings_controller.dart';
import 'package:lfc_monitor/ros_keeper.dart';

class MockRosKeeper extends Mock implements RosKeeper {}

void main() {
  late Directory tmp;
  late File cfgFile;
  late MockRosKeeper current;
  late RosKeeper written;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('lfc_settings_');
    cfgFile = File('${tmp.path}/config.json');
    current = MockRosKeeper();
    when(() => current.cfg).thenReturn(AppConfig.defaults());
    when(() => current.stop()).thenAnswer((_) async {});
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  SettingsController make() => SettingsController(
        initialConfig: AppConfig.defaults(),
        readKeeper: () => current,
        writeKeeper: (next) => written = next,
        keeperFactory: (cfg) {
          final k = MockRosKeeper();
          when(() => k.cfg).thenReturn(cfg);
          when(() => k.start()).thenAnswer((_) async {});
          when(() => k.stop()).thenAnswer((_) async {});
          return k;
        },
        configFilePathResolver: () async => cfgFile,
      );

  group('isValidUrl', () {
    test('빈 문자열/과다길이/비ws → false', () {
      expect(SettingsController.isValidUrl(''), isFalse);
      expect(SettingsController.isValidUrl('http://x'), isFalse);
      expect(SettingsController.isValidUrl('ws://${'a' * 3000}'), isFalse);
    });
    test('정상 ws/wss → true', () {
      expect(SettingsController.isValidUrl('ws://localhost:9090'), isTrue);
      expect(SettingsController.isValidUrl('wss://host/path'), isTrue);
    });
  });

  test('applyUrl: 유효 → 파일 기록 + keeper 교체', () async {
    final ok = await make().applyUrl('ws://192.168.0.7:9090');
    expect(ok, isTrue);
    expect(cfgFile.existsSync(), isTrue);
    final saved = json.decode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
    expect((saved['rosbridge'] as Map)['url'], 'ws://192.168.0.7:9090');
    verify(() => current.stop()).called(1);
    expect(written, isNotNull);
  });

  test('applyUrl: 무효 → false, 파일 미생성', () async {
    final ok = await make().applyUrl('not-a-url');
    expect(ok, isFalse);
    expect(cfgFile.existsSync(), isFalse);
  });

  test('applyTheme: light/dark → true 기록, 그 외 → false', () async {
    final c = make();
    expect(await c.applyTheme('dark'), isTrue);
    final saved = json.decode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
    expect(saved['theme'], 'dark');
    expect(await c.applyTheme('rainbow'), isFalse);
  });

  test('_writeJsonField: 기존 파일 병합(파싱)', () async {
    cfgFile.writeAsStringSync(json.encode({'keep': 1}));
    await make().applyTheme('light');
    final saved = json.decode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
    expect(saved['keep'], 1); // 기존 값 보존
    expect(saved['theme'], 'light');
  });

  test('_writeJsonField: 손상된 기존 파일 → 새로 덮어씀', () async {
    cfgFile.writeAsStringSync('{ broken json');
    final ok = await make().applyTheme('dark');
    expect(ok, isTrue);
    final saved = json.decode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
    expect(saved['theme'], 'dark');
  });

  test('resetToDefault: 초기 config URL 로 복원', () async {
    final ok = await make().resetToDefault();
    expect(ok, isTrue);
    expect(cfgFile.existsSync(), isTrue);
  });
}

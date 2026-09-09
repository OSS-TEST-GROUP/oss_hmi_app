// QA(docs/qa): ota_monitor SettingsController — applyTheme / resetToDefault /
// _writeJsonField 엣지(기존 파일 병합·손상 복구). applyUrl 은 기존 테스트가 커버.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ota_monitor/config/app_config.dart';
import 'package:ota_monitor/controller/settings_controller.dart';
import 'package:ota_monitor/ros/ros_keeper.dart';

class MockRosKeeper extends Mock implements RosKeeper {}

void main() {
  late Directory tmp;
  late File cfgFile;
  late MockRosKeeper current;

  AppConfig cfg() =>
      AppConfig(rosUrl: Uri.parse('ws://localhost:9090'), statusTopic: '/x');

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ota_settings_');
    cfgFile = File('${tmp.path}/config.json');
    current = MockRosKeeper();
    when(() => current.cfg).thenReturn(cfg());
    when(() => current.stop()).thenAnswer((_) async {});
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  SettingsController make() => SettingsController(
        initialConfig: cfg(),
        readKeeper: () => current,
        writeKeeper: (_) {},
        keeperFactory: (c) {
          final k = MockRosKeeper();
          when(() => k.cfg).thenReturn(c);
          when(() => k.start()).thenAnswer((_) async {});
          when(() => k.stop()).thenAnswer((_) async {});
          return k;
        },
        configFilePathResolver: () async => cfgFile,
      );

  test('applyTheme: dark/light 기록, 그 외 false', () async {
    final c = make();
    expect(await c.applyTheme('dark'), isTrue);
    expect((json.decode(cfgFile.readAsStringSync()) as Map)['theme'], 'dark');
    expect(await c.applyTheme('neon'), isFalse);
  });

  test('_writeJsonField: 기존 파일 병합(다른 키 보존)', () async {
    cfgFile.writeAsStringSync(json.encode({'keep': 42}));
    await make().applyTheme('light');
    final saved = json.decode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
    expect(saved['keep'], 42);
    expect(saved['theme'], 'light');
  });

  test('_writeJsonField: 손상 파일 → 새로 덮어씀', () async {
    cfgFile.writeAsStringSync('{ not json');
    expect(await make().applyTheme('dark'), isTrue);
    expect((json.decode(cfgFile.readAsStringSync()) as Map)['theme'], 'dark');
  });

  test('resetToDefault: 초기 URL 로 복원(파일 기록 + keeper 교체)', () async {
    final ok = await make().resetToDefault();
    expect(ok, isTrue);
    expect(cfgFile.existsSync(), isTrue);
    verify(() => current.stop()).called(1);
  });

  test('applyUrl 후 rosbridge.url 기록', () async {
    await make().applyUrl('wss://board.local:9090/rosbridge');
    final saved = json.decode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
    expect((saved['rosbridge'] as Map)['url'], 'wss://board.local:9090/rosbridge');
  });
}

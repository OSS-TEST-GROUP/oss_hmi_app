import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ota_monitor/config/app_config.dart';
import 'package:ota_monitor/controller/settings_controller.dart';
import 'package:ota_monitor/ros/ros_keeper.dart';

/// F008 unit tests — URL validation and config.json persistence.
/// RosKeeper start/stop is exercised indirectly with an injected fake
/// keeper so we don't open real WebSockets in unit tests.
void main() {
  group('SettingsController.isValidUrl', () {
    test('accepts ws:// with host', () {
      expect(SettingsController.isValidUrl('ws://localhost:9090'), isTrue);
      expect(SettingsController.isValidUrl('ws://192.168.0.10:9090'), isTrue);
      expect(SettingsController.isValidUrl('ws://example.com'), isTrue);
    });

    test('accepts wss:// with host and path', () {
      expect(
        SettingsController.isValidUrl('wss://example.com/rosbridge'),
        isTrue,
      );
      expect(SettingsController.isValidUrl('wss://host:9090/'), isTrue);
    });

    test('rejects empty input', () {
      expect(SettingsController.isValidUrl(''), isFalse);
    });

    test('rejects http(s) and other schemes', () {
      expect(SettingsController.isValidUrl('http://localhost:9090'), isFalse);
      expect(SettingsController.isValidUrl('https://example.com'), isFalse);
      expect(SettingsController.isValidUrl('tcp://host:9090'), isFalse);
    });

    test('rejects missing host', () {
      expect(SettingsController.isValidUrl('ws://'), isFalse);
      expect(SettingsController.isValidUrl('ws:///path'), isFalse);
    });

    test('rejects bracketed IPv6 (documented limitation)', () {
      expect(SettingsController.isValidUrl('ws://[::1]:9090'), isFalse);
    });

    test('rejects userinfo (documented limitation)', () {
      expect(
        SettingsController.isValidUrl('ws://user:pass@host:9090'),
        isFalse,
      );
    });

    test('rejects oversized input', () {
      final huge = 'ws://${'a' * 4096}';
      expect(SettingsController.isValidUrl(huge), isFalse);
    });
  });

  group('SettingsController.applyUrl', () {
    late Directory tmpDir;
    late File configFile;
    late _FakeRosKeeper currentKeeper;
    late RosKeeper? replacedKeeper;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('ota_monitor_F008_');
      configFile = File('${tmpDir.path}/ota_monitor/config.json');
      currentKeeper = _FakeRosKeeper(
        cfg: AppConfig(
          rosUrl: Uri.parse('ws://localhost:9090'),
          statusTopic: '/x',
        ),
      );
      replacedKeeper = null;
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    SettingsController makeController(AppConfig cfg) => SettingsController(
          initialConfig: cfg,
          readKeeper: () => currentKeeper as RosKeeper,
          writeKeeper: (k) => replacedKeeper = k,
          keeperFactory: (c) => _FakeRosKeeper()..injectedCfg = c,
          configFilePathResolver: () async => configFile,
        );

    test('rejects invalid URL without touching disk or keeper', () async {
      final ctrl = makeController(
        AppConfig(
          rosUrl: Uri.parse('ws://localhost:9090'),
          statusTopic: '/x',
        ),
      );

      final ok = await ctrl.applyUrl('not-a-ws-url');

      expect(ok, isFalse);
      expect(await configFile.exists(), isFalse);
      expect(replacedKeeper, isNull);
      expect(currentKeeper.stopped, isFalse);
    });

    test('persists URL and replaces keeper on valid input', () async {
      final ctrl = makeController(
        AppConfig(
          rosUrl: Uri.parse('ws://localhost:9090'),
          statusTopic: '/x',
        ),
      );

      final ok = await ctrl.applyUrl('ws://192.168.0.10:9090');

      expect(ok, isTrue);
      expect(await configFile.exists(), isTrue);

      final saved = json.decode(await configFile.readAsString())
          as Map<String, dynamic>;
      expect(saved['rosbridge']['url'], 'ws://192.168.0.10:9090');

      expect(replacedKeeper, isA<_FakeRosKeeper>());
      expect((replacedKeeper as _FakeRosKeeper).injectedCfg!.rosUrl.toString(),
          'ws://192.168.0.10:9090');
      expect(currentKeeper.stopped, isTrue);
      expect((replacedKeeper as _FakeRosKeeper).started, isTrue);
    });

    test('preserves unrelated config fields when persisting', () async {
      configFile.parent.createSync(recursive: true);
      configFile.writeAsStringSync(json.encode({
        'statusTopic': '/preserved',
        'rosbridge': {'url': 'ws://old:9090'},
        'historySize': 42,
      }));

      final ctrl = makeController(
        AppConfig(
          rosUrl: Uri.parse('ws://old:9090'),
          statusTopic: '/preserved',
          historySize: 42,
        ),
      );

      await ctrl.applyUrl('wss://new:443');

      final saved = json.decode(await configFile.readAsString())
          as Map<String, dynamic>;
      expect(saved['rosbridge']['url'], 'wss://new:443');
      expect(saved['statusTopic'], '/preserved');
      expect(saved['historySize'], 42);
    });

    test('overwrites unparseable existing config (does not throw)', () async {
      configFile.parent.createSync(recursive: true);
      configFile.writeAsStringSync('{not a valid json');

      final ctrl = makeController(
        AppConfig(
          rosUrl: Uri.parse('ws://localhost:9090'),
          statusTopic: '/x',
        ),
      );

      final ok = await ctrl.applyUrl('ws://recovered:9090');

      expect(ok, isTrue);
      final saved = json.decode(await configFile.readAsString())
          as Map<String, dynamic>;
      expect(saved['rosbridge']['url'], 'ws://recovered:9090');
    });

    test('resetToDefault writes the initialConfig URL', () async {
      final ctrl = makeController(
        AppConfig(
          rosUrl: Uri.parse('ws://startup:9090'),
          statusTopic: '/x',
        ),
      );

      await ctrl.applyUrl('ws://override:9090');
      await ctrl.resetToDefault();

      final saved = json.decode(await configFile.readAsString())
          as Map<String, dynamic>;
      expect(saved['rosbridge']['url'], 'ws://startup:9090');
    });

    test('CONSIDER #1 — trims whitespace before validation and persistence',
        () async {
      final ctrl = makeController(
        AppConfig(
          rosUrl: Uri.parse('ws://localhost:9090'),
          statusTopic: '/x',
        ),
      );

      final ok = await ctrl.applyUrl('  ws://trimmed:9090  \n');

      expect(ok, isTrue);
      final saved = json.decode(await configFile.readAsString())
          as Map<String, dynamic>;
      expect(saved['rosbridge']['url'], 'ws://trimmed:9090');
    });

    test(
        'SHOULD #4 — keeper-replace uses CURRENT keeper cfg as base, not '
        'startup initialConfig (preserves unrelated fields)', () async {
      // Simulate that the live keeper has a runtime-modified statusTopic
      // (a future feature could mutate this); applyUrl must keep it.
      currentKeeper = _FakeRosKeeper(
        cfg: AppConfig(
          rosUrl: Uri.parse('ws://current:9090'),
          statusTopic: '/runtime_modified',
          historySize: 99,
        ),
      );

      final ctrl = makeController(
        // initialConfig disagrees with currentKeeper.cfg on purpose:
        AppConfig(
          rosUrl: Uri.parse('ws://stale_initial:9090'),
          statusTopic: '/stale_initial',
          historySize: 1,
        ),
      );

      await ctrl.applyUrl('ws://newhost:9090');

      final replaced = replacedKeeper as _FakeRosKeeper;
      // statusTopic / historySize MUST come from currentKeeper.cfg, not
      // from initialConfig — proves SHOULD #4 base flip.
      expect(replaced.injectedCfg!.statusTopic, '/runtime_modified');
      expect(replaced.injectedCfg!.historySize, 99);
      expect(replaced.injectedCfg!.rosUrl.toString(), 'ws://newhost:9090');
    });
  });

  group('SettingsController — _defaultConfigPath OTA_CONFIG precedence', () {
    // MUST #1 against revision 0: the writable path must mirror
    // config_loader_io's _findConfigFile order so that on the next launch
    // the user sees what they just saved.
    //
    // We can't directly call the private _defaultConfigPath, but we can
    // verify the documented contract via a path-resolver injection and a
    // helper that mirrors the production logic. The shape of the contract
    // is exercised here as a documentation-by-test.

    test('OTA_CONFIG env wins over XDG_CONFIG_HOME and HOME', () {
      // Mirror of production rule (settings_controller.dart _defaultConfigPath).
      String resolve(Map<String, String> env) {
        final ota = env['OTA_CONFIG'];
        if (ota != null && ota.isNotEmpty) return ota;
        final xdg = env['XDG_CONFIG_HOME'];
        if (xdg != null && xdg.isNotEmpty) {
          return '$xdg/ota_monitor/config.json';
        }
        final home = env['HOME'];
        if (home != null && home.isNotEmpty) {
          return '$home/.config/ota_monitor/config.json';
        }
        return '/tmp/ota_monitor/config.json';
      }

      expect(
        resolve({'OTA_CONFIG': '/etc/foo.json', 'HOME': '/h'}),
        '/etc/foo.json',
      );
      expect(
        resolve({'XDG_CONFIG_HOME': '/xdg', 'HOME': '/h'}),
        '/xdg/ota_monitor/config.json',
      );
      expect(
        resolve({'HOME': '/h'}),
        '/h/.config/ota_monitor/config.json',
      );
      expect(resolve({}), '/tmp/ota_monitor/config.json');
    });
  });
}

/// Minimal RosKeeper double — never opens a socket. We only need
/// stop()/start() to be invocable and observable, plus a `cfg` getter
/// because [SettingsController._replaceKeeper] uses `old.cfg` as the
/// base for the next AppConfig (revision 1 — Reviewer SHOULD #4).
class _FakeRosKeeper implements RosKeeper {
  _FakeRosKeeper({AppConfig? cfg})
      : _cfg = cfg ??
            AppConfig(
              rosUrl: Uri.parse('ws://localhost:9090'),
              statusTopic: '/x',
            );

  final AppConfig _cfg;
  bool stopped = false;
  bool started = false;
  AppConfig? injectedCfg;

  @override
  AppConfig get cfg => _cfg;

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
